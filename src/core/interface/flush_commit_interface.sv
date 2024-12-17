`include "prv664_config.svh"
`include "prv664_define.svh"
interface flush_commit_interface();
    logic               valid;
    logic [`XLEN-1:0]   newpc;
    modport master(
        output valid,
        output newpc
    );
endinterface
