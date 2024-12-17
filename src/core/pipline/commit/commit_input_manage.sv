`include "timescale.v"
module commit_input_manage(
    input wire clk_i,
    input wire arst_i,
    pip_flush_interface.slave   flush_slave,
    pip_robread_interface.slave pip_robread_sif0,
    pip_robread_interface.slave pip_robread_sif1,
    pip_robread_interface.master instr0,
    pip_robread_interface.master instr1
);
    logic ptr;
always_comb begin
    //---------------------------------instr0 input mux------------------------------
    instr0.data             = ptr ? pip_robread_sif1.data           : pip_robread_sif0.data;
    instr0.csrdata          = ptr ? pip_robread_sif1.csrdata        : pip_robread_sif0.csrdata;
    instr0.branchaddr       = ptr ? pip_robread_sif1.branchaddr     : pip_robread_sif0.branchaddr;
    instr0.pc               = ptr ? pip_robread_sif1.pc             : pip_robread_sif0.pc;
    instr0.jump             = ptr ? pip_robread_sif1.jump           : pip_robread_sif0.jump;
    instr0.fflag            = ptr ? pip_robread_sif1.fflag          : pip_robread_sif0.fflag;;
    instr0.mmio             = ptr ? pip_robread_sif1.mmio           : pip_robread_sif0.mmio;
    instr0.load_acc_flt     = ptr ? pip_robread_sif1.load_acc_flt   : pip_robread_sif0.load_acc_flt;
    instr0.load_addr_mis    = ptr ? pip_robread_sif1.load_addr_mis  : pip_robread_sif0.load_addr_mis;
    instr0.load_page_flt    = ptr ? pip_robread_sif1.load_page_flt  : pip_robread_sif0.load_page_flt;
    instr0.store_acc_flt    = ptr ? pip_robread_sif1.store_acc_flt  : pip_robread_sif0.store_acc_flt;
    instr0.store_addr_mis   = ptr ? pip_robread_sif1.store_addr_mis : pip_robread_sif0.store_addr_mis;
    instr0.store_page_flt   = ptr ? pip_robread_sif1.store_page_flt : pip_robread_sif0.store_page_flt;
    instr0.instr_accflt     = ptr ? pip_robread_sif1.instr_accflt   : pip_robread_sif0.instr_accflt;
    instr0.instr_pageflt    = ptr ? pip_robread_sif1.instr_pageflt  : pip_robread_sif0.instr_pageflt;
    instr0.instr_addrmis    = ptr ? pip_robread_sif1.instr_addrmis  : pip_robread_sif0.instr_addrmis;
    instr0.opcode           = ptr ? pip_robread_sif1.opcode         : pip_robread_sif0.opcode;
    instr0.mret             = ptr ? pip_robread_sif1.mret           : pip_robread_sif0.mret;
    instr0.sret             = ptr ? pip_robread_sif1.sret           : pip_robread_sif0.sret;
    instr0.illins           = ptr ? pip_robread_sif1.illins         : pip_robread_sif0.illins;
    instr0.ecall            = ptr ? pip_robread_sif1.ecall          : pip_robread_sif0.ecall;
    instr0.ebreak           = ptr ? pip_robread_sif1.ebreak         : pip_robread_sif0.ebreak;
    instr0.irrevo           = ptr ? pip_robread_sif1.irrevo         : pip_robread_sif0.irrevo;
    instr0.rdindex          = ptr ? pip_robread_sif1.rdindex        : pip_robread_sif0.rdindex;
    instr0.rden             = ptr ? pip_robread_sif1.rden           : pip_robread_sif0.rden;
    instr0.frdindex         = ptr ? pip_robread_sif1.frdindex       : pip_robread_sif0.frdindex;
    instr0.frden            = ptr ? pip_robread_sif1.frden          : pip_robread_sif0.frden;
    instr0.csrindex         = ptr ? pip_robread_sif1.csrindex       : pip_robread_sif0.csrindex;
    instr0.csren            = ptr ? pip_robread_sif1.csren          : pip_robread_sif0.csren;
    instr0.fflagen          = ptr ? pip_robread_sif1.fflagen        : pip_robread_sif0.fflagen;
    instr0.branchtype       = ptr ? pip_robread_sif1.branchtype     : pip_robread_sif0.branchtype;
    instr0.complete         = ptr ? pip_robread_sif1.complete       : pip_robread_sif0.complete;
    instr0.itag             = ptr ? pip_robread_sif1.itag           : pip_robread_sif0.itag;
    instr0.valid            = ptr ? pip_robread_sif1.valid          : pip_robread_sif0.valid;
    //-----------------------------instr1 input mux--------------------------------------
    instr1.data             = ptr ? pip_robread_sif0.data           : pip_robread_sif1.data;
    instr1.csrdata          = ptr ? pip_robread_sif0.csrdata        : pip_robread_sif1.csrdata;
    instr1.branchaddr       = ptr ? pip_robread_sif0.branchaddr     : pip_robread_sif1.branchaddr;
    instr1.pc               = ptr ? pip_robread_sif0.pc             : pip_robread_sif1.pc;
    instr1.jump             = ptr ? pip_robread_sif0.jump           : pip_robread_sif1.jump;
    instr1.fflag            = ptr ? pip_robread_sif0.fflag          : pip_robread_sif1.fflag;;
    instr1.mmio             = ptr ? pip_robread_sif0.mmio           : pip_robread_sif1.mmio;
    instr1.load_acc_flt     = ptr ? pip_robread_sif0.load_acc_flt   : pip_robread_sif1.load_acc_flt;
    instr1.load_addr_mis    = ptr ? pip_robread_sif0.load_addr_mis  : pip_robread_sif1.load_addr_mis;
    instr1.load_page_flt    = ptr ? pip_robread_sif0.load_page_flt  : pip_robread_sif1.load_page_flt;
    instr1.store_acc_flt    = ptr ? pip_robread_sif0.store_acc_flt  : pip_robread_sif1.store_acc_flt;
    instr1.store_addr_mis   = ptr ? pip_robread_sif0.store_addr_mis : pip_robread_sif1.store_addr_mis;
    instr1.store_page_flt   = ptr ? pip_robread_sif0.store_page_flt : pip_robread_sif1.store_page_flt;
    instr1.instr_accflt     = ptr ? pip_robread_sif0.instr_accflt   : pip_robread_sif1.instr_accflt;
    instr1.instr_pageflt    = ptr ? pip_robread_sif0.instr_pageflt  : pip_robread_sif1.instr_pageflt;
    instr1.instr_addrmis    = ptr ? pip_robread_sif0.instr_addrmis  : pip_robread_sif1.instr_addrmis;
    instr1.opcode           = ptr ? pip_robread_sif0.opcode         : pip_robread_sif1.opcode;
    instr1.mret             = ptr ? pip_robread_sif0.mret           : pip_robread_sif1.mret;
    instr1.sret             = ptr ? pip_robread_sif0.sret           : pip_robread_sif1.sret;
    instr1.illins           = ptr ? pip_robread_sif0.illins         : pip_robread_sif1.illins;
    instr1.ecall            = ptr ? pip_robread_sif0.ecall          : pip_robread_sif1.ecall;
    instr1.ebreak           = ptr ? pip_robread_sif0.ebreak         : pip_robread_sif1.ebreak;
    instr1.irrevo           = ptr ? pip_robread_sif0.irrevo         : pip_robread_sif1.irrevo;
    instr1.rdindex          = ptr ? pip_robread_sif0.rdindex        : pip_robread_sif1.rdindex;
    instr1.rden             = ptr ? pip_robread_sif0.rden           : pip_robread_sif1.rden;
    instr1.frdindex         = ptr ? pip_robread_sif0.frdindex       : pip_robread_sif1.frdindex;
    instr1.frden            = ptr ? pip_robread_sif0.frden          : pip_robread_sif1.frden;
    instr1.csrindex         = ptr ? pip_robread_sif0.csrindex       : pip_robread_sif1.csrindex;
    instr1.csren            = ptr ? pip_robread_sif0.csren          : pip_robread_sif1.csren;
    instr1.fflagen          = ptr ? pip_robread_sif0.fflagen        : pip_robread_sif1.fflagen;
    instr1.branchtype       = ptr ? pip_robread_sif0.branchtype     : pip_robread_sif1.branchtype;
    instr1.complete         = ptr ? pip_robread_sif0.complete       : pip_robread_sif1.complete;
    instr1.itag             = ptr ? pip_robread_sif0.itag           : pip_robread_sif1.itag;
    instr1.valid            = ptr ? pip_robread_sif0.valid          : pip_robread_sif1.valid;
end

always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        ptr <= 1'b0;
    end
    else if(flush_slave.flush)begin
        ptr <= 1'b0;
    end
    else begin
        ptr <= ptr + (instr1.ready & instr1.valid) + (instr0.ready & instr0.valid);
    end
end

assign pip_robread_sif0.ready = ptr ? instr1.ready : instr0.ready;
assign pip_robread_sif1.ready = ptr ? instr0.ready : instr1.ready;

endmodule