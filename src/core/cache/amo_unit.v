`include "riscv_define.svh"
`include "timescale.v"
module amo_unit#(
    parameter XLEN = 64     //64 for rv64, 32 for rv32
)(
    input wire clk_i,
    input wire rst_i,
    input wire       en,
    input wire [2:0] funct3,
    input wire [4:0] funct5,
    input wire [XLEN-1:0] data1,data2,  //data1 is the value from instruction, data2 is the value from memory
    output reg [XLEN-1:0] data2rf,      //q1 is the value write back to register
    output reg [XLEN-1:0] data2mem       //q2 is the value write back to memory
);
    reg [XLEN-1:0] in1, in2;
//--------------input register-----------------
always@(posedge clk_i)begin
    if(en)begin
        in1 <= data1;
        in2 <= data2;
    end
end
//--------------output register-------------------
always@(posedge clk_i)begin
    /*verilator lint_off CASEINCOMPLETE*/
    case(funct5)
        `FUNCT5_LR:begin
            data2rf <= in2;     //LR指令写回寄存器的数据为内存中读取的值，并且不改写内存中的值
            data2mem <= in2;
        end
        `FUNCT5_SC:begin
            data2rf <= 0;       //SC指令写回寄存器的值固定为1，表示SC永远成功
            data2mem <= in1;     
        end
        `FUNCT5_AMOSWAP:begin
            data2rf <= in2;
            data2mem <= in1; 
        end
        `FUNCT5_AMOADD:begin
            data2rf <= in2;
            data2mem <= in2 + in1;
        end
        `FUNCT5_AMOXOR:begin
            data2rf <= in2;
            data2mem <= in2 ^ in1;
        end
        `FUNCT5_AMOAND:begin
            data2rf <= in2;
            data2mem <= in2 & in1;
        end
        `FUNCT5_AMOOR:begin
            data2rf <= in2;
            data2mem <= in2 | in1;
        end
        `FUNCT5_AMOMIN:begin
            data2rf <= in2;
            if(funct3==3'b010)begin
                data2mem <= ($signed(in2[31:0]) < $signed(in1[31:0])) ? in2 : in1;
            end else begin
                data2mem <= ($signed(in2) < $signed(in1)) ? in2 : in1;
            end
        end
        `FUNCT5_AMOMAX:begin
            data2rf <= in2;
            if(funct3==3'b010)begin
                data2mem <= ($signed(in2[31:0]) < $signed(in1[31:0])) ? in1 : in2;
            end else begin
                data2mem <= ($signed(in2) < $signed(in1)) ? in1 : in2;
            end
        end
        `FUNCT5_AMOMINU:begin
            data2rf <= in2;
            if(funct3==3'b010)begin
                data2mem <= (in2[31:0] < in1[31:0]) ? in2 : in1;
            end else begin
                data2mem <= (in2 < in1) ? in2 : in1;
            end
        end
        `FUNCT5_AMOMAXU:begin
            data2rf <= in2;
            if(funct3==3'b010)begin
                data2mem <= (in2[31:0] < in1[31:0]) ? in1 : in2;
            end else begin
                data2mem <= (in2 < in1) ? in1 : in2;
            end
        end
    endcase
    /*verilator lint_on CASEINCOMPLETE*/
end
endmodule