`include"salyut1_soc_config.svh"

interface sys_axi_r();
    logic [`AXI_ID_WIDTH-1:0]   rid;
    logic [`AXI_DATA_WIDTH-1:0] rdata;
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