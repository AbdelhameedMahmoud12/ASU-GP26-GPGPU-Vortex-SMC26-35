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

// Pure-RTL IEEE-754 FP32 square root unit.
// Replaces acl_fsqrt (Quartus) and xil_fsqrt (Vivado) for ASIC flow.
// Uses a 25-iteration digit-recurrence (restoring) algorithm on the
// 24-bit significand.  For odd unbiased exponents, shifts mantissa right 1
// before the loop so that the biased output exponent remains integral.
// Fixed-latency: 28 pipeline stages.

`include "VX_fpu_define.vh"

`ifdef FPU_DSP

module VX_fsqrt_unit import VX_gpu_pkg::*, VX_fpu_pkg::*; #(
    parameter LATENCY = `LATENCY_FSQRT,
    parameter OUT_REG = 0
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,
    input  wire [2:0]  frm,
    input  wire [31:0] a,
    output wire [31:0] result,
    output wire [`FP_FLAGS_BITS-1:0] fflags
);

    localparam [31:0] QNAN = 32'h7FC00000;

    // -----------------------------------------------------------------------
    // Stage 0 (Combinational before first register)
    // -----------------------------------------------------------------------
    wire        sa = a[31];
    wire [7:0]  ea = a[30:23];
    wire [22:0] ma = a[22:0];

    wire a_zero = (ea == 8'h00) && (ma == 23'h0);
    wire a_inf  = (ea == 8'hFF) && (ma == 23'h0);
    wire a_nan  = (ea == 8'hFF) && (ma != 23'h0);
    wire a_snan = a_nan && !ma[22];
    wire a_neg  = sa && !a_zero;
    wire a_norm = (ea != 8'h00);

    wire sp_NaN_s0  = a_nan | a_neg;
    wire sp_NV_s0   = a_snan | a_neg;
    wire sp_inf_s0  = a_inf && !a_neg;
    wire sp_zero_s0 = a_zero;

    wire [7:0] ea_m1 = ea - 8'h01;
    wire exp_is_odd = ea_m1[0];
    wire [8:0] res_exp_exact = ({1'b0, ea} + 9'd127) >> 1;
    wire [7:0] res_exp_s0 = res_exp_exact[7:0];

    wire [24:0] sig_in = exp_is_odd ? {2'b01, ma[22:1]} : {1'b1, ma, 1'b0};
    wire [48:0] rem_init = {24'b0, sig_in};

    // Stage 0 Registers
    reg [2:0]  frm_s0_r;
    reg        sa_s0_r;
    reg [7:0]  res_exp_s0_r;
    reg [48:0] rem_s0_r;
    reg        sp_NaN_s0_r;
    reg        sp_NV_s0_r;
    reg        sp_inf_s0_r;
    reg        sp_zero_s0_r;

    always @(posedge clk) begin
        if (reset) begin
            frm_s0_r     <= 3'b0;
            sa_s0_r      <= 1'b0;
            res_exp_s0_r <= 8'b0;
            rem_s0_r     <= 49'b0;
            sp_NaN_s0_r  <= 1'b0;
            sp_NV_s0_r   <= 1'b0;
            sp_inf_s0_r  <= 1'b0;
            sp_zero_s0_r <= 1'b0;
        end else if (enable) begin
            frm_s0_r     <= frm;
            sa_s0_r      <= sa;
            res_exp_s0_r <= res_exp_s0;
            rem_s0_r     <= rem_init;
            sp_NaN_s0_r  <= sp_NaN_s0;
            sp_NV_s0_r   <= sp_NV_s0;
            sp_inf_s0_r  <= sp_inf_s0;
            sp_zero_s0_r <= sp_zero_s0;
        end
    end

    // -----------------------------------------------------------------------
    // Stages 1-25 (Recurrence iterations)
    // -----------------------------------------------------------------------
    wire [48:0] rem_in0 = rem_s0_r;
    wire [24:0] root_in0 = 25'b0;

    reg [48:0] rem_pipe [1:25];
    reg [24:0] root_pipe [1:25];
    reg [2:0]  frm_pipe [1:25];
    reg        sa_pipe [1:25];
    reg [7:0]  res_exp_pipe [1:25];
    reg        sp_NaN_pipe [1:25];
    reg        sp_NV_pipe [1:25];
    reg        sp_inf_pipe [1:25];
    reg        sp_zero_pipe [1:25];

    genvar s;
    generate
        for (s = 0; s < 25; s = s + 1) begin : g_stages
            wire [48:0] rem_in  = (s == 0) ? rem_in0  : rem_pipe[s];
            wire [24:0] root_in = (s == 0) ? root_in0 : root_pipe[s];
            wire [2:0]  frm_in  = (s == 0) ? frm_s0_r  : frm_pipe[s];
            wire        sa_in   = (s == 0) ? sa_s0_r   : sa_pipe[s];
            wire [7:0]  res_exp_in = (s == 0) ? res_exp_s0_r : res_exp_pipe[s];
            wire        sp_NaN_in  = (s == 0) ? sp_NaN_s0_r  : sp_NaN_pipe[s];
            wire        sp_NV_in   = (s == 0) ? sp_NV_s0_r   : sp_NV_pipe[s];
            wire        sp_inf_in  = (s == 0) ? sp_inf_s0_r  : sp_inf_pipe[s];
            wire        sp_zero_in = (s == 0) ? sp_zero_s0_r : sp_zero_pipe[s];

            wire [48:0] rem_shifted = rem_in << 2;
            wire [24:0] root_bit = 25'b1 << (24 - s);

            // Compute subtractor: {1'b0, root_prev, 1'b1} + {24'b0, root_bit}
            // {1'b0, root_in, 1'b1} has 27 bits, which is zero-padded to 49 bits
            wire [48:0] subtractor = {22'b0, {1'b0, root_in, 1'b1}} + {24'b0, root_bit};

            // Compare: rem_shifted[48:24] >= subtractor
            wire rem_ge_sub = ({24'b0, rem_shifted[48:24]} >= subtractor);

            wire [48:0] rem_next;
            wire [24:0] root_next;

            assign rem_next = rem_ge_sub ? {rem_shifted[48:24] - subtractor[24:0], rem_shifted[23:0]} : rem_shifted;
            assign root_next = rem_ge_sub ? (root_in | root_bit) : root_in;

            always @(posedge clk) begin
                if (reset) begin
                    rem_pipe[s+1]     <= 49'b0;
                    root_pipe[s+1]    <= 25'b0;
                    frm_pipe[s+1]     <= 3'b0;
                    sa_pipe[s+1]      <= 1'b0;
                    res_exp_pipe[s+1] <= 8'b0;
                    sp_NaN_pipe[s+1]  <= 1'b0;
                    sp_NV_pipe[s+1]   <= 1'b0;
                    sp_inf_pipe[s+1]  <= 1'b0;
                    sp_zero_pipe[s+1] <= 1'b0;
                end else if (enable) begin
                    rem_pipe[s+1]     <= rem_next;
                    root_pipe[s+1]    <= root_next;
                    frm_pipe[s+1]     <= frm_in;
                    sa_pipe[s+1]      <= sa_in;
                    res_exp_pipe[s+1] <= res_exp_in;
                    sp_NaN_pipe[s+1]  <= sp_NaN_in;
                    sp_NV_pipe[s+1]   <= sp_NV_in;
                    sp_inf_pipe[s+1]  <= sp_inf_in;
                    sp_zero_pipe[s+1] <= sp_zero_in;
                end
            end
        end
    endgenerate

    // -----------------------------------------------------------------------
    // Stage 26 (Extract guard/sticky)
    // -----------------------------------------------------------------------
    wire [48:0] rem_done  = rem_pipe[25];
    wire [24:0] root_done = root_pipe[25];

    wire sticky = (rem_done != 49'b0);
    wire [23:0] root24 = root_done[23:0];
    wire guard_bit = root24[0];
    wire [22:0] res_mant_prnd = root24[23:1];

    reg [2:0]  frm_s26_r;
    reg        sa_s26_r;
    reg [7:0]  res_exp_s26_r;
    reg [22:0] res_mant_prnd_s26_r;
    reg        guard_bit_s26_r;
    reg        sticky_s26_r;
    reg        sp_NaN_s26_r;
    reg        sp_NV_s26_r;
    reg        sp_inf_s26_r;
    reg        sp_zero_s26_r;

    always @(posedge clk) begin
        if (reset) begin
            frm_s26_r           <= 3'b0;
            sa_s26_r            <= 1'b0;
            res_exp_s26_r       <= 8'b0;
            res_mant_prnd_s26_r <= 23'b0;
            guard_bit_s26_r     <= 1'b0;
            sticky_s26_r        <= 1'b0;
            sp_NaN_s26_r        <= 1'b0;
            sp_NV_s26_r         <= 1'b0;
            sp_inf_s26_r        <= 1'b0;
            sp_zero_s26_r       <= 1'b0;
        end else if (enable) begin
            frm_s26_r           <= frm_pipe[25];
            sa_s26_r            <= sa_pipe[25];
            res_exp_s26_r       <= res_exp_pipe[25];
            res_mant_prnd_s26_r <= res_mant_prnd;
            guard_bit_s26_r     <= guard_bit;
            sticky_s26_r        <= sticky;
            sp_NaN_s26_r        <= sp_NaN_pipe[25];
            sp_NV_s26_r         <= sp_NV_pipe[25];
            sp_inf_s26_r        <= sp_inf_pipe[25];
            sp_zero_s26_r       <= sp_zero_pipe[25];
        end
    end

    // -----------------------------------------------------------------------
    // Stage 27 (Round & Format)
    // -----------------------------------------------------------------------
    wire [1:0] rs_bits = {guard_bit_s26_r, sticky_s26_r};
    reg round_up;
    always @(*) begin
        case (frm_s26_r)
            3'b000: // RNE
                case (rs_bits)
                    2'b00, 2'b01: round_up = 1'b0;
                    2'b10:        round_up = res_mant_prnd_s26_r[0];
                    2'b11:        round_up = 1'b1;
                    default:      round_up = 1'b0;
                endcase
            3'b001: round_up = 1'b0;
            3'b010: round_up = (|rs_bits) & 1'b0; // result is always positive; RDN toward zero
            3'b011: round_up = (|rs_bits);        // RUP away from zero
            3'b100: round_up = rs_bits[1];
            default: round_up = 1'b0;
        endcase
    end

    wire [23:0] res_mant_rounded = {1'b0, res_mant_prnd_s26_r} + {23'b0, round_up};
    wire        carry_out = res_mant_rounded[23];
    wire [22:0] res_mant_f = carry_out ? res_mant_rounded[23:1] : res_mant_rounded[22:0];
    wire [7:0]  res_exp_f = carry_out ? (res_exp_s26_r + 8'h01) : res_exp_s26_r;
    wire        inexact = |rs_bits;

    reg [31:0] result_comb;
    reg [`FP_FLAGS_BITS-1:0] fflags_comb;

    always @(*) begin
        if (sp_NaN_s26_r) begin
            result_comb = QNAN;
            fflags_comb = {sp_NV_s26_r, 4'b0000};
        end else if (sp_inf_s26_r) begin
            result_comb = 32'h7F800000;
            fflags_comb = 5'b0;
        end else if (sp_zero_s26_r) begin
            result_comb = {sa_s26_r, 31'b0};
            fflags_comb = 5'b0;
        end else begin
            result_comb = {1'b0, res_exp_f, res_mant_f};
            fflags_comb = {1'b0, 1'b0, 1'b0, 1'b0, inexact};
        end
    end

    // Stage 27 output registers
    reg [31:0] result_r;
    reg [`FP_FLAGS_BITS-1:0] fflags_r;

    always @(posedge clk) begin
        if (reset) begin
            result_r <= 32'b0;
            fflags_r <= 5'b0;
        end else if (enable) begin
            result_r <= result_comb;
            fflags_r <= fflags_comb;
        end
    end

    assign result = result_r;
    assign fflags = fflags_r;

endmodule

`endif
