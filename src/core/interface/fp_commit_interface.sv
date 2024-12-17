`include "prv664_config.svh"
`include "prv664_define.svh"
interface fp_commit_interface();

    logic               valid;
    logic               wren;
    logic [`XLEN-1:0]   data;
    logic [4:0]         rdindex;

    modport master(
        output valid,
        output wren,
        output data,
        output rdindex
    );


endinterface
