`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
/******************************************************************************************

   Copyright (c) [2023] [JackPan, XiaoyuHong, KuiSun]
   [prv664] is licensed under Mulan PSL v2.
   You can use this software according to the terms and conditions of the Mulan PSL v2. 
   You may obtain a copy of Mulan PSL v2 at:
            http://license.coscl.org.cn/MulanPSL2 
   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.  
   See the Mulan PSL v2 for more details.  

____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 

    DESC： prv664 decode core module
    Author: Jack Pan
    Date: 20231215
    Version:2.0       Added 0x6b decode for Openxiangshan difftest use

    change log:
        231215: added switch to turn on/off fp decode

******************************************************************************************/
module decode#(

    parameter IDWIDTH = 8

)(
//------------------csr input-------------------------
    input wire              csr_tsr_i,
    input wire              csr_tvm_i,
//------------------global signal---------------------
    input wire [31:0]       instr_i,
    input wire [`XLEN-1:0]  instrpc_i,
    input wire [1:0]        instrpriv_i,
    input wire              instr_valid_i,
    input wire              instr_pageflt_i,
    input wire              instr_accflt_i,
    input wire              instr_addrmis_i,
    input wire [IDWIDTH-1:0]instr_id_i,        
//---------------------decode output-------------------

    decoder_interface.master decode_mif

);
localparam  ENABLE          = 1'b1,
            DISABLE         = 1'b0;

    wire [4:0] instr_opcode;
    wire [2:0] instr_funct3;                    //主要的funct3编码段
    wire [4:0] instr_funct5;                    //浮点操作使用的funct5编码段
    wire [6:0] instr_funct7;                    //主要的funct7编码段

assign instr_opcode = (instr_i[6:2]);
assign instr_funct3 = (instr_i[14:12]);
assign instr_funct5 = (instr_i[31:27]);
assign instr_funct7 = (instr_i[31:25]);

//--------------immediate data decode----------------

    wire [19:0]imm20;		                    //LUI，AUIPC指令使用的20位立即数（进行符号位拓展）
    wire [19:0]imm20_jal;	                    //jal指令使用的20位立即数，左移一位，高位进行符号拓展
    wire [19:0]imm12_i;		                    //I-type，L-type指令使用的12位立即数（进行符号位拓展）
    wire [19:0]imm12_b;		                    //b-type指令使用的12位立即数（进行符号位拓展）
    wire [19:0]imm12_s;		                    //S-type指令使用的12位立即数（进行符号位拓展）
    wire [19:0]imm5_csr;	                    //csr指令使用的5位立即数，高位补0
    wire [19:0]shamt;                           //64bit 移位指令用的6bit立即数

