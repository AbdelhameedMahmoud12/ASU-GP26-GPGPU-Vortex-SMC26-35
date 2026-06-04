// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Pure-RTL IEEE-754 FP32 division unit (a / b).
// 28-stage pipelined restoring long-division on 24-bit mantissas,
// producing a 25-bit quotient. Result is normalized and rounded per frm.
// Stage 0: unpack/classify, Stages 1-25: division iterations,
// Stage 26: normalize/exponent, Stage 27: round/format.

`include "VX_fpu_define.vh"

`ifdef FPU_DSP

module VX_fdiv_unit import VX_gpu_pkg::*, VX_fpu_pkg::*; #(
    parameter LATENCY = `LATENCY_FDIV,
    parameter OUT_REG = 0
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,

    input  wire [2:0]  frm,

    input  wire [31:0] a,
    input  wire [31:0] b,

    output wire [31:0] result,
    output wire [`FP_FLAGS_BITS-1:0] fflags
);

    localparam [31:0] QNAN = 32'h7FC00000;

    // -----------------------------------------------------------------------
    // Stage 0: Unpack & Classify (combinational)
    // -----------------------------------------------------------------------

    wire        sa = a[31], sb = b[31];
    wire [7:0]  ea = a[30:23], eb = b[30:23];
    wire [22:0] ma = a[22:0],  mb = b[22:0];

    wire a_zero  = (ea == 8'h00) && (ma == 23'h0);
    wire b_zero  = (eb == 8'h00) && (mb == 23'h0);
    wire a_inf   = (ea == 8'hFF) && (ma == 23'h0);
    wire b_inf   = (eb == 8'hFF) && (mb == 23'h0);
    wire a_nan   = (ea == 8'hFF) && (ma != 23'h0);
    wire b_nan   = (eb == 8'hFF) && (mb != 23'h0);
    wire a_snan  = a_nan && !ma[22];
    wire b_snan  = b_nan && !mb[22];

    wire res_sign_s0 = sa ^ sb;

    wire sp_NaN_s0  = a_nan | b_nan | (a_inf && b_inf) | (a_zero && b_zero);
    wire sp_NV_s0   = a_snan | b_snan | (a_inf && b_inf) | (a_zero && b_zero);
    wire sp_DZ_s0   = b_zero && !a_nan && !a_zero;
    wire sp_inf_s0  = (a_inf && !b_inf) || sp_DZ_s0;
    wire sp_zero_s0 = (a_zero && !b_zero) || (b_inf && !a_inf);

    wire a_norm = (ea != 8'h00);
    wire b_norm = (eb != 8'h00);
    wire [23:0] a_mant = {a_norm, ma};
    wire [23:0] b_mant_s0 = {b_norm, mb};
    wire [25:0] rem_init = {2'b0, a_mant};

    // -----------------------------------------------------------------------
    // Stage 0 output registers
    // -----------------------------------------------------------------------

    reg [2:0]  frm_s0_r;
    reg        res_sign_s0_r;
    reg [23:0] b_mant_s0_r;
    reg [25:0] rem_s0_r;
    reg        sp_NaN_s0_r, sp_NV_s0_r, sp_DZ_s0_r, sp_inf_s0_r, sp_zero_s0_r;
    reg [7:0]  ea_s0_r, eb_s0_r;

    always @(posedge clk) begin
        if (reset) begin
            frm_s0_r      <= '0;
            res_sign_s0_r <= '0;
            b_mant_s0_r   <= '0;
            rem_s0_r      <= '0;
            sp_NaN_s0_r   <= '0;
            sp_NV_s0_r    <= '0;
            sp_DZ_s0_r    <= '0;
            sp_inf_s0_r   <= '0;
            sp_zero_s0_r  <= '0;
            ea_s0_r       <= '0;
            eb_s0_r       <= '0;
        end else if (enable) begin
            frm_s0_r      <= frm;
            res_sign_s0_r <= res_sign_s0;
            b_mant_s0_r   <= b_mant_s0;
            rem_s0_r      <= rem_init;
            sp_NaN_s0_r   <= sp_NaN_s0;
            sp_NV_s0_r    <= sp_NV_s0;
            sp_DZ_s0_r    <= sp_DZ_s0;
            sp_inf_s0_r   <= sp_inf_s0;
            sp_zero_s0_r  <= sp_zero_s0;
            ea_s0_r       <= ea;
            eb_s0_r       <= eb;
        end
    end

    // -----------------------------------------------------------------------
    // Stages 1–25: Restoring division iterations (generate loop)
    // -----------------------------------------------------------------------

    // Initial values feeding into stage 1 (index 0 wires)
    wire [25:0] rem_in0    = rem_s0_r;
    wire [24:0] quot_in0   = 25'b0;
    wire [23:0] bmant_in0  = b_mant_s0_r;
    wire [2:0]  frm_in0    = frm_s0_r;
    wire        sign_in0   = res_sign_s0_r;
    wire        spNaN_in0  = sp_NaN_s0_r;
    wire        spNV_in0   = sp_NV_s0_r;
    wire        spDZ_in0   = sp_DZ_s0_r;
    wire        spInf_in0  = sp_inf_s0_r;
    wire        spZero_in0 = sp_zero_s0_r;
    wire [7:0]  ea_in0     = ea_s0_r;
    wire [7:0]  eb_in0     = eb_s0_r;

    // Pipeline registers for stages 1-25 (index 1..25 = output of each stage)
    reg [25:0] rem_pipe   [1:25];
    reg [24:0] quot_pipe  [1:25];
    reg [23:0] bmant_pipe [1:25];
    reg [2:0]  frm_pipe   [1:25];
    reg        sign_pipe  [1:25];
    reg        spNaN_pipe [1:25];
    reg        spNV_pipe  [1:25];
    reg        spDZ_pipe  [1:25];
    reg        spInf_pipe [1:25];
    reg        spZero_pipe[1:25];
    reg [7:0]  ea_pipe    [1:25];
    reg [7:0]  eb_pipe    [1:25];

    // Helper wires to select input for each stage
    // Stage s (0-indexed in loop) reads from index s if s>0, else from in0 wires
    genvar s;
    generate
        for (s = 0; s < 25; s = s + 1) begin : g_div_stage
            // Select inputs: stage 0 reads from in0 wires, stages 1+ read from pipe regs
            wire [25:0] rem_in    = (s == 0) ? rem_in0    : rem_pipe[s];
            wire [24:0] quot_in   = (s == 0) ? quot_in0   : quot_pipe[s];
            wire [23:0] bmant_in  = (s == 0) ? bmant_in0  : bmant_pipe[s];
            wire [2:0]  frm_in    = (s == 0) ? frm_in0    : frm_pipe[s];
            wire        sign_in   = (s == 0) ? sign_in0   : sign_pipe[s];
            wire        spNaN_in  = (s == 0) ? spNaN_in0  : spNaN_pipe[s];
            wire        spNV_in   = (s == 0) ? spNV_in0   : spNV_pipe[s];
            wire        spDZ_in   = (s == 0) ? spDZ_in0   : spDZ_pipe[s];
            wire        spInf_in  = (s == 0) ? spInf_in0  : spInf_pipe[s];
            wire        spZero_in = (s == 0) ? spZero_in0 : spZero_pipe[s];
            wire [7:0]  ea_in     = (s == 0) ? ea_in0     : ea_pipe[s];
            wire [7:0]  eb_in     = (s == 0) ? eb_in0     : eb_pipe[s];

            // Division iteration
            wire [25:0] rem_shifted  = rem_in << 1;
            wire [23:0] trial        = rem_shifted[25:2] - bmant_in;
            wire        no_underflow = (rem_shifted[25:2] >= bmant_in);

            always @(posedge clk) begin
                if (reset) begin
                    rem_pipe[s+1]    <= '0;
                    quot_pipe[s+1]   <= '0;
                    bmant_pipe[s+1]  <= '0;
                    frm_pipe[s+1]    <= '0;
                    sign_pipe[s+1]   <= '0;
                    spNaN_pipe[s+1]  <= '0;
                    spNV_pipe[s+1]   <= '0;
                    spDZ_pipe[s+1]   <= '0;
                    spInf_pipe[s+1]  <= '0;
                    spZero_pipe[s+1] <= '0;
                    ea_pipe[s+1]     <= '0;
                    eb_pipe[s+1]     <= '0;
                end else if (enable) begin
                    rem_pipe[s+1]    <= no_underflow ? {trial, rem_shifted[1:0]} : rem_shifted;
                    quot_pipe[s+1]   <= {quot_in[23:0], no_underflow};
                    bmant_pipe[s+1]  <= bmant_in;
                    frm_pipe[s+1]    <= frm_in;
                    sign_pipe[s+1]   <= sign_in;
                    spNaN_pipe[s+1]  <= spNaN_in;
                    spNV_pipe[s+1]   <= spNV_in;
                    spDZ_pipe[s+1]   <= spDZ_in;
                    spInf_pipe[s+1]  <= spInf_in;
                    spZero_pipe[s+1] <= spZero_in;
                    ea_pipe[s+1]     <= ea_in;
                    eb_pipe[s+1]     <= eb_in;
                end
            end
        end
    endgenerate

    // -----------------------------------------------------------------------
    // Stage 26: Normalize & Exponent
    // -----------------------------------------------------------------------

    // Outputs of stage 25 (division complete)
    wire [24:0] quot_done = quot_pipe[25];
    wire [25:0] rem_done  = rem_pipe[25];

    wire sticky_s26 = (rem_done != 26'b0);
    wire guard_s26  = quot_done[0];
    wire [23:0] quot24_s26 = quot_done[24:1];

    // Biased result exponent: ea - eb + 127 (signed 11-bit arithmetic)
    wire [9:0]        ea_ext = {2'b0, ea_pipe[25]};
    wire [9:0]        eb_ext = {2'b0, eb_pipe[25]};
    wire signed [10:0] exp_raw = $signed({1'b0, ea_ext}) - $signed({1'b0, eb_ext}) + 11'sd127;

    // Normalize: if MSB of quot24 is 0, shift left 1 and decrement exponent
    wire        quot_msb_s26 = quot24_s26[23];
    wire [22:0] res_mant_prnd_s26 = quot_msb_s26 ? quot24_s26[22:0] : quot24_s26[21:0];
    wire signed [10:0] exp_adj_s26 = quot_msb_s26 ? exp_raw : (exp_raw - 11'sd1);

    // Stage 26 output registers
    reg [2:0]          frm_s26_r;
    reg                sign_s26_r;
    reg [22:0]         mant_prnd_s26_r;
    reg                guard_s26_r;
    reg                sticky_s26_r;
    reg signed [10:0]  exp_adj_s26_r;
    reg                spNaN_s26_r, spNV_s26_r, spDZ_s26_r, spInf_s26_r, spZero_s26_r;

    always @(posedge clk) begin
        if (reset) begin
            frm_s26_r       <= '0;
            sign_s26_r      <= '0;
            mant_prnd_s26_r <= '0;
            guard_s26_r     <= '0;
            sticky_s26_r    <= '0;
            exp_adj_s26_r   <= '0;
            spNaN_s26_r     <= '0;
            spNV_s26_r      <= '0;
            spDZ_s26_r      <= '0;
            spInf_s26_r     <= '0;
            spZero_s26_r    <= '0;
        end else if (enable) begin
            frm_s26_r       <= frm_pipe[25];
            sign_s26_r      <= sign_pipe[25];
            mant_prnd_s26_r <= res_mant_prnd_s26;
            guard_s26_r     <= guard_s26;
            sticky_s26_r    <= sticky_s26;
            exp_adj_s26_r   <= exp_adj_s26;
            spNaN_s26_r     <= spNaN_pipe[25];
            spNV_s26_r      <= spNV_pipe[25];
            spDZ_s26_r      <= spDZ_pipe[25];
            spInf_s26_r     <= spInf_pipe[25];
            spZero_s26_r    <= spZero_pipe[25];
        end
    end

    // -----------------------------------------------------------------------
    // Stage 27: Round & Format
    // -----------------------------------------------------------------------

    wire [1:0] rs_bits = {guard_s26_r, sticky_s26_r};

    reg round_up;
    always @(*) begin
        case (frm_s26_r)
            3'b000: // RNE
                case (rs_bits)
                    2'b00, 2'b01: round_up = 1'b0;
                    2'b10:        round_up = mant_prnd_s26_r[0];
                    2'b11:        round_up = 1'b1;
                    default:      round_up = 1'b0;
                endcase
            3'b001: round_up = 1'b0;                              // RTZ
            3'b010: round_up = (|rs_bits) &  sign_s26_r;          // RDN
            3'b011: round_up = (|rs_bits) & ~sign_s26_r;          // RUP
            3'b100: round_up = rs_bits[1];                        // RMM
            default: round_up = 1'b0;
        endcase
    end

    wire [23:0]        res_mant_rounded = {1'b0, mant_prnd_s26_r} + {23'b0, round_up};
    wire               carry_out        = res_mant_rounded[23];
    wire [22:0]        res_mant_f       = carry_out ? res_mant_rounded[23:1] : res_mant_rounded[22:0];
    wire signed [10:0] res_exp_f        = carry_out ? (exp_adj_s26_r + 11'sd1) : exp_adj_s26_r;

    // Flags
    wire overflow_s27  = !spNaN_s26_r && !spInf_s26_r && !spZero_s26_r && ($signed(res_exp_f) >= $signed(11'sd255));
    wire underflow_s27 = !spNaN_s26_r && !spInf_s26_r && !spZero_s26_r && ($signed(res_exp_f) <= $signed(11'sd0)) && (|res_mant_f);
    wire inexact_s27   = (|rs_bits) | overflow_s27 | underflow_s27;

    reg [31:0]              result_s27;
    reg [`FP_FLAGS_BITS-1:0] fflags_s27; // {NV, DZ, OF, UF, NX}

    always @(*) begin
        if (spNaN_s26_r) begin
            result_s27 = QNAN;
            fflags_s27 = {spNV_s26_r, 4'b0000};
        end else if (spInf_s26_r) begin
            result_s27 = {sign_s26_r, 8'hFF, 23'h0};
            fflags_s27 = {1'b0, spDZ_s26_r, 1'b0, 1'b0, 1'b0};
        end else if (spZero_s26_r) begin
            result_s27 = {sign_s26_r, 31'b0};
            fflags_s27 = 5'b0;
        end else if (overflow_s27) begin
            result_s27 = {sign_s26_r, 8'hFF, 23'h0};
            fflags_s27 = {1'b0, 1'b0, 1'b1, 1'b0, 1'b1}; // OF, NX
        end else if (underflow_s27) begin
            result_s27 = {sign_s26_r, 8'h00, 23'h0};
            fflags_s27 = {1'b0, 1'b0, 1'b0, 1'b1, 1'b1}; // UF, NX
        end else begin
            result_s27 = {sign_s26_r, res_exp_f[7:0], res_mant_f};
            fflags_s27 = {1'b0, 1'b0, 1'b0, 1'b0, inexact_s27};
        end
    end

    // Stage 27 output registers (drive the module outputs)
    reg [31:0]              result_r;
    reg [`FP_FLAGS_BITS-1:0] fflags_r;

    always @(posedge clk) begin
        if (reset) begin
            result_r <= '0;
            fflags_r <= '0;
        end else if (enable) begin
            result_r <= result_s27;
            fflags_r <= fflags_s27;
        end
    end

    assign result = result_r;
    assign fflags = fflags_r;

endmodule

`endif
