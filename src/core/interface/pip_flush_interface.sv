`include"prv664_config.svh"
`include"prv664_define.svh"
interface pip_flush_interface(

);
    logic [`XLEN-1:0]   newpc;
    logic               flush;
    logic               hold;
    logic               flushbpu;
    modport master(
        output newpc,
        output flush,
        output hold,
        output flushbpu
    );

    modport slave(
        input newpc,
        input flush,
        input hold,
        input flushbpu 
    );

endinterface