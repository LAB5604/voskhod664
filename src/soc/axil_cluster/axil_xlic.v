`include "timescale.v"
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
                                                                             
    Desc    : PRV664(voskhod664) xlic unit include timer, crtc ontrol, gpio control
    Author  : JackPan
    Date    : 2024/5/5
    Version : 1.0

    Address space:
        +0 : MTIME 64bit read/write
        +8 : MTIMECMP 64bit read/write
        +16: SYSINFO 64bit read only
        +24: CRTC config base address write only
        +32: CRTC config reg write only
        +40: GPIO direction register write/read
        +48: GPIO output register write/read
        +56: GPIO input register read only

***********************************************************************************************/
module axil_xlic#(
    // Width of data bus in bits
    parameter DATA_WIDTH = 64,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 8,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Timeout delay (cycles)
    parameter TIMEOUT = 4
)(
    input  wire                   clk,
    input  wire                   rst,
    /*
     * AXI-Lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]  s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [DATA_WIDTH-1:0]  s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,

    output reg [DATA_WIDTH-1:0]   crtc_base_addr,   //base address of vga use
    output reg                    crtc_cfg_en,      //enable crtc
    output reg                    mti,              //machine mode timer interrupt

    output reg [DATA_WIDTH-1:0]   gpio_dir,       //1=output 0=input, default=input
    output reg [DATA_WIDTH-1:0]   gpio_out,
    input wire [DATA_WIDTH-1:0]   gpio_in
);
localparam MTIME_ADDR = 0,
           MTIMECMP_ADDR=8,
           SYSINFO_ADDR = 16,
           CRTC_BASE_ADDR = 24,     //WO
           CRTC_CFG_ADDR = 32,      //WO
           GPIO_DIR      = 40,      //WR
           GPIO_OUT      = 48,      //WR
           GPIO_IN       = 56;      //RO

    wire [ADDR_WIDTH-1:0]  reg_wr_addr;
    wire [DATA_WIDTH-1:0]  reg_wr_data;
    wire [STRB_WIDTH-1:0]  reg_wr_strb;
    wire                   reg_wr_en;
    wire                   reg_wr_wait;
    wire                   reg_wr_ack;
    wire [ADDR_WIDTH-1:0]  reg_rd_addr;
    wire                   reg_rd_en;
    reg  [DATA_WIDTH-1:0]  reg_rd_data;
    wire                   reg_rd_wait;
    wire                   reg_rd_ack;

    reg [DATA_WIDTH-1:0] mtime, mtimecmp;       //machine mode timer
    reg [DATA_WIDTH-1:0]    gpio_in_reg;

axil_reg_if#(
    // Width of data bus in bits
    .DATA_WIDTH             (DATA_WIDTH),
    // Width of address bus in bits
    .ADDR_WIDTH             (ADDR_WIDTH),
    // Width of wstrb (width of data bus in words)
    // Timeout delay (cycles)
    .TIMEOUT                (TIMEOUT)
)axil_reg(
    .clk                        (clk),
    .rst                        (rst),
    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr              (s_axil_awaddr),
    .s_axil_awprot              (s_axil_awprot),
    .s_axil_awvalid             (s_axil_awvalid),
    .s_axil_awready             (s_axil_awready),
    .s_axil_wdata               (s_axil_wdata),
    .s_axil_wstrb               (s_axil_wstrb),
    .s_axil_wvalid              (s_axil_wvalid),
    .s_axil_wready              (s_axil_wready),
    .s_axil_bresp               (s_axil_bresp),
    .s_axil_bvalid              (s_axil_bvalid),
    .s_axil_bready              (s_axil_bready),
    .s_axil_araddr              (s_axil_araddr),
    .s_axil_arprot              (s_axil_arprot),
    .s_axil_arvalid             (s_axil_arvalid),
    .s_axil_arready             (s_axil_arready),
    .s_axil_rdata               (s_axil_rdata),
    .s_axil_rresp               (s_axil_rresp),
    .s_axil_rvalid              (s_axil_rvalid),
    .s_axil_rready              (s_axil_rready),
    /*
     * Register interface
     */
    .reg_wr_addr                (reg_wr_addr),
    .reg_wr_data                (reg_wr_data),
    .reg_wr_strb                (reg_wr_strb),
    .reg_wr_en                  (reg_wr_en),
    .reg_wr_wait                (reg_wr_wait),
    .reg_wr_ack                 (reg_wr_ack),
    .reg_rd_addr                (reg_rd_addr),
    .reg_rd_en                  (reg_rd_en),
    .reg_rd_data                (reg_rd_data),
    .reg_rd_wait                (reg_rd_wait),
    .reg_rd_ack                 (reg_rd_ack)
);
always@(posedge clk)begin
    gpio_in_reg <= gpio_in;
end

always@(posedge clk or posedge rst)begin
    if(rst)begin
        mtime           <= 64'h0;
        mtimecmp        <= 64'h0;
        crtc_base_addr  <= 64'h0;
        crtc_cfg_en     <= 64'h0;
        gpio_dir        <= 64'h0;
        gpio_out        <= 64'h0;
    end
    else if(reg_wr_en)begin
        case(reg_wr_addr)
            MTIME_ADDR    :
            begin 
                mtime          <= reg_wr_data;
                $display("XLIC: mtime is writen, data=0x%h",reg_wr_data);
            end
            MTIMECMP_ADDR :begin
                mtimecmp       <= reg_wr_data;
                $display("XLIC: mtimecmp is writen, data=0x%h",reg_wr_data);
            end
            CRTC_BASE_ADDR : crtc_base_addr <= reg_wr_data;
            CRTC_CFG_ADDR  : crtc_cfg_en <= reg_wr_data[0];
            GPIO_DIR : gpio_dir <= reg_wr_data;
            GPIO_OUT : gpio_out <= reg_wr_data;
            default:
            begin
                $display("XLIC: wrong address is used when access!");
                $stop();
            end
        endcase
    end
    else begin
        mtime <= mtime + 64'd1;
    end
end
assign reg_wr_ack = reg_wr_en;
assign reg_wr_wait= 0;
//---------------------read interface--------------------
always@(*)begin
    case(reg_rd_addr)
        MTIME_ADDR     : reg_rd_data = mtime;
        MTIMECMP_ADDR  : reg_rd_data = mtimecmp;
        SYSINFO_ADDR   : reg_rd_data = 'h0;
        GPIO_DIR       : reg_rd_data = gpio_dir;
        GPIO_OUT       : reg_rd_data = gpio_out;
        GPIO_IN        : reg_rd_data = gpio_in_reg;
        default : reg_rd_data = 64'hx;
    endcase
end
assign reg_rd_ack = reg_rd_en;
assign reg_rd_wait= 0;
//--------------------mti logic--------------------------
always@(posedge clk)begin
    mti <= (mtime > mtimecmp);
end
endmodule