`include "prv664_bus_define.svh"
`include"timescale.v"
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
                                                                             
    Desc    : PRV664(voskhod664) simple bus interface unit(biu)
    Author  : JackPan
    Date    : 2023/3/28
    Version : 0.0(file initialize)

    此总线接口单元支持两个接口：单次访问接口、流式访问接口，将二者的访问信号转发到AXI总线上
    单次访问接口：支持64位数据位宽
    流式访问接口：仅支持128位访问位宽，当开始一个传输后，发送请求的一方必须时刻准备好读出数据或接收数据，不进行等待。

***********************************************************************************************/
module biu#(
    parameter PADDR_SIZE = 32,
              SINGLE_DATA_WIDTH = 64,
              DATA_WIDTH = 128,     //NO TOUCH
              BEAT_NUM = 4          //NO TOUCH
)(
    input wire                          clk_i, srst_i,
//-----------------------single access port-----------------
//          single access port only support 64bit access
    input wire                          single_read_req,
    input wire                          single_write_req,
    input wire [PADDR_SIZE-1:0]         single_addr,
    input wire [2:0]                    single_size,
    input wire [7:0]                    single_bsel,
    input wire [SINGLE_DATA_WIDTH-1:0]  single_wdata,
    output wire [SINGLE_DATA_WIDTH-1:0] single_rdata,
    output wire                         single_ack,
    output wire                         single_error,       
//-----------------------stream access port-----------------
    output wire                         stream_error,
    output wire                         stream_write_done,
    output reg                          stream_rvalid,
    output reg                          stream_rlast,       //标识当前读取流到最后一个数据
    output wire                         stream_wready,      //写数据准备好，此信号直接连接在请求方FIFO的ren上
    input wire                          stream_wvalid,      //写数据有效，此信号直接为FIFO信号empty取反，此模块不判定此信号
    input wire                          stream_readline_req,
    input wire                          stream_writeline_req,//请求读一行，行大小为beat_num * 128bit
    input wire [PADDR_SIZE-1:0]         stream_addr,
    input wire [DATA_WIDTH-1:0]         stream_wdata,
    output wire [DATA_WIDTH-1:0]        stream_rdata,
//------------------------axi interface--------------------
    axi_ar.master                       biu_axi_ar,
    axi_r.slave                         biu_axi_r,
    axi_aw.master                       biu_axi_aw,
    axi_w.master                        biu_axi_w,
    axi_b.slave                         biu_axi_b
);
localparam STATE_STD = 'h0,
           STATE_AR = 'h1,
           STATE_R = 'h2,
           STATE_AW= 'h3,
           STATE_W = 'h4,
           STATE_B = 'h5,
           STATE_RDY='h6,
           STATE_ERR= 'h7;

localparam INBUS_BEAT_NUM = BEAT_NUM * 2;       //系统总线为64位，输入总线128位，总线上所需拍数是输入总线的2倍

logic [3:0] state, state_next;

reg [7:0] beat_counter;         //拍计数器，用于计算在总线上成功完成了多少次传输
reg [63:0]l64_reg, h64_reg;     //缓冲总线上来的数据到高低64位值上
wire      l64_wen, h64_wen;

always_ff @( posedge clk_i ) begin
    if(srst_i)begin
        state <= STATE_STD;
    end
    else begin
        state <= state_next;
    end
end
always_comb begin
    case(state)
        STATE_STD:begin
            if(single_read_req |  stream_readline_req)begin
                state_next = STATE_AR;
            end else if(single_write_req |stream_writeline_req)begin
                state_next = STATE_AW;
            end else begin
                state_next = state;
            end
        end
        STATE_AR:state_next = biu_axi_ar.arready ? STATE_R : state;
        STATE_R:begin
            if(biu_axi_r.rvalid & biu_axi_r.rresp)begin
                state_next = STATE_ERR;
            end else if(stream_readline_req)begin
                state_next = (biu_axi_r.rvalid & (beat_counter==(INBUS_BEAT_NUM-1))) ? STATE_RDY : state;   //read line模式下需要等待计数器到顶
            end else if(single_read_req)begin
                state_next = biu_axi_r.rvalid ? STATE_RDY : state;              //单次访问模式下只读一个数据，读完之后直接跳转到就绪状态
            end else begin
                state_next = state;
            end
        end
        STATE_AW:state_next = biu_axi_aw.awready ? STATE_W : state;
        STATE_W:begin
            if(stream_writeline_req)begin
                state_next = (biu_axi_w.wready & (beat_counter==(INBUS_BEAT_NUM-1))) ? STATE_B : state;   //write line模式下需要等计数器到顶
            end else if(single_write_req)begin
                state_next = biu_axi_w.wready ? STATE_B : state;
            end else begin
                state_next = state;
            end
        end
        STATE_B:begin
            if(biu_axi_b.bvalid & biu_axi_b.bresp)begin
                state_next = STATE_ERR;
            end else begin
                state_next = biu_axi_b.bvalid ? STATE_RDY : state;
            end
        end
        default: state_next = STATE_STD;
    endcase
end
always_ff @( posedge clk_i ) begin
    if(h64_wen)begin
        h64_reg <= biu_axi_r.rdata;
    end
    if(l64_wen)begin
        l64_reg <= biu_axi_r.rdata;
    end
end
assign h64_wen = (state==STATE_R)&beat_counter[0]&biu_axi_r.rvalid;
assign l64_wen = (state==STATE_R)&(!beat_counter[0])&biu_axi_r.rvalid;

always_ff @( posedge clk_i ) begin
    case(state)
        STATE_STD:beat_counter <= 0;
        STATE_R:  beat_counter <= biu_axi_r.rvalid ? (beat_counter+1) : beat_counter;   
        STATE_W:  beat_counter <= biu_axi_w.wready ? (beat_counter+1) : beat_counter;   //在写内存模式下，因为此模块将wvalid始终置1，因此只判断wready即可
    endcase
end
//----------------------axi interface--------------------------
always_comb begin
    biu_axi_ar.arid   = 0;
    biu_axi_ar.araddr = (single_read_req | single_write_req)?single_addr : stream_addr;
    biu_axi_ar.arlen  = (single_read_req | single_write_req)? 8'b0:(INBUS_BEAT_NUM-1) ;     //单次读模式下一次读1拍，stream模式下一次读一整个cache行(16拍共128字节)
    biu_axi_ar.arsize = (single_read_req | single_write_req)? single_size : 3'b011; //单次读模式大小不超过64bit，连续模式下为固定的64位burst
    biu_axi_ar.arburst= `AXI_BURST_INCR;                                            //burst模式固定为地址自增模式
    biu_axi_ar.arlock = 0;
    biu_axi_ar.arcache= 0;
    biu_axi_ar.arprot = 0;
    biu_axi_ar.arqos  = 0;
    biu_axi_ar.arregion=0;
    biu_axi_ar.arvalid= (state==STATE_AR);
    //--------------rchannel---------------------
    biu_axi_r.rready  = (state==STATE_R);
    //--------------awchannel--------------------
    biu_axi_aw.awid   = 0;
    biu_axi_aw.awaddr = (single_read_req | single_write_req)?single_addr : stream_addr;
    biu_axi_aw.awlen  = (single_read_req | single_write_req)? 8'b0:(INBUS_BEAT_NUM-1);
    biu_axi_aw.awsize = (single_read_req | single_write_req)? single_size : 3'b011;
    biu_axi_aw.awburst= `AXI_BURST_INCR;
    biu_axi_aw.awlock = 0;
    biu_axi_aw.awcache= 0;
    biu_axi_aw.awprot = 0;
    biu_axi_aw.awqos  = 0;
    biu_axi_aw.awregion=0;
    biu_axi_aw.awvalid = (state==STATE_AW);
    //--------------wchannel-----------------------
    biu_axi_w.wdata   = single_write_req ? single_wdata : (beat_counter[0]?stream_wdata[127:64] : stream_wdata[63:0]);
    biu_axi_w.wstrb   = single_write_req ? single_bsel : 8'b11111111;       //当进行stream传输时，字节选择全1
    biu_axi_w.wlast   = (state==STATE_W)&(single_write_req | (beat_counter==(INBUS_BEAT_NUM-1)));
    biu_axi_w.wvalid  = (state==STATE_W);
    //-------------bchannel----------------------
    biu_axi_b.bready  = (state==STATE_B);
end
//----------------------stream access interface-------------------
assign stream_write_done = (state==STATE_B) & biu_axi_b.bvalid;
assign stream_error = (stream_readline_req | stream_writeline_req) & (state==STATE_ERR);
always_ff @( posedge clk_i ) begin
    stream_rvalid <= h64_wen;                               //当写高64位寄存器时，将写信号延迟一拍作为128位数据就绪标志
    stream_rlast  <= biu_axi_r.rlast & biu_axi_r.rvalid;    //通知当前以及传输完成最后一个数据
end
assign stream_wready= (state==STATE_W) & stream_writeline_req & beat_counter[0] & biu_axi_w.wready;   //FIXME: 128到64位总线位宽转换问题
assign stream_rdata = {h64_reg, l64_reg};
//---------------------single access interface----------------------
assign single_rdata = l64_reg;
assign single_ack   = (single_read_req | single_write_req) & (state==STATE_RDY);
assign single_error = (single_read_req | single_write_req) & (state==STATE_ERR);
//----------------------assert----------------------
always@(posedge clk_i)begin
    if(!srst_i)begin
        case({single_read_req, single_write_req, stream_readline_req, stream_writeline_req})
            4'b0001, 4'b0010, 4'b0100, 4'b1000, 4'b0000:begin     //合法访问，一次只有一个req
            end
            default:begin
                $display("ERR: wrone control signal in biu control signal.");   //如果任意有两个以上的req被拉高，则认为是错误的
                $stop();
            end
        endcase
    end
end
endmodule