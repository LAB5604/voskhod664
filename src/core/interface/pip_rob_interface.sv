`include"prv664_config.svh"
`include"prv664_define.svh"
interface pip_rob_interface();
    
    logic [`XLEN-1:0]   pc;
    logic [4:0]         opcode;
    logic               instr_accflt;
    logic               instr_pageflt;
    logic               instr_addrmis;
    logic               mret;
    logic               sret;
    logic               illins;
    logic               ecall;
    logic               ebreak;
    logic               irrevo;
    logic [4:0]         rdindex;
    logic               rden;
    logic [4:0]         frdindex;
    logic               frden;
    logic [11:0]        csrindex;
    logic               csren;
    logic               fflagen;
    logic [2:0]         branchtype;
    logic               valid;
    logic               full;
    logic               empty;
    logic               complete;
    logic [7:0]         entrynum;           //which entry will be use

    modport master(

        output pc,
        output opcode,
        output instr_accflt,
        output instr_pageflt,
        output instr_addrmis,
        output mret,
        output sret,
        output illins,
        output ecall,
        output ebreak,
        output irrevo,
        output rdindex,
        output rden,
        output frdindex,
        output frden,
        output csrindex,
        output csren,
        output fflagen,
        output branchtype,
        output valid,
        input  full,
        input  empty,
        output complete,
        input  entrynum

    );
    modport slave(

        input pc,
        input opcode,
        input instr_accflt,
        input instr_pageflt,
        input instr_addrmis,
        input mret,
        input sret,
        input illins,
        input ecall,
        input ebreak,
        input irrevo,
        input rdindex,
        input rden,
        input frdindex,
        input frden,
        input csrindex,
        input csren,
        input fflagen,
        input branchtype,
        input valid,
        output full,
        output empty,
        input complete,
        output entrynum

    );
endinterface