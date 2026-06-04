`include "VX_define.vh"

interface VX_dcache_bus_if import VX_gpu_pkg::*; #(
    parameter DATA_SIZE  = DCACHE_WORD_SIZE,
    parameter FLAGS_WIDTH = MEM_FLAGS_WIDTH,
    parameter TAG_WIDTH  = DCACHE_TAG_WIDTH,
    parameter MEM_ADDR_WIDTH = `MEM_ADDR_WIDTH,
    parameter ADDR_WIDTH = MEM_ADDR_WIDTH - `CLOG2(DATA_SIZE)
) ();

    logic                   req_valid;
    logic                   req_rw;
    logic [ADDR_WIDTH-1:0]  req_addr;
    logic [DATA_SIZE*8-1:0] req_data;
    logic [DATA_SIZE-1:0]   req_byteen;
    logic [FLAGS_WIDTH-1:0] req_flags;
    logic [TAG_WIDTH-1:0]   req_tag;
    logic                   req_ready;

    logic                   rsp_valid;
    logic [DATA_SIZE*8-1:0] rsp_data;
    logic [TAG_WIDTH-1:0]   rsp_tag;
    logic                   rsp_ready;

    modport master (
        output req_valid,
        output req_rw,
        output req_addr,
        output req_data,
        output req_byteen,
        output req_flags,
        output req_tag,
        input  req_ready,

        input  rsp_valid,
        input  rsp_data,
        input  rsp_tag,
        output rsp_ready
    );

    modport slave (
        input  req_valid,
        input  req_rw,
        input  req_addr,
        input  req_data,
        input  req_byteen,
        input  req_flags,
        input  req_tag,
        output req_ready,

        output rsp_valid,
        output rsp_data,
        output rsp_tag,
        input  rsp_ready
    );

endinterface
