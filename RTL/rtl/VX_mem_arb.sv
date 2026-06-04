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

module VX_mem_arb import VX_gpu_pkg::*; #(
    parameter NUM_INPUTS     = 1,
    parameter NUM_OUTPUTS    = 1,
    parameter DATA_SIZE      = 1,
    parameter TAG_WIDTH      = 1,
    parameter TAG_SEL_IDX    = 0,
    parameter REQ_OUT_BUF    = 0,
    parameter RSP_OUT_BUF    = 0,
    parameter `STRING ARBITER = "R",
    parameter MEM_ADDR_WIDTH = `MEM_ADDR_WIDTH,
    parameter ADDR_WIDTH     = (MEM_ADDR_WIDTH-`CLOG2(DATA_SIZE)),
    parameter FLAGS_WIDTH    = MEM_FLAGS_WIDTH
) (
    input wire              clk,
    input wire              reset,

    // Flattened bus_in (slave) ports — NUM_INPUTS wide
    input  wire [NUM_INPUTS-1:0]                             bus_in_req_valid,
    input  wire [NUM_INPUTS-1:0]                             bus_in_req_rw,
    input  wire [NUM_INPUTS-1:0][ADDR_WIDTH-1:0]             bus_in_req_addr,
    input  wire [NUM_INPUTS-1:0][DATA_SIZE*8-1:0]            bus_in_req_data,
    input  wire [NUM_INPUTS-1:0][DATA_SIZE-1:0]              bus_in_req_byteen,
    input  wire [NUM_INPUTS-1:0][FLAGS_WIDTH-1:0]            bus_in_req_flags,
    input  wire [NUM_INPUTS-1:0][TAG_WIDTH-1:0]              bus_in_req_tag,
    output wire [NUM_INPUTS-1:0]                             bus_in_req_ready,

    output wire [NUM_INPUTS-1:0]                             bus_in_rsp_valid,
    output wire [NUM_INPUTS-1:0][DATA_SIZE*8-1:0]            bus_in_rsp_data,
    output wire [NUM_INPUTS-1:0][TAG_WIDTH-1:0]              bus_in_rsp_tag,
    input  wire [NUM_INPUTS-1:0]                             bus_in_rsp_ready,

    // Flattened bus_out (master) ports — NUM_OUTPUTS wide
    output wire [NUM_OUTPUTS-1:0]                            bus_out_req_valid,
    output wire [NUM_OUTPUTS-1:0]                            bus_out_req_rw,
    output wire [NUM_OUTPUTS-1:0][ADDR_WIDTH-1:0]            bus_out_req_addr,
    output wire [NUM_OUTPUTS-1:0][DATA_SIZE*8-1:0]           bus_out_req_data,
    output wire [NUM_OUTPUTS-1:0][DATA_SIZE-1:0]             bus_out_req_byteen,
    output wire [NUM_OUTPUTS-1:0][FLAGS_WIDTH-1:0]           bus_out_req_flags,
    output wire [NUM_OUTPUTS-1:0][TAG_WIDTH+`ARB_SEL_BITS(NUM_INPUTS,NUM_OUTPUTS)-1:0] bus_out_req_tag,
    input  wire [NUM_OUTPUTS-1:0]                            bus_out_req_ready,

    input  wire [NUM_OUTPUTS-1:0]                            bus_out_rsp_valid,
    input  wire [NUM_OUTPUTS-1:0][DATA_SIZE*8-1:0]           bus_out_rsp_data,
    input  wire [NUM_OUTPUTS-1:0][TAG_WIDTH+`ARB_SEL_BITS(NUM_INPUTS,NUM_OUTPUTS)-1:0] bus_out_rsp_tag,
    output wire [NUM_OUTPUTS-1:0]                            bus_out_rsp_ready
);
    localparam DATA_WIDTH   = (8 * DATA_SIZE);
    localparam LOG_NUM_REQS = `ARB_SEL_BITS(NUM_INPUTS, NUM_OUTPUTS);
    localparam REQ_DATAW    = 1 + ADDR_WIDTH + DATA_WIDTH + DATA_SIZE + FLAGS_WIDTH + TAG_WIDTH;
    localparam RSP_DATAW    = DATA_WIDTH + TAG_WIDTH;
    localparam SEL_COUNT    = `MIN(NUM_INPUTS, NUM_OUTPUTS);

    wire [NUM_INPUTS-1:0]                 req_valid_in;
    wire [NUM_INPUTS-1:0][REQ_DATAW-1:0]  req_data_in;
    wire [NUM_INPUTS-1:0]                 req_ready_in;

    wire [NUM_OUTPUTS-1:0]                req_valid_out;
    wire [NUM_OUTPUTS-1:0][REQ_DATAW-1:0] req_data_out;
    wire [SEL_COUNT-1:0][`UP(LOG_NUM_REQS)-1:0] req_sel_out;
    wire [NUM_OUTPUTS-1:0]                req_ready_out;

    // Map flat input ports to internal wires
    for (genvar i = 0; i < NUM_INPUTS; ++i) begin : g_req_data_in
        assign req_valid_in[i] = bus_in_req_valid[i];
        assign req_data_in[i]  = {bus_in_req_rw[i], bus_in_req_addr[i], bus_in_req_data[i], bus_in_req_byteen[i], bus_in_req_flags[i], bus_in_req_tag[i]};
        assign bus_in_req_ready[i] = req_ready_in[i];
    end

    VX_stream_arb #(
        .NUM_INPUTS  (NUM_INPUTS),
        .NUM_OUTPUTS (NUM_OUTPUTS),
        .DATAW       (REQ_DATAW),
        .ARBITER     (ARBITER),
        .OUT_BUF     (REQ_OUT_BUF)
    ) req_arb (
        .clk       (clk),
        .reset     (reset),
        .valid_in  (req_valid_in),
        .ready_in  (req_ready_in),
        .data_in   (req_data_in),
        .data_out  (req_data_out),
        .sel_out   (req_sel_out),
        .valid_out (req_valid_out),
        .ready_out (req_ready_out)
    );

    for (genvar i = 0; i < NUM_OUTPUTS; ++i) begin : g_bus_out_if
        wire [TAG_WIDTH-1:0] req_tag_out;
        assign bus_out_req_valid[i] = req_valid_out[i];
        assign {
            bus_out_req_rw[i],
            bus_out_req_addr[i],
            bus_out_req_data[i],
            bus_out_req_byteen[i],
            bus_out_req_flags[i],
            req_tag_out
        } = req_data_out[i];
        assign req_ready_out[i] = bus_out_req_ready[i];
        
        if (NUM_INPUTS > NUM_OUTPUTS) begin : g_req_tag_sel_out
            VX_bits_insert #(
            .N   (TAG_WIDTH),
            .S   (LOG_NUM_REQS),
            .POS (TAG_SEL_IDX)
            ) bits_insert (
                .data_in  (req_tag_out),
                .ins_in   (req_sel_out[i]),
                .data_out (bus_out_req_tag[i])
            );
        end else begin : g_req_tag_out
            `UNUSED_VAR (req_sel_out)
            assign bus_out_req_tag[i] = req_tag_out;
        end
    end

    ///////////////////////////////////////////////////////////////////////////

    wire [NUM_INPUTS-1:0]                 rsp_valid_out;
    wire [NUM_INPUTS-1:0][RSP_DATAW-1:0]  rsp_data_out;
    wire [NUM_INPUTS-1:0]                 rsp_ready_out;

    wire [NUM_OUTPUTS-1:0]                rsp_valid_in;
    wire [NUM_OUTPUTS-1:0][RSP_DATAW-1:0] rsp_data_in;
    wire [NUM_OUTPUTS-1:0]                rsp_ready_in;

    if (NUM_INPUTS > NUM_OUTPUTS) begin : g_rsp_select

        wire [NUM_OUTPUTS-1:0][LOG_NUM_REQS-1:0] rsp_sel_in;

        for (genvar i = 0; i < NUM_OUTPUTS; ++i) begin : g_rsp_data_in
            wire [TAG_WIDTH-1:0] rsp_tag_out;
            VX_bits_remove #(
                .N   (TAG_WIDTH + LOG_NUM_REQS),
                .S   (LOG_NUM_REQS),
                .POS (TAG_SEL_IDX)
            ) bits_remove (
                .data_in  (bus_out_rsp_tag[i]),
                .sel_out  (rsp_sel_in[i]),
                .data_out (rsp_tag_out)
            );
            assign rsp_valid_in[i] = bus_out_rsp_valid[i];
            assign rsp_data_in[i]  = {bus_out_rsp_data[i], rsp_tag_out};
            assign bus_out_rsp_ready[i] = rsp_ready_in[i];
        end

        VX_stream_switch #(
            .NUM_INPUTS  (NUM_OUTPUTS),
            .NUM_OUTPUTS (NUM_INPUTS),
            .DATAW       (RSP_DATAW),
            .OUT_BUF     (RSP_OUT_BUF)
        ) rsp_switch (
            .clk       (clk),
            .reset     (reset),
            .sel_in    (rsp_sel_in),
            .valid_in  (rsp_valid_in),
            .ready_in  (rsp_ready_in),
            .data_in   (rsp_data_in),
            .data_out  (rsp_data_out),
            .valid_out (rsp_valid_out),
            .ready_out (rsp_ready_out)
        );

    end else begin : g_rsp_arb

        for (genvar i = 0; i < NUM_OUTPUTS; ++i) begin : g_rsp_data_in
            assign rsp_valid_in[i] = bus_out_rsp_valid[i];
            assign rsp_data_in[i]  = {bus_out_rsp_data[i], bus_out_rsp_tag[i]};
            assign bus_out_rsp_ready[i] = rsp_ready_in[i];
        end

        VX_stream_arb #(
            .NUM_INPUTS  (NUM_OUTPUTS),
            .NUM_OUTPUTS (NUM_INPUTS),
            .DATAW       (RSP_DATAW),
            .ARBITER     (ARBITER),
            .OUT_BUF     (RSP_OUT_BUF)
        ) req_arb (
            .clk       (clk),
            .reset     (reset),
            .valid_in  (rsp_valid_in),
            .ready_in  (rsp_ready_in),
            .data_in   (rsp_data_in),
            .data_out  (rsp_data_out),
            .valid_out (rsp_valid_out),
            .ready_out (rsp_ready_out),
            `UNUSED_PIN (sel_out)
        );

    end

    for (genvar i = 0; i < NUM_INPUTS; ++i) begin : g_output
        assign bus_in_rsp_valid[i] = rsp_valid_out[i];
        assign {bus_in_rsp_data[i], bus_in_rsp_tag[i]} = rsp_data_out[i];
        assign rsp_ready_out[i] = bus_in_rsp_ready[i];
    end

endmodule