assign imm20 	= instr_i[31:12];				                                            //LUI，AUIPC指令使用的20位立即数（进行符号位拓展）
assign imm20_jal= {instr_i[31],instr_i[19:12],instr_i[20],instr_i[30:21]};		            //jal指令使用的20位立即数，左移一位，高位进行符号拓展
assign imm12_i	= {{8{instr_i[31]}},instr_i[31:20]};						                //I-type，L-type指令使用的12位立即数（进行符号位拓展）
assign imm12_b	= {{8{instr_i[31]}},instr_i[31],instr_i[7],instr_i[30:25],instr_i[11:8]};	//b-type指令使用的12位立即数（进行符号位拓展）
assign imm12_s	= {{8{instr_i[31]}},instr_i[31:25],instr_i[11:7]};		                    //S-type指令使用的12位立即数（进行符号位拓展）
assign imm5_csr = {15'b0,instr_i[19:15]};
//---------------------------rs1index rs2index rs2index decode---------------------------
assign decode_mif.rs1index = instr_i[19:15];
assign decode_mif.rs2index = instr_i[24:20];
assign decode_mif.rdindex  = instr_i[11:7];
assign decode_mif.csrindex = instr_i[31:20];
assign decode_mif.frs1index= instr_i[19:15];
assign decode_mif.frs2index= instr_i[24:20];
assign decode_mif.frs3index= instr_i[31:27];
assign decode_mif.frdindex = instr_i[11:7];
//-----------------------------opcode decode--------------------------------------
assign decode_mif.opcode = instr_opcode;
//-----------------------------RAS function decode-----------------------------------
    wire      rdisx1x5,    rs1isx1x5, rdeqrs1;
assign rdisx1x5 = (decode_mif.rdindex == 5'h01) | (decode_mif.rdindex==5'h05); 
assign rs1isx1x5= (decode_mif.rs1index == 5'h01) | (decode_mif.rs1index==5'h05); 
assign rdeqrs1  = decode_mif.rs1index == decode_mif.rdindex;

//----------------------------指令派遣位置和非法指令判定----------------------------
always_comb begin
    if(instr_pageflt_i | instr_accflt_i | instr_addrmis_i)begin
        decode_mif.disp_dest  = `DECODE_DISP_NONE;
        decode_mif.illins     = DISABLE;
    end
    else begin
        case(instr_opcode)
            `OPCODE_LOAD, `OPCODE_LOADFP, `OPCODE_STORE, `OPCODE_STOREFP : 
            begin
                decode_mif.disp_dest  = `DECODE_DISP_LOADSTORE;
                decode_mif.illins     = DISABLE;
            end
            `ifdef AMO_ON
                `OPCODE_AMO:begin
                    decode_mif.disp_dest  = `DECODE_DISP_LOADSTORE;
                    decode_mif.illins     = DISABLE;
                end
            `endif
            `OPCODE_MISCMEM :
            begin
                decode_mif.disp_dest  = `DECODE_DISP_SYSMAG;
                decode_mif.illins     = DISABLE;
            end
            `OPCODE_OPIMM,`OPCODE_OPIMM32, `OPCODE_LUI :
            begin
                decode_mif.disp_dest  = `DECODE_DISP_SHORTINT;
                decode_mif.illins     = DISABLE;
            end
            `OPCODE_OP, `OPCODE_OP32 :
            begin
                case(instr_funct7)
                    7'b0000001 :
                    begin
                        decode_mif.disp_dest  = `DECODE_DISP_MULDIV;
                        decode_mif.illins     = DISABLE;
                    end
                    default :
                    begin
                        decode_mif.disp_dest  = `DECODE_DISP_SHORTINT;
                        decode_mif.illins     = DISABLE;
                    end
                endcase
            end
            `OPCODE_MADD, `OPCODE_MSUB, `OPCODE_NMSUB, `OPCODE_NMADD, `OPCODE_OPFP:
            begin
                decode_mif.disp_dest  = `DECODE_DISP_FPU;
                `ifdef FPU_ON
                    decode_mif.illins     = DISABLE;
                `elsif 
                    decode_mif.illins     = ENABLE;
                `endif
            end
            `OPCODE_AUIPC, `OPCODE_BRANCH, `OPCODE_JAL, `OPCODE_JALR  :
            begin
                decode_mif.disp_dest  = `DECODE_DISP_BRANCH;
                decode_mif.illins     = DISABLE;
            end
            `OPCODE_SYSTEM  :
            begin
                if(instr_funct3==3'b000)begin       //funct3=PRIV instructions
                    case(instr_funct7)
                        7'b0000000 :                //ecall ebreak
                        begin
                            decode_mif.disp_dest  = `DECODE_DISP_NONE;
                            decode_mif.illins     = DISABLE;
                        end
                        7'b0001000 :                //sret
                        begin
                            if((instrpriv_i==`SUPERVISIOR) | (decode_mif.rs2index==5'b00101))begin
                                decode_mif.disp_dest  = `DECODE_DISP_NONE;
                                decode_mif.illins     = DISABLE;
                            end
                            else begin                          //在非Supervisior模式下尝试执行SRET指令是不允许的
                                decode_mif.disp_dest  = `DECODE_DISP_NONE;
                                decode_mif.illins     = ENABLE;
                            end
                        end
                        7'b0011000 :                //mret
                        begin
                            if(instrpriv_i==`MACHINE)begin
                                decode_mif.disp_dest  = `DECODE_DISP_NONE;
                                decode_mif.illins     = DISABLE;
                            end
                            else begin                          //在非Machine模式下尝试执行MRET指令是不允许的
                                decode_mif.disp_dest  = `DECODE_DISP_NONE;
                                decode_mif.illins     = ENABLE;
                            end
                        end
                        7'b0001001 :
                        begin       //sfence.vma instruction
                            decode_mif.disp_dest  = `DECODE_DISP_SYSMAG;    //sfencevma指令发送给sysmag运行
                            decode_mif.illins     = DISABLE;
                        end
                        default :
                        begin
                            decode_mif.disp_dest  = `DECODE_DISP_NONE;
                            decode_mif.illins     = ENABLE;
                        end
                    endcase
                end
                else begin                          //standerd csr instruction
                    if(instrpriv_i >= decode_mif.csrindex[9:8])begin
                        decode_mif.disp_dest  = `DECODE_DISP_SHORTINT;
                        decode_mif.illins     = DISABLE;
                    end
                    else begin                      //a illegal instruction happen
                        decode_mif.disp_dest  = `DECODE_DISP_NONE;
                        decode_mif.illins     = ENABLE;
                    end
                end
            end
            `ifdef SIMULATION   //如果是在仿真状态下，对0x6b指令进行解码
                    `OPCODE_HALT:begin
                        decode_mif.disp_dest  = `DECODE_DISP_NONE;
                        decode_mif.illins     = DISABLE;
                    end
            `endif
            default         :
            begin
                decode_mif.disp_dest  = `DECODE_DISP_NONE;
                decode_mif.illins     = ENABLE;
            end
        endcase
    end
end
//---------------------------------------指令整数操作数1和操作数2译码-------------------------------------
always_comb begin
    case(instr_opcode)
        `OPCODE_LOAD    : 
        begin
            decode_mif.funct   = {7'b0,instr_funct3};
            decode_mif.rs1en      = ENABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = ENABLE;
        end
        `ifdef FPU_ON
        `OPCODE_LOADFP  :
        begin
            decode_mif.funct      = {7'b0,instr_funct3};
            decode_mif.rs1en      = ENABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = DISABLE;
        end
        `OPCODE_STOREFP :
        begin
            decode_mif.funct   = {7'b0,instr_funct3};
            decode_mif.rs1en      = ENABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = DISABLE;
        end
        `OPCODE_MADD, `OPCODE_MSUB, `OPCODE_NMSUB, `OPCODE_NMADD   :
        begin
            decode_mif.funct      = {instr_funct7,instr_funct3};
            decode_mif.rs1en      = DISABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = DISABLE;
        end
        `OPCODE_OPFP    :
            case(instr_funct5)
                `FUNCT5_FCVT_fmt_int, `FUNCT5_FMV_fmt_int:   //整数-浮点转换
                begin
                    decode_mif.funct      = {instr_funct7,instr_funct3};
                    decode_mif.rs1en      = ENABLE;
                    decode_mif.rs2en      = DISABLE;
                    decode_mif.rden       = DISABLE;
                end
                `FUNCT5_FCVT_int_fmt, /*`FUNCT5_FCLASS,*/ `FUNCT5_FMV_int_fmt:   //浮点-整数转换，因为FCLASS的FUNCT5和FCVTint_fmt的操作数一样，故只取一个
                begin
                    decode_mif.funct      = {instr_funct7,instr_funct3};
                    decode_mif.rs1en      = DISABLE;
                    decode_mif.rs2en      = DISABLE;
                    decode_mif.rden       = ENABLE;
                end
                `FUNCT5_FCVT_fmt_fmt  :       //1浮点-1浮点转换
                begin
                    decode_mif.funct      = {instr_funct7,instr_funct3};
                    decode_mif.rs1en      = DISABLE;
                    decode_mif.rs2en      = DISABLE;
                    decode_mif.rden       = DISABLE;
                end
                `FUNCT5_FCMP :                              //2浮点比较，结果写回整数寄存器
                begin
                    decode_mif.funct      = {instr_funct7,instr_funct3};
                    decode_mif.rs1en      = DISABLE;
                    decode_mif.rs2en      = DISABLE;
                    decode_mif.rden       = ENABLE;
                end
                default :                                   //2浮点操作，结果写回浮点寄存器
                begin
                    decode_mif.funct      = {instr_funct7,instr_funct3};
                    decode_mif.rs1en      = DISABLE;
                    decode_mif.rs2en      = DISABLE;
                    decode_mif.rden       = DISABLE;
                end
            endcase
        `endif
        `OPCODE_MISCMEM:
        begin
            decode_mif.funct      = {instr_funct7,instr_funct3};
            decode_mif.rs1en      = DISABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = DISABLE;
        end
        `OPCODE_OPIMM,`OPCODE_OPIMM32  :
        begin
            decode_mif.funct      = {instr_funct7,instr_funct3};
            decode_mif.rs1en      = ENABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = ENABLE;
        end
        `OPCODE_AUIPC   :
        begin
            decode_mif.funct      = 'h0;
            decode_mif.rs1en      = DISABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = ENABLE;
        end
        `OPCODE_STORE   :
        begin
            decode_mif.funct   = {7'b0,instr_funct3};
            decode_mif.rs1en      = ENABLE;
            decode_mif.rs2en      = ENABLE;
            decode_mif.rden       = DISABLE;
        end
        
        `OPCODE_AMO, `OPCODE_OP, `OPCODE_OP32:
        begin
            decode_mif.funct      = {instr_funct7,instr_funct3};
            decode_mif.rs1en      = ENABLE;
            decode_mif.rs2en      = ENABLE;
            decode_mif.rden       = ENABLE;
        end
        `OPCODE_LUI     :
        begin
            decode_mif.funct      = 'h0;
            decode_mif.rs1en      = DISABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = ENABLE;

        end
        
        `OPCODE_BRANCH  :
        begin
            decode_mif.funct   = {7'b0,instr_funct3};
            decode_mif.rs1en      = ENABLE;
            decode_mif.rs2en      = ENABLE;
            decode_mif.rden       = DISABLE;
        end
        `OPCODE_JALR    :
        begin
            decode_mif.funct      = {7'b0,instr_funct3};
            decode_mif.rs1en      = ENABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = ENABLE;
        end
        `OPCODE_JAL     :
        begin
            decode_mif.funct      = 'h0;
            decode_mif.rs1en      = DISABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = ENABLE;
        end
        `OPCODE_SYSTEM  :
        begin
            if(instr_funct3!=3'b000)begin                       //funct3不为PRIV 即CSR操作指令
                decode_mif.funct      = {7'b0,instr_funct3};
                decode_mif.rs1en      = ENABLE;
                decode_mif.rs2en      = DISABLE;
                decode_mif.rden       = ENABLE;
            end
            else begin
                decode_mif.funct      = {instr_funct7, instr_funct3};
                decode_mif.rs1en      = DISABLE;
                decode_mif.rs2en      = DISABLE;
                decode_mif.rden       = DISABLE;
            end
        end
        default         :
        begin
            decode_mif.funct      = 'h0;
            decode_mif.rs1en      = DISABLE;
            decode_mif.rs2en      = DISABLE;
            decode_mif.rden       = DISABLE;
        end
    endcase
end
////////////////////////////////////////////////////////////////////////////////////
//
//                                      浮点指令操作数译码
//
////////////////////////////////////////////////////////////////////////////////////
always_comb begin
    case(instr_opcode)
        `OPCODE_LOADFP  :
        begin
            decode_mif.frs1en     = DISABLE;
            decode_mif.frs2en     = DISABLE;
            decode_mif.frs3en     = DISABLE;
            decode_mif.frden      = ENABLE;
            decode_mif.fflagen    = DISABLE;
        end
        `OPCODE_STOREFP :
        begin
            decode_mif.frs1en     = DISABLE;
            decode_mif.frs2en     = ENABLE;
            decode_mif.frs3en     = DISABLE;
            decode_mif.frden      = DISABLE;
            decode_mif.fflagen    = DISABLE;
        end
        `OPCODE_MADD, `OPCODE_MSUB, `OPCODE_NMSUB, `OPCODE_NMADD   :
        begin
            decode_mif.frs1en     = ENABLE;
            decode_mif.frs2en     = ENABLE;
            decode_mif.frs3en     = ENABLE;
            decode_mif.frden      = ENABLE;
            decode_mif.fflagen    = ENABLE;
        end
        `OPCODE_OPFP    :
            case(instr_funct5)
                `FUNCT5_FCVT_fmt_int, `FUNCT5_FMV_fmt_int:   //整数-浮点转换
                begin
                    decode_mif.frs1en     = DISABLE;
                    decode_mif.frs2en     = DISABLE;
                    decode_mif.frs3en     = DISABLE;
                    decode_mif.frden      = ENABLE;
                    decode_mif.fflagen    = ENABLE;
                end
                `FUNCT5_FCVT_int_fmt, /*`FUNCT5_FCLASS,*/ `FUNCT5_FMV_int_fmt:   //浮点-整数转换
                begin
                    decode_mif.frs1en     = ENABLE;
                    decode_mif.frs2en     = DISABLE;
                    decode_mif.frs3en     = DISABLE;
                    decode_mif.frden      = DISABLE;
                    decode_mif.fflagen    = ENABLE;
                end
                `FUNCT5_FCVT_fmt_fmt  :       //1浮点-1浮点转换
                begin
                    decode_mif.frs1en     = ENABLE;
                    decode_mif.frs2en     = DISABLE;
                    decode_mif.frs3en     = DISABLE;
                    decode_mif.frden      = ENABLE;
                    decode_mif.fflagen    = ENABLE;
                end
                `FUNCT5_FCMP :                              //2浮点比较，结果写回整数寄存器
                begin
                    decode_mif.frs1en     = ENABLE;
                    decode_mif.frs2en     = ENABLE;
                    decode_mif.frs3en     = DISABLE;
                    decode_mif.frden      = DISABLE;
                    decode_mif.fflagen    = ENABLE;
                end
                default :                                   //2浮点操作，结果写回浮点寄存器
                begin
                    decode_mif.frs1en     = ENABLE;
                    decode_mif.frs2en     = ENABLE;
                    decode_mif.frs3en     = DISABLE;
                    decode_mif.frden      = ENABLE;
                    decode_mif.fflagen    = ENABLE;
                end
            endcase
        default         :
        begin
            decode_mif.frs1en     = DISABLE;
            decode_mif.frs2en     = DISABLE;
            decode_mif.frs3en     = DISABLE;
            decode_mif.frden      = DISABLE;
            decode_mif.fflagen    = DISABLE;
        end
    endcase
end

//////////////////////////////////////////////////////////////////////////////////////
//
//                                    CSR使用标志位 
//
///////////////////////////////////////////////////////////////////////////////////////
always_comb begin
    case(instr_opcode)
        `OPCODE_SYSTEM:
        begin
            if(instr_funct3!=3'b000)begin       //funct3=PRIV instructions
                if(instrpriv_i >= decode_mif.csrindex[9:8])begin
                    decode_mif.csren      = ENABLE;
                end
                else begin                      //a illegal instruction happen
                    decode_mif.csren      = DISABLE;
                end
            end
            else begin
                decode_mif.csren = DISABLE;
            end
        end
        default : decode_mif.csren      = DISABLE;
    endcase
end

always_comb begin
    case(instr_opcode)
        `OPCODE_OPIMM, `OPCODE_OPIMM32: decode_mif.imm = imm12_i;
        `OPCODE_LOAD, `OPCODE_LOADFP  : decode_mif.imm = imm12_i;
        `OPCODE_STORE, `OPCODE_STOREFP: decode_mif.imm = imm12_s;
        `OPCODE_BRANCH                : decode_mif.imm = imm12_b;
        `OPCODE_JAL                   : decode_mif.imm = imm20_jal;
        `OPCODE_JALR                  : decode_mif.imm = imm12_i;
        `OPCODE_LUI, `OPCODE_AUIPC    : decode_mif.imm = imm20;
        `OPCODE_SYSTEM                : decode_mif.imm = imm5_csr;
        `OPCODE_OPFP                  : decode_mif.imm = decode_mif.rs2index;
        default                       : decode_mif.imm = 'hx;
    endcase
end
//------------------------------instruction branch type decode-----------------------------
assign decode_mif.branchtype[`BTB_BIT_BRANCH] = (instr_opcode==`OPCODE_BRANCH) |
                                           (instr_opcode==`OPCODE_JAL);
assign decode_mif.branchtype[`BTB_BIT_CALL]   = (instr_opcode==`OPCODE_JAL) & rdisx1x5 |
                                           (instr_opcode==`OPCODE_JALR) & rdisx1x5;
assign decode_mif.branchtype[`BTB_BIT_RETURN] = (instr_opcode==`OPCODE_JALR) & !rdisx1x5 & rs1isx1x5 |
                                           (instr_opcode==`OPCODE_JALR) & rdisx1x5 & rs1isx1x5 & !rdeqrs1;
                                           
//------------------------------mret/sret/ecall/ebreak decode-------------------------------
assign decode_mif.mret    = !decode_mif.illins & (instr_opcode==`OPCODE_SYSTEM) & (instr_funct3==3'b000) & (instr_funct7==7'b0011000) & (decode_mif.rs2index==5'b00010);
assign decode_mif.sret    = !decode_mif.illins & (instr_opcode==`OPCODE_SYSTEM) & (instr_funct3==3'b000) & (instr_funct7==7'b0001000) & (decode_mif.rs2index==5'b00010);
assign decode_mif.ecall   = !decode_mif.illins & (instr_opcode==`OPCODE_SYSTEM) & (instr_funct3==3'b000) & (instr_funct7==7'b0000000) & (decode_mif.rs2index==5'b00000);
assign decode_mif.ebreak  = !decode_mif.illins & (instr_opcode==`OPCODE_SYSTEM) & (instr_funct3==3'b000) & (instr_funct7==7'b0000000) & (decode_mif.rs2index==5'b00001);
//------------------------------instruction irrevo assert-------------------------------------
`ifdef SAFE_EXECUTE
always_comb begin
    case(decode_mif.opcode)
        `OPCODE_LOAD,`OPCODE_LOADFP,`OPCODE_STORE, `OPCODE_STOREFP,`OPCODE_AMO, `OPCODE_SYSTEM, `OPCODE_MISCMEM:decode_mif.irrevo=1;
        default : decode_mif.irrevo=0;
    endcase
end
`else
    assign decode_mif.irrevo=0;
`endif
//------------------------------decode valid---------------------------------------------------
assign decode_mif.instrpageflt    = instr_pageflt_i;
assign decode_mif.instraccflt     = instr_accflt_i;
assign decode_mif.instraddrmis    = instr_addrmis_i;
//-----------------------------itag of current instruction-------------------------------------
assign decode_mif.itag            = instr_id_i;
assign decode_mif.pc              = instrpc_i;

endmodule

