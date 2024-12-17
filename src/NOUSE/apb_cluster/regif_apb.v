/**********************************************************************************************

   Copyright (c) [2023] [JackPan]
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
                                                                             
    Desc    : axi-lite interface to apb interface
    Author  : JackPan
    Date    : 2023/9/1
    Version : 0.0 (file initialize)


***********************************************************************************************/
module regif_apb#(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)(
    input wire                    clk_i,
    input wire                    arst_i,
    //   reg interface
    input wire [ADDR_WIDTH-1:0]   reg_wr_addr,
    input wire [DATA_WIDTH-1:0]   reg_wr_data,
    input wire [STRB_WIDTH-1:0]   reg_wr_strb,
    input wire                    reg_wr_en,
    output wire                   reg_wr_wait,
    output wire                   reg_wr_ack,
    input wire [ADDR_WIDTH-1:0]   reg_rd_addr,
    input wire                    reg_rd_en,
    output wire [DATA_WIDTH-1:0]  reg_rd_data,
    output wire                   reg_rd_wait,
    output wire                   reg_rd_ack,
    //   apb interface
    output wire                   psel,   penable, pwrite,
    output wire [DATA_WIDTH-1:0]  pwdata,
    output wire [ADDR_WIDTH-1:0]  paddr,
    input wire                    pready, pslverr,
    input wire  [DATA_WIDTH-1:0]  prdata
);
localparam STATE_IDLE = 2'b00,
           STATE_READ = 2'b01,      //a read cycle in process
           STATE_WRITE= 2'b10;      //an write cycle in process

    reg [1:0] state;

always @(posedge clk_i or posedge arst_i) begin
    if(arst_i)begin
        state <= STATE_IDLE;
    end
    else begin
        case(state)
            STATE_IDLE:begin                            //读写通道抢占式使用APB总线
                if(reg_rd_en)begin
                    state <= STATE_READ;
                end else if(reg_wr_en)begin
                    state <= STATE_WRITE;
                end
            end
            STATE_READ:begin
                state <= reg_rd_en ? state : STATE_IDLE;    //如果master不再需要进行读取，切换回idle模式
            end
            STATE_WRITE:begin
                state <= reg_wr_en ? state : STATE_IDLE;
            end
            default: state <= STATE_IDLE;
        endcase
    end
end
//---------------apb output mux------------------
assign psel     = (state==STATE_READ) ? reg_rd_en:(state==STATE_WRITE)?reg_wr_en:1'b0; 
assign penable  = (state==STATE_READ) ? reg_rd_en:(state==STATE_WRITE)?reg_wr_en:1'b0; 
assign pwrite   = (state==STATE_WRITE)? reg_wr_en:1'b0;
assign pwdata   = (state==STATE_WRITE)? reg_wr_data:1'b0;
assign paddr    = (state==STATE_READ) ? reg_rd_addr:(state==STATE_WRITE)?reg_wr_addr:0;
//---------------reg interface mux--------------
assign reg_wr_wait = 1'b0;
assign reg_wr_ack  = (state==STATE_WRITE)?pready:1'b0;
assign reg_rd_wait = 1'b0;
assign reg_rd_data = prdata;
assign reg_rd_ack  = (state==STATE_READ)?pready:1'b0;
endmodule