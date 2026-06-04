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
`include "VX_define.vh"
module VX_alu_unit import VX_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,
    // Inputs
    input wire [`ISSUE_WIDTH-1:0]       dispatch_valid,
    input dispatch_t [`ISSUE_WIDTH-1:0] dispatch_data,
    output wire [`ISSUE_WIDTH-1:0]      dispatch_ready,
    // Outputs
    output wire [`ISSUE_WIDTH-1:0]       commit_valid,
    output commit_t [`ISSUE_WIDTH-1:0]   commit_data,
    input wire [`ISSUE_WIDTH-1:0]        commit_ready,
    VX_branch_ctl_if.master branch_ctl_if [`NUM_ALU_BLOCKS]
);
    `UNUSED_SPARAM (INSTANCE_ID)
    localparam BLOCK_SIZE   = `NUM_ALU_BLOCKS;
    localparam NUM_LANES    = `NUM_ALU_LANES;
    localparam PARTIAL_BW   = (BLOCK_SIZE != `ISSUE_WIDTH) || (NUM_LANES != `SIMD_WIDTH);
    localparam PE_COUNT     = 1 + `EXT_M_ENABLED;
    localparam PE_SEL_BITS  = `CLOG2(PE_COUNT);
    localparam PE_IDX_INT   = 0;
    localparam PE_IDX_MDV   = PE_IDX_INT + `EXT_M_ENABLED;

    VX_dispatch_if dispatch_if [`ISSUE_WIDTH]();
    for (genvar i = 0; i < `ISSUE_WIDTH; ++i) begin : g_dispatch_if
        assign dispatch_if[i].valid = dispatch_valid[i];
        assign dispatch_if[i].data  = dispatch_data[i];
        assign dispatch_ready[i]    = dispatch_if[i].ready;
    end

    VX_commit_if commit_if [`ISSUE_WIDTH]();
    for (genvar i = 0; i < `ISSUE_WIDTH; ++i) begin : g_commit_if
        assign commit_valid[i]   = commit_if[i].valid;
        assign commit_data[i]    = commit_if[i].data;
        assign commit_if[i].ready = commit_ready[i];
    end

    VX_execute_if #(
        .data_t (alu_exe_t)
    ) per_block_execute_if[BLOCK_SIZE]();
    VX_result_if #(
        .data_t (alu_res_t)
    ) per_block_result_if[BLOCK_SIZE]();
    VX_dispatch_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (PARTIAL_BW ? 3 : 0)
    ) dispatch_unit (
        .clk        (clk),
        .reset      (reset),
        .dispatch_if(dispatch_if),
        .execute_if (per_block_execute_if)
    );
    for (genvar block_idx = 0; block_idx < BLOCK_SIZE; ++block_idx) begin : g_blocks
        wire [PE_COUNT-1:0] pe_execute_valid;
        alu_exe_t [PE_COUNT-1:0] pe_execute_data;
        wire [PE_COUNT-1:0] pe_execute_ready;

        wire [PE_COUNT-1:0] pe_result_valid;
        alu_res_t [PE_COUNT-1:0] pe_result_data;
        wire [PE_COUNT-1:0] pe_result_ready;

        VX_execute_if #(
            .data_t (alu_exe_t)
        ) pe_execute_if[PE_COUNT]();
        VX_result_if#(
            .data_t (alu_res_t)
        ) pe_result_if[PE_COUNT]();
        reg [`UP(PE_SEL_BITS)-1:0] pe_select;
        always @(*) begin
            pe_select = PE_IDX_INT;
            if (`EXT_M_ENABLED && (per_block_execute_if[block_idx].data.op_args.alu.xtype == ALU_TYPE_MULDIV))
                pe_select = PE_IDX_MDV;
        end
        VX_pe_switch_alu #(
            .PE_COUNT    (PE_COUNT),
            .NUM_LANES   (NUM_LANES),
            .ARBITER     ("R"),
            .REQ_OUT_BUF (0),
            .RSP_OUT_BUF (PARTIAL_BW ? 1 : 3)
        ) pe_switch (
            .clk            (clk),
            .reset          (reset),
            .pe_sel         (pe_select),
            .execute_in_if  (per_block_execute_if[block_idx]),
            .result_out_if  (per_block_result_if[block_idx]),
            .execute_out_valid(pe_execute_valid),
            .execute_out_data (pe_execute_data),
            .execute_out_ready(pe_execute_ready),
            .result_in_valid(pe_result_valid),
            .result_in_data (pe_result_data),
            .result_in_ready(pe_result_ready)
        );
        VX_alu_int #(
            .INSTANCE_ID (`SFORMATF(("%s-int%0d", INSTANCE_ID, block_idx))),
            .BLOCK_IDX (block_idx),
            .NUM_LANES (NUM_LANES)
        ) alu_int (
            .clk            (clk),
            .reset          (reset),
            .execute_valid  (pe_execute_valid[PE_IDX_INT]),
            .execute_data   (pe_execute_data[PE_IDX_INT]),
            .execute_ready  (pe_execute_ready[PE_IDX_INT]),
            .result_valid   (pe_result_valid[PE_IDX_INT]),
            .result_data    (pe_result_data[PE_IDX_INT]),
            .result_ready   (pe_result_ready[PE_IDX_INT]),
            .branch_ctl_if  (branch_ctl_if[block_idx])
        );
    `ifdef EXT_M_ENABLE
        VX_alu_muldiv #(
            .INSTANCE_ID (`SFORMATF(("%s-muldiv%0d", INSTANCE_ID, block_idx))),
            .NUM_LANES (NUM_LANES)
        ) muldiv_unit (
            .clk            (clk),
            .reset          (reset),
            .execute_valid  (pe_execute_valid[PE_IDX_MDV]),
            .execute_data   (pe_execute_data[PE_IDX_MDV]),
            .execute_ready  (pe_execute_ready[PE_IDX_MDV]),
            .result_valid   (pe_result_valid[PE_IDX_MDV]),
            .result_data    (pe_result_data[PE_IDX_MDV]),
            .result_ready   (pe_result_ready[PE_IDX_MDV])
        );
    `endif
    end
    VX_gather_unit #(
        .BLOCK_SIZE (BLOCK_SIZE),
        .NUM_LANES  (NUM_LANES),
        .OUT_BUF    (PARTIAL_BW ? 3 : 0)
    ) gather_unit (
        .clk       (clk),
        .reset     (reset),
        .result_if (per_block_result_if),
        .commit_if (commit_if)
    );
endmodule

