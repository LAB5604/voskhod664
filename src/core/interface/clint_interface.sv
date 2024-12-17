`include"prv664_config.svh"
`include"prv664_define.svh"
`include"prv664_bus_define.svh"
//////////////////////////////////////////////////////////////////////
//                 interrupt bus interface                          //
//     this interface connect PLIC and core                         //
//////////////////////////////////////////////////////////////////////
interface clint_interface();
    logic   mei, sei;       //machine and supervisior exteneral interrupt
    logic   msi;            //machine software interrupt
    logic   mti;            //machine timer interrupt
    logic [`XLEN-1:0] mtime;
    modport master(
        output mei, sei,
        output msi,
        output mti,
        output mtime
    );
    modport slave(
        input mei, sei,
        input msi,
        input mti,
        input mtime
    );
endinterface