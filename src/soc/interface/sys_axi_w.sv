`include"salyut1_soc_config.svh"

interface sys_axi_w();
    logic [`AXI_DATA_WIDTH-1:0] wdata;
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