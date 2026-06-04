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

module VX_mem_unit import VX_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID = ""
) (
    input wire              clk,
    input wire              reset,

`ifdef PERF_ENABLE
    output lmem_perf_t      lmem_perf,
    output coalescer_perf_t coalescer_perf,
`endif

    VX_lsu_mem_if.slave     lsu_mem_if [`NUM_LSU_BLOCKS],

    // Flattened dcache bus ports (replacing VX_dcache_bus_if array)
    output wire [DCACHE_NUM_REQS-1:0]                                           dcache_bus_req_valid,
    output wire [DCACHE_NUM_REQS-1:0]                                           dcache_bus_req_rw,
    output wire [DCACHE_NUM_REQS-1:0][`MEM_ADDR_WIDTH-`CLOG2(DCACHE_WORD_SIZE)-1:0] dcache_bus_req_addr,
    output wire [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE*8-1:0]                   dcache_bus_req_data,
    output wire [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE-1:0]                     dcache_bus_req_byteen,
    output wire [DCACHE_NUM_REQS-1:0][MEM_FLAGS_WIDTH-1:0]                      dcache_bus_req_flags,
    output wire [DCACHE_NUM_REQS-1:0][DCACHE_TAG_WIDTH-1:0]                     dcache_bus_req_tag,
    input  wire [DCACHE_NUM_REQS-1:0]                                           dcache_bus_req_ready,
    input  wire [DCACHE_NUM_REQS-1:0]                                           dcache_bus_rsp_valid,
    input  wire [DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE*8-1:0]                   dcache_bus_rsp_data,
    input  wire [DCACHE_NUM_REQS-1:0][DCACHE_TAG_WIDTH-1:0]                     dcache_bus_rsp_tag,
    output wire [DCACHE_NUM_REQS-1:0]                                           dcache_bus_rsp_ready
);
    VX_lsu_mem_if #(
        .NUM_LANES (`NUM_LSU_LANES),
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LSU_TAG_WIDTH)
    ) lsu_dcache_if[`NUM_LSU_BLOCKS]();

`ifdef LMEM_ENABLE

    `STATIC_ASSERT(`IS_DIVISBLE((1 << `LMEM_LOG_SIZE), `MEM_BLOCK_SIZE), ("invalid parameter"))
    `STATIC_ASSERT(0 == (`LMEM_BASE_ADDR % (1 << `LMEM_LOG_SIZE)), ("invalid parameter"))

    localparam LMEM_ADDR_WIDTH = `LMEM_LOG_SIZE - `CLOG2(LSU_WORD_SIZE);

    VX_lsu_mem_if #(
        .NUM_LANES (`NUM_LSU_LANES),
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LSU_TAG_WIDTH)
    ) lsu_lmem_if[`NUM_LSU_BLOCKS]();

    for (genvar i = 0; i < `NUM_LSU_BLOCKS; ++i) begin : g_lmem_switches
        VX_lmem_switch #(
            .GLOBAL_OUT_BUF(1),
            .LOCAL_OUT_BUF(1),
            .RSP_OUT_BUF  (1),
            .ARBITER      ("P")
        ) lmem_switch (
            .clk          (clk),
            .reset        (reset),
            .lsu_in_if    (lsu_mem_if[i]),
            .global_out_if(lsu_dcache_if[i]),
            .local_out_if (lsu_lmem_if[i])
        );
    end

    VX_lsu_mem_if #(
        .NUM_LANES (`NUM_LSU_LANES),
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LMEM_TAG_WIDTH)
    ) lmem_arb_if[1]();

    VX_lsu_mem_arb #(
        .NUM_INPUTS (`NUM_LSU_BLOCKS),
        .NUM_OUTPUTS(1),
        .NUM_LANES  (`NUM_LSU_LANES),
        .DATA_SIZE  (LSU_WORD_SIZE),
        .TAG_WIDTH  (LSU_TAG_WIDTH),
        .TAG_SEL_IDX(0),
        .ARBITER    ("R"),
        .REQ_OUT_BUF(0),
        .RSP_OUT_BUF(2)
    ) lmem_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_if  (lsu_lmem_if),
        .bus_out_if (lmem_arb_if)
    );

    VX_mem_bus_if #(
        .DATA_SIZE (LSU_WORD_SIZE),
        .TAG_WIDTH (LMEM_TAG_WIDTH)
    ) lmem_adapt_if[`NUM_LSU_LANES]();

    // Explicit wires for lmem_adapter output
    wire [`NUM_LSU_LANES-1:0]                                              lmem_tmp_req_valid;
    wire [`NUM_LSU_LANES-1:0]                                              lmem_tmp_req_rw;
    wire [`NUM_LSU_LANES-1:0][`MEM_ADDR_WIDTH-`CLOG2(LSU_WORD_SIZE)-1:0]   lmem_tmp_req_addr;
    wire [`NUM_LSU_LANES-1:0][LSU_WORD_SIZE*8-1:0]                         lmem_tmp_req_data;
    wire [`NUM_LSU_LANES-1:0][LSU_WORD_SIZE-1:0]                           lmem_tmp_req_byteen;
    wire [`NUM_LSU_LANES-1:0][MEM_FLAGS_WIDTH-1:0]                         lmem_tmp_req_flags;
    wire [`NUM_LSU_LANES-1:0][LMEM_TAG_WIDTH-1:0]                          lmem_tmp_req_tag;
    wire [`NUM_LSU_LANES-1:0]                                              lmem_tmp_req_ready;
    wire [`NUM_LSU_LANES-1:0]                                              lmem_tmp_rsp_valid;
    wire [`NUM_LSU_LANES-1:0][LSU_WORD_SIZE*8-1:0]                         lmem_tmp_rsp_data;
    wire [`NUM_LSU_LANES-1:0][LMEM_TAG_WIDTH-1:0]                          lmem_tmp_rsp_tag;
    wire [`NUM_LSU_LANES-1:0]                                              lmem_tmp_rsp_ready;

    VX_lsu_adapter #(
        .NUM_LANES    (`NUM_LSU_LANES),
        .DATA_SIZE    (LSU_WORD_SIZE),
        .TAG_WIDTH    (LMEM_TAG_WIDTH),
        .TAG_SEL_BITS (LMEM_TAG_WIDTH - UUID_WIDTH),
        .ARBITER      ("P"),
        .REQ_OUT_BUF  (3),
        .RSP_OUT_BUF  (0)
    ) lmem_adapter (
        .clk                (clk),
        .reset              (reset),
        .lsu_mem_if         (lmem_arb_if[0]),
        .mem_bus_req_valid  (lmem_tmp_req_valid),
        .mem_bus_req_rw     (lmem_tmp_req_rw),
        .mem_bus_req_addr   (lmem_tmp_req_addr),
        .mem_bus_req_data   (lmem_tmp_req_data),
        .mem_bus_req_byteen (lmem_tmp_req_byteen),
        .mem_bus_req_flags  (lmem_tmp_req_flags),
        .mem_bus_req_tag    (lmem_tmp_req_tag),
        .mem_bus_req_ready  (lmem_tmp_req_ready),
        .mem_bus_rsp_valid  (lmem_tmp_rsp_valid),
        .mem_bus_rsp_data   (lmem_tmp_rsp_data),
        .mem_bus_rsp_tag    (lmem_tmp_rsp_tag),
        .mem_bus_rsp_ready  (lmem_tmp_rsp_ready)
    );

    // Bridge explicit wires back to lmem_adapt_if for VX_local_mem
    for (genvar k = 0; k < `NUM_LSU_LANES; ++k) begin : g_lmem_adapt_bridge
        assign lmem_adapt_if[k].req_valid      = lmem_tmp_req_valid[k];
        assign lmem_adapt_if[k].req_data.rw    = lmem_tmp_req_rw[k];
        assign lmem_adapt_if[k].req_data.addr  = lmem_tmp_req_addr[k];
        assign lmem_adapt_if[k].req_data.data  = lmem_tmp_req_data[k];
        assign lmem_adapt_if[k].req_data.byteen= lmem_tmp_req_byteen[k];
        assign lmem_adapt_if[k].req_data.flags = lmem_tmp_req_flags[k];
        assign lmem_adapt_if[k].req_data.tag   = lmem_tmp_req_tag[k];
        assign lmem_tmp_req_ready[k] = lmem_adapt_if[k].req_ready;
        assign lmem_tmp_rsp_valid[k] = lmem_adapt_if[k].rsp_valid;
        assign lmem_tmp_rsp_data[k]  = lmem_adapt_if[k].rsp_data.data;
        assign lmem_tmp_rsp_tag[k]   = lmem_adapt_if[k].rsp_data.tag;
        assign lmem_adapt_if[k].rsp_ready      = lmem_tmp_rsp_ready[k];
    end

    VX_local_mem #(
        .INSTANCE_ID(`SFORMATF(("%s-lmem", INSTANCE_ID))),
        .SIZE       (1 << `LMEM_LOG_SIZE),
        .NUM_REQS   (`NUM_LSU_LANES),
        .NUM_BANKS  (`LMEM_NUM_BANKS),
        .WORD_SIZE  (LSU_WORD_SIZE),
        .ADDR_WIDTH (LMEM_ADDR_WIDTH),
        .TAG_WIDTH  (LMEM_TAG_WIDTH),
        .OUT_BUF    (3)
    ) local_mem (
        .clk        (clk),
        .reset      (reset),
    `ifdef PERF_ENABLE
        .lmem_perf  (lmem_perf),
    `endif
        .mem_bus_if (lmem_adapt_if)
    );

