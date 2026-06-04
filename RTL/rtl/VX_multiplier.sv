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

`include "VX_platform.vh"

`TRACING_OFF
module VX_multiplier #(
    parameter A_WIDTH = 1,
    parameter B_WIDTH = A_WIDTH,
    parameter R_WIDTH = A_WIDTH + B_WIDTH,
    parameter SIGNED  = 0,
    parameter LATENCY = 0
) (
    input wire clk,
    input wire enable,
    input wire [A_WIDTH-1:0]  dataa,
    input wire [B_WIDTH-1:0]  datab,
    output wire [R_WIDTH-1:0] result
);
    if (A_WIDTH == 33 && B_WIDTH == 33 && SIGNED != 0 && LATENCY == 3) begin : g_imul_3stage
        // 3-stage pipelined 33x33 signed multiplier for ASIC timing closure at 200 MHz.
        // Stage 0: Split inputs
        // Stage 1: Register split inputs
        // Stage 2: Register partial products
        // Stage 3: Register final sum

        reg [15:0] a_low_s1;
        reg signed [16:0] a_high_s1;
        reg [15:0] b_low_s1;
        reg signed [16:0] b_high_s1;

        always_ff @(posedge clk) begin
            if (enable) begin
                a_low_s1  <= dataa[15:0];
                a_high_s1 <= $signed(dataa[32:16]);
                b_low_s1  <= datab[15:0];
                b_high_s1 <= $signed(datab[32:16]);
            end
        end

        reg [31:0] p00_s2;
        reg signed [32:0] p01_s2;
        reg signed [32:0] p10_s2;
        reg signed [33:0] p11_s2;

        always_ff @(posedge clk) begin
            if (enable) begin
                p00_s2 <= a_low_s1 * b_low_s1;
                p01_s2 <= $signed({1'b0, a_low_s1}) * b_high_s1;
                p10_s2 <= a_high_s1 * $signed({1'b0, b_low_s1});
                p11_s2 <= a_high_s1 * b_high_s1;
            end
        end

        reg signed [65:0] prod_s3;
        always_ff @(posedge clk) begin
            if (enable) begin
                prod_s3 <= ($signed(p11_s2) << 32) + (($signed(p01_s2) + $signed(p10_s2)) << 16) + $signed({1'b0, p00_s2});
            end
        end

        assign result = prod_s3;

    end else begin : g_behavioral
        wire [R_WIDTH-1:0] prod_w;

        if (SIGNED != 0) begin : g_prod_s
            assign prod_w = R_WIDTH'($signed(dataa) * $signed(datab));
        end else begin : g_prod_u
            assign prod_w = R_WIDTH'(dataa * datab);
        end

        VX_pipe_register #(
            .DATAW (R_WIDTH),
            .DEPTH (LATENCY)
        ) pipe_reg (
            .clk     (clk),
            .enable  (enable),
            .reset   (1'b0),
            .data_in (prod_w),
            .data_out(result)
        );
    end

endmodule
`TRACING_ON
