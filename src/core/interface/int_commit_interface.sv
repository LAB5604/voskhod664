`include "prv664_config.svh"
`include "prv664_define.svh"
//          整数提交接口，向整数寄存器组提交值
interface int_commit_interface();

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
    modport slave(
        input  valid,
        input  wren,
        input  data,
        input  rdindex
    );

endinterface