`else

`ifdef PERF_ENABLE
    assign lmem_perf = '0;
`endif

    for (genvar i = 0; i < `NUM_LSU_BLOCKS; ++i) begin : g_lsu_dcache_if
        `ASSIGN_VX_MEM_BUS_IF (lsu_dcache_if[i], lsu_mem_if[i]);
    end

`endif

    VX_lsu_mem_if #(
        .NUM_LANES (DCACHE_CHANNELS),
        .DATA_SIZE (DCACHE_WORD_SIZE),
        .TAG_WIDTH (DCACHE_TAG_WIDTH)
    ) dcache_coalesced_if[`NUM_LSU_BLOCKS]();

`ifdef PERF_ENABLE
    wire [`NUM_LSU_BLOCKS-1:0][PERF_CTR_BITS-1:0] per_block_coalescer_misses;
    wire [PERF_CTR_BITS-1:0] coalescer_misses;
    VX_reduce_tree #(
        .IN_W (PERF_CTR_BITS),
        .N    (`NUM_LSU_BLOCKS),
        .OP   ("+")
    ) coalescer_reduce (
        .data_in  (per_block_coalescer_misses),
        .data_out (coalescer_misses)
    );
    `BUFFER(coalescer_perf.misses, coalescer_misses);
`endif

    if ((`NUM_LSU_LANES > 1) && (LSU_WORD_SIZE != DCACHE_WORD_SIZE)) begin : g_enabled

        for (genvar i = 0; i < `NUM_LSU_BLOCKS; ++i) begin : g_coalescers
            VX_mem_coalescer #(
                .INSTANCE_ID    (`SFORMATF(("%s-coalescer%0d", INSTANCE_ID, i))),
                .NUM_REQS       (`NUM_LSU_LANES),
                .DATA_IN_SIZE   (LSU_WORD_SIZE),
                .DATA_OUT_SIZE  (DCACHE_WORD_SIZE),
                .ADDR_WIDTH     (LSU_ADDR_WIDTH),
                .FLAGS_WIDTH    (MEM_FLAGS_WIDTH),
                .TAG_WIDTH      (LSU_TAG_WIDTH),
                .UUID_WIDTH     (UUID_WIDTH),
                .QUEUE_SIZE     (`LSUQ_OUT_SIZE),
                .PERF_CTR_BITS  (PERF_CTR_BITS)
            ) mem_coalescer (
                .clk            (clk),
                .reset          (reset),

            `ifdef PERF_ENABLE
                .misses         (per_block_coalescer_misses[i]),
            `else
                `UNUSED_PIN (misses),
            `endif

                // Input request
                .in_req_valid   (lsu_dcache_if[i].req_valid),
                .in_req_mask    (lsu_dcache_if[i].req_data.mask),
                .in_req_rw      (lsu_dcache_if[i].req_data.rw),
                .in_req_byteen  (lsu_dcache_if[i].req_data.byteen),
                .in_req_addr    (lsu_dcache_if[i].req_data.addr),
                .in_req_flags   (lsu_dcache_if[i].req_data.flags),
                .in_req_data    (lsu_dcache_if[i].req_data.data),
                .in_req_tag     (lsu_dcache_if[i].req_data.tag),
                .in_req_ready   (lsu_dcache_if[i].req_ready),

                // Input response
                .in_rsp_valid   (lsu_dcache_if[i].rsp_valid),
                .in_rsp_mask    (lsu_dcache_if[i].rsp_data.mask),
                .in_rsp_data    (lsu_dcache_if[i].rsp_data.data),
                .in_rsp_tag     (lsu_dcache_if[i].rsp_data.tag),
                .in_rsp_ready   (lsu_dcache_if[i].rsp_ready),

                // Output request
                .out_req_valid  (dcache_coalesced_if[i].req_valid),
                .out_req_mask   (dcache_coalesced_if[i].req_data.mask),
                .out_req_rw     (dcache_coalesced_if[i].req_data.rw),
                .out_req_byteen (dcache_coalesced_if[i].req_data.byteen),
                .out_req_addr   (dcache_coalesced_if[i].req_data.addr),
                .out_req_flags  (dcache_coalesced_if[i].req_data.flags),
                .out_req_data   (dcache_coalesced_if[i].req_data.data),
                .out_req_tag    (dcache_coalesced_if[i].req_data.tag),
                .out_req_ready  (dcache_coalesced_if[i].req_ready),

                // Output response
                .out_rsp_valid  (dcache_coalesced_if[i].rsp_valid),
                .out_rsp_mask   (dcache_coalesced_if[i].rsp_data.mask),
                .out_rsp_data   (dcache_coalesced_if[i].rsp_data.data),
                .out_rsp_tag    (dcache_coalesced_if[i].rsp_data.tag),
                .out_rsp_ready  (dcache_coalesced_if[i].rsp_ready)
            );
        end

    end else begin : g_passthru

        for (genvar i = 0; i < `NUM_LSU_BLOCKS; ++i) begin : g_dcache_coalesced_if
            `ASSIGN_VX_MEM_BUS_IF (dcache_coalesced_if[i], lsu_dcache_if[i]);
        `ifdef PERF_ENABLE
            assign per_block_coalescer_misses[i] = '0;
        `endif
        end

    end

    for (genvar i = 0; i < `NUM_LSU_BLOCKS; ++i) begin : g_dcache_adapters

        // Explicit wires replacing dcache_bus_tmp_if interface
        wire [DCACHE_CHANNELS-1:0]                                    dcache_tmp_req_valid;
        wire [DCACHE_CHANNELS-1:0]                                    dcache_tmp_req_rw;
        wire [DCACHE_CHANNELS-1:0][DCACHE_ADDR_WIDTH-1:0]             dcache_tmp_req_addr;
        wire [DCACHE_CHANNELS-1:0][DCACHE_WORD_SIZE*8-1:0]            dcache_tmp_req_data;
        wire [DCACHE_CHANNELS-1:0][DCACHE_WORD_SIZE-1:0]              dcache_tmp_req_byteen;
        wire [DCACHE_CHANNELS-1:0][MEM_FLAGS_WIDTH-1:0]               dcache_tmp_req_flags;
        wire [DCACHE_CHANNELS-1:0][DCACHE_TAG_WIDTH-1:0]              dcache_tmp_req_tag;
        wire [DCACHE_CHANNELS-1:0]                                    dcache_tmp_req_ready;
        wire [DCACHE_CHANNELS-1:0]                                    dcache_tmp_rsp_valid;
        wire [DCACHE_CHANNELS-1:0][DCACHE_WORD_SIZE*8-1:0]            dcache_tmp_rsp_data;
        wire [DCACHE_CHANNELS-1:0][DCACHE_TAG_WIDTH-1:0]              dcache_tmp_rsp_tag;
        wire [DCACHE_CHANNELS-1:0]                                    dcache_tmp_rsp_ready;

        VX_lsu_adapter #(
            .NUM_LANES    (DCACHE_CHANNELS),
            .DATA_SIZE    (DCACHE_WORD_SIZE),
            .TAG_WIDTH    (DCACHE_TAG_WIDTH),
            .TAG_SEL_BITS (DCACHE_TAG_WIDTH - UUID_WIDTH),
            .ARBITER      ("P"),
            .REQ_OUT_BUF  (0),
            .RSP_OUT_BUF  (0)
        ) dcache_adapter (
            .clk                (clk),
            .reset              (reset),
            .lsu_mem_if         (dcache_coalesced_if[i]),
            .mem_bus_req_valid  (dcache_tmp_req_valid),
            .mem_bus_req_rw     (dcache_tmp_req_rw),
            .mem_bus_req_addr   (dcache_tmp_req_addr),
            .mem_bus_req_data   (dcache_tmp_req_data),
            .mem_bus_req_byteen (dcache_tmp_req_byteen),
            .mem_bus_req_flags  (dcache_tmp_req_flags),
            .mem_bus_req_tag    (dcache_tmp_req_tag),
            .mem_bus_req_ready  (dcache_tmp_req_ready),
            .mem_bus_rsp_valid  (dcache_tmp_rsp_valid),
            .mem_bus_rsp_data   (dcache_tmp_rsp_data),
            .mem_bus_rsp_tag    (dcache_tmp_rsp_tag),
            .mem_bus_rsp_ready  (dcache_tmp_rsp_ready)
        );

        for (genvar j = 0; j < DCACHE_CHANNELS; ++j) begin : g_dcache_bus_if
            assign dcache_bus_req_valid[i * DCACHE_CHANNELS + j]  = dcache_tmp_req_valid[j];
            assign dcache_bus_req_rw[i * DCACHE_CHANNELS + j]     = dcache_tmp_req_rw[j];
            assign dcache_bus_req_addr[i * DCACHE_CHANNELS + j]   = dcache_tmp_req_addr[j];
            assign dcache_bus_req_data[i * DCACHE_CHANNELS + j]   = dcache_tmp_req_data[j];
            assign dcache_bus_req_byteen[i * DCACHE_CHANNELS + j] = dcache_tmp_req_byteen[j];
            assign dcache_bus_req_flags[i * DCACHE_CHANNELS + j]  = dcache_tmp_req_flags[j];
            assign dcache_bus_req_tag[i * DCACHE_CHANNELS + j]    = dcache_tmp_req_tag[j];
            assign dcache_tmp_req_ready[j] = dcache_bus_req_ready[i * DCACHE_CHANNELS + j];
            assign dcache_tmp_rsp_valid[j] = dcache_bus_rsp_valid[i * DCACHE_CHANNELS + j];
            assign dcache_tmp_rsp_data[j]  = dcache_bus_rsp_data[i * DCACHE_CHANNELS + j];
            assign dcache_tmp_rsp_tag[j]   = dcache_bus_rsp_tag[i * DCACHE_CHANNELS + j];
            assign dcache_bus_rsp_ready[i * DCACHE_CHANNELS + j]  = dcache_tmp_rsp_ready[j];
        end

    end

endmodule
