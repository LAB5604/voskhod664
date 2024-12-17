`include"prv664_config.svh"
`include"prv664_define.svh"
`include"prv664_bus_define.svh"
interface axi_r();
    logic [`BUS_ID_W-1:0]       rid;
    logic [`XLEN-1:0]           rdata;
    logic [1:0]                 rresp;
    logic                       rlast;
    logic                       rvalid;
    logic                       rready;
    modport master(
        output rid,
        output rdata,
        output rresp,
        output rlast,
        output rvalid,
        input  rready
    );
    modport slave(
        input rid,
        input rdata,
        input rresp,
        input rlast,
        input rvalid,
        output rready
    );
endinterface