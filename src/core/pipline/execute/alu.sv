`include"prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
/******************************************************************************************

   Copyright (c) [2024] [JackPan]
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

    DESC： prv664 alu module
    Author: Jack Pan
    Date: 20240301
    Version:2.0       Fixed 32bit operation bug in slliw 

    Change log:
        Version1.0 20220830 : File initial
        Version2.0 20240301 : Bug in 32bit operation slliw fixed

******************************************************************************************/
module alu(
    input           clk_i,
    input           arst_i,
    pip_flush_interface.slave flush_slave,

    pip_exu_interface.alu_sif alu_sif,          //connect to decode interface

    pip_wb_interface.master   alu_mif            //connect to wrtie back interface

);
//------------------------from uop buffer--------------------
    logic [4:0]         opcode;
    logic [2:0]         funct3;          
    logic [6:0]         funct7;
    logic [19:0]        imm20;
    logic [`XLEN-1:0]   data1,  data2;          //operation data1 and data2
    logic [7:0]         itag;
    logic               ren;
    logic               empty;                  //uop bugger is empty
//------------------------ALU data input ------------------------
    logic [`XLEN-1:0]   opdata1, opdata2;

    logic [5:0]         shift_value;            //shift value in 32bit/64bit operation is different

    logic [`XLEN-1:0]   data_op1st;             //data output from 1st operation (no width operation)
    logic [`XLEN-1:0]   data_opfin;             //data output from final operation (with width operation)
	 
	logic [`XLEN-1:0]   csrdata;

    logic               valid;                  //data is valid

