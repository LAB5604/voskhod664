`include"prv664_config.svh"
`include"prv664_define.svh"
`include"prv664_bus_define.svh"
interface cache_return_interface();

    logic [2*`XLEN-1:0]   rdata;                //return read data
    logic [7:0]           id;
    logic [`CACHE_USER_W-1:0]user;
    logic                 valid;
    logic [5:0]           error;
    logic                 mmio;

    modport master(
        output rdata,
        output id,
        output user,
        output valid,
        output error,
        output mmio
    );
    modport slave(
        input rdata,
        input id,
        input user,
        input valid,
        input error,
        input mmio
    );
endinterface