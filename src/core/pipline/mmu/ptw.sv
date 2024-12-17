`include "prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_bus_define.svh"
/**********************************************************************************************

   Copyright (c) [2022] [JackPan, XiaoyuHong, KuiSun]
   [Software Name] is licensed under Mulan PSL v2.
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
                                                                             
    Name    : PRV664(voskhod664) page table walker
    Author  : Jack.Pan
    Date    : 2022/9/7
    Version : 1.0 debug module csr include
    Desc    :   standard valid-ready handshake.


***********************************************************************************************/
module ptw
#(
    parameter SRCID    = 5'h00
)
(
//---------Global Signals-------------
    input wire                      ptw_clk_i,
    input wire                      ptw_arst_i,
    sysinfo_interface.slave         sysinfo_slave,
//---------Command & Data signals------------
    input wire                      ptw_valid_i,
    input wire [26:0]               ptw_vpn_i,
    output logic                    ptw_ready_o,
//---------PTE and PPN Reply-----------------
    output logic [43:0]             ptw_ppn_o,
    output logic [9:0]              ptw_pte_o,
    output logic [1:0]              ptw_pgsize_o,
    output logic                    ptw_error_o,
//------------FIB bus interface--------------
    axi_ar.master                   ptw_axi_ar,
    axi_r.slave                     ptw_axi_r
);

    localparam STD 	    = 4'h0,	                //等待状态，当需要进行页面检查时候跳转
               S2_1	    = 4'h1,	                //向axi总线发出地址，等待arready后转到S2_2
               S2_2	    = 4'h2,                 //等待ar通道响应
               S4  	    = 4'h3,	                //页面有效性检查，如果是指针则继续进行页表访问
               S5  	    = 4'h4,	                //页面权限检查，如果权限不符合则直接引起页面异常
               RDY	    = 4'h7,		            //转换完成
               PGFLT    = 4'h8;
//-----------------转换用的临时寄存器------------------------
    reg [26:0]      vpn_temp;
    reg [3:0]       state;                  //state Machine of PTW
    reg [1:0]       i;
    reg [`XLEN-1:0] pte_temp;               //临时保存的PTE
    reg [43:0]      a;                      //A寄存器（RISCV privilege文档中定义的）
//------------------输入命令首先寄存一排-------------------------------
always@(posedge ptw_clk_i)begin
    if(ptw_valid_i)begin
        vpn_temp         <= ptw_vpn_i;               //Virtual Address Input
    end
end
//------------------Page Table walk 状态机----------------------------
always@(posedge ptw_clk_i or posedge ptw_arst_i)begin
    if(ptw_arst_i)begin
        state <= STD;
    end
    else begin
        case(state)
            STD     :   if(ptw_valid_i)begin        //如果输出保持的值已被取走，则继续转换
                            state <= S2_1;
                            i     <= 2'h2;          //reset i
                            a     <= sysinfo_slave.satp[`SATP_BIT_PPN_HI:`SATP_BIT_PPN_LO]; //A = satp ppn
                        end
            S2_1    :   if(ptw_axi_ar.arready)begin
                            state <= S2_2;
                        end
            S2_2    :   if((ptw_axi_r.rid==SRCID) & ptw_axi_r.rvalid)begin
                            case(ptw_axi_r.rresp)
                                `AXI_RESP_OKAY : state <= S4;
                                default : state <= PGFLT;    //页面错误
                            endcase   
                        end
            S4      :   if(!pte_temp[`SV39_PTE_BIT_V] | !pte_temp[`SV39_PTE_BIT_R] & pte_temp[`SV39_PTE_BIT_W])begin
                            state <= PGFLT;                    //如果V==0或者R、W==0、0、1，造成错误页面
                        end
                        else if(pte_temp[`SV39_PTE_BIT_R] | pte_temp[`SV39_PTE_BIT_X])begin
                            state <= S5;                       //如果R==1或x==1，则是一个末端页面，转到s5
                        end
                        else if(i==2'h0)begin
                            state <= PGFLT;                    //如果i=0，已经无法继续转换，造成错误页面
                        end
                        else begin: NextPTE                    //这不是末端页面，继续分页
                            state <= S2_1;
                            i     <= i - 2'h1;
                            a     <= pte_temp[`SV39_PTE_BIT_PPN2_HI:`SV39_PTE_BIT_PPN0_LO];
                        end
            S5      :   if(((i==2'h1)&pte_temp[`SV39_PTE_BIT_PPN0_HI:`SV39_PTE_BIT_PPN0_LO]!=9'b0)|((i==2'h2)&pte_temp[`SV39_PTE_BIT_PPN1_HI:`SV39_PTE_BIT_PPN0_LO]!=18'b0))begin  //若页面是一个对齐的超页面，则引起页面错误
                            state <= PGFLT;
                        end
                        else begin
                            state <= RDY;
                        end
		    RDY:	state <= STD;
		    PGFLT:	state <= STD;
            default:state <= STD;
        endcase
    end
end
//PTE_temp寄存器更新
always@(posedge ptw_clk_i or posedge ptw_arst_i)begin
    if(ptw_arst_i)begin
        pte_temp <= 64'h0;
    end
	else if(state==S2_2)begin
		pte_temp <= ptw_axi_r.rdata;
	end
end
//----------------------------转换后值输出-----------------------------
always_comb begin
    ptw_ready_o = (state==RDY)|(state==PGFLT);
    ptw_error_o = (state==PGFLT);
    ptw_ppn_o   = pte_temp[`SV39_PTE_BIT_PPN2_HI:`SV39_PTE_BIT_PPN0_LO];
    ptw_pte_o   = pte_temp[9:0];
    ptw_pgsize_o= i;
end
//---------------------------------------tilelink总线接口-------------------------------------------
always_comb begin
    case(state)
        S2_1: ptw_axi_ar.arburst = `AXI_BURST_INCR;
        default : ptw_axi_ar.arburst = 'hx;
    endcase
    ptw_axi_ar.arvalid = (state==S2_1);
    ptw_axi_ar.arlen = 0;
    ptw_axi_ar.arsize= 3'b110;
    ptw_axi_ar.arlock= 0;
    ptw_axi_ar.arcache=0;
    ptw_axi_ar.arprot =0;
    ptw_axi_ar.arqos  =0;
    ptw_axi_ar.arregion=0;
    ptw_axi_ar.arid   = SRCID;
    case(i)
        2'h0    :   ptw_axi_ar.araddr = {8'b0,a,vpn_temp[8:0],3'b0};
        2'h1    :   ptw_axi_ar.araddr = {8'b0,a,vpn_temp[17:9],3'b0};
        2'h2    :   ptw_axi_ar.araddr = {8'b0,a,vpn_temp[26:18],3'b0};
    default     :   ptw_axi_ar.araddr = 64'h0;
    endcase
    ptw_axi_r.rready = 1'b1;
end

endmodule
