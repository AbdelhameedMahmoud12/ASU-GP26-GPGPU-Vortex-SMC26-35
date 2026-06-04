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

module VX_cluster import VX_gpu_pkg::*; #(
    parameter CLUSTER_ID = 0,
    parameter `STRING INSTANCE_ID = ""
) (
    `SCOPE_IO_DECL

    // Clock
    input  wire                 clk,
    input  wire                 reset,

`ifdef PERF_ENABLE
    input sysmem_perf_t         sysmem_perf,
`endif

    // DCRs
    VX_dcr_bus_if.slave         dcr_bus_if,

    // Memory (flattened — L2_MEM_PORTS wide)
    output wire [`L2_MEM_PORTS-1:0]                                          mem_bus_req_valid,
    output wire [`L2_MEM_PORTS-1:0]                                          mem_bus_req_rw,
    output wire [`L2_MEM_PORTS-1:0][`MEM_ADDR_WIDTH-`CLOG2(`L2_LINE_SIZE)-1:0] mem_bus_req_addr,
    output wire [`L2_MEM_PORTS-1:0][`L2_LINE_SIZE*8-1:0]                     mem_bus_req_data,
    output wire [`L2_MEM_PORTS-1:0][`L2_LINE_SIZE-1:0]                       mem_bus_req_byteen,
    output wire [`L2_MEM_PORTS-1:0][MEM_FLAGS_WIDTH-1:0]                     mem_bus_req_flags,
    output wire [`L2_MEM_PORTS-1:0][L2_MEM_TAG_WIDTH-1:0]                    mem_bus_req_tag,
    input  wire [`L2_MEM_PORTS-1:0]                                          mem_bus_req_ready,
    input  wire [`L2_MEM_PORTS-1:0]                                          mem_bus_rsp_valid,
    input  wire [`L2_MEM_PORTS-1:0][`L2_LINE_SIZE*8-1:0]                     mem_bus_rsp_data,
    input  wire [`L2_MEM_PORTS-1:0][L2_MEM_TAG_WIDTH-1:0]                    mem_bus_rsp_tag,
    output wire [`L2_MEM_PORTS-1:0]                                          mem_bus_rsp_ready,

    // Status
    output wire                 busy
);

`ifdef SCOPE
    localparam scope_socket = 0;
    `SCOPE_IO_SWITCH (NUM_SOCKETS);
`endif

`ifdef PERF_ENABLE
    cache_perf_t l2_perf;
    sysmem_perf_t sysmem_perf_tmp;
    always @(*) begin
        sysmem_perf_tmp = sysmem_perf;
        sysmem_perf_tmp.l2cache = l2_perf;
    end
