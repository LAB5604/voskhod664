`include"prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
/**********************************************************************************************

   Copyright (c) [2022] [JackPan, XiaoyuHong, KuiSun]
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
                                                                             
    Desc    : PRV664(voskhod664) mul & div unit
    Author  : JackPan
    Date    : 2024/6/20
    Version : 1.1 bugs in 32bit operation fixed
              1.0 (NOTE: Mulcycle Div from 564 is used)
              
***********************************************************************************************/
module mdiv(
    input           clk_i,
    input           arst_i,
    pip_flush_interface.slave flush_slave,

    pip_exu_interface.mdiv_sif mdiv_sif,          //connect to decode interface

    pip_wb_interface.master   mdiv_mif            //connect to wrtie back interface

);
    localparam STATE_STD = 3'h0,    //standby for new access
               STATE_START=3'h1,    //generate run palse
               STATE_RUN = 3'h2,    //running
               STATE_RDY = 3'h3;    //ready and wait for write back
//------------------------FSM-----------------------------
    logic [3:0] state, state_next;
//------------------------from uop buffer--------------------
    logic [4:0]         opcode;
    logic [2:0]         funct3;          
    logic [6:0]         funct7;
    logic [`XLEN-1:0]   data1,  data2;          //operation data1 and data2
    logic [7:0]         itag;
    logic               ren;
    logic               empty;                  //uop buffer is empty
//---------------------data to execute unit-------------------
    logic [`XLEN-1:0]   srcdata1, srcdata2;     //参与运算的两个源数据,均为无符号数
//---------------------mdiv control--------------------------
    logic               mul_en, div_en;         //启动乘法、启动除法
    wire                div_sign;
    logic               mul_done, div_done;
    wire [`XLEN-1:0]    div_res_data, div_rem_data, div_res_data_final, div_rem_data_final; //除法结果
    wire [2*`XLEN-1:0]  mul_p_data, mul_p_data_sign;//乘法结果 128位无符号数
    reg  [63:0]         mdiv_result;                //乘除法结果
    logic               result_sign;                //单独计算运算结果的符号位
fifo1r1w#(
    .DWID           (`XLEN+`XLEN+5+10+8),
    .DDEPTH         (`MDIV_UOP_BUFFER_DEEPTH)
)mdiv_uop_buffer(
    .clk            (clk_i),
    .rst            (arst_i | flush_slave.flush),
    .ren            (ren),
    .wen            (mdiv_sif.valid),
    .wdata          ({
                        mdiv_sif.data1,
                        mdiv_sif.data2,
                        mdiv_sif.opcode,
                        mdiv_sif.funct,
                        mdiv_sif.itag
                    }),
    .rdata          ({
                        data1,
                        data2,
                        opcode,
                        funct7,
                        funct3,
                        itag
                    }),
    .full           (mdiv_sif.full),
    .empty          (empty)
);
//               FSM
always_ff @( posedge clk_i or posedge arst_i) begin
    if(arst_i)begin
        state <= STATE_STD;
    end else if(flush_slave.flush)begin
        state <= STATE_STD;
    end else begin
        state <= state_next;
    end
end
always_comb begin
    case(state)
        STATE_STD: state_next = empty ? state : STATE_START;
        STATE_START:state_next= STATE_RUN;                          //此阶段只停留一个周期，产生启动脉冲
        STATE_RUN: state_next = (mul_done|div_done)?STATE_RDY:state;
        STATE_RDY: state_next = mdiv_mif.ready ? STATE_STD : state; //在RDY阶段下，output valid固定为1，因此只判断ready信号
        default : state_next = STATE_STD;
    endcase
