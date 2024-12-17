`include"prv664_config.svh"
`include"prv664_define.svh"
`include"prv664_bus_define.svh"
interface axi_w();
    logic [`XLEN-1:0]           wdata;
    logic [7:0]                 wstrb;
    logic                       wlast;
    logic                       wvalid;
    logic                       wready;
    modport master(
        output wdata,
        output wstrb,
        output wlast,
        output wvalid,
        input  wready
    );
    modport slave(
        input wdata,
        input wstrb,
        input wlast,
        input wvalid,
        output wready
    );
endinterface