//-----------------------------input uop buffer--------------------------
fifo1r1w#(
    .DWID           (`XLEN+`XLEN+20+5+10+8),
    .DDEPTH         (`ALU_UOP_BUFFER_DEEPTH)
)alu_uop_buffer(
    .clk            (clk_i),
    .rst            (arst_i | flush_slave.flush),
    .ren            (ren),
    .wen            (alu_sif.valid),
    .wdata          ({
                        alu_sif.data1,
                        alu_sif.data2,
                        alu_sif.imm20,
                        alu_sif.opcode,
                        alu_sif.funct,
                        alu_sif.itag
                    }),
    .rdata          ({
                        data1,
                        data2,
                        imm20,
                        opcode,
                        funct7,
                        funct3,
                        itag
                    }),
    .full           (alu_sif.full),
    .empty          (empty)
);

//-------------------operation 1st data and 2st data generate-----------------------
always_comb begin
    case(opcode)
        `OPCODE_LUI:
        begin
            opdata1 = {{32{imm20[19]}},imm20,12'b0};
            opdata2 = 'hx;
        end
        `OPCODE_OP:
        begin
            opdata1 = data1;
            opdata2 = data2;
        end
        `OPCODE_OP32:
        begin
            if((funct3==`FUNCT3_SRLA)&(funct7[5]==1'b0))begin    //逻辑右移时不进行操作数符号位拓展
                opdata1 = {32'b0,data1[31:0]};
                opdata2 = {{32{data2[31]}},data2[31:0]};
            end else begin
                opdata1 = {{32{data1[31]}},data1[31:0]};
                opdata2 = {{32{data2[31]}},data2[31:0]};
            end
        end
        `OPCODE_OPIMM:
        begin
            opdata1 = data1;
            opdata2 = {{44{imm20[19]}},imm20};
        end
        `OPCODE_OPIMM32:
        begin
            if((funct3==`FUNCT3_SRLA)&(funct7[5]==1'b0))begin    //逻辑右移时不进行操作数符号位拓展
                opdata1 = {32'b0,data1[31:0]};
                opdata2 = {{44{imm20[19]}},imm20};
            end else begin
                opdata1 = {{32{data1[31]}},data1[31:0]};
                opdata2 = {{44{imm20[19]}},imm20};
            end
        end
        `OPCODE_SYSTEM:
        begin
            case(funct3)
                `FUNCT3_CSRRC, `FUNCT3_CSRRS, `FUNCT3_CSRRW:
                begin
                    opdata1 = data1;
                    opdata2 = data2;
                end
                `FUNCT3_CSRRCI, `FUNCT3_CSRRSI, `FUNCT3_CSRRWI:
                begin
                    opdata1 = {44'b0,imm20};
                    opdata2 = data2;
                end
                default :
                begin
                    opdata1 = 'hx;
                    opdata2 = 'hx;
                end
            endcase
        end
        default :
        begin
            opdata1 = 'hx;
            opdata2 = 'hx;
        end
    endcase
end
//------------------generate shift value in different opcode-----------------
always_comb begin
    case(opcode)
        `OPCODE_OP, `OPCODE_OPIMM:   shift_value  = opdata2[5:0];
        `OPCODE_OP32, `OPCODE_OPIMM32: shift_value  = {1'b0,opdata2[4:0]};
        default: shift_value = 6'hx;
    endcase
end
//-------------------alu operation-----------------
always_comb begin
    //---------------------------ALU第一次操作结果------------------------------
    case(opcode)
    `OPCODE_LUI: data_op1st = opdata1;
    `OPCODE_OPIMM, `OPCODE_OPIMM32:
    begin
        case(funct3)
            `FUNCT3_ADD:begin data_op1st = opdata1 + opdata2;end
            `FUNCT3_SLL:begin data_op1st = opdata1 << shift_value ;end
            `FUNCT3_SRLA: 
                begin
                    if(funct7[5])begin
                        data_op1st = ($signed(opdata1)) >>> shift_value;
                    end
                    else begin
                        data_op1st = opdata1 >> shift_value;
                    end
                end
            `FUNCT3_SLT:                    begin data_op1st =  ($signed(opdata1) < $signed(opdata2));  end
            `FUNCT3_SLTU:                   begin data_op1st = (opdata1 < opdata2);                     end
            `FUNCT3_XOR:                    begin data_op1st = opdata1 ^ opdata2;                       end
            `FUNCT3_OR:                     begin data_op1st = opdata1 | opdata2;                       end
            `FUNCT3_AND:                    begin data_op1st = opdata1 & opdata2;                       end
            default : begin data_op1st = 'hx; end
        endcase
    end
    `OPCODE_OP, `OPCODE_OP32:
    begin
        case(funct3)
            `FUNCT3_ADD:
                begin
                    if(funct7==7'b0100000)begin
                        data_op1st = opdata1 - opdata2;
                    end
                    else begin
                        data_op1st = opdata1 + opdata2;
                    end
                end
            `FUNCT3_SLL:
                begin
                    data_op1st = opdata1 << shift_value;
                end
            `FUNCT3_SRLA: 
                begin
                    if(funct7[5])begin
                        data_op1st = ($signed(opdata1)) >>> shift_value;
                    end
                    else begin
                        data_op1st = opdata1 >> shift_value;
                    end
                end
            `FUNCT3_SLT:                    begin data_op1st =  ($signed(opdata1) < $signed(opdata2));  end
            `FUNCT3_SLTU:                   begin data_op1st = (opdata1 < opdata2);                     end
            `FUNCT3_XOR:                    begin data_op1st = opdata1 ^ opdata2;                       end
            `FUNCT3_OR:                     begin data_op1st = opdata1 | opdata2;                       end
            `FUNCT3_AND:                    begin data_op1st = opdata1 & opdata2;                       end
            default : begin data_op1st = 'hx; end
        endcase
    end
    `OPCODE_SYSTEM:
    begin
        case(funct3)
            `FUNCT3_CSRRC, `FUNCT3_CSRRCI,
            `FUNCT3_CSRRS, `FUNCT3_CSRRSI,
            `FUNCT3_CSRRW, `FUNCT3_CSRRWI:  begin data_op1st = opdata2;                                 end
            default : data_op1st = 'hx;
        endcase
    end
    default :begin data_op1st = 'hx; end
    endcase
    //------------------------ALU第二次操作，生成最终结果，进行符号位的取值和拓展-----------------------------
    case(opcode)
        `OPCODE_OPIMM32, `OPCODE_OP32:  begin data_opfin = {{32{data_op1st[31]}}, data_op1st[31:0]};  end
        default :                       begin data_opfin = data_op1st;                          end
    endcase

    //----------------------产生csr数据---------------------------------
    case(opcode)
        `OPCODE_SYSTEM :
        begin
            case(funct3)
                `FUNCT3_CSRRC, `FUNCT3_CSRRCI:  begin csrdata = ~opdata1 & opdata2; end
                `FUNCT3_CSRRS, `FUNCT3_CSRRSI:  begin csrdata = opdata1 | opdata2;  end
                `FUNCT3_CSRRW, `FUNCT3_CSRRWI:  begin csrdata = opdata1;            end
                default                      :  begin csrdata = 'hx;                end
            endcase
        end
        default : csrdata = 'hx;
    endcase
    
end
assign valid = !empty;
assign ren = !(alu_mif.valid & !alu_mif.ready);

always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        alu_mif.valid <= 1'b0;
    end
    else if (flush_slave.flush)begin
        alu_mif.valid <= 1'b0;
    end
    else begin
        case(alu_mif.valid)
            1'b1: alu_mif.valid <= alu_mif.ready ? valid : alu_mif.valid;
            1'b0: alu_mif.valid <= valid;
            default: alu_mif.valid <= 1'bx;
        endcase
    end
end

always_ff @( posedge clk_i ) begin
    if(!(alu_mif.valid & !alu_mif.ready))begin
        alu_mif.data <= data_opfin;
        alu_mif.csrdata <= csrdata;
        alu_mif.itag <= itag;
    end
end


endmodule