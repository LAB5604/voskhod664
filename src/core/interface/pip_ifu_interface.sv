`include"prv664_config.svh"
`include"prv664_define.svh"
interface pip_ifu_interface(

);

    logic [127:0]           instr;
    logic [`XLEN-1:0]       grouppc;
    logic [3:0]             validword;
    logic [5:0]             errtype;
    logic                   valid;
    logic                   ready;

    modport master (

        output                  instr,
        output                  grouppc,
        output                  validword,
        output                  errtype,
        output                  valid,
        input                   ready

    );

    modport slave (

        input                   instr,
        input                   grouppc,
        input                   validword,
        input                   errtype,
        input                   valid,
        output                  ready

    );

endinterface