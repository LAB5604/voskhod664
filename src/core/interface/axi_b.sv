`include"prv664_config.svh"
`include"prv664_define.svh"
`include"prv664_bus_define.svh"
interface axi_b();
    logic  [`BUS_ID_W-1:0]      bid;
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