`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
module decode_output_manage(
    input wire                      clk_i, arst_i,
    pip_flush_interface.slave       pip_flush_sif,
    //--------------from decoder----------------
    decoder_interface.slave         decode0_sif,
    decoder_interface.slave         decode1_sif,
    input wire [1:0]                push_en,
    output logic [7:0]              wentrynum   [1:0],
    output wire                     full, empty,
    //--------------to next stage----------------
    pip_rob_interface.master        pip_rob_mif0,
    pip_rob_interface.master        pip_rob_mif1,
    pip_decode_interface.master     pip_decode_mif0,
    pip_decode_interface.master     pip_decode_mif1
);
    reg ptr;
    wire decode_queue0_empty, decode_queue1_empty, decode_queue0_full, decode_queue1_full;

always_comb begin
    pip_rob_mif0.pc             =   ptr? decode1_sif.pc         : decode0_sif.pc;
    pip_rob_mif0.opcode         =   ptr? decode1_sif.opcode     : decode0_sif.opcode;
    pip_rob_mif0.instr_accflt   =   ptr? decode1_sif.instraccflt: decode0_sif.instraccflt;
    pip_rob_mif0.instr_pageflt  =   ptr? decode1_sif.instrpageflt:decode0_sif.instrpageflt;
    pip_rob_mif0.instr_addrmis  =   ptr? decode1_sif.instraddrmis:decode0_sif.instraddrmis;
    pip_rob_mif0.mret           =   ptr? decode1_sif.mret       : decode0_sif.mret;
    pip_rob_mif0.sret           =   ptr? decode1_sif.sret       : decode0_sif.sret;
    pip_rob_mif0.illins         =   ptr? decode1_sif.illins     : decode0_sif.illins;
    pip_rob_mif0.ecall          =   ptr? decode1_sif.ecall      : decode0_sif.ecall;
    pip_rob_mif0.ebreak         =   ptr? decode1_sif.ebreak     : decode0_sif.ebreak;
    pip_rob_mif0.irrevo         =   ptr? decode1_sif.irrevo     : decode0_sif.irrevo;
    pip_rob_mif0.branchtype     =   ptr? decode1_sif.branchtype : decode0_sif.branchtype;
    pip_rob_mif0.rdindex        =   ptr? decode1_sif.rdindex    : decode0_sif.rdindex;
    pip_rob_mif0.rden           =   ptr? decode1_sif.rden       : decode0_sif.rden;
    pip_rob_mif0.frdindex       =   ptr? decode1_sif.frdindex   : decode0_sif.frdindex;
    pip_rob_mif0.frden          =   ptr? decode1_sif.frden      : decode0_sif.frden;
    pip_rob_mif0.csrindex       =   ptr? decode1_sif.csrindex   : decode0_sif.csrindex;
    pip_rob_mif0.csren          =   ptr? decode1_sif.csren      : decode0_sif.csren;
    pip_rob_mif0.fflagen        =   ptr? decode1_sif.fflagen    : decode0_sif.fflagen;
    pip_rob_mif0.valid          =   ptr? push_en[1]             : push_en[0];
    pip_rob_mif0.complete       =   1'b0;

    pip_rob_mif1.pc             =   ptr? decode0_sif.pc         : decode1_sif.pc;
    pip_rob_mif1.opcode         =   ptr? decode0_sif.opcode     : decode1_sif.opcode;
    pip_rob_mif1.instr_accflt   =   ptr? decode0_sif.instraccflt: decode1_sif.instraccflt;
    pip_rob_mif1.instr_pageflt  =   ptr? decode0_sif.instrpageflt:decode1_sif.instrpageflt;
    pip_rob_mif1.instr_addrmis  =   ptr? decode0_sif.instraddrmis:decode1_sif.instraddrmis;
    pip_rob_mif1.mret           =   ptr? decode0_sif.mret       : decode1_sif.mret;
    pip_rob_mif1.sret           =   ptr? decode0_sif.sret       : decode1_sif.sret;
    pip_rob_mif1.illins         =   ptr? decode0_sif.illins     : decode1_sif.illins;
    pip_rob_mif1.ecall          =   ptr? decode0_sif.ecall      : decode1_sif.ecall;
    pip_rob_mif1.ebreak         =   ptr? decode0_sif.ebreak     : decode1_sif.ebreak;
    pip_rob_mif1.irrevo         =   ptr? decode0_sif.irrevo     : decode1_sif.irrevo;
    pip_rob_mif1.branchtype     =   ptr? decode0_sif.branchtype : decode1_sif.branchtype;
    pip_rob_mif1.rdindex        =   ptr? decode0_sif.rdindex    : decode1_sif.rdindex;
    pip_rob_mif1.rden           =   ptr? decode0_sif.rden       : decode1_sif.rden;
    pip_rob_mif1.frdindex       =   ptr? decode0_sif.frdindex   : decode1_sif.frdindex;
    pip_rob_mif1.frden          =   ptr? decode0_sif.frden      : decode1_sif.frden;
    pip_rob_mif1.csrindex       =   ptr? decode0_sif.csrindex   : decode1_sif.csrindex;
    pip_rob_mif1.csren          =   ptr? decode0_sif.csren      : decode1_sif.csren;
    pip_rob_mif1.fflagen        =   ptr? decode0_sif.fflagen    : decode1_sif.fflagen;
    pip_rob_mif1.valid          =   ptr? push_en[0]             : push_en[1];
    pip_rob_mif1.complete       =   1'b0;

    wentrynum[0]                =   ptr ? {1'b1,pip_rob_mif1.entrynum[6:0]} : {1'b0,pip_rob_mif0.entrynum[6:0]};
    wentrynum[1]                =   ptr ? {1'b0,pip_rob_mif0.entrynum[6:0]} : {1'b1,pip_rob_mif1.entrynum[6:0]};
end
//----------------------------------Decode queue--------------------------------
// decode queue stores the micro-ops after decode, waiting for dispatch stage to use
// the read port of this module is connect directly to dispatch

fifo1r1w#(

    .DWID           (5+10+5+1+5+1+5+1+`XLEN+20+5+1+5+1+5+1+5+1+12+1+1+8+4),
    .DDEPTH         (4)         //decode queue is short, not need too long 

)decode_queue0(

    .clk            (clk_i),
    .rst            (arst_i | pip_flush_sif.flush),
    .ren            (pip_decode_mif0.ready),
    .wen            (ptr ? push_en[1] : push_en[0]),
    .wdata          (ptr ? 
                        {  
                        decode1_sif.opcode,
                        decode1_sif.funct,
                        decode1_sif.rs1index,
                        decode1_sif.rs1en,
                        decode1_sif.rs2index,
                        decode1_sif.rs2en,
                        decode1_sif.rdindex,
                        decode1_sif.rden,
                        decode1_sif.pc,
                        decode1_sif.imm,
                        decode1_sif.frs1index,
                        decode1_sif.frs1en,
                        decode1_sif.frs2index,
                        decode1_sif.frs2en,
                        decode1_sif.frs3index,
                        decode1_sif.frs3en,
                        decode1_sif.frdindex,
                        decode1_sif.frden,
                        decode1_sif.csrindex,
                        decode1_sif.csren,
                        decode1_sif.fflagen,
                        decode1_sif.itag,
                        decode1_sif.disp_dest
                    }:{  
                        decode0_sif.opcode,
                        decode0_sif.funct,
                        decode0_sif.rs1index,
                        decode0_sif.rs1en,
                        decode0_sif.rs2index,
                        decode0_sif.rs2en,
                        decode0_sif.rdindex,
                        decode0_sif.rden,
                        decode0_sif.pc,
                        decode0_sif.imm,
                        decode0_sif.frs1index,
                        decode0_sif.frs1en,
                        decode0_sif.frs2index,
                        decode0_sif.frs2en,
                        decode0_sif.frs3index,
                        decode0_sif.frs3en,
                        decode0_sif.frdindex,
                        decode0_sif.frden,
                        decode0_sif.csrindex,
                        decode0_sif.csren,
                        decode0_sif.fflagen,
                        decode0_sif.itag,
                        decode0_sif.disp_dest
                    }),
    .rdata          ({  
                        pip_decode_mif0.opcode,
                        pip_decode_mif0.funct,
                        pip_decode_mif0.rs1index,
                        pip_decode_mif0.rs1en,
                        pip_decode_mif0.rs2index,
                        pip_decode_mif0.rs2en,
                        pip_decode_mif0.rdindex,
                        pip_decode_mif0.rden,
                        pip_decode_mif0.pc,
                        pip_decode_mif0.imm,
                        pip_decode_mif0.frs1index,
                        pip_decode_mif0.frs1en,
                        pip_decode_mif0.frs2index,
                        pip_decode_mif0.frs2en,
                        pip_decode_mif0.frs3index,
                        pip_decode_mif0.frs3en,
                        pip_decode_mif0.frdindex,
                        pip_decode_mif0.frden,
                        pip_decode_mif0.csrindex,
                        pip_decode_mif0.csren,
                        pip_decode_mif0.fflagen,
                        pip_decode_mif0.itag,
                        pip_decode_mif0.disp_dest
                    }),
    .full           (decode_queue0_full),
    .empty          (decode_queue0_empty)

);

fifo1r1w#(
    
    .DWID           (5+10+5+1+5+1+5+1+`XLEN+20+5+1+5+1+5+1+5+1+12+1+1+8+4),
    .DDEPTH         (4)         //decode queue is short, not need too long 

)decode_queue1(

    .clk            (clk_i),
    .rst            (arst_i | pip_flush_sif.flush),
    .ren            (pip_decode_mif1.ready),
    .wen            (ptr ? push_en[0] : push_en[1]),
    .wdata          (ptr ? {  
                        decode0_sif.opcode,
                        decode0_sif.funct,
                        decode0_sif.rs1index,
                        decode0_sif.rs1en,
                        decode0_sif.rs2index,
                        decode0_sif.rs2en,
                        decode0_sif.rdindex,
                        decode0_sif.rden,
                        decode0_sif.pc,
                        decode0_sif.imm,
                        decode0_sif.frs1index,
                        decode0_sif.frs1en,
                        decode0_sif.frs2index,
                        decode0_sif.frs2en,
                        decode0_sif.frs3index,
                        decode0_sif.frs3en,
                        decode0_sif.frdindex,
                        decode0_sif.frden,
                        decode0_sif.csrindex,
                        decode0_sif.csren,
                        decode0_sif.fflagen,
                        decode0_sif.itag,
                        decode0_sif.disp_dest
                    }:{  
                        decode1_sif.opcode,
                        decode1_sif.funct,
                        decode1_sif.rs1index,
                        decode1_sif.rs1en,
                        decode1_sif.rs2index,
                        decode1_sif.rs2en,
                        decode1_sif.rdindex,
                        decode1_sif.rden,
                        decode1_sif.pc,
                        decode1_sif.imm,
                        decode1_sif.frs1index,
                        decode1_sif.frs1en,
                        decode1_sif.frs2index,
                        decode1_sif.frs2en,
                        decode1_sif.frs3index,
                        decode1_sif.frs3en,
                        decode1_sif.frdindex,
                        decode1_sif.frden,
                        decode1_sif.csrindex,
                        decode1_sif.csren,
                        decode1_sif.fflagen,
                        decode1_sif.itag,
                        decode1_sif.disp_dest
                    }),
    .rdata          ({  
                        pip_decode_mif1.opcode,
                        pip_decode_mif1.funct,
                        pip_decode_mif1.rs1index,
                        pip_decode_mif1.rs1en,
                        pip_decode_mif1.rs2index,
                        pip_decode_mif1.rs2en,
                        pip_decode_mif1.rdindex,
                        pip_decode_mif1.rden,
                        pip_decode_mif1.pc,
                        pip_decode_mif1.imm,
                        pip_decode_mif1.frs1index,
                        pip_decode_mif1.frs1en,
                        pip_decode_mif1.frs2index,
                        pip_decode_mif1.frs2en,
                        pip_decode_mif1.frs3index,
                        pip_decode_mif1.frs3en,
                        pip_decode_mif1.frdindex,
                        pip_decode_mif1.frden,
                        pip_decode_mif1.csrindex,
                        pip_decode_mif1.csren,
                        pip_decode_mif1.fflagen,
                        pip_decode_mif1.itag,
                        pip_decode_mif1.disp_dest
                    }),
    .full           (decode_queue1_full),
    .empty          (decode_queue1_empty)

);
assign pip_decode_mif0.valid = !decode_queue0_empty;
assign pip_decode_mif1.valid = !decode_queue1_empty;

assign full = decode_queue0_full | decode_queue1_full | pip_rob_mif0.full | pip_rob_mif1.full;  //只要有一个输出接口满了，就认为是满
assign empty= decode_queue0_empty& decode_queue1_empty& pip_rob_mif0.empty& pip_rob_mif1.empty;
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        ptr <= 0;
    end
    else if(pip_flush_sif.flush)begin
        ptr <= 0;
    end
    else begin
        ptr <= ptr + push_en[0] + push_en[1];
    end
end
endmodule
