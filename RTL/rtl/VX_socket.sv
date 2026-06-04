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

module VX_socket import VX_gpu_pkg::*; #(
    parameter SOCKET_ID = 0,
    parameter `STRING INSTANCE_ID = ""
) (
    `SCOPE_IO_DECL

    // Clock
    input wire              clk,
    input wire              reset,

`ifdef PERF_ENABLE
    input sysmem_perf_t     sysmem_perf,
`endif

    // DCRs
    VX_dcr_bus_if.slave     dcr_bus_if,

    // Memory (flattened — L1_MEM_PORTS wide)
    output wire [`L1_MEM_PORTS-1:0]                                          mem_bus_req_valid,
    output wire [`L1_MEM_PORTS-1:0]                                          mem_bus_req_rw,
    output wire [`L1_MEM_PORTS-1:0][`MEM_ADDR_WIDTH-`CLOG2(`L1_LINE_SIZE)-1:0] mem_bus_req_addr,
    output wire [`L1_MEM_PORTS-1:0][`L1_LINE_SIZE*8-1:0]                     mem_bus_req_data,
    output wire [`L1_MEM_PORTS-1:0][`L1_LINE_SIZE-1:0]                       mem_bus_req_byteen,
    output wire [`L1_MEM_PORTS-1:0][MEM_FLAGS_WIDTH-1:0]                     mem_bus_req_flags,
    output wire [`L1_MEM_PORTS-1:0][L1_MEM_ARB_TAG_WIDTH-1:0]                mem_bus_req_tag,
    input  wire [`L1_MEM_PORTS-1:0]                                          mem_bus_req_ready,
    input  wire [`L1_MEM_PORTS-1:0]                                          mem_bus_rsp_valid,
    input  wire [`L1_MEM_PORTS-1:0][`L1_LINE_SIZE*8-1:0]                     mem_bus_rsp_data,
    input  wire [`L1_MEM_PORTS-1:0][L1_MEM_ARB_TAG_WIDTH-1:0]                mem_bus_rsp_tag,
    output wire [`L1_MEM_PORTS-1:0]                                          mem_bus_rsp_ready,

`ifdef GBAR_ENABLE
    // Barrier
    VX_gbar_bus_if.master   gbar_bus_if,
`endif
    // Status
    output wire             busy
);

`ifdef SCOPE
    localparam scope_core = 0;
    `SCOPE_IO_SWITCH (`SOCKET_SIZE);
`endif

`ifdef GBAR_ENABLE
    VX_gbar_bus_if per_core_gbar_bus_if[`SOCKET_SIZE]();

    VX_gbar_arb #(
        .NUM_REQS (`SOCKET_SIZE),
        .OUT_BUF  ((`SOCKET_SIZE > 1) ? 2 : 0)
    ) gbar_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_if  (per_core_gbar_bus_if),
        .bus_out_if (gbar_bus_if)
    );
`endif

    ///////////////////////////////////////////////////////////////////////////

`ifdef PERF_ENABLE
    cache_perf_t icache_perf, dcache_perf;
    sysmem_perf_t sysmem_perf_tmp;
    always @(*) begin
        sysmem_perf_tmp = sysmem_perf;
        sysmem_perf_tmp.icache = icache_perf;
        sysmem_perf_tmp.dcache = dcache_perf;
    end
`endif

    ///////////////////////////////////////////////////////////////////////////

    VX_icache_bus_if per_core_icache_bus_if[`SOCKET_SIZE]();

    // Bridge: VX_icache_bus_if (flat) -> VX_mem_bus_if (struct) for cache cluster
    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_WORD_SIZE),
        .TAG_WIDTH (ICACHE_TAG_WIDTH)
    ) icache_core_bus_if[`SOCKET_SIZE]();

    for (genvar i = 0; i < `SOCKET_SIZE; ++i) begin : g_icache_bridge
        assign icache_core_bus_if[i].req_valid       = per_core_icache_bus_if[i].req_valid;
        assign icache_core_bus_if[i].req_data.rw     = per_core_icache_bus_if[i].req_rw;
        assign icache_core_bus_if[i].req_data.addr   = per_core_icache_bus_if[i].req_addr;
        assign icache_core_bus_if[i].req_data.data   = per_core_icache_bus_if[i].req_data;
        assign icache_core_bus_if[i].req_data.byteen = per_core_icache_bus_if[i].req_byteen;
        assign icache_core_bus_if[i].req_data.flags  = per_core_icache_bus_if[i].req_flags;
        assign icache_core_bus_if[i].req_data.tag    = per_core_icache_bus_if[i].req_tag;
        assign per_core_icache_bus_if[i].req_ready   = icache_core_bus_if[i].req_ready;

        assign per_core_icache_bus_if[i].rsp_valid   = icache_core_bus_if[i].rsp_valid;
        assign per_core_icache_bus_if[i].rsp_data    = icache_core_bus_if[i].rsp_data.data;
        assign per_core_icache_bus_if[i].rsp_tag     = icache_core_bus_if[i].rsp_data.tag;
        assign icache_core_bus_if[i].rsp_ready       = per_core_icache_bus_if[i].rsp_ready;
    end

    VX_mem_bus_if #(
        .DATA_SIZE (ICACHE_LINE_SIZE),
        .TAG_WIDTH (ICACHE_MEM_TAG_WIDTH)
    ) icache_mem_bus_if[1]();

    `RESET_RELAY (icache_reset, reset);

    VX_cache_cluster #(
        .INSTANCE_ID    (`SFORMATF(("%s-icache", INSTANCE_ID))),
        .NUM_UNITS      (`NUM_ICACHES),
        .NUM_INPUTS     (`SOCKET_SIZE),
        .TAG_SEL_IDX    (0),
        .CACHE_SIZE     (`ICACHE_SIZE),
        .LINE_SIZE      (ICACHE_LINE_SIZE),
        .NUM_BANKS      (1),
        .NUM_WAYS       (`ICACHE_NUM_WAYS),
        .WORD_SIZE      (ICACHE_WORD_SIZE),
        .NUM_REQS       (1),
        .MEM_PORTS      (1),
        .CRSQ_SIZE      (`ICACHE_CRSQ_SIZE),
        .MSHR_SIZE      (`ICACHE_MSHR_SIZE),
        .MRSQ_SIZE      (`ICACHE_MRSQ_SIZE),
        .MREQ_SIZE      (`ICACHE_MREQ_SIZE),
        .TAG_WIDTH      (ICACHE_TAG_WIDTH),
        .WRITE_ENABLE   (0),
        .REPL_POLICY    (`ICACHE_REPL_POLICY),
        .NC_ENABLE      (0),
        .CORE_OUT_BUF   (3),
        .MEM_OUT_BUF    (2)
    ) icache (
    `ifdef PERF_ENABLE
        .cache_perf     (icache_perf),
    `endif
        .clk            (clk),
        .reset          (icache_reset),
        .core_bus_if    (icache_core_bus_if),
        .mem_bus_if     (icache_mem_bus_if)
    );

    ///////////////////////////////////////////////////////////////////////////

    // Flat dcache bus wires (replacing VX_dcache_bus_if per_core_dcache_bus_if array)
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0]                                       per_core_dcache_req_valid;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0]                                       per_core_dcache_req_rw;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0][DCACHE_ADDR_WIDTH-1:0]                per_core_dcache_req_addr;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE*8-1:0]               per_core_dcache_req_data;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE-1:0]                 per_core_dcache_req_byteen;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0][MEM_FLAGS_WIDTH-1:0]                  per_core_dcache_req_flags;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0][DCACHE_TAG_WIDTH-1:0]                 per_core_dcache_req_tag;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0]                                       per_core_dcache_req_ready;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0]                                       per_core_dcache_rsp_valid;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0][DCACHE_WORD_SIZE*8-1:0]               per_core_dcache_rsp_data;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0][DCACHE_TAG_WIDTH-1:0]                 per_core_dcache_rsp_tag;
    wire [`SOCKET_SIZE * DCACHE_NUM_REQS-1:0]                                       per_core_dcache_rsp_ready;

    // Bridge: flat dcache wires -> VX_mem_bus_if (struct) for cache cluster
    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_WORD_SIZE),
        .TAG_WIDTH (DCACHE_TAG_WIDTH)
    ) dcache_core_bus_if[`SOCKET_SIZE * DCACHE_NUM_REQS]();

    for (genvar i = 0; i < `SOCKET_SIZE * DCACHE_NUM_REQS; ++i) begin : g_dcache_bridge
        assign dcache_core_bus_if[i].req_valid       = per_core_dcache_req_valid[i];
        assign dcache_core_bus_if[i].req_data.rw     = per_core_dcache_req_rw[i];
        assign dcache_core_bus_if[i].req_data.addr   = per_core_dcache_req_addr[i];
        assign dcache_core_bus_if[i].req_data.data   = per_core_dcache_req_data[i];
        assign dcache_core_bus_if[i].req_data.byteen = per_core_dcache_req_byteen[i];
        assign dcache_core_bus_if[i].req_data.flags  = per_core_dcache_req_flags[i];
        assign dcache_core_bus_if[i].req_data.tag    = per_core_dcache_req_tag[i];
        assign per_core_dcache_req_ready[i]          = dcache_core_bus_if[i].req_ready;

        assign per_core_dcache_rsp_valid[i]          = dcache_core_bus_if[i].rsp_valid;
        assign per_core_dcache_rsp_data[i]           = dcache_core_bus_if[i].rsp_data.data;
        assign per_core_dcache_rsp_tag[i]            = dcache_core_bus_if[i].rsp_data.tag;
        assign dcache_core_bus_if[i].rsp_ready       = per_core_dcache_rsp_ready[i];
    end

    VX_mem_bus_if #(
        .DATA_SIZE (DCACHE_LINE_SIZE),
        .TAG_WIDTH (DCACHE_MEM_TAG_WIDTH)
    ) dcache_mem_bus_if[`L1_MEM_PORTS]();

    `RESET_RELAY (dcache_reset, reset);

    VX_cache_cluster #(
        .INSTANCE_ID    (`SFORMATF(("%s-dcache", INSTANCE_ID))),
        .NUM_UNITS      (`NUM_DCACHES),
        .NUM_INPUTS     (`SOCKET_SIZE),
        .TAG_SEL_IDX    (0),
        .CACHE_SIZE     (`DCACHE_SIZE),
        .LINE_SIZE      (DCACHE_LINE_SIZE),
        .NUM_BANKS      (`DCACHE_NUM_BANKS),
        .NUM_WAYS       (`DCACHE_NUM_WAYS),
        .WORD_SIZE      (DCACHE_WORD_SIZE),
        .NUM_REQS       (DCACHE_NUM_REQS),
        .MEM_PORTS      (`L1_MEM_PORTS),
        .CRSQ_SIZE      (`DCACHE_CRSQ_SIZE),
        .MSHR_SIZE      (`DCACHE_MSHR_SIZE),
        .MRSQ_SIZE      (`DCACHE_MRSQ_SIZE),
        .MREQ_SIZE      (`DCACHE_WRITEBACK ? `DCACHE_MSHR_SIZE : `DCACHE_MREQ_SIZE),
        .TAG_WIDTH      (DCACHE_TAG_WIDTH),
        .WRITE_ENABLE   (1),
        .WRITEBACK      (`DCACHE_WRITEBACK),
        .DIRTY_BYTES    (`DCACHE_DIRTYBYTES),
        .REPL_POLICY    (`DCACHE_REPL_POLICY),
        .NC_ENABLE      (1),
        .CORE_OUT_BUF   (3),
        .MEM_OUT_BUF    (2)
    ) dcache (
    `ifdef PERF_ENABLE
        .cache_perf     (dcache_perf),
    `endif
        .clk            (clk),
        .reset          (dcache_reset),
        .core_bus_if    (dcache_core_bus_if),
        .mem_bus_if     (dcache_mem_bus_if)
    );

    ///////////////////////////////////////////////////////////////////////////

    // ---- Port 0: icache + dcache share via arbiter (declared at module scope to avoid nested generate) ----

    VX_mem_bus_if #(
        .DATA_SIZE (`L1_LINE_SIZE),
        .TAG_WIDTH (L1_MEM_TAG_WIDTH)
    ) l1_mem_bus_if_0();

    VX_mem_bus_if #(
        .DATA_SIZE (`L1_LINE_SIZE),
        .TAG_WIDTH (L1_MEM_TAG_WIDTH)
    ) l1_mem_bus_if_1();

    VX_mem_bus_if #(
        .DATA_SIZE (`L1_LINE_SIZE),
        .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
    ) l1_mem_arb_bus_if_0();

    // icache -> l1_mem_bus_if_0 (tag width adaptation)
    assign l1_mem_bus_if_0.req_valid       = icache_mem_bus_if[0].req_valid;
    assign l1_mem_bus_if_0.req_data.rw     = icache_mem_bus_if[0].req_data.rw;
    assign l1_mem_bus_if_0.req_data.addr   = icache_mem_bus_if[0].req_data.addr;
    assign l1_mem_bus_if_0.req_data.data   = icache_mem_bus_if[0].req_data.data;
    assign l1_mem_bus_if_0.req_data.byteen = icache_mem_bus_if[0].req_data.byteen;
    assign l1_mem_bus_if_0.req_data.flags  = icache_mem_bus_if[0].req_data.flags;
    if (L1_MEM_TAG_WIDTH != ICACHE_MEM_TAG_WIDTH) begin : g_icache_req_tag
        if (UUID_WIDTH != 0) begin : g_uuid
            if (L1_MEM_TAG_WIDTH > ICACHE_MEM_TAG_WIDTH) begin : g_wider
                assign l1_mem_bus_if_0.req_data.tag = {icache_mem_bus_if[0].req_data.tag.uuid, {(L1_MEM_TAG_WIDTH-ICACHE_MEM_TAG_WIDTH){1'b0}}, icache_mem_bus_if[0].req_data.tag.value};
            end else begin : g_narrower
                assign l1_mem_bus_if_0.req_data.tag = {icache_mem_bus_if[0].req_data.tag.uuid, icache_mem_bus_if[0].req_data.tag.value[L1_MEM_TAG_WIDTH-UUID_WIDTH-1:0]};
            end
        end else begin : g_no_uuid
            if (L1_MEM_TAG_WIDTH > ICACHE_MEM_TAG_WIDTH) begin : g_wider
                assign l1_mem_bus_if_0.req_data.tag = {{(L1_MEM_TAG_WIDTH-ICACHE_MEM_TAG_WIDTH){1'b0}}, icache_mem_bus_if[0].req_data.tag};
            end else begin : g_narrower
                assign l1_mem_bus_if_0.req_data.tag = icache_mem_bus_if[0].req_data.tag[L1_MEM_TAG_WIDTH-1:0];
            end
        end
    end else begin : g_icache_req_tag
        assign l1_mem_bus_if_0.req_data.tag = icache_mem_bus_if[0].req_data.tag;
    end
    assign icache_mem_bus_if[0].req_ready   = l1_mem_bus_if_0.req_ready;
    assign icache_mem_bus_if[0].rsp_valid   = l1_mem_bus_if_0.rsp_valid;
    assign icache_mem_bus_if[0].rsp_data.data = l1_mem_bus_if_0.rsp_data.data;
    if (L1_MEM_TAG_WIDTH != ICACHE_MEM_TAG_WIDTH) begin : g_icache_rsp_tag
        if (UUID_WIDTH != 0) begin : g_uuid
            if (L1_MEM_TAG_WIDTH > ICACHE_MEM_TAG_WIDTH) begin : g_wider
                assign icache_mem_bus_if[0].rsp_data.tag = {l1_mem_bus_if_0.rsp_data.tag.uuid, l1_mem_bus_if_0.rsp_data.tag.value[ICACHE_MEM_TAG_WIDTH-UUID_WIDTH-1:0]};
            end else begin : g_narrower
                assign icache_mem_bus_if[0].rsp_data.tag = {l1_mem_bus_if_0.rsp_data.tag.uuid, {(ICACHE_MEM_TAG_WIDTH-L1_MEM_TAG_WIDTH){1'b0}}, l1_mem_bus_if_0.rsp_data.tag.value};
            end
        end else begin : g_no_uuid
            if (L1_MEM_TAG_WIDTH > ICACHE_MEM_TAG_WIDTH) begin : g_wider
                assign icache_mem_bus_if[0].rsp_data.tag = l1_mem_bus_if_0.rsp_data.tag[ICACHE_MEM_TAG_WIDTH-1:0];
            end else begin : g_narrower
                assign icache_mem_bus_if[0].rsp_data.tag = {{(ICACHE_MEM_TAG_WIDTH-L1_MEM_TAG_WIDTH){1'b0}}, l1_mem_bus_if_0.rsp_data.tag};
            end
        end
    end else begin : g_icache_rsp_tag
        assign icache_mem_bus_if[0].rsp_data.tag = l1_mem_bus_if_0.rsp_data.tag;
    end
    assign l1_mem_bus_if_0.rsp_ready = icache_mem_bus_if[0].rsp_ready;

    // dcache port 0 -> l1_mem_bus_if_1 (tag width adaptation)
    assign l1_mem_bus_if_1.req_valid       = dcache_mem_bus_if[0].req_valid;
    assign l1_mem_bus_if_1.req_data.rw     = dcache_mem_bus_if[0].req_data.rw;
    assign l1_mem_bus_if_1.req_data.addr   = dcache_mem_bus_if[0].req_data.addr;
    assign l1_mem_bus_if_1.req_data.data   = dcache_mem_bus_if[0].req_data.data;
    assign l1_mem_bus_if_1.req_data.byteen = dcache_mem_bus_if[0].req_data.byteen;
    assign l1_mem_bus_if_1.req_data.flags  = dcache_mem_bus_if[0].req_data.flags;
    if (L1_MEM_TAG_WIDTH != DCACHE_MEM_TAG_WIDTH) begin : g_dcache0_req_tag
        if (UUID_WIDTH != 0) begin : g_uuid
            if (L1_MEM_TAG_WIDTH > DCACHE_MEM_TAG_WIDTH) begin : g_wider
                assign l1_mem_bus_if_1.req_data.tag = {dcache_mem_bus_if[0].req_data.tag.uuid, {(L1_MEM_TAG_WIDTH-DCACHE_MEM_TAG_WIDTH){1'b0}}, dcache_mem_bus_if[0].req_data.tag.value};
            end else begin : g_narrower
                assign l1_mem_bus_if_1.req_data.tag = {dcache_mem_bus_if[0].req_data.tag.uuid, dcache_mem_bus_if[0].req_data.tag.value[L1_MEM_TAG_WIDTH-UUID_WIDTH-1:0]};
            end
        end else begin : g_no_uuid
            if (L1_MEM_TAG_WIDTH > DCACHE_MEM_TAG_WIDTH) begin : g_wider
                assign l1_mem_bus_if_1.req_data.tag = {{(L1_MEM_TAG_WIDTH-DCACHE_MEM_TAG_WIDTH){1'b0}}, dcache_mem_bus_if[0].req_data.tag};
            end else begin : g_narrower
                assign l1_mem_bus_if_1.req_data.tag = dcache_mem_bus_if[0].req_data.tag[L1_MEM_TAG_WIDTH-1:0];
            end
        end
    end else begin : g_dcache0_req_tag
        assign l1_mem_bus_if_1.req_data.tag = dcache_mem_bus_if[0].req_data.tag;
    end
    assign dcache_mem_bus_if[0].req_ready     = l1_mem_bus_if_1.req_ready;
    assign dcache_mem_bus_if[0].rsp_valid     = l1_mem_bus_if_1.rsp_valid;
    assign dcache_mem_bus_if[0].rsp_data.data = l1_mem_bus_if_1.rsp_data.data;
    if (L1_MEM_TAG_WIDTH != DCACHE_MEM_TAG_WIDTH) begin : g_dcache0_rsp_tag
        if (UUID_WIDTH != 0) begin : g_uuid
            if (L1_MEM_TAG_WIDTH > DCACHE_MEM_TAG_WIDTH) begin : g_wider
                assign dcache_mem_bus_if[0].rsp_data.tag = {l1_mem_bus_if_1.rsp_data.tag.uuid, l1_mem_bus_if_1.rsp_data.tag.value[DCACHE_MEM_TAG_WIDTH-UUID_WIDTH-1:0]};
            end else begin : g_narrower
                assign dcache_mem_bus_if[0].rsp_data.tag = {l1_mem_bus_if_1.rsp_data.tag.uuid, {(DCACHE_MEM_TAG_WIDTH-L1_MEM_TAG_WIDTH){1'b0}}, l1_mem_bus_if_1.rsp_data.tag.value};
            end
        end else begin : g_no_uuid
            if (L1_MEM_TAG_WIDTH > DCACHE_MEM_TAG_WIDTH) begin : g_wider
                assign dcache_mem_bus_if[0].rsp_data.tag = l1_mem_bus_if_1.rsp_data.tag[DCACHE_MEM_TAG_WIDTH-1:0];
            end else begin : g_narrower
                assign dcache_mem_bus_if[0].rsp_data.tag = {{(DCACHE_MEM_TAG_WIDTH-L1_MEM_TAG_WIDTH){1'b0}}, l1_mem_bus_if_1.rsp_data.tag};
            end
        end
    end else begin : g_dcache0_rsp_tag
        assign dcache_mem_bus_if[0].rsp_data.tag = l1_mem_bus_if_1.rsp_data.tag;
    end
    assign l1_mem_bus_if_1.rsp_ready = dcache_mem_bus_if[0].rsp_ready;

    // Arbiter: merge icache (port 0) + dcache (port 0) into mem_bus_if[0]
    // Need an array of 2 interfaces for the arbiter input
    VX_mem_bus_if #(
        .DATA_SIZE (`L1_LINE_SIZE),
        .TAG_WIDTH (L1_MEM_TAG_WIDTH)
    ) l1_mem_bus_arb_in[2]();

    // Connect the scalar interfaces to the array for the arbiter
    assign l1_mem_bus_arb_in[0].req_valid       = l1_mem_bus_if_0.req_valid;
    assign l1_mem_bus_arb_in[0].req_data        = l1_mem_bus_if_0.req_data;
    assign l1_mem_bus_if_0.req_ready            = l1_mem_bus_arb_in[0].req_ready;
    assign l1_mem_bus_if_0.rsp_valid            = l1_mem_bus_arb_in[0].rsp_valid;
    assign l1_mem_bus_if_0.rsp_data             = l1_mem_bus_arb_in[0].rsp_data;
    assign l1_mem_bus_arb_in[0].rsp_ready       = l1_mem_bus_if_0.rsp_ready;

    assign l1_mem_bus_arb_in[1].req_valid       = l1_mem_bus_if_1.req_valid;
    assign l1_mem_bus_arb_in[1].req_data        = l1_mem_bus_if_1.req_data;
    assign l1_mem_bus_if_1.req_ready            = l1_mem_bus_arb_in[1].req_ready;
    assign l1_mem_bus_if_1.rsp_valid            = l1_mem_bus_arb_in[1].rsp_valid;
    assign l1_mem_bus_if_1.rsp_data             = l1_mem_bus_arb_in[1].rsp_data;
    assign l1_mem_bus_arb_in[1].rsp_ready       = l1_mem_bus_if_1.rsp_ready;

    VX_mem_bus_if #(
        .DATA_SIZE (`L1_LINE_SIZE),
        .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
    ) l1_mem_arb_out[1]();

    // --- Bridge l1_mem_bus_arb_in[2] to flat wires for VX_mem_arb ---
    localparam L1_ARB_ADDR_WIDTH  = (`MEM_ADDR_WIDTH - `CLOG2(`L1_LINE_SIZE));
    localparam L1_ARB_DATA_WIDTH  = `L1_LINE_SIZE * 8;
    localparam L1_ARB_FLAGS_WIDTH = MEM_FLAGS_WIDTH;

    wire [1:0]                                l1_arb_in_req_valid;
    wire [1:0]                                l1_arb_in_req_rw;
    wire [1:0][L1_ARB_ADDR_WIDTH-1:0]         l1_arb_in_req_addr;
    wire [1:0][L1_ARB_DATA_WIDTH-1:0]         l1_arb_in_req_data;
    wire [1:0][`L1_LINE_SIZE-1:0]             l1_arb_in_req_byteen;
    wire [1:0][L1_ARB_FLAGS_WIDTH-1:0]        l1_arb_in_req_flags;
    wire [1:0][L1_MEM_TAG_WIDTH-1:0]          l1_arb_in_req_tag;
    wire [1:0]                                l1_arb_in_req_ready;
    wire [1:0]                                l1_arb_in_rsp_valid;
    wire [1:0][L1_ARB_DATA_WIDTH-1:0]         l1_arb_in_rsp_data;
    wire [1:0][L1_MEM_TAG_WIDTH-1:0]          l1_arb_in_rsp_tag;
    wire [1:0]                                l1_arb_in_rsp_ready;

    wire [0:0]                                l1_arb_out_req_valid;
    wire [0:0]                                l1_arb_out_req_rw;
    wire [0:0][L1_ARB_ADDR_WIDTH-1:0]         l1_arb_out_req_addr;
    wire [0:0][L1_ARB_DATA_WIDTH-1:0]         l1_arb_out_req_data;
    wire [0:0][`L1_LINE_SIZE-1:0]             l1_arb_out_req_byteen;
    wire [0:0][L1_ARB_FLAGS_WIDTH-1:0]        l1_arb_out_req_flags;
    wire [0:0][L1_MEM_ARB_TAG_WIDTH-1:0]      l1_arb_out_req_tag;
    wire [0:0]                                l1_arb_out_req_ready;
    wire [0:0]                                l1_arb_out_rsp_valid;
    wire [0:0][L1_ARB_DATA_WIDTH-1:0]         l1_arb_out_rsp_data;
    wire [0:0][L1_MEM_ARB_TAG_WIDTH-1:0]      l1_arb_out_rsp_tag;
    wire [0:0]                                l1_arb_out_rsp_ready;

    for (genvar i = 0; i < 2; ++i) begin : g_l1_arb_in_bridge
        assign l1_arb_in_req_valid[i]      = l1_mem_bus_arb_in[i].req_valid;
        assign l1_arb_in_req_rw[i]         = l1_mem_bus_arb_in[i].req_data.rw;
        assign l1_arb_in_req_addr[i]       = l1_mem_bus_arb_in[i].req_data.addr;
        assign l1_arb_in_req_data[i]       = l1_mem_bus_arb_in[i].req_data.data;
        assign l1_arb_in_req_byteen[i]     = l1_mem_bus_arb_in[i].req_data.byteen;
        assign l1_arb_in_req_flags[i]      = l1_mem_bus_arb_in[i].req_data.flags;
        assign l1_arb_in_req_tag[i]        = l1_mem_bus_arb_in[i].req_data.tag;
        assign l1_mem_bus_arb_in[i].req_ready = l1_arb_in_req_ready[i];

        assign l1_mem_bus_arb_in[i].rsp_valid = l1_arb_in_rsp_valid[i];
        assign l1_mem_bus_arb_in[i].rsp_data  = {l1_arb_in_rsp_data[i], l1_arb_in_rsp_tag[i]};
        assign l1_arb_in_rsp_ready[i]         = l1_mem_bus_arb_in[i].rsp_ready;
    end

    // Bridge arb output to l1_mem_arb_out[0]
    assign l1_mem_arb_out[0].req_valid  = l1_arb_out_req_valid[0];
    assign l1_mem_arb_out[0].req_data   = {l1_arb_out_req_rw[0], l1_arb_out_req_addr[0], l1_arb_out_req_data[0], l1_arb_out_req_byteen[0], l1_arb_out_req_flags[0], l1_arb_out_req_tag[0]};
    assign l1_arb_out_req_ready[0]      = l1_mem_arb_out[0].req_ready;

    assign l1_arb_out_rsp_valid[0]  = l1_mem_arb_out[0].rsp_valid;
    assign l1_arb_out_rsp_data[0]   = l1_mem_arb_out[0].rsp_data.data;
    assign l1_arb_out_rsp_tag[0]    = l1_mem_arb_out[0].rsp_data.tag;
    assign l1_mem_arb_out[0].rsp_ready = l1_arb_out_rsp_ready[0];

    VX_mem_arb #(
        .NUM_INPUTS (2),
        .NUM_OUTPUTS(1),
        .DATA_SIZE  (`L1_LINE_SIZE),
        .TAG_WIDTH  (L1_MEM_TAG_WIDTH),
        .TAG_SEL_IDX(0),
        .ARBITER    ("P"), // prioritize the icache
        .REQ_OUT_BUF(3),
        .RSP_OUT_BUF(3)
    ) mem_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_req_valid   (l1_arb_in_req_valid),
        .bus_in_req_rw      (l1_arb_in_req_rw),
        .bus_in_req_addr    (l1_arb_in_req_addr),
        .bus_in_req_data    (l1_arb_in_req_data),
        .bus_in_req_byteen  (l1_arb_in_req_byteen),
        .bus_in_req_flags   (l1_arb_in_req_flags),
        .bus_in_req_tag     (l1_arb_in_req_tag),
        .bus_in_req_ready   (l1_arb_in_req_ready),
        .bus_in_rsp_valid   (l1_arb_in_rsp_valid),
        .bus_in_rsp_data    (l1_arb_in_rsp_data),
        .bus_in_rsp_tag     (l1_arb_in_rsp_tag),
        .bus_in_rsp_ready   (l1_arb_in_rsp_ready),
        .bus_out_req_valid  (l1_arb_out_req_valid),
        .bus_out_req_rw     (l1_arb_out_req_rw),
        .bus_out_req_addr   (l1_arb_out_req_addr),
        .bus_out_req_data   (l1_arb_out_req_data),
        .bus_out_req_byteen (l1_arb_out_req_byteen),
        .bus_out_req_flags  (l1_arb_out_req_flags),
        .bus_out_req_tag    (l1_arb_out_req_tag),
        .bus_out_req_ready  (l1_arb_out_req_ready),
        .bus_out_rsp_valid  (l1_arb_out_rsp_valid),
        .bus_out_rsp_data   (l1_arb_out_rsp_data),
        .bus_out_rsp_tag    (l1_arb_out_rsp_tag),
        .bus_out_rsp_ready  (l1_arb_out_rsp_ready)
    );

    // Connect arbiter output to flat mem_bus ports [0]
    assign mem_bus_req_valid[0]        = l1_mem_arb_out[0].req_valid;
    assign mem_bus_req_rw[0]           = l1_mem_arb_out[0].req_data.rw;
    assign mem_bus_req_addr[0]         = l1_mem_arb_out[0].req_data.addr;
    assign mem_bus_req_data[0]         = l1_mem_arb_out[0].req_data.data;
    assign mem_bus_req_byteen[0]       = l1_mem_arb_out[0].req_data.byteen;
    assign mem_bus_req_flags[0]        = l1_mem_arb_out[0].req_data.flags;
    assign mem_bus_req_tag[0]          = l1_mem_arb_out[0].req_data.tag;
    assign l1_mem_arb_out[0].req_ready = mem_bus_req_ready[0];
    assign l1_mem_arb_out[0].rsp_valid = mem_bus_rsp_valid[0];
    assign l1_mem_arb_out[0].rsp_data  = {mem_bus_rsp_data[0], mem_bus_rsp_tag[0]};
    assign mem_bus_rsp_ready[0]        = l1_mem_arb_out[0].rsp_ready;

    // ---- Ports 1..N-1: dcache only (for L1_MEM_PORTS > 1) ----
    for (genvar i = 1; i < `L1_MEM_PORTS; ++i) begin : g_mem_bus_extra
        VX_mem_bus_if #(
            .DATA_SIZE (`L1_LINE_SIZE),
            .TAG_WIDTH (L1_MEM_ARB_TAG_WIDTH)
        ) l1_mem_arb_bus_if();

        // Inlined ASSIGN_VX_MEM_BUS_IF_EX(l1_mem_arb_bus_if, dcache_mem_bus_if[i], ...)
        assign l1_mem_arb_bus_if.req_valid       = dcache_mem_bus_if[i].req_valid;
        assign l1_mem_arb_bus_if.req_data.rw     = dcache_mem_bus_if[i].req_data.rw;
        assign l1_mem_arb_bus_if.req_data.addr   = dcache_mem_bus_if[i].req_data.addr;
        assign l1_mem_arb_bus_if.req_data.data   = dcache_mem_bus_if[i].req_data.data;
        assign l1_mem_arb_bus_if.req_data.byteen = dcache_mem_bus_if[i].req_data.byteen;
        assign l1_mem_arb_bus_if.req_data.flags  = dcache_mem_bus_if[i].req_data.flags;
        if (L1_MEM_ARB_TAG_WIDTH != DCACHE_MEM_TAG_WIDTH) begin : g_dcache_arb_req_tag
            if (UUID_WIDTH != 0) begin : g_uuid
                if (L1_MEM_ARB_TAG_WIDTH > DCACHE_MEM_TAG_WIDTH) begin : g_wider
                    assign l1_mem_arb_bus_if.req_data.tag = {dcache_mem_bus_if[i].req_data.tag.uuid, {(L1_MEM_ARB_TAG_WIDTH-DCACHE_MEM_TAG_WIDTH){1'b0}}, dcache_mem_bus_if[i].req_data.tag.value};
                end else begin : g_narrower
                    assign l1_mem_arb_bus_if.req_data.tag = {dcache_mem_bus_if[i].req_data.tag.uuid, dcache_mem_bus_if[i].req_data.tag.value[L1_MEM_ARB_TAG_WIDTH-UUID_WIDTH-1:0]};
                end
            end else begin : g_no_uuid
                if (L1_MEM_ARB_TAG_WIDTH > DCACHE_MEM_TAG_WIDTH) begin : g_wider
                    assign l1_mem_arb_bus_if.req_data.tag = {{(L1_MEM_ARB_TAG_WIDTH-DCACHE_MEM_TAG_WIDTH){1'b0}}, dcache_mem_bus_if[i].req_data.tag};
                end else begin : g_narrower
                    assign l1_mem_arb_bus_if.req_data.tag = dcache_mem_bus_if[i].req_data.tag[L1_MEM_ARB_TAG_WIDTH-1:0];
                end
            end
        end else begin : g_dcache_arb_req_tag
            assign l1_mem_arb_bus_if.req_data.tag = dcache_mem_bus_if[i].req_data.tag;
        end
        assign dcache_mem_bus_if[i].req_ready     = l1_mem_arb_bus_if.req_ready;
        assign dcache_mem_bus_if[i].rsp_valid     = l1_mem_arb_bus_if.rsp_valid;
        assign dcache_mem_bus_if[i].rsp_data.data = l1_mem_arb_bus_if.rsp_data.data;
        if (L1_MEM_ARB_TAG_WIDTH != DCACHE_MEM_TAG_WIDTH) begin : g_dcache_arb_rsp_tag
            if (UUID_WIDTH != 0) begin : g_uuid
                if (L1_MEM_ARB_TAG_WIDTH > DCACHE_MEM_TAG_WIDTH) begin : g_wider
                    assign dcache_mem_bus_if[i].rsp_data.tag = {l1_mem_arb_bus_if.rsp_data.tag.uuid, l1_mem_arb_bus_if.rsp_data.tag.value[DCACHE_MEM_TAG_WIDTH-UUID_WIDTH-1:0]};
                end else begin : g_narrower
                    assign dcache_mem_bus_if[i].rsp_data.tag = {l1_mem_arb_bus_if.rsp_data.tag.uuid, {(DCACHE_MEM_TAG_WIDTH-L1_MEM_ARB_TAG_WIDTH){1'b0}}, l1_mem_arb_bus_if.rsp_data.tag.value};
                end
            end else begin : g_no_uuid
                if (L1_MEM_ARB_TAG_WIDTH > DCACHE_MEM_TAG_WIDTH) begin : g_wider
                    assign dcache_mem_bus_if[i].rsp_data.tag = l1_mem_arb_bus_if.rsp_data.tag[DCACHE_MEM_TAG_WIDTH-1:0];
                end else begin : g_narrower
                    assign dcache_mem_bus_if[i].rsp_data.tag = {{(DCACHE_MEM_TAG_WIDTH-L1_MEM_ARB_TAG_WIDTH){1'b0}}, l1_mem_arb_bus_if.rsp_data.tag};
                end
            end
        end else begin : g_dcache_arb_rsp_tag
            assign dcache_mem_bus_if[i].rsp_data.tag = l1_mem_arb_bus_if.rsp_data.tag;
        end
        assign l1_mem_arb_bus_if.rsp_ready = dcache_mem_bus_if[i].rsp_ready;
        // Connect to flat mem_bus ports [i]
        assign mem_bus_req_valid[i]          = l1_mem_arb_bus_if.req_valid;
        assign mem_bus_req_rw[i]             = l1_mem_arb_bus_if.req_data.rw;
        assign mem_bus_req_addr[i]           = l1_mem_arb_bus_if.req_data.addr;
        assign mem_bus_req_data[i]           = l1_mem_arb_bus_if.req_data.data;
        assign mem_bus_req_byteen[i]         = l1_mem_arb_bus_if.req_data.byteen;
        assign mem_bus_req_flags[i]          = l1_mem_arb_bus_if.req_data.flags;
        assign mem_bus_req_tag[i]            = l1_mem_arb_bus_if.req_data.tag;
        assign l1_mem_arb_bus_if.req_ready   = mem_bus_req_ready[i];
        assign l1_mem_arb_bus_if.rsp_valid   = mem_bus_rsp_valid[i];
        assign l1_mem_arb_bus_if.rsp_data    = {mem_bus_rsp_data[i], mem_bus_rsp_tag[i]};
        assign mem_bus_rsp_ready[i]          = l1_mem_arb_bus_if.rsp_ready;
    end

    ///////////////////////////////////////////////////////////////////////////

    wire [`SOCKET_SIZE-1:0] per_core_busy;

    // Generate all cores
    for (genvar core_id = 0; core_id < `SOCKET_SIZE; ++core_id) begin : g_cores

        `RESET_RELAY (core_reset, reset);

        VX_dcr_bus_if core_dcr_bus_if();
        `BUFFER_DCR_BUS_IF (core_dcr_bus_if, dcr_bus_if, 1'b1, (`SOCKET_SIZE > 1))

        VX_core #(
            .CORE_ID  ((SOCKET_ID * `SOCKET_SIZE) + core_id),
            .INSTANCE_ID (`SFORMATF(("%s-core%0d", INSTANCE_ID, core_id)))
        ) core (
            `SCOPE_IO_BIND  (scope_core + core_id)

            .clk            (clk),
            .reset          (core_reset),

        `ifdef PERF_ENABLE
            .sysmem_perf    (sysmem_perf_tmp),
        `endif

            .dcr_bus_if     (core_dcr_bus_if),

            .dcache_bus_req_valid  (per_core_dcache_req_valid[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_req_rw     (per_core_dcache_req_rw[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_req_addr   (per_core_dcache_req_addr[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_req_data   (per_core_dcache_req_data[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_req_byteen (per_core_dcache_req_byteen[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_req_flags  (per_core_dcache_req_flags[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_req_tag    (per_core_dcache_req_tag[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_req_ready  (per_core_dcache_req_ready[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_rsp_valid  (per_core_dcache_rsp_valid[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_rsp_data   (per_core_dcache_rsp_data[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_rsp_tag    (per_core_dcache_rsp_tag[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),
            .dcache_bus_rsp_ready  (per_core_dcache_rsp_ready[core_id * DCACHE_NUM_REQS +: DCACHE_NUM_REQS]),

            .icache_bus_if  (per_core_icache_bus_if[core_id]),

        `ifdef GBAR_ENABLE
            .gbar_bus_if    (per_core_gbar_bus_if[core_id]),
        `endif

            .busy           (per_core_busy[core_id])
        );
    end


    VX_pipe_register #( 
        .DATAW  ($bits(busy)), 
        .RESETW (1), 
        .DEPTH  ((`SOCKET_SIZE > 1)) 
    ) buffer_ex_edited ( 
        .clk      (clk), 
        .reset    (reset), 
        .enable   (1'b1), 
        .data_in  ((| per_core_busy)), 
        .data_out (busy) 
    );

endmodule
