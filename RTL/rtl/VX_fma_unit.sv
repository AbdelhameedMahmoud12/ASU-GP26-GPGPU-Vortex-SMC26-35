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

// Pure-RTL IEEE-754 FP32 Fused Multiply-Add unit (a * b + c)
// Replaces acl_fmadd (Quartus) and xil_fma (Vivado) for ASIC flow.
// Interface matches the FPU_DSP PE interface used in VX_fpu_fma.sv:
//   - inputs:  a, b, c (FP32), frm (3-bit rounding mode)
//   - outputs: result (FP32), fflags {NV, DZ, OF, UF, NX}
// Pipelined to 10 stages.

`include "VX_fpu_define.vh"

`ifdef FPU_DSP

module VX_fma_unit import VX_gpu_pkg::*, VX_fpu_pkg::*; #(
    parameter LATENCY = `LATENCY_FMA,
    parameter OUT_REG = 0
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        enable,

    input  wire [2:0]  frm,

    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] c,

    output wire [31:0] result,
    output wire [`FP_FLAGS_BITS-1:0] fflags
);
    // -----------------------------------------------------------------------
    // Stage 0: Special case detection & Unpacking
    // -----------------------------------------------------------------------
    wire        sa = a[31], sb = b[31], sc = c[31];
    wire [7:0]  ea = a[30:23], eb = b[30:23], ec = c[30:23];
    wire [22:0] ma = a[22:0],  mb = b[22:0],  mc = c[22:0];

    wire a_zero = (ea == 8'h00) && (ma == 23'h0);
    wire b_zero = (eb == 8'h00) && (mb == 23'h0);
    wire c_zero = (ec == 8'h00) && (mc == 23'h0);
    wire a_inf  = (ea == 8'hFF) && (ma == 23'h0);
    wire b_inf  = (eb == 8'hFF) && (mb == 23'h0);
    wire c_inf  = (ec == 8'hFF) && (mc == 23'h0);
    wire a_nan  = (ea == 8'hFF) && (ma != 23'h0);
    wire b_nan  = (eb == 8'hFF) && (mb != 23'h0);
    wire c_nan  = (ec == 8'hFF) && (mc != 23'h0);
    wire a_snan = a_nan && !ma[22];
    wire b_snan = b_nan && !mb[22];
    wire c_snan = c_nan && !mc[22];

    // Canonical qNaN
    localparam [31:0] QNAN = 32'h7FC00000;

    wire sp_NaN = a_nan | b_nan | c_nan              // any nan
               | (a_inf && b_zero) | (b_inf && a_zero); // inf × 0
    wire sp_NV  = a_snan | b_snan | c_snan
               | (a_inf && b_zero) | (b_inf && a_zero);
    wire sp_inf = (a_inf | b_inf) & ~sp_NaN;
    wire sp_inf_sign = sp_inf ? (sa ^ sb) : 1'b0;
    wire sp_c_inf_conflict = sp_inf && c_inf && ((sa ^ sb) != sc);
    // inf + (-inf) → invalid
    wire sp_NV_final = sp_NV | sp_c_inf_conflict;

    // Implicit leading bits
    wire a_norm = (ea != 8'h0);
    wire b_norm = (eb != 8'h0);
    wire c_norm = (ec != 8'h0);

    wire [23:0] a_mant = {a_norm, ma};
    wire [23:0] b_mant = {b_norm, mb};
    wire [23:0] c_mant = {c_norm, mc};

    // -----------------------------------------------------------------------
    // Stage 1 Registers (registered at end of S0)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s1;
    reg [23:0] a_mant_s1, b_mant_s1, c_mant_s1;
    reg [7:0]  ea_s1, eb_s1, ec_s1;
    reg        sa_s1, sb_s1, sc_s1;
    reg        sp_NaN_s1, sp_NV_final_s1, sp_inf_s1, sp_inf_sign_s1, sp_c_inf_conflict_s1;
    reg        a_zero_s1, b_zero_s1, c_zero_s1;

    always @(posedge clk) begin
        if (reset) begin
            frm_s1 <= '0;
            a_mant_s1 <= '0;
            b_mant_s1 <= '0;
            c_mant_s1 <= '0;
            ea_s1 <= '0;
            eb_s1 <= '0;
            ec_s1 <= '0;
            sa_s1 <= '0;
            sb_s1 <= '0;
            sc_s1 <= '0;
            sp_NaN_s1 <= '0;
            sp_NV_final_s1 <= '0;
            sp_inf_s1 <= '0;
            sp_inf_sign_s1 <= '0;
            sp_c_inf_conflict_s1 <= '0;
            a_zero_s1 <= '0;
            b_zero_s1 <= '0;
            c_zero_s1 <= '0;
        end else if (enable) begin
            frm_s1 <= frm;
            a_mant_s1 <= a_mant;
            b_mant_s1 <= b_mant;
            c_mant_s1 <= c_mant;
            ea_s1 <= ea;
            eb_s1 <= eb;
            ec_s1 <= ec;
            sa_s1 <= sa;
            sb_s1 <= sb;
            sc_s1 <= sc;
            sp_NaN_s1 <= sp_NaN;
            sp_NV_final_s1 <= sp_NV_final;
            sp_inf_s1 <= sp_inf;
            sp_inf_sign_s1 <= sp_inf_sign;
            sp_c_inf_conflict_s1 <= sp_c_inf_conflict;
            a_zero_s1 <= a_zero;
            b_zero_s1 <= b_zero;
            c_zero_s1 <= c_zero;
        end
    end

    // -----------------------------------------------------------------------
    // Stage 2 Registers (registered at end of S1)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s2;
    reg [23:0] c_mant_s2;
    reg [7:0]  ea_s2, eb_s2, ec_s2;
    reg        sa_s2, sb_s2, sc_s2;
    reg        sp_NaN_s2, sp_NV_final_s2, sp_inf_s2, sp_inf_sign_s2, sp_c_inf_conflict_s2;
    reg        a_zero_s2, b_zero_s2, c_zero_s2;
    reg [23:0] pp0, pp1, pp2, pp3;

    always @(posedge clk) begin
        if (reset) begin
            frm_s2 <= '0;
            c_mant_s2 <= '0;
            ea_s2 <= '0;
            eb_s2 <= '0;
            ec_s2 <= '0;
            sa_s2 <= '0;
            sb_s2 <= '0;
            sc_s2 <= '0;
            sp_NaN_s2 <= '0;
            sp_NV_final_s2 <= '0;
            sp_inf_s2 <= '0;
            sp_inf_sign_s2 <= '0;
            sp_c_inf_conflict_s2 <= '0;
            a_zero_s2 <= '0;
            b_zero_s2 <= '0;
            c_zero_s2 <= '0;
            pp0 <= '0;
            pp1 <= '0;
            pp2 <= '0;
            pp3 <= '0;
        end else if (enable) begin
            frm_s2 <= frm_s1;
            c_mant_s2 <= c_mant_s1;
            ea_s2 <= ea_s1;
            eb_s2 <= eb_s1;
            ec_s2 <= ec_s1;
            sa_s2 <= sa_s1;
            sb_s2 <= sb_s1;
            sc_s2 <= sc_s1;
            sp_NaN_s2 <= sp_NaN_s1;
            sp_NV_final_s2 <= sp_NV_final_s1;
            sp_inf_s2 <= sp_inf_s1;
            sp_inf_sign_s2 <= sp_inf_sign_s1;
            sp_c_inf_conflict_s2 <= sp_c_inf_conflict_s1;
            a_zero_s2 <= a_zero_s1;
            b_zero_s2 <= b_zero_s1;
            c_zero_s2 <= c_zero_s1;
            pp0 <= a_mant_s1[11:0]  * b_mant_s1[11:0];
            pp1 <= a_mant_s1[11:0]  * b_mant_s1[23:12];
            pp2 <= a_mant_s1[23:12] * b_mant_s1[11:0];
            pp3 <= a_mant_s1[23:12] * b_mant_s1[23:12];
        end
    end

    // -----------------------------------------------------------------------
    // Stage 3 Registers (registered at end of S2)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s3;
    reg [23:0] c_mant_s3;
    reg [7:0]  ea_s3, eb_s3, ec_s3;
    reg        sa_s3, sb_s3, sc_s3;
    reg        sp_NaN_s3, sp_NV_final_s3, sp_inf_s3, sp_inf_sign_s3, sp_c_inf_conflict_s3;
    reg        a_zero_s3, b_zero_s3, c_zero_s3;
    reg [47:0] prod_mant_s3;

    wire [24:0] sum_mid = pp1 + pp2;
    wire [47:0] prod_mant_comb = {pp3, 24'b0} + {sum_mid, 12'b0} + pp0;

    always @(posedge clk) begin
        if (reset) begin
            frm_s3 <= '0;
            c_mant_s3 <= '0;
            ea_s3 <= '0;
            eb_s3 <= '0;
            ec_s3 <= '0;
            sa_s3 <= '0;
            sb_s3 <= '0;
            sc_s3 <= '0;
            sp_NaN_s3 <= '0;
            sp_NV_final_s3 <= '0;
            sp_inf_s3 <= '0;
            sp_inf_sign_s3 <= '0;
            sp_c_inf_conflict_s3 <= '0;
            a_zero_s3 <= '0;
            b_zero_s3 <= '0;
            c_zero_s3 <= '0;
            prod_mant_s3 <= '0;
        end else if (enable) begin
            frm_s3 <= frm_s2;
            c_mant_s3 <= c_mant_s2;
            ea_s3 <= ea_s2;
            eb_s3 <= eb_s2;
            ec_s3 <= ec_s2;
            sa_s3 <= sa_s2;
            sb_s3 <= sb_s2;
            sc_s3 <= sc_s2;
            sp_NaN_s3 <= sp_NaN_s2;
            sp_NV_final_s3 <= sp_NV_final_s2;
            sp_inf_s3 <= sp_inf_s2;
            sp_inf_sign_s3 <= sp_inf_sign_s2;
            sp_c_inf_conflict_s3 <= sp_c_inf_conflict_s2;
            a_zero_s3 <= a_zero_s2;
            b_zero_s3 <= b_zero_s2;
            c_zero_s3 <= c_zero_s2;
            prod_mant_s3 <= prod_mant_comb;
        end
    end

    // -----------------------------------------------------------------------
    // Stage 3 Combinational Logic (Product normalization & Exponent Prep)
    // -----------------------------------------------------------------------
    wire prod_sign = sa_s3 ^ sb_s3;

    // Product exponent (biased): ea + eb - 127
    wire [9:0] ea_ext = {2'b0, ea_s3};
    wire [9:0] eb_ext = {2'b0, eb_s3};
    wire [9:0] prod_exp_raw = ea_ext + eb_ext - 10'd127;

    // Normalize: if MSB=1 (bit47) then shift right 1
    wire prod_mant_msb = prod_mant_s3[47];
    wire [46:0] prod_mant_norm = prod_mant_msb ? prod_mant_s3[47:1] : prod_mant_s3[46:0];
    wire [9:0]  prod_exp  = prod_mant_msb ? (prod_exp_raw + 10'd1) : prod_exp_raw;

    // exponent of c
    wire [9:0] ec_ext = {2'b0, ec_s3};

    // Determine which is larger
    wire signed [10:0] exp_diff_s = $signed({1'b0, prod_exp}) - $signed({2'b0, ec_ext});
    wire signed_prod_gt = (exp_diff_s >= 0);

    wire [9:0]  larger_exp   = signed_prod_gt ? prod_exp : ec_ext;
    wire [10:0] align_shift  = signed_prod_gt ? exp_diff_s[10:0] : (-exp_diff_s[10:0]);

    // -----------------------------------------------------------------------
    // Stage 4 Registers (registered at end of S3)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s4;
    reg        prod_sign_s4;
    reg        sc_s4;
    reg [9:0]  larger_exp_s4;
    reg [10:0] align_shift_s4;
    reg        signed_prod_gt_s4;
    reg [46:0] prod_mant_norm_s4;
    reg [23:0] c_mant_s4;
    reg        sp_NaN_s4, sp_NV_final_s4, sp_inf_s4, sp_inf_sign_s4, sp_c_inf_conflict_s4;
    reg        a_zero_s4, b_zero_s4, c_zero_s4;

    always @(posedge clk) begin
        if (reset) begin
            frm_s4 <= '0;
            prod_sign_s4 <= '0;
            sc_s4 <= '0;
            larger_exp_s4 <= '0;
            align_shift_s4 <= '0;
            signed_prod_gt_s4 <= '0;
            prod_mant_norm_s4 <= '0;
            c_mant_s4 <= '0;
            sp_NaN_s4 <= '0;
            sp_NV_final_s4 <= '0;
            sp_inf_s4 <= '0;
            sp_inf_sign_s4 <= '0;
            sp_c_inf_conflict_s4 <= '0;
            a_zero_s4 <= '0;
            b_zero_s4 <= '0;
            c_zero_s4 <= '0;
        end else if (enable) begin
            frm_s4 <= frm_s3;
            prod_sign_s4 <= prod_sign;
            sc_s4 <= sc_s3;
            larger_exp_s4 <= larger_exp;
            align_shift_s4 <= align_shift;
            signed_prod_gt_s4 <= signed_prod_gt;
            prod_mant_norm_s4 <= prod_mant_norm;
            c_mant_s4 <= c_mant_s3;
            sp_NaN_s4 <= sp_NaN_s3;
            sp_NV_final_s4 <= sp_NV_final_s3;
            sp_inf_s4 <= sp_inf_s3;
            sp_inf_sign_s4 <= sp_inf_sign_s3;
            sp_c_inf_conflict_s4 <= sp_c_inf_conflict_s3;
            a_zero_s4 <= a_zero_s3;
            b_zero_s4 <= b_zero_s3;
            c_zero_s4 <= c_zero_s3;
        end
    end

    // -----------------------------------------------------------------------
    // Stage 4 Combinational Logic (Alignment shift)
    // -----------------------------------------------------------------------
    wire [70:0] c_mant_wide = {c_mant_s4, 47'b0};
    wire [70:0] p_mant_wide = {prod_mant_norm_s4, 24'b0};

    // Shift the smaller operand right, collecting sticky
    wire [70:0] c_shifted     = (c_mant_wide >> (signed_prod_gt_s4 ? align_shift_s4 : 11'b0));
    wire [70:0] p_shifted     = (p_mant_wide >> (signed_prod_gt_s4 ? 11'b0 : align_shift_s4));

    wire c_sticky_lost = (c_mant_wide & ~({71{1'b1}} << (signed_prod_gt_s4 ? align_shift_s4 : 11'b0))) != 71'b0;
    wire p_sticky_lost = (p_mant_wide & ~({71{1'b1}} << (signed_prod_gt_s4 ? 11'b0 : align_shift_s4))) != 71'b0;

    // -----------------------------------------------------------------------
    // Stage 5 Registers (registered at end of S4)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s5;
    reg        prod_sign_s5, sc_s5;
    reg [9:0]  larger_exp_s5;
    reg [70:0] c_shifted_s5;
    reg [70:0] p_shifted_s5;
    reg        c_sticky_lost_s5, p_sticky_lost_s5;
    reg        sp_NaN_s5, sp_NV_final_s5, sp_inf_s5, sp_inf_sign_s5, sp_c_inf_conflict_s5;
    reg        a_zero_s5, b_zero_s5, c_zero_s5;

    always @(posedge clk) begin
        if (reset) begin
            frm_s5 <= '0;
            prod_sign_s5 <= '0;
            sc_s5 <= '0;
            larger_exp_s5 <= '0;
            c_shifted_s5 <= '0;
            p_shifted_s5 <= '0;
            c_sticky_lost_s5 <= '0;
            p_sticky_lost_s5 <= '0;
            sp_NaN_s5 <= '0;
            sp_NV_final_s5 <= '0;
            sp_inf_s5 <= '0;
            sp_inf_sign_s5 <= '0;
            sp_c_inf_conflict_s5 <= '0;
            a_zero_s5 <= '0;
            b_zero_s5 <= '0;
            c_zero_s5 <= '0;
        end else if (enable) begin
            frm_s5 <= frm_s4;
            prod_sign_s5 <= prod_sign_s4;
            sc_s5 <= sc_s4;
            larger_exp_s5 <= larger_exp_s4;
            c_shifted_s5 <= c_shifted;
            p_shifted_s5 <= p_shifted;
            c_sticky_lost_s5 <= c_sticky_lost;
            p_sticky_lost_s5 <= p_sticky_lost;
            sp_NaN_s5 <= sp_NaN_s4;
            sp_NV_final_s5 <= sp_NV_final_s4;
            sp_inf_s5 <= sp_inf_s4;
            sp_inf_sign_s5 <= sp_inf_sign_s4;
            sp_c_inf_conflict_s5 <= sp_c_inf_conflict_s4;
            a_zero_s5 <= a_zero_s4;
            b_zero_s5 <= b_zero_s4;
            c_zero_s5 <= c_zero_s4;
        end
    end

    // -----------------------------------------------------------------------
    // Stage 5 Combinational Logic (Low 36-bit addition/subtraction)
    // -----------------------------------------------------------------------
    wire eff_sub = (prod_sign_s5 ^ sc_s5);

    wire [36:0] sum_raw_low = eff_sub ? ({1'b0, p_shifted_s5[35:0]} - {1'b0, c_shifted_s5[35:0]})
                                     : ({1'b0, p_shifted_s5[35:0]} + {1'b0, c_shifted_s5[35:0]});

    // -----------------------------------------------------------------------
    // Stage 6 Registers (registered at end of S5)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s6;
    reg        prod_sign_s6, sc_s6;
    reg [9:0]  larger_exp_s6;
    reg        c_sticky_lost_s6, p_sticky_lost_s6;
    reg        sp_NaN_s6, sp_NV_final_s6, sp_inf_s6, sp_inf_sign_s6, sp_c_inf_conflict_s6;
    reg        a_zero_s6, b_zero_s6, c_zero_s6;
    reg [35:0] sum_raw_low_s6;
    reg        carry_borrow_s6;
    reg [34:0] p_shifted_high_s6;
    reg [34:0] c_shifted_high_s6;
    reg        eff_sub_s6;

    always @(posedge clk) begin
        if (reset) begin
            frm_s6 <= '0;
            prod_sign_s6 <= '0;
            sc_s6 <= '0;
            larger_exp_s6 <= '0;
            c_sticky_lost_s6 <= '0;
            p_sticky_lost_s6 <= '0;
            sp_NaN_s6 <= '0;
            sp_NV_final_s6 <= '0;
            sp_inf_s6 <= '0;
            sp_inf_sign_s6 <= '0;
            sp_c_inf_conflict_s6 <= '0;
            a_zero_s6 <= '0;
            b_zero_s6 <= '0;
            c_zero_s6 <= '0;
            sum_raw_low_s6 <= '0;
            carry_borrow_s6 <= '0;
            p_shifted_high_s6 <= '0;
            c_shifted_high_s6 <= '0;
            eff_sub_s6 <= '0;
        end else if (enable) begin
            frm_s6 <= frm_s5;
            prod_sign_s6 <= prod_sign_s5;
            sc_s6 <= sc_s5;
            larger_exp_s6 <= larger_exp_s5;
            c_sticky_lost_s6 <= c_sticky_lost_s5;
            p_sticky_lost_s6 <= p_sticky_lost_s5;
            sp_NaN_s6 <= sp_NaN_s5;
            sp_NV_final_s6 <= sp_NV_final_s5;
            sp_inf_s6 <= sp_inf_s5;
            sp_inf_sign_s6 <= sp_inf_sign_s5;
            sp_c_inf_conflict_s6 <= sp_c_inf_conflict_s5;
            a_zero_s6 <= a_zero_s5;
            b_zero_s6 <= b_zero_s5;
            c_zero_s6 <= c_zero_s5;
            sum_raw_low_s6 <= sum_raw_low[35:0];
            carry_borrow_s6 <= sum_raw_low[36];
            p_shifted_high_s6 <= p_shifted_s5[70:36];
            c_shifted_high_s6 <= c_shifted_s5[70:36];
            eff_sub_s6 <= eff_sub;
        end
    end

    // -----------------------------------------------------------------------
    // Stage 6 Combinational Logic (High 36-bit add/sub & absolute value)
    // -----------------------------------------------------------------------
    wire [35:0] sum_raw_high = eff_sub_s6 ? (p_shifted_high_s6 - c_shifted_high_s6 - {34'b0, carry_borrow_s6})
                                          : (p_shifted_high_s6 + c_shifted_high_s6 + {34'b0, carry_borrow_s6});

    wire [71:0] sum_raw = {sum_raw_high, sum_raw_low_s6};

    wire sum_sign_raw = sum_raw[71] ? sc_s6 : prod_sign_s6;
    wire [70:0] sum_abs      = sum_raw[71] ? (~sum_raw[70:0] + 71'b1) : sum_raw[70:0];

    wire sum_zero = (sum_abs == 71'b0);

    // -----------------------------------------------------------------------
    // Stage 7 Registers (registered at end of S6)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s7;
    reg        sum_sign_s7;
    reg [70:0] sum_abs_s7;
    reg        sum_zero_s7;
    reg [9:0]  larger_exp_s7;
    reg        c_sticky_lost_s7, p_sticky_lost_s7;
    reg        sp_NaN_s7, sp_NV_final_s7, sp_inf_s7, sp_inf_sign_s7, sp_c_inf_conflict_s7;
    reg        a_zero_s7, b_zero_s7, c_zero_s7;

    always @(posedge clk) begin
        if (reset) begin
            frm_s7 <= '0;
            sum_sign_s7 <= '0;
            sum_abs_s7 <= '0;
            sum_zero_s7 <= '0;
            larger_exp_s7 <= '0;
            c_sticky_lost_s7 <= '0;
            p_sticky_lost_s7 <= '0;
            sp_NaN_s7 <= '0;
            sp_NV_final_s7 <= '0;
            sp_inf_s7 <= '0;
            sp_inf_sign_s7 <= '0;
            sp_c_inf_conflict_s7 <= '0;
            a_zero_s7 <= '0;
            b_zero_s7 <= '0;
            c_zero_s7 <= '0;
        end else if (enable) begin
            frm_s7 <= frm_s6;
            sum_sign_s7 <= sum_sign_raw;
            sum_abs_s7 <= sum_abs;
            sum_zero_s7 <= sum_zero;
            larger_exp_s7 <= larger_exp_s6;
            c_sticky_lost_s7 <= c_sticky_lost_s6;
            p_sticky_lost_s7 <= p_sticky_lost_s6;
            sp_NaN_s7 <= sp_NaN_s6;
            sp_NV_final_s7 <= sp_NV_final_s6;
            sp_inf_s7 <= sp_inf_s6;
            sp_inf_sign_s7 <= sp_inf_sign_s6;
            sp_c_inf_conflict_s7 <= sp_c_inf_conflict_s6;
            a_zero_s7 <= a_zero_s6;
            b_zero_s7 <= b_zero_s6;
            c_zero_s7 <= c_zero_s6;
        end
    end

    // -----------------------------------------------------------------------
    // Stage 7 Combinational Logic (LZC and normalize shift)
    // -----------------------------------------------------------------------
    // Leading-zero count on sum_abs_s7[70:0]
    reg [6:0] lzc;
    integer jj;
    always @(*) begin
        lzc = 7'd70;
        for (jj = 70; jj >= 0; jj--) begin
            if (sum_abs_s7[jj]) lzc = 7'(70 - jj);
        end
    end

    wire [70:0] sum_norm   = sum_abs_s7 << lzc;
    wire [9:0]  res_exp_raw = larger_exp_s7 - {3'b0, lzc[6:0]};

    // -----------------------------------------------------------------------
    // Stage 8 Registers (registered at end of S7)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s8;
    reg        sum_sign_s8;
    reg        sum_zero_s8;
    reg [70:0] sum_norm_s8;
    reg [9:0]  res_exp_raw_s8;
    reg        c_sticky_lost_s8, p_sticky_lost_s8;
    reg        sp_NaN_s8, sp_NV_final_s8, sp_inf_s8, sp_inf_sign_s8, sp_c_inf_conflict_s8;
    reg        a_zero_s8, b_zero_s8, c_zero_s8;

    always @(posedge clk) begin
        if (reset) begin
            frm_s8 <= '0;
            sum_sign_s8 <= '0;
            sum_zero_s8 <= '0;
            sum_norm_s8 <= '0;
            res_exp_raw_s8 <= '0;
            c_sticky_lost_s8 <= '0;
            p_sticky_lost_s8 <= '0;
            sp_NaN_s8 <= '0;
            sp_NV_final_s8 <= '0;
            sp_inf_s8 <= '0;
            sp_inf_sign_s8 <= '0;
            sp_c_inf_conflict_s8 <= '0;
            a_zero_s8 <= '0;
            b_zero_s8 <= '0;
            c_zero_s8 <= '0;
        end else if (enable) begin
            frm_s8 <= frm_s7;
            sum_sign_s8 <= sum_sign_s7;
            sum_zero_s8 <= sum_zero_s7;
            sum_norm_s8 <= sum_norm;
            res_exp_raw_s8 <= res_exp_raw;
            c_sticky_lost_s8 <= c_sticky_lost_s7;
            p_sticky_lost_s8 <= p_sticky_lost_s7;
            sp_NaN_s8 <= sp_NaN_s7;
            sp_NV_final_s8 <= sp_NV_final_s7;
            sp_inf_s8 <= sp_inf_s7;
            sp_inf_sign_s8 <= sp_inf_sign_s7;
            sp_c_inf_conflict_s8 <= sp_c_inf_conflict_s7;
            a_zero_s8 <= a_zero_s7;
            b_zero_s8 <= b_zero_s7;
            c_zero_s8 <= c_zero_s7;
        end
    end

    // -----------------------------------------------------------------------
    // Stage 8 Combinational Logic (Extract mantissa & rounding decision)
    // -----------------------------------------------------------------------
    // Extract mantissa bits [69:47] (23 bits after implicit 1)
    wire [22:0] res_mant_prnd = sum_norm_s8[69:47];
    wire        guard_bit      = sum_norm_s8[46];
    wire        round_bit      = sum_norm_s8[45];
    wire        sticky_in      = (sum_norm_s8[44:0] != 45'b0) | c_sticky_lost_s8 | p_sticky_lost_s8;
    wire [1:0]  rs_bits        = {guard_bit, round_bit | sticky_in};

    reg round_up;
    always @(*) begin
        case (frm_s8)
            3'b000: // RNE
                case (rs_bits)
                    2'b00, 2'b01: round_up = 1'b0;
                    2'b10:        round_up = res_mant_prnd[0];
                    2'b11:        round_up = 1'b1;
                    default:      round_up = 1'b0;
                endcase
            3'b001: round_up = 1'b0;                                 // RTZ
            3'b010: round_up = (|rs_bits) &  sum_sign_s8;          // RDN
            3'b011: round_up = (|rs_bits) & ~sum_sign_s8;          // RUP
            3'b100: round_up = rs_bits[1];                           // RMM
            default: round_up = 1'b0;
        endcase
    end

    wire [23:0] res_mant_rounded = {1'b0, res_mant_prnd} + {23'b0, round_up};
    wire        carry_out        = res_mant_rounded[23];
    wire [22:0] res_mant_final  = carry_out ? res_mant_rounded[23:1] : res_mant_rounded[22:0];
    wire [9:0]  res_exp_final   = carry_out ? (res_exp_raw_s8 + 10'd1) : res_exp_raw_s8;

    // -----------------------------------------------------------------------
    // Stage 9 Registers (registered at end of S8)
    // -----------------------------------------------------------------------
    reg [2:0]  frm_s9;
    reg        sum_sign_s9;
    reg        sum_zero_s9;
    reg [22:0] res_mant_final_s9;
    reg [9:0]  res_exp_final_s9;
    reg [1:0]  rs_bits_s9;
    reg        sp_NaN_s9, sp_NV_final_s9, sp_inf_s9, sp_inf_sign_s9, sp_c_inf_conflict_s9;
    reg        a_zero_s9, b_zero_s9, c_zero_s9;

    always @(posedge clk) begin
        if (reset) begin
            frm_s9 <= '0;
            sum_sign_s9 <= '0;
            sum_zero_s9 <= '0;
            res_mant_final_s9 <= '0;
            res_exp_final_s9 <= '0;
            rs_bits_s9 <= '0;
            sp_NaN_s9 <= '0;
            sp_NV_final_s9 <= '0;
            sp_inf_s9 <= '0;
            sp_inf_sign_s9 <= '0;
            sp_c_inf_conflict_s9 <= '0;
            a_zero_s9 <= '0;
            b_zero_s9 <= '0;
            c_zero_s9 <= '0;
        end else if (enable) begin
            frm_s9 <= frm_s8;
            sum_sign_s9 <= sum_sign_s8;
            sum_zero_s9 <= sum_zero_s8;
            res_mant_final_s9 <= res_mant_final;
            res_exp_final_s9 <= res_exp_final;
            rs_bits_s9 <= rs_bits;
            sp_NaN_s9 <= sp_NaN_s8;
            sp_NV_final_s9 <= sp_NV_final_s8;
            sp_inf_s9 <= sp_inf_s8;
            sp_inf_sign_s9 <= sp_inf_sign_s8;
            sp_c_inf_conflict_s9 <= sp_c_inf_conflict_s8;
            a_zero_s9 <= a_zero_s8;
            b_zero_s9 <= b_zero_s8;
            c_zero_s9 <= c_zero_s8;
        end
    end

    // -----------------------------------------------------------------------
    // Stage 9 Combinational Logic (Formatting & Output Muxing)
    // -----------------------------------------------------------------------
    wire overflow  = !sp_NaN_s9 && !sp_inf_s9 && ($signed(res_exp_final_s9) >= $signed(10'd255));
    wire underflow = !sp_NaN_s9 && !sp_inf_s9 && ($signed(res_exp_final_s9) <= $signed(10'd0)) && (|res_mant_final_s9);
    wire inexact   = (|rs_bits_s9) | overflow | underflow;

    wire [31:0] res_normal = {sum_sign_s9, res_exp_final_s9[7:0], res_mant_final_s9};
    wire [31:0] res_inf    = {sp_inf_sign_s9,  8'hFF, 23'h0};

    reg [31:0] result_comb;
    reg [`FP_FLAGS_BITS-1:0] fflags_comb;

    always @(*) begin
        if (sp_NaN_s9 | sp_c_inf_conflict_s9) begin
            result_comb = QNAN;
            fflags_comb = {sp_NV_final_s9, 4'b0000};
        end else if (sp_inf_s9) begin
            result_comb = res_inf;
            fflags_comb = 5'b0;
        end else if (sum_zero_s9) begin
            // +0 unless RDN and both zero of same sign, negative
            result_comb = (frm_s9 == 3'b010) ? {1'b1, 31'b0} : 32'h00000000;
            fflags_comb = 5'b0;
        end else if (overflow) begin
            // overflow → ±inf
            result_comb = {sum_sign_s9, 8'hFF, 23'h0};
            fflags_comb = {1'b0, 1'b0, 1'b1, 1'b0, 1'b1};   // OF, NX
        end else if (underflow) begin
            result_comb = {sum_sign_s9, 8'h00, 23'h0};
            fflags_comb = {1'b0, 1'b0, 1'b0, 1'b1, 1'b1};   // UF, NX
        end else begin
            result_comb = res_normal;
            fflags_comb = {1'b0, 1'b0, 1'b0, 1'b0, inexact}; // NX
        end
    end

    // -----------------------------------------------------------------------
    // Stage 10 Output Registers (registered at end of S9)
    // -----------------------------------------------------------------------
    reg [31:0] result_r;
    reg [`FP_FLAGS_BITS-1:0] fflags_r;

    always @(posedge clk) begin
        if (reset) begin
            result_r <= '0;
            fflags_r <= '0;
        end else if (enable) begin
            result_r <= result_comb;
            fflags_r <= fflags_comb;
        end
    end

    assign result = result_r;
    assign fflags = fflags_r;

endmodule

`endif
