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

`include "VX_cache_define.vh"

module VX_cache_cluster import VX_gpu_pkg::*; #(
    parameter `STRING INSTANCE_ID    = "",

    parameter NUM_UNITS             = 1,
    parameter NUM_INPUTS            = 1,
    parameter TAG_SEL_IDX           = 0,

    // Number of requests per cycle
    parameter NUM_REQS              = 4,

    // Number of memory ports
    parameter MEM_PORTS             = 1,

    // Size of cache in bytes
    parameter CACHE_SIZE            = 32768,
    // Size of line inside a bank in bytes
    parameter LINE_SIZE             = 64,
    // Number of banks
    parameter NUM_BANKS             = 4,
    // Number of associative ways
    parameter NUM_WAYS              = 4,
    // Size of a word in bytes
    parameter WORD_SIZE             = 16,

    // Core Response Queue Size
    parameter CRSQ_SIZE             = 4,
    // Miss Reserv Queue Knob
    parameter MSHR_SIZE             = 16,
    // Memory Response Queue Size
    parameter MRSQ_SIZE             = 4,
    // Memory Request Queue Size
    parameter MREQ_SIZE             = 4,

    // Enable cache writeable
    parameter WRITE_ENABLE          = 1,

    // Enable cache writeback
    parameter WRITEBACK             = 0,

    // Enable dirty bytes on writeback
    parameter DIRTY_BYTES           = 0,

    // Replacement policy
    parameter REPL_POLICY           = `CS_REPL_FIFO,

    // core request tag size
    parameter TAG_WIDTH             = UUID_WIDTH + 1,

    // enable bypass for non-cacheable addresses
    parameter NC_ENABLE             = 0,

    // Core response output buffer
    parameter CORE_OUT_BUF          = 3,

    // Memory request output buffer
    parameter MEM_OUT_BUF           = 3
 ) (
    input wire clk,
    input wire reset,

    // PERF
`ifdef PERF_ENABLE
    output cache_perf_t     cache_perf,
`endif

    VX_mem_bus_if.slave     core_bus_if [NUM_INPUTS * NUM_REQS],
    VX_mem_bus_if.master    mem_bus_if [MEM_PORTS]
);
    localparam NUM_CACHES = `UP(NUM_UNITS);
    localparam PASSTHRU   = (NUM_UNITS == 0);
    localparam ARB_TAG_WIDTH = TAG_WIDTH + `ARB_SEL_BITS(NUM_INPUTS, NUM_CACHES);

    localparam CACHE_MEM_TAG_WIDTH = `CACHE_MEM_TAG_WIDTH(MSHR_SIZE, NUM_BANKS, MEM_PORTS, UUID_WIDTH);
    localparam BYPASS_TAG_WIDTH = `CACHE_BYPASS_TAG_WIDTH(NUM_REQS, MEM_PORTS, LINE_SIZE, WORD_SIZE, ARB_TAG_WIDTH);
    localparam NC_TAG_WIDTH = `MAX(CACHE_MEM_TAG_WIDTH, BYPASS_TAG_WIDTH) + 1;
    localparam MEM_TAG_WIDTH = PASSTHRU ? BYPASS_TAG_WIDTH : (NC_ENABLE ? NC_TAG_WIDTH : CACHE_MEM_TAG_WIDTH);

    // Width constants for flat wire arrays
    localparam CORE_ADDR_WIDTH     = `CS_WORD_ADDR_WIDTH;
    localparam CORE_DATA_WIDTH     = WORD_SIZE * 8;
    localparam CORE_FLAGS_WIDTH    = MEM_FLAGS_WIDTH;
    localparam MEM_ADDR_WIDTH_L    = `CS_MEM_ADDR_WIDTH;
    localparam MEM_DATA_WIDTH      = LINE_SIZE * 8;
    localparam MEM_FLAGS_WIDTH_L   = MEM_FLAGS_WIDTH;

    // Core arbiter LOG_NUM_REQS per req channel
    localparam LOG_NUM_REQS_CORE = `ARB_SEL_BITS(NUM_INPUTS, NUM_CACHES);

    `STATIC_ASSERT(NUM_INPUTS >= NUM_CACHES, ("invalid parameter"))

`ifdef PERF_ENABLE
    cache_perf_t perf_cache_unit[NUM_CACHES];
    `PERF_CACHE_ADD (cache_perf, perf_cache_unit, NUM_CACHES)
`endif

    ///////////////////////////////////////////////////////////////////////////
    // Bridge core_bus_if interface array -> flat wire arrays (module scope)
    ///////////////////////////////////////////////////////////////////////////

    localparam TOTAL_CORE_INPUTS = NUM_INPUTS * NUM_REQS;

    wire [TOTAL_CORE_INPUTS-1:0]                          core_in_req_valid;
    wire [TOTAL_CORE_INPUTS-1:0]                          core_in_req_rw;
    wire [TOTAL_CORE_INPUTS-1:0][CORE_ADDR_WIDTH-1:0]     core_in_req_addr;
    wire [TOTAL_CORE_INPUTS-1:0][CORE_DATA_WIDTH-1:0]     core_in_req_data;
    wire [TOTAL_CORE_INPUTS-1:0][WORD_SIZE-1:0]           core_in_req_byteen;
    wire [TOTAL_CORE_INPUTS-1:0][CORE_FLAGS_WIDTH-1:0]    core_in_req_flags;
    wire [TOTAL_CORE_INPUTS-1:0][TAG_WIDTH-1:0]           core_in_req_tag;
    wire [TOTAL_CORE_INPUTS-1:0]                          core_in_req_ready;
    wire [TOTAL_CORE_INPUTS-1:0]                          core_in_rsp_valid;
    wire [TOTAL_CORE_INPUTS-1:0][CORE_DATA_WIDTH-1:0]     core_in_rsp_data;
    wire [TOTAL_CORE_INPUTS-1:0][TAG_WIDTH-1:0]           core_in_rsp_tag;
    wire [TOTAL_CORE_INPUTS-1:0]                          core_in_rsp_ready;

    for (genvar i = 0; i < TOTAL_CORE_INPUTS; ++i) begin : g_core_in_bridge
        assign core_in_req_valid[i]       = core_bus_if[i].req_valid;
        assign core_in_req_rw[i]          = core_bus_if[i].req_data.rw;
        assign core_in_req_addr[i]        = core_bus_if[i].req_data.addr;
        assign core_in_req_data[i]        = core_bus_if[i].req_data.data;
        assign core_in_req_byteen[i]      = core_bus_if[i].req_data.byteen;
        assign core_in_req_flags[i]       = core_bus_if[i].req_data.flags;
        assign core_in_req_tag[i]         = core_bus_if[i].req_data.tag;
        assign core_bus_if[i].req_ready   = core_in_req_ready[i];

        assign core_bus_if[i].rsp_valid   = core_in_rsp_valid[i];
        assign core_bus_if[i].rsp_data    = {core_in_rsp_data[i], core_in_rsp_tag[i]};
        assign core_in_rsp_ready[i]       = core_bus_if[i].rsp_ready;
    end

    ///////////////////////////////////////////////////////////////////////////
    // Transpose: core_in[j*NUM_REQS+i] -> core_tmp[i*NUM_INPUTS+j]
    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_REQS * NUM_INPUTS-1:0]                          core_tmp_req_valid;
    wire [NUM_REQS * NUM_INPUTS-1:0]                          core_tmp_req_rw;
    wire [NUM_REQS * NUM_INPUTS-1:0][CORE_ADDR_WIDTH-1:0]     core_tmp_req_addr;
    wire [NUM_REQS * NUM_INPUTS-1:0][CORE_DATA_WIDTH-1:0]     core_tmp_req_data;
    wire [NUM_REQS * NUM_INPUTS-1:0][WORD_SIZE-1:0]           core_tmp_req_byteen;
    wire [NUM_REQS * NUM_INPUTS-1:0][CORE_FLAGS_WIDTH-1:0]    core_tmp_req_flags;
    wire [NUM_REQS * NUM_INPUTS-1:0][TAG_WIDTH-1:0]           core_tmp_req_tag;
    wire [NUM_REQS * NUM_INPUTS-1:0]                          core_tmp_req_ready;
    wire [NUM_REQS * NUM_INPUTS-1:0]                          core_tmp_rsp_valid;
    wire [NUM_REQS * NUM_INPUTS-1:0][CORE_DATA_WIDTH-1:0]     core_tmp_rsp_data;
    wire [NUM_REQS * NUM_INPUTS-1:0][TAG_WIDTH-1:0]           core_tmp_rsp_tag;
    wire [NUM_REQS * NUM_INPUTS-1:0]                          core_tmp_rsp_ready;

    for (genvar i = 0; i < NUM_REQS; ++i) begin : g_core_transpose_i
        for (genvar j = 0; j < NUM_INPUTS; ++j) begin : g_core_transpose_j
            localparam SRC = j * NUM_REQS + i;
            localparam DST = i * NUM_INPUTS + j;
            assign core_tmp_req_valid[DST]  = core_in_req_valid[SRC];
            assign core_tmp_req_rw[DST]     = core_in_req_rw[SRC];
            assign core_tmp_req_addr[DST]   = core_in_req_addr[SRC];
            assign core_tmp_req_data[DST]   = core_in_req_data[SRC];
            assign core_tmp_req_byteen[DST] = core_in_req_byteen[SRC];
            assign core_tmp_req_flags[DST]  = core_in_req_flags[SRC];
            assign core_tmp_req_tag[DST]    = core_in_req_tag[SRC];
            assign core_in_req_ready[SRC]   = core_tmp_req_ready[DST];

            assign core_in_rsp_valid[SRC]   = core_tmp_rsp_valid[DST];
            assign core_in_rsp_data[SRC]    = core_tmp_rsp_data[DST];
            assign core_in_rsp_tag[SRC]     = core_tmp_rsp_tag[DST];
            assign core_tmp_rsp_ready[DST]  = core_in_rsp_ready[SRC];
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Core arbiters: one per NUM_REQS (slicing with +: on flat wires - supported!)
    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_REQS * NUM_CACHES-1:0]                              arb_out_req_valid;
    wire [NUM_REQS * NUM_CACHES-1:0]                              arb_out_req_rw;
    wire [NUM_REQS * NUM_CACHES-1:0][CORE_ADDR_WIDTH-1:0]         arb_out_req_addr;
    wire [NUM_REQS * NUM_CACHES-1:0][CORE_DATA_WIDTH-1:0]         arb_out_req_data;
    wire [NUM_REQS * NUM_CACHES-1:0][WORD_SIZE-1:0]               arb_out_req_byteen;
    wire [NUM_REQS * NUM_CACHES-1:0][CORE_FLAGS_WIDTH-1:0]        arb_out_req_flags;
    wire [NUM_REQS * NUM_CACHES-1:0][ARB_TAG_WIDTH-1:0]           arb_out_req_tag;
    wire [NUM_REQS * NUM_CACHES-1:0]                              arb_out_req_ready;
    wire [NUM_REQS * NUM_CACHES-1:0]                              arb_out_rsp_valid;
    wire [NUM_REQS * NUM_CACHES-1:0][CORE_DATA_WIDTH-1:0]         arb_out_rsp_data;
    wire [NUM_REQS * NUM_CACHES-1:0][ARB_TAG_WIDTH-1:0]           arb_out_rsp_tag;
    wire [NUM_REQS * NUM_CACHES-1:0]                              arb_out_rsp_ready;

    for (genvar i = 0; i < NUM_REQS; ++i) begin : g_core_arb
        VX_mem_arb #(
            .NUM_INPUTS   (NUM_INPUTS),
            .NUM_OUTPUTS  (NUM_CACHES),
            .DATA_SIZE    (WORD_SIZE),
            .TAG_WIDTH    (TAG_WIDTH),
            .TAG_SEL_IDX  (TAG_SEL_IDX),
            .ARBITER      ("R"),
            .REQ_OUT_BUF  ((NUM_INPUTS != NUM_CACHES) ? 2 : 0),
            .RSP_OUT_BUF  ((NUM_INPUTS != NUM_CACHES) ? CORE_OUT_BUF : 0)
        ) core_arb (
            .clk        (clk),
            .reset      (reset),
            .bus_in_req_valid   (core_tmp_req_valid  [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_req_rw      (core_tmp_req_rw     [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_req_addr    (core_tmp_req_addr   [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_req_data    (core_tmp_req_data   [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_req_byteen  (core_tmp_req_byteen [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_req_flags   (core_tmp_req_flags  [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_req_tag     (core_tmp_req_tag    [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_req_ready   (core_tmp_req_ready  [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_rsp_valid   (core_tmp_rsp_valid  [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_rsp_data    (core_tmp_rsp_data   [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_rsp_tag     (core_tmp_rsp_tag    [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_in_rsp_ready   (core_tmp_rsp_ready  [i * NUM_INPUTS +: NUM_INPUTS]),
            .bus_out_req_valid  (arb_out_req_valid   [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_req_rw     (arb_out_req_rw      [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_req_addr   (arb_out_req_addr    [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_req_data   (arb_out_req_data    [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_req_byteen (arb_out_req_byteen  [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_req_flags  (arb_out_req_flags   [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_req_tag    (arb_out_req_tag     [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_req_ready  (arb_out_req_ready   [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_rsp_valid  (arb_out_rsp_valid   [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_rsp_data   (arb_out_rsp_data    [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_rsp_tag    (arb_out_rsp_tag     [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_rsp_ready  (arb_out_rsp_ready   [i * NUM_CACHES +: NUM_CACHES])
        );
    end

    ///////////////////////////////////////////////////////////////////////////
    // Transpose arb outputs: arb_out[i*NUM_CACHES+k] -> cache_in[k*NUM_REQS+i]
    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_CACHES * NUM_REQS-1:0]                              cache_in_req_valid;
    wire [NUM_CACHES * NUM_REQS-1:0]                              cache_in_req_rw;
    wire [NUM_CACHES * NUM_REQS-1:0][CORE_ADDR_WIDTH-1:0]         cache_in_req_addr;
    wire [NUM_CACHES * NUM_REQS-1:0][CORE_DATA_WIDTH-1:0]         cache_in_req_data;
    wire [NUM_CACHES * NUM_REQS-1:0][WORD_SIZE-1:0]               cache_in_req_byteen;
    wire [NUM_CACHES * NUM_REQS-1:0][CORE_FLAGS_WIDTH-1:0]        cache_in_req_flags;
    wire [NUM_CACHES * NUM_REQS-1:0][ARB_TAG_WIDTH-1:0]           cache_in_req_tag;
    wire [NUM_CACHES * NUM_REQS-1:0]                              cache_in_req_ready;
    wire [NUM_CACHES * NUM_REQS-1:0]                              cache_in_rsp_valid;
    wire [NUM_CACHES * NUM_REQS-1:0][CORE_DATA_WIDTH-1:0]         cache_in_rsp_data;
    wire [NUM_CACHES * NUM_REQS-1:0][ARB_TAG_WIDTH-1:0]           cache_in_rsp_tag;
    wire [NUM_CACHES * NUM_REQS-1:0]                              cache_in_rsp_ready;

    for (genvar i = 0; i < NUM_REQS; ++i) begin : g_cache_in_transpose_i
        for (genvar k = 0; k < NUM_CACHES; ++k) begin : g_cache_in_transpose_k
            localparam SRC = i * NUM_CACHES + k;
            localparam DST = k * NUM_REQS + i;
            assign cache_in_req_valid[DST]  = arb_out_req_valid[SRC];
            assign cache_in_req_rw[DST]     = arb_out_req_rw[SRC];
            assign cache_in_req_addr[DST]   = arb_out_req_addr[SRC];
            assign cache_in_req_data[DST]   = arb_out_req_data[SRC];
            assign cache_in_req_byteen[DST] = arb_out_req_byteen[SRC];
            assign cache_in_req_flags[DST]  = arb_out_req_flags[SRC];
            assign cache_in_req_tag[DST]    = arb_out_req_tag[SRC];
            assign arb_out_req_ready[SRC]   = cache_in_req_ready[DST];

            assign arb_out_rsp_valid[SRC]   = cache_in_rsp_valid[DST];
            assign arb_out_rsp_data[SRC]    = cache_in_rsp_data[DST];
            assign arb_out_rsp_tag[SRC]     = cache_in_rsp_tag[DST];
            assign cache_in_rsp_ready[DST]  = arb_out_rsp_ready[SRC];
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Cache wraps: one per NUM_CACHES (using +: on flat wires)
    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_CACHES * MEM_PORTS-1:0]                              cache_mem_req_valid;
    wire [NUM_CACHES * MEM_PORTS-1:0]                              cache_mem_req_rw;
    wire [NUM_CACHES * MEM_PORTS-1:0][MEM_ADDR_WIDTH_L-1:0]        cache_mem_req_addr;
    wire [NUM_CACHES * MEM_PORTS-1:0][MEM_DATA_WIDTH-1:0]          cache_mem_req_data;
    wire [NUM_CACHES * MEM_PORTS-1:0][LINE_SIZE-1:0]               cache_mem_req_byteen;
    wire [NUM_CACHES * MEM_PORTS-1:0][MEM_FLAGS_WIDTH_L-1:0]       cache_mem_req_flags;
    wire [NUM_CACHES * MEM_PORTS-1:0][MEM_TAG_WIDTH-1:0]           cache_mem_req_tag;
    wire [NUM_CACHES * MEM_PORTS-1:0]                              cache_mem_req_ready;
    wire [NUM_CACHES * MEM_PORTS-1:0]                              cache_mem_rsp_valid;
    wire [NUM_CACHES * MEM_PORTS-1:0][MEM_DATA_WIDTH-1:0]          cache_mem_rsp_data;
    wire [NUM_CACHES * MEM_PORTS-1:0][MEM_TAG_WIDTH-1:0]           cache_mem_rsp_tag;
    wire [NUM_CACHES * MEM_PORTS-1:0]                              cache_mem_rsp_ready;

    for (genvar i = 0; i < NUM_CACHES; ++i) begin : g_cache_wrap
        VX_cache_wrap #(
            .INSTANCE_ID  (`SFORMATF(("%s%0d", INSTANCE_ID, i))),
            .CACHE_SIZE   (CACHE_SIZE),
            .LINE_SIZE    (LINE_SIZE),
            .NUM_BANKS    (NUM_BANKS),
            .NUM_WAYS     (NUM_WAYS),
            .WORD_SIZE    (WORD_SIZE),
            .NUM_REQS     (NUM_REQS),
            .MEM_PORTS    (MEM_PORTS),
            .WRITE_ENABLE (WRITE_ENABLE),
            .WRITEBACK    (WRITEBACK),
            .DIRTY_BYTES  (DIRTY_BYTES),
            .REPL_POLICY  (REPL_POLICY),
            .CRSQ_SIZE    (CRSQ_SIZE),
            .MSHR_SIZE    (MSHR_SIZE),
            .MRSQ_SIZE    (MRSQ_SIZE),
            .MREQ_SIZE    (MREQ_SIZE),
            .TAG_WIDTH    (ARB_TAG_WIDTH),
            .TAG_SEL_IDX  (TAG_SEL_IDX),
            .CORE_OUT_BUF ((NUM_INPUTS != NUM_CACHES) ? 2 : CORE_OUT_BUF),
            .MEM_OUT_BUF  ((NUM_CACHES > 1) ? 2 : MEM_OUT_BUF),
            .NC_ENABLE    (NC_ENABLE),
            .PASSTHRU     (PASSTHRU),
            .MEM_TAG_WIDTH_LOCAL (MEM_TAG_WIDTH)
        ) cache_wrap (
        `ifdef PERF_ENABLE
            .cache_perf         (perf_cache_unit[i]),
        `endif
            .clk                (clk),
            .reset              (reset),
            .core_bus_req_valid (cache_in_req_valid  [i * NUM_REQS +: NUM_REQS]),
            .core_bus_req_rw    (cache_in_req_rw     [i * NUM_REQS +: NUM_REQS]),
            .core_bus_req_addr  (cache_in_req_addr   [i * NUM_REQS +: NUM_REQS]),
            .core_bus_req_data  (cache_in_req_data   [i * NUM_REQS +: NUM_REQS]),
            .core_bus_req_byteen(cache_in_req_byteen [i * NUM_REQS +: NUM_REQS]),
            .core_bus_req_flags (cache_in_req_flags  [i * NUM_REQS +: NUM_REQS]),
            .core_bus_req_tag   (cache_in_req_tag    [i * NUM_REQS +: NUM_REQS]),
            .core_bus_req_ready (cache_in_req_ready  [i * NUM_REQS +: NUM_REQS]),
            .core_bus_rsp_valid (cache_in_rsp_valid  [i * NUM_REQS +: NUM_REQS]),
            .core_bus_rsp_data  (cache_in_rsp_data   [i * NUM_REQS +: NUM_REQS]),
            .core_bus_rsp_tag   (cache_in_rsp_tag    [i * NUM_REQS +: NUM_REQS]),
            .core_bus_rsp_ready (cache_in_rsp_ready  [i * NUM_REQS +: NUM_REQS]),
            .mem_bus_req_valid  (cache_mem_req_valid  [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_req_rw     (cache_mem_req_rw     [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_req_addr   (cache_mem_req_addr   [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_req_data   (cache_mem_req_data   [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_req_byteen (cache_mem_req_byteen [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_req_flags  (cache_mem_req_flags  [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_req_tag    (cache_mem_req_tag    [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_req_ready  (cache_mem_req_ready  [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_rsp_valid  (cache_mem_rsp_valid  [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_rsp_data   (cache_mem_rsp_data   [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_rsp_tag    (cache_mem_rsp_tag    [i * MEM_PORTS +: MEM_PORTS]),
            .mem_bus_rsp_ready  (cache_mem_rsp_ready  [i * MEM_PORTS +: MEM_PORTS])
        );
    end

    ///////////////////////////////////////////////////////////////////////////
    // Transpose cache mem outputs: cache_mem[j*MEM_PORTS+i] -> mem_tmp[i*NUM_CACHES+j]
    ///////////////////////////////////////////////////////////////////////////

    wire [MEM_PORTS * NUM_CACHES-1:0]                              mem_tmp_req_valid;
    wire [MEM_PORTS * NUM_CACHES-1:0]                              mem_tmp_req_rw;
    wire [MEM_PORTS * NUM_CACHES-1:0][MEM_ADDR_WIDTH_L-1:0]        mem_tmp_req_addr;
    wire [MEM_PORTS * NUM_CACHES-1:0][MEM_DATA_WIDTH-1:0]          mem_tmp_req_data;
    wire [MEM_PORTS * NUM_CACHES-1:0][LINE_SIZE-1:0]               mem_tmp_req_byteen;
    wire [MEM_PORTS * NUM_CACHES-1:0][MEM_FLAGS_WIDTH_L-1:0]       mem_tmp_req_flags;
    wire [MEM_PORTS * NUM_CACHES-1:0][MEM_TAG_WIDTH-1:0]           mem_tmp_req_tag;
    wire [MEM_PORTS * NUM_CACHES-1:0]                              mem_tmp_req_ready;
    wire [MEM_PORTS * NUM_CACHES-1:0]                              mem_tmp_rsp_valid;
    wire [MEM_PORTS * NUM_CACHES-1:0][MEM_DATA_WIDTH-1:0]          mem_tmp_rsp_data;
    wire [MEM_PORTS * NUM_CACHES-1:0][MEM_TAG_WIDTH-1:0]           mem_tmp_rsp_tag;
    wire [MEM_PORTS * NUM_CACHES-1:0]                              mem_tmp_rsp_ready;

    for (genvar i = 0; i < MEM_PORTS; ++i) begin : g_mem_transpose_i
        for (genvar j = 0; j < NUM_CACHES; ++j) begin : g_mem_transpose_j
            localparam SRC = j * MEM_PORTS + i;
            localparam DST = i * NUM_CACHES + j;
            assign mem_tmp_req_valid[DST]     = cache_mem_req_valid[SRC];
            assign mem_tmp_req_rw[DST]        = cache_mem_req_rw[SRC];
            assign mem_tmp_req_addr[DST]      = cache_mem_req_addr[SRC];
            assign mem_tmp_req_data[DST]      = cache_mem_req_data[SRC];
            assign mem_tmp_req_byteen[DST]    = cache_mem_req_byteen[SRC];
            assign mem_tmp_req_flags[DST]     = cache_mem_req_flags[SRC];
            assign mem_tmp_req_tag[DST]       = cache_mem_req_tag[SRC];
            assign cache_mem_req_ready[SRC]   = mem_tmp_req_ready[DST];

            assign cache_mem_rsp_valid[SRC]   = mem_tmp_rsp_valid[DST];
            assign cache_mem_rsp_data[SRC]    = mem_tmp_rsp_data[DST];
            assign cache_mem_rsp_tag[SRC]     = mem_tmp_rsp_tag[DST];
            assign mem_tmp_rsp_ready[DST]     = cache_mem_rsp_ready[SRC];
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Memory arbiters: one per MEM_PORTS (using +: on flat wires)
    ///////////////////////////////////////////////////////////////////////////

    localparam MEM_ARB_OUT_TAG_WIDTH = MEM_TAG_WIDTH + `ARB_SEL_BITS(NUM_CACHES, 1);

    wire [MEM_PORTS-1:0]                                           mem_out_req_valid;
    wire [MEM_PORTS-1:0]                                           mem_out_req_rw;
    wire [MEM_PORTS-1:0][MEM_ADDR_WIDTH_L-1:0]                     mem_out_req_addr;
    wire [MEM_PORTS-1:0][MEM_DATA_WIDTH-1:0]                       mem_out_req_data;
    wire [MEM_PORTS-1:0][LINE_SIZE-1:0]                            mem_out_req_byteen;
    wire [MEM_PORTS-1:0][MEM_FLAGS_WIDTH_L-1:0]                    mem_out_req_flags;
    wire [MEM_PORTS-1:0][MEM_ARB_OUT_TAG_WIDTH-1:0]                mem_out_req_tag;
    wire [MEM_PORTS-1:0]                                           mem_out_req_ready;
    wire [MEM_PORTS-1:0]                                           mem_out_rsp_valid;
    wire [MEM_PORTS-1:0][MEM_DATA_WIDTH-1:0]                       mem_out_rsp_data;
    wire [MEM_PORTS-1:0][MEM_ARB_OUT_TAG_WIDTH-1:0]                mem_out_rsp_tag;
    wire [MEM_PORTS-1:0]                                           mem_out_rsp_ready;

    for (genvar i = 0; i < MEM_PORTS; ++i) begin : g_mem_arb
        VX_mem_arb #(
            .NUM_INPUTS  (NUM_CACHES),
            .NUM_OUTPUTS (1),
            .DATA_SIZE   (LINE_SIZE),
            .TAG_WIDTH   (MEM_TAG_WIDTH),
            .TAG_SEL_IDX (TAG_SEL_IDX),
            .ARBITER     ("R"),
            .REQ_OUT_BUF ((NUM_CACHES > 1) ? MEM_OUT_BUF : 0),
            .RSP_OUT_BUF ((NUM_CACHES > 1) ? 2 : 0)
        ) mem_arb (
            .clk        (clk),
            .reset      (reset),
            .bus_in_req_valid   (mem_tmp_req_valid  [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_req_rw      (mem_tmp_req_rw     [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_req_addr    (mem_tmp_req_addr   [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_req_data    (mem_tmp_req_data   [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_req_byteen  (mem_tmp_req_byteen [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_req_flags   (mem_tmp_req_flags  [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_req_tag     (mem_tmp_req_tag    [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_req_ready   (mem_tmp_req_ready  [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_rsp_valid   (mem_tmp_rsp_valid  [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_rsp_data    (mem_tmp_rsp_data   [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_rsp_tag     (mem_tmp_rsp_tag    [i * NUM_CACHES +: NUM_CACHES]),
            .bus_in_rsp_ready   (mem_tmp_rsp_ready  [i * NUM_CACHES +: NUM_CACHES]),
            .bus_out_req_valid  (mem_out_req_valid  [i +: 1]),
            .bus_out_req_rw     (mem_out_req_rw     [i +: 1]),
            .bus_out_req_addr   (mem_out_req_addr   [i +: 1]),
            .bus_out_req_data   (mem_out_req_data   [i +: 1]),
            .bus_out_req_byteen (mem_out_req_byteen [i +: 1]),
            .bus_out_req_flags  (mem_out_req_flags  [i +: 1]),
            .bus_out_req_tag    (mem_out_req_tag    [i +: 1]),
            .bus_out_req_ready  (mem_out_req_ready  [i +: 1]),
            .bus_out_rsp_valid  (mem_out_rsp_valid  [i +: 1]),
            .bus_out_rsp_data   (mem_out_rsp_data   [i +: 1]),
            .bus_out_rsp_tag    (mem_out_rsp_tag    [i +: 1]),
            .bus_out_rsp_ready  (mem_out_rsp_ready  [i +: 1])
        );

        // Bridge arb output to mem_bus_if interface
        if (WRITE_ENABLE) begin : g_we
            assign mem_bus_if[i].req_valid       = mem_out_req_valid[i];
            assign mem_bus_if[i].req_data        = {mem_out_req_rw[i], mem_out_req_addr[i], mem_out_req_data[i], mem_out_req_byteen[i], mem_out_req_flags[i], mem_out_req_tag[i]};
            assign mem_out_req_ready[i]          = mem_bus_if[i].req_ready;
        end else begin : g_ro
            assign mem_bus_if[i].req_valid       = mem_out_req_valid[i];
            assign mem_bus_if[i].req_data.rw     = 1'b0;
            assign mem_bus_if[i].req_data.addr   = mem_out_req_addr[i];
            assign mem_bus_if[i].req_data.data   = '0;
            assign mem_bus_if[i].req_data.byteen = '0;
            assign mem_bus_if[i].req_data.flags  = mem_out_req_flags[i];
            assign mem_bus_if[i].req_data.tag    = mem_out_req_tag[i];
            assign mem_out_req_ready[i]          = mem_bus_if[i].req_ready;
        end

        assign mem_out_rsp_valid[i]  = mem_bus_if[i].rsp_valid;
        assign mem_out_rsp_data[i]   = mem_bus_if[i].rsp_data.data;
        assign mem_out_rsp_tag[i]    = mem_bus_if[i].rsp_data.tag;
        assign mem_bus_if[i].rsp_ready = mem_out_rsp_ready[i];
    end

endmodule
