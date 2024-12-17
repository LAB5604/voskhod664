`include "prv664_config.svh"
`include "prv664_define.svh"
interface pip_robread_interface();

    logic [`XLEN-1:0]   data;
    logic [`XLEN-1:0]   csrdata;
    logic [`XLEN-1:0]   branchaddr;
    logic [`XLEN-1:0]   pc;
    logic               jump;
    logic [4:0]         fflag;
    logic               mmio;
    logic               load_acc_flt, load_addr_mis, load_page_flt;
    logic               store_acc_flt, store_addr_mis, store_page_flt;
    logic               instr_accflt,   instr_pageflt,  instr_addrmis;
    logic [4:0]         opcode;
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

    logic [7:0]         itag;
    logic               complete;
    logic               valid;
    logic               ready;

    modport master(
        output data,
        output csrdata,
        output branchaddr,
        output pc,
        output jump,
        output fflag,
        output mmio,
        output load_acc_flt, load_addr_mis, load_page_flt,
        output store_acc_flt, store_addr_mis, store_page_flt,
        output instr_accflt,   instr_pageflt,  instr_addrmis,
        output opcode,
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

        output itag,
        output complete,
        output valid,
        input  ready
    );

    modport slave(
        input data,
        input csrdata,
        input branchaddr,
        input pc,
        input jump,
        input fflag,
        input mmio,
        input load_acc_flt, load_addr_mis, load_page_flt,
        input store_acc_flt, store_addr_mis, store_page_flt,
        input instr_accflt,   instr_pageflt,  instr_addrmis,
        input opcode,
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

        input itag,
        input complete,
        input valid,
        output ready
    );

endinterface