end
//               产生参与运算的数据
//进行乘法运算时，操作数首先被转换为无符号数，符号位单独处理；进行除法运算时，符号位由除法器进行控制。
always_comb begin
    case(opcode)
        `OPCODE_OP:begin
            case(funct3)
                `FUNCT3_MUL, `FUNCT3_MULH:begin
                    srcdata1 = data1[63] ? (~data1+1):data1;   //rs1与rs2均为有符号数，参加运算的过程中需要取绝对值
                    srcdata2 = data2[63] ? (~data2+1):data2;    
                end
                `FUNCT3_MULHSU:begin
                    srcdata1 = data1[63] ? (~data1+1):data1;   //rs1为有符号数
                    srcdata2 = data2;        //rs2为无符号数，不拓展符号位，当作正数处理
                end
                `FUNCT3_MULHU,`FUNCT3_DIV,`FUNCT3_REM,`FUNCT3_DIVU,`FUNCT3_REMU:begin
                    srcdata1 = data1;
                    srcdata2 = data2;
                end
                default:begin
                    srcdata1 = 'hx; 
                    srcdata2 = 'hx;
                end
            endcase
        end
        `OPCODE_OP32:begin      //rv64 have mulw divw remw divuw remuw
            case(funct3)
                `FUNCT3_MUL:begin
                    srcdata1 = data1[31]?{32'b0,(~data1[31:0]+1)}:{32'b0,data1[31:0]};   //rs1与rs2的低32位为有符号数
                    srcdata2 = data2[31]?{32'b0,(~data2[31:0]+1)}:{32'b0,data2[31:0]};
                end
                `FUNCT3_DIV,`FUNCT3_REM:begin
                    srcdata1 = {{32{data1[31]}},data1[31:0]};
                    srcdata2 = {{32{data2[31]}},data2[31:0]};
                end
                `FUNCT3_DIVU,`FUNCT3_REMU:begin
                    srcdata1 = {32'b0,data1[31:0]};     //rs1与rs2的低32位作为无符号数
                    srcdata2 = {32'b0,data2[31:0]};
                end
                default:begin
                    srcdata1 = 'hx;     //should never go in here
                    srcdata2 = 'hx;
                end
            endcase
        end
        default:begin
            srcdata1 = 'hx; 
            srcdata2 = 'hx;
        end
    endcase
    if(state_next==STATE_START)begin
        case(funct3)
            `FUNCT3_MUL,`FUNCT3_MULH,`FUNCT3_MULHSU,`FUNCT3_MULHU:begin
                mul_en = 1'b1;
                div_en = 1'b0;
            end
            `FUNCT3_DIV,`FUNCT3_REM,`FUNCT3_DIVU,`FUNCT3_REMU:begin
                mul_en = 1'b0;
                div_en = 1'b1;
            end
            default:begin
                mul_en = 1'b0;
                div_en = 1'b0;
            end
        endcase
    end
    else begin
        mul_en = 1'b0;
        div_en = 1'b0;
    end
end
assign div_sign = (funct3==`FUNCT3_DIV) | (funct3==`FUNCT3_REM);
/*                                TODO: fix this too slow div(Freq=54MHz MAX in Stratix5 FPGA)
hp_int_div #(
    .DIV_WIDTH      (65)                     //除法器位宽
)int_div(
    .clk            (clk_i),
    .rst            (arst_i|flush_slave.flush),
//输入
    .su_dived_i     (srcdata1),     //有符号、无符号被除数
    .su_divor_i     (srcdata2),     //有符号、无符号除数
    .signed_en      (1),            //所有运算都是有符号运算
    .div_in_valid   (div_en),
    .div_in_ready   (),             //不用判断此信号，一次只灌一个访问进去
//输出
    .div_res_data   (div_res_data),
    .div_rem_data   (div_rem_data),
    .div_out_valid  (div_done),
    .div_out_ready  (1'b1)
);
*/
MulCyc_Div#(                                            //FIXME: 这个除法器是无符号的，估计要出问题
		.DIV_WIDTH      (`XLEN)
    )int_div(
	.clk            (clk_i),
	.rst            (arst_i|flush_slave.flush),
	.flush          (1'b0),
	.start          (div_en),
	.stall          (1'b0),
    .sign           (div_sign),         //除法器一定需要带符号位运算
	.DIVIDEND       (srcdata1),
	.DIVISOR        (srcdata2),
	.DIV            (div_res_data),//商
	.MOD            (div_rem_data),//余数
	.div_idle       (),//Calculate done
	.calc_done      (div_done)
	);
Booth_Multiplier_4xB #(
    .N      (`XLEN)
)int_mul(
    .Rst            (arst_i | flush_slave.flush),
    .Clk            (clk_i),
    .Ld             (mul_en),
    .Unsigned       (1'b1),     //运算过程中一律使用无符号数
    .M              (srcdata1),
    .R              (srcdata2),
    .Valid          (mul_done),
    .P              (mul_p_data)
);
//-----------------计算符号位-------------------------------
always_comb begin
    case(opcode)
        `OPCODE_OP:begin
            case(funct3)
                `FUNCT3_MUL, `FUNCT3_MULH,`FUNCT3_DIV,`FUNCT3_REM:begin
                    result_sign = data1[63] ^ data2[63];    
                end
                `FUNCT3_MULHSU:begin
                    result_sign = data1[63];    //有符号数x无符号数，结果的符号位由有符号数确定
                end
                `FUNCT3_MULHU,`FUNCT3_DIVU,`FUNCT3_REMU:begin
                    result_sign = 1'b0;         //无符号数x无符号数，结果无符号
                end
                default:begin
                    result_sign = 1'b0;
                end
            endcase
        end
        `OPCODE_OP32:begin      //rv64 have mulw divw remw divuw remuw
            case(funct3)
                `FUNCT3_MUL, `FUNCT3_DIV,`FUNCT3_REM:begin
                    result_sign = data1[31] ^ data2[31];
                end
                `FUNCT3_DIVU,`FUNCT3_REMU:begin
                    result_sign = 1'b0;
                end
                default:begin
                    result_sign = 1'b0;
                end
            endcase
        end
        default:begin
            result_sign = 1'b0;
        end
    endcase
end
assign mul_p_data_sign = result_sign ? (~mul_p_data+1):(mul_p_data);
assign div_res_data_final = (srcdata2==64'b0)?64'hffff_ffff_ffff_ffff : div_res_data;
assign div_rem_data_final = (srcdata2==64'b0)?srcdata1 : div_rem_data;
//-----------------运算结果先用DFF打一拍----------------------
always_ff @( posedge clk_i ) begin
    if(state_next==STATE_RDY)begin
        case(opcode)
            `OPCODE_OP:begin
                case(funct3)
                    `FUNCT3_MUL:mdiv_result <= mul_p_data_sign[63:0];
                    `FUNCT3_MULH,`FUNCT3_MULHSU,`FUNCT3_MULHU: mdiv_result <= mul_p_data_sign[127:64];
                    `FUNCT3_DIV,`FUNCT3_DIVU: mdiv_result <= div_res_data_final;
                    `FUNCT3_REM,`FUNCT3_REMU: mdiv_result <= div_rem_data_final;
                    default : mdiv_result <= 'hx;   //should never get here
                endcase
            end
            `OPCODE_OP32:begin
                case(funct3)
                    `FUNCT3_MUL:mdiv_result <= {{32{mul_p_data_sign[31]}},mul_p_data_sign[31:0]};
                    `FUNCT3_DIV,`FUNCT3_DIVU: mdiv_result <= {{32{div_res_data_final[31]}},div_res_data_final[31:0]};
                    `FUNCT3_REM,`FUNCT3_REMU: mdiv_result <= {{32{div_rem_data_final[31]}},div_rem_data_final[31:0]};
                    default : mdiv_result <= 'hx;   //should never get here
                endcase
            end
            default:begin
                mdiv_result <= 'hx;
            end
        endcase
    end
end
//-----------------pipline output--------------------
assign ren = mdiv_mif.valid & mdiv_mif.ready;
always_comb begin
    mdiv_mif.valid = (state==STATE_RDY);
    mdiv_mif.data  = mdiv_result;
    mdiv_mif.itag  = itag;
end
endmodule