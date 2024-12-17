`include "prv664_define.svh"
`include "prv664_config.svh"
module dispatch_input_manage(

    input wire                      clk_i,
    input wire                      arst_i,
    input wire                      flush_i,
    pip_decode_interface.slave      pip_decode_sif0,
    pip_decode_interface.slave      pip_decode_sif1,
    pip_decode_interface.master     instr0,
    pip_decode_interface.master     instr1

);
    reg ptr;

always_ff @ (posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        ptr <= 1'b0;
    end
    else if(flush_i)begin
        ptr <= 1'b0;
    end
    else begin
        ptr <= ptr + (instr0.ready&instr0.valid) + (instr1.ready&instr1.valid);     //一定注意括号，当心优先级问题
    end
end

assign pip_decode_sif0.ready = ptr ? instr1.ready : instr0.ready;
assign pip_decode_sif1.ready = ptr ? instr0.ready : instr1.ready;

always_comb begin
//-------------------------------------------确定末尾指令的位置--------------------------------------------------
    instr0.opcode   = ptr ? pip_decode_sif1.opcode  : pip_decode_sif0.opcode;
    instr0.funct    = ptr ? pip_decode_sif1.funct   : pip_decode_sif0.funct;
    instr0.rs1index =ptr ? pip_decode_sif1.rs1index : pip_decode_sif0.rs1index; 
    instr0.rs1en    =ptr ? pip_decode_sif1.rs1en    : pip_decode_sif0.rs1en;
    instr0.rs2index =ptr ? pip_decode_sif1.rs2index : pip_decode_sif0.rs2index;
    instr0.rs2en    =ptr ? pip_decode_sif1.rs2en    : pip_decode_sif0.rs2en;
    instr0.rdindex  =ptr ? pip_decode_sif1.rdindex  : pip_decode_sif0.rdindex;
    instr0.rden     =ptr ? pip_decode_sif1.rden     : pip_decode_sif0.rden;
    instr0.pc       =ptr ? pip_decode_sif1.pc       : pip_decode_sif0.pc;
    instr0.imm      =ptr ? pip_decode_sif1.imm      : pip_decode_sif0.imm;
    instr0.frs1index=ptr ? pip_decode_sif1.frs1index: pip_decode_sif0.frs1index;
    instr0.frs1en   =ptr ? pip_decode_sif1.frs1en   : pip_decode_sif0.frs1en;
    instr0.frs2index=ptr ? pip_decode_sif1.frs2index: pip_decode_sif0.frs2index;
    instr0.frs2en   =ptr ? pip_decode_sif1.frs2en   : pip_decode_sif0.frs2en;
    instr0.frs3index=ptr ? pip_decode_sif1.frs3index: pip_decode_sif0.frs3index;
    instr0.frs3en   =ptr ? pip_decode_sif1.frs3en   : pip_decode_sif0.frs3en;
    instr0.frdindex =ptr ? pip_decode_sif1.frdindex : pip_decode_sif0.frdindex;
    instr0.frden    =ptr ? pip_decode_sif1.frden    : pip_decode_sif0.frden;
    instr0.csrindex =ptr ? pip_decode_sif1.csrindex : pip_decode_sif0.csrindex;
    instr0.csren    =ptr ? pip_decode_sif1.csren    : pip_decode_sif0.csren;
    instr0.fflagen  =ptr ? pip_decode_sif1.fflagen  : pip_decode_sif0.fflagen;
    instr0.itag     =ptr ? pip_decode_sif1.itag     : pip_decode_sif0.itag;
    instr0.disp_dest=ptr ? pip_decode_sif1.disp_dest: pip_decode_sif0.disp_dest;
    instr0.valid    =ptr ? pip_decode_sif1.valid    : pip_decode_sif0.valid;
end
always_comb begin
    instr1.opcode   = ptr ? pip_decode_sif0.opcode  : pip_decode_sif1.opcode;
    instr1.funct    = ptr ? pip_decode_sif0.funct   : pip_decode_sif1.funct;
    instr1.rs1index =ptr ? pip_decode_sif0.rs1index : pip_decode_sif1.rs1index; 
    instr1.rs1en    =ptr ? pip_decode_sif0.rs1en    : pip_decode_sif1.rs1en;
    instr1.rs2index =ptr ? pip_decode_sif0.rs2index : pip_decode_sif1.rs2index;
    instr1.rs2en    =ptr ? pip_decode_sif0.rs2en    : pip_decode_sif1.rs2en;
    instr1.rdindex  =ptr ? pip_decode_sif0.rdindex  : pip_decode_sif1.rdindex;
    instr1.rden     =ptr ? pip_decode_sif0.rden     : pip_decode_sif1.rden;
    instr1.pc       =ptr ? pip_decode_sif0.pc       : pip_decode_sif1.pc;
    instr1.imm      =ptr ? pip_decode_sif0.imm      : pip_decode_sif1.imm;
    instr1.frs1index=ptr ? pip_decode_sif0.frs1index: pip_decode_sif1.frs1index;
    instr1.frs1en   =ptr ? pip_decode_sif0.frs1en   : pip_decode_sif1.frs1en;
    instr1.frs2index=ptr ? pip_decode_sif0.frs2index: pip_decode_sif1.frs2index;
    instr1.frs2en   =ptr ? pip_decode_sif0.frs2en   : pip_decode_sif1.frs2en;
    instr1.frs3index=ptr ? pip_decode_sif0.frs3index: pip_decode_sif1.frs3index;
    instr1.frs3en   =ptr ? pip_decode_sif0.frs3en   : pip_decode_sif1.frs3en;
    instr1.frdindex =ptr ? pip_decode_sif0.frdindex : pip_decode_sif1.frdindex;
    instr1.frden    =ptr ? pip_decode_sif0.frden    : pip_decode_sif1.frden;
    instr1.csrindex =ptr ? pip_decode_sif0.csrindex : pip_decode_sif1.csrindex;
    instr1.csren    =ptr ? pip_decode_sif0.csren    : pip_decode_sif1.csren;
    instr1.fflagen  =ptr ? pip_decode_sif0.fflagen  : pip_decode_sif1.fflagen;
    instr1.itag     =ptr ? pip_decode_sif0.itag     : pip_decode_sif1.itag;
    instr1.disp_dest=ptr ? pip_decode_sif0.disp_dest: pip_decode_sif1.disp_dest;
    instr1.valid    =ptr ? pip_decode_sif0.valid    : pip_decode_sif1.valid;

end

endmodule