`endif

`ifdef GBAR_ENABLE

    VX_gbar_bus_if per_socket_gbar_bus_if[NUM_SOCKETS]();
    VX_gbar_bus_if gbar_bus_if();

    VX_gbar_arb #(
        .NUM_REQS (NUM_SOCKETS),
        .OUT_BUF  ((NUM_SOCKETS > 2) ? 1 : 0) // bgar_unit has no backpressure
    ) gbar_arb (
        .clk        (clk),
        .reset      (reset),
        .bus_in_if  (per_socket_gbar_bus_if),
        .bus_out_if (gbar_bus_if)
    );

    VX_gbar_unit #(
        .INSTANCE_ID (`SFORMATF(("gbar%0d", CLUSTER_ID)))
    ) gbar_unit (
        .clk         (clk),
        .reset       (reset),
        .gbar_bus_if (gbar_bus_if)
    );

`endif

    // Flat wires for per-socket memory bus (NUM_SOCKETS * L1_MEM_PORTS wide)
    localparam L2_CORE_PORTS = NUM_SOCKETS * `L1_MEM_PORTS;
    localparam L2_CORE_ADDR_WIDTH = (`MEM_ADDR_WIDTH - `CLOG2(`L1_LINE_SIZE));

    wire [L2_CORE_PORTS-1:0]                                       per_socket_mem_req_valid;
    wire [L2_CORE_PORTS-1:0]                                       per_socket_mem_req_rw;
    wire [L2_CORE_PORTS-1:0][L2_CORE_ADDR_WIDTH-1:0]               per_socket_mem_req_addr;
    wire [L2_CORE_PORTS-1:0][`L1_LINE_SIZE*8-1:0]                  per_socket_mem_req_data;
    wire [L2_CORE_PORTS-1:0][`L1_LINE_SIZE-1:0]                    per_socket_mem_req_byteen;
    wire [L2_CORE_PORTS-1:0][MEM_FLAGS_WIDTH-1:0]                  per_socket_mem_req_flags;
    wire [L2_CORE_PORTS-1:0][L1_MEM_ARB_TAG_WIDTH-1:0]             per_socket_mem_req_tag;
    wire [L2_CORE_PORTS-1:0]                                       per_socket_mem_req_ready;
    wire [L2_CORE_PORTS-1:0]                                       per_socket_mem_rsp_valid;
    wire [L2_CORE_PORTS-1:0][`L1_LINE_SIZE*8-1:0]                  per_socket_mem_rsp_data;
    wire [L2_CORE_PORTS-1:0][L1_MEM_ARB_TAG_WIDTH-1:0]             per_socket_mem_rsp_tag;
    wire [L2_CORE_PORTS-1:0]                                       per_socket_mem_rsp_ready;

    `RESET_RELAY (l2_reset, reset);

    VX_cache_wrap #(
        .INSTANCE_ID    (`SFORMATF(("%s-l2cache", INSTANCE_ID))),
        .CACHE_SIZE     (`L2_CACHE_SIZE),
        .LINE_SIZE      (`L2_LINE_SIZE),
        .NUM_BANKS      (`L2_NUM_BANKS),
        .NUM_WAYS       (`L2_NUM_WAYS),
        .WORD_SIZE      (L2_WORD_SIZE),
        .NUM_REQS       (L2_NUM_REQS),
        .MEM_PORTS      (`L2_MEM_PORTS),
        .CRSQ_SIZE      (`L2_CRSQ_SIZE),
        .MSHR_SIZE      (`L2_MSHR_SIZE),
        .MRSQ_SIZE      (`L2_MRSQ_SIZE),
        .MREQ_SIZE      (`L2_WRITEBACK ? `L2_MSHR_SIZE : `L2_MREQ_SIZE),
        .TAG_WIDTH      (L2_TAG_WIDTH),
        .WRITE_ENABLE   (1),
        .WRITEBACK      (`L2_WRITEBACK),
        .DIRTY_BYTES    (`L2_DIRTYBYTES),
        .REPL_POLICY    (`L2_REPL_POLICY),
        .CORE_OUT_BUF   (3),
        .MEM_OUT_BUF    (3),
        .NC_ENABLE      (1),
        .PASSTHRU       (!`L2_ENABLED),
        .MEM_TAG_WIDTH_LOCAL (L2_MEM_TAG_WIDTH)
    ) l2cache (
        .clk            (clk),
        .reset          (l2_reset),
    `ifdef PERF_ENABLE
        .cache_perf     (l2_perf),
    `endif
        // Core side — flat wires
        .core_bus_req_valid  (per_socket_mem_req_valid),
        .core_bus_req_rw     (per_socket_mem_req_rw),
        .core_bus_req_addr   (per_socket_mem_req_addr),
        .core_bus_req_data   (per_socket_mem_req_data),
        .core_bus_req_byteen (per_socket_mem_req_byteen),
        .core_bus_req_flags  (per_socket_mem_req_flags),
        .core_bus_req_tag    (per_socket_mem_req_tag),
        .core_bus_req_ready  (per_socket_mem_req_ready),
        .core_bus_rsp_valid  (per_socket_mem_rsp_valid),
        .core_bus_rsp_data   (per_socket_mem_rsp_data),
        .core_bus_rsp_tag    (per_socket_mem_rsp_tag),
        .core_bus_rsp_ready  (per_socket_mem_rsp_ready),
        // Mem side — flat wires to top-level ports
        .mem_bus_req_valid   (mem_bus_req_valid),
        .mem_bus_req_rw      (mem_bus_req_rw),
        .mem_bus_req_addr    (mem_bus_req_addr),
        .mem_bus_req_data    (mem_bus_req_data),
        .mem_bus_req_byteen  (mem_bus_req_byteen),
        .mem_bus_req_flags   (mem_bus_req_flags),
        .mem_bus_req_tag     (mem_bus_req_tag),
        .mem_bus_req_ready   (mem_bus_req_ready),
        .mem_bus_rsp_valid   (mem_bus_rsp_valid),
        .mem_bus_rsp_data    (mem_bus_rsp_data),
        .mem_bus_rsp_tag     (mem_bus_rsp_tag),
        .mem_bus_rsp_ready   (mem_bus_rsp_ready)
    );

    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_SOCKETS-1:0] per_socket_busy;

    // Generate all sockets
    for (genvar socket_id = 0; socket_id < NUM_SOCKETS; ++socket_id) begin : g_sockets

        `RESET_RELAY (socket_reset, reset);

        VX_dcr_bus_if socket_dcr_bus_if();
        wire is_base_dcr_addr = (dcr_bus_if.write_addr >= `VX_DCR_BASE_STATE_BEGIN && dcr_bus_if.write_addr < `VX_DCR_BASE_STATE_END);
        `BUFFER_DCR_BUS_IF (socket_dcr_bus_if, dcr_bus_if, is_base_dcr_addr, (NUM_SOCKETS > 1))

        VX_socket #(
            .SOCKET_ID ((CLUSTER_ID * NUM_SOCKETS) + socket_id),
            .INSTANCE_ID (`SFORMATF(("%s-socket%0d", INSTANCE_ID, socket_id)))
        ) socket (
            `SCOPE_IO_BIND  (scope_socket+socket_id)

            .clk            (clk),
            .reset          (socket_reset),

        `ifdef PERF_ENABLE
            .sysmem_perf    (sysmem_perf_tmp),
        `endif

            .dcr_bus_if     (socket_dcr_bus_if),

            // Flat mem_bus wires — use regular wire slicing (not interface array slicing)
            .mem_bus_req_valid  (per_socket_mem_req_valid [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_req_rw     (per_socket_mem_req_rw    [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_req_addr   (per_socket_mem_req_addr  [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_req_data   (per_socket_mem_req_data  [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_req_byteen (per_socket_mem_req_byteen[socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_req_flags  (per_socket_mem_req_flags [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_req_tag    (per_socket_mem_req_tag   [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_req_ready  (per_socket_mem_req_ready [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_rsp_valid  (per_socket_mem_rsp_valid [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_rsp_data   (per_socket_mem_rsp_data  [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_rsp_tag    (per_socket_mem_rsp_tag   [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),
            .mem_bus_rsp_ready  (per_socket_mem_rsp_ready [socket_id * `L1_MEM_PORTS +: `L1_MEM_PORTS]),

        `ifdef GBAR_ENABLE
            .gbar_bus_if    (per_socket_gbar_bus_if[socket_id]),
        `endif

            .busy           (per_socket_busy[socket_id])
        );
    end

    VX_pipe_register #(
        .DATAW  (1),
        .RESETW (1),
        .DEPTH  (NUM_SOCKETS > 1)
    ) busy_pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  (| per_socket_busy),
        .data_out (busy)
    );

endmodule
