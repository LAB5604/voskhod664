`include"salyut1_soc_config.svh"

interface sys_axi_b();
    logic  [`AXI_ID_WIDTH-1:0]  bid;
    logic  [1:0]                bresp;
    logic                       bvalid;
    logic                       bready;
    modport master(
        output bid,
        output bresp,
        output bvalid,
        input  bready
    );
    modport slave(
        input bid,
        input bresp,
        input bvalid,
        output bready 
    );
endinterface