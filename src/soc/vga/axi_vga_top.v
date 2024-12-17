/******************************************************************************************

   Copyright (c) [2023] [JackPan]
   [axi_vga_top] is licensed under Mulan PSL v2.
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

    Name: axi interface text mode VGA display module
    Auth: Jack.Pan
    Date: 2023/11/30
    Desc: 使用AXI作为master接口的字符显卡，和系统共享一片5120字节的显存，程序通过设置BASEADDR寄存器确定显示卡使用那一片内存
        VGA字符卡只使用总数为64字节的burst读写操作，以加快ddr存储器的访问速度并降低对系统的占用

    axi-lite config register defines:
        +0 CFG
        bit63~1   RESV
        bit0      EN   0=disable display  1=enable display
        +8 BASEADDR
        bit63~0   BASEADDR    baseaddress of vga card use


******************************************************************************************/
module axi_vga_top#(
    parameter REFERSH_DELAY = 833333,   //两次刷新的间隔，50MHz sys时钟下 60Hz刷新间隔为833333
              AXI_ADDR_W = 32,  
              AXI_DATA_W = 64,  //can only config to 64 or 32
              AXI_ID_W   = 4,
              INIT_FRAME_ENABLE             = "DISABLE",                       //enable frame initial with CHAR,COLOR,BLANKING file
			  INIT_FRAME_CHAR_FILE_NAME     = "",      //this file is for frame init, can be nothing
    		  INIT_FRAME_COLOR_FILE_NAME    = "",     //this file is for frame init, can be nothing
			  INIT_FRAME_BLINK_FILE_NAME    = "",		//this file is for frame init, can be nothing
    		  INIT_CHAR_ROM_FILE_NAME       = "font.txt"               //this rom is for char's shape, must have it!  

)(
    input wire                          clk_i,
    input wire                          clk25_i,
    input wire                          rst_i,
    //----------------axi master interface--------------

    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    output wire [AXI_ADDR_W    -1:0]    m_axi_araddr,
    output wire [8             -1:0]    m_axi_arlen,
    output wire [3             -1:0]    m_axi_arsize,
    output wire [2             -1:0]    m_axi_arburst,
    output wire [AXI_ID_W      -1:0]    m_axi_arid,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,
    input  wire  [AXI_ID_W      -1:0]   m_axi_rid,
    input  wire  [2             -1:0]   m_axi_rresp,
    input  wire  [AXI_DATA_W    -1:0]   m_axi_rdata,
    input  wire                         m_axi_rlast,
    //-----------------config signal-----------------
    input wire [63:0]                   cfg_baseaddr,
    input wire                          cfg_en,
    //--------------vga display interface------------
    output	wire	     [7:0]		    vga_b_o,
	output	wire	     [7:0]		    vga_g_o,
	output	wire	          		    vga_hs_o,
	output	wire	     [7:0]		    vga_r_o,
	output	wire	          		    vga_vs_o
);
//-----------------FSM------------------
localparam STATE_IDLE = 4'h0,   //IDLE状态，等待刷新计数器
           STATE_AR   = 4'h1,   //AR状态，发送读取地址
           STATE_R    = 4'h2,   //R状态，从总线上接数据，更新字节计数器
           STATE_NEXT = 4'h3;   //NEXT状态，判断是否结束传输，如果没有结束继续跳转到AR进行下一轮读取
localparam TOTAL_BYTE = 5120;   //总共需要从内存中读取的字符数量，NO TOUCH
//-----------------config register define-------------
localparam CFG_ADDR = 0,
           BASEADDR_ADDR = 8;
//-----------------other defines----------------------
localparam CHAR_ADDR_WIDTH  = $clog2(2400/(AXI_DATA_W/8)),
		   BLK_ADDR_WIDTH  = $clog2(300/(AXI_DATA_W/8));

    reg [3:0]   state, state_next;
    reg [12:0]  byte_count;
    reg [20:0]  refersh_count;  //刷新计数器，用于控制每次刷新屏幕上字符的间隔时间

//--------------config reg----------------
    reg [64-1:0]                config_cfg;
    reg [64-1:0]                config_baseaddr;
//-------------refersh paulse-------------
    wire                refersh_req, refersh_finish;
//---------------frontend ram write signal-----------------
    wire [CHAR_ADDR_WIDTH-1:0] charram_addr_i, colorram_addr_i;
    wire                       charram_wren_i, colorram_wren_i;
    wire [BLK_ADDR_WIDTH-1:0]  blinkram_addr_i;
    wire                       blinkram_wren_i;
    
always @(posedge clk_i) begin
    if(rst_i)begin
        state <= STATE_IDLE;
    end else begin
        state <= state_next;
    end
end
always@(*)begin
    case(state)
        STATE_IDLE:state_next = (!config_cfg[0]) ? STATE_IDLE : refersh_req ? STATE_AR : state;
        STATE_AR:  state_next = m_axi_arready ? STATE_R : state;
        STATE_R: state_next = (m_axi_rvalid & m_axi_rlast) ? STATE_NEXT : state;
        STATE_NEXT: state_next = refersh_finish ? STATE_IDLE : STATE_AR;//当前行读取完成后，如果已经刷新完成，则进入idle状态等待下一次更新字符缓存
        default: state_next = STATE_IDLE;
    endcase
end

always @(posedge clk_i) begin
    if(rst_i)begin
        byte_count <= 0;
    end else begin
        case(state)
            STATE_IDLE: byte_count <= 0;        //IDLE状态下清零计数器
            STATE_AR,STATE_NEXT: byte_count <= byte_count; //AR状态下保持
            STATE_R: byte_count <= m_axi_rvalid ? (byte_count + (AXI_DATA_W/8)) : byte_count;
        endcase
    end
end
always @(posedge clk_i) begin
    if(rst_i)begin
        refersh_count <= 0;
    end else begin
        refersh_count <= (refersh_count==REFERSH_DELAY) ? 0 : (refersh_count + 1);
    end
end
assign refersh_req = (refersh_count==REFERSH_DELAY);
assign refersh_finish = (byte_count == TOTAL_BYTE);
//-------------------AXI bus-----------------------
assign m_axi_araddr = config_baseaddr + byte_count;
assign m_axi_arburst= 2'b01;
assign m_axi_arid = 0;

generate
    if(AXI_DATA_W==64)begin
        assign m_axi_arsize = 3'b011;   //64位总线模式下8拍搞定
        assign m_axi_arlen=8'd7;
    end else begin
        assign m_axi_arsize = 3'b010;   //32位总线模式下16拍搞定
        assign m_axi_arlen = 8'd15;
    end
endgenerate
assign m_axi_arvalid = (state==STATE_AR);

assign m_axi_rready = (state==STATE_R);

//---------------VGA front end 写信号和写地址------------------
assign charram_wren_i = (state==STATE_R) & m_axi_rvalid & (13'd0<=byte_count) & (byte_count<13'd2400);
assign colorram_wren_i= (state==STATE_R) & m_axi_rvalid & (13'd2400<=byte_count) & (byte_count<13'd4800);
assign blinkram_wren_i= (state==STATE_R) & m_axi_rvalid & (13'd4800<=byte_count) & (byte_count<13'd5100);

assign charram_addr_i = byte_count>>$clog2(AXI_DATA_W/8);         //byte count为字节计数，在不同总线宽度下需要进行右移进行字节匹配
assign colorram_addr_i= (byte_count-13'd2400)>>$clog2(AXI_DATA_W/8);
assign blinkram_addr_i= (byte_count-13'd4800)>>$clog2(AXI_DATA_W/8);

textvga_top#(
	.DATA_WIDTH                 (AXI_DATA_W),								//32 or 64
    .INIT_FRAME_ENABLE          (INIT_FRAME_ENABLE),                       //enable frame initial with CHAR,COLOR,BLANKING file
	.INIT_FRAME_CHAR_FILE_NAME  (INIT_FRAME_CHAR_FILE_NAME),      //this file is for frame init, can be nothing
    .INIT_FRAME_COLOR_FILE_NAME (INIT_FRAME_COLOR_FILE_NAME),     //this file is for frame init, can be nothing
	.INIT_FRAME_BLINK_FILE_NAME (INIT_FRAME_BLINK_FILE_NAME),		//this file is for frame init, can be nothing
    .INIT_CHAR_ROM_FILE_NAME    (INIT_CHAR_ROM_FILE_NAME)               //this rom is for char's shape, must have it!  			
)vga_frontend(
    .sysclk_i               (clk_i),     //system clock, can be any value
    .vgaclk_i               (clk25_i),   //must use 25MHz for vga clock
    .rst_i                  (rst_i),     //async reset
    .pallete_select         (2'b00),     //select a pallete to use, default=00 is IBM PC/XT's color shape!
    ////////////system logic access port/////////////////
    .charram_addr_i         (charram_addr_i),     
    .colorram_addr_i        (colorram_addr_i),
	.blinkram_addr_i        (blinkram_addr_i),
    .charram_wren_i         (charram_wren_i),
    .colorram_wren_i        (colorram_wren_i),
    .blinkram_wren_i        (blinkram_wren_i),
    .charram_data_i         (m_axi_rdata),
    .colorram_data_i        (m_axi_rdata),
    .blinkram_data_i        (m_axi_rdata),
	//////////// VGA //////////
	.vga_b_o                (vga_b_o),
	.vga_g_o                (vga_g_o),
	.vga_hs_o               (vga_hs_o),
	.vga_r_o                (vga_r_o),
	.vga_vs_o               (vga_vs_o)
);
always@(posedge clk_i or posedge rst_i)begin
    if(rst_i)begin
        config_cfg <= 0;
        config_baseaddr <= 0;
    end
    else begin
        config_baseaddr <= cfg_baseaddr;
        config_cfg[0]   <= cfg_en;
    end
end

endmodule