`include "salyut1_soc_config.svh"
`timescale 1ns/1ps
module vga_tb();

    localparam RAM_SIZE = 8192;
    localparam OCRAM_ADDR_WIDTH = $clog2(RAM_SIZE);
    localparam INIT_FILE = "init.txt";

    reg   clk, clk25, rst;

    wire                        sram_req;
    wire                        sram_we;
    wire [OCRAM_ADDR_WIDTH-1:0] sram_addr;
    wire [7:0]                  sram_be;
    wire [63:0]                 sram_rdata;
    wire [63:0]                 sram_wdata;

    sys_axi_ar    axi_ar();
    sys_axi_r     axi_r();
    sys_axi_aw    axi_aw();
    assign axi_aw.awvalid = 0;  //vga card dont use axi write channel
    sys_axi_w     axi_w();
    assign axi_w.wvalid = 0;
    sys_axi_b     axi_b();
    assign axi_b.bready = 0;

    wire [7:0] vga_b, vga_r, vga_g;
    wire       vga_hs, vga_vs;
//-----------------------------------------
initial begin
    clk = 0;
    clk25=0;
    rst = 1;
#15
    rst = 0;
end
always  begin
    #10
        clk = ~clk;
end

always  begin
    #20
        clk25 = ~clk25;
end

//----------------duts----------------------
axi_vga_top#(
    .REFERSH_DELAY(833333),   //两次刷新的间隔，50MHz sys时钟下 60Hz刷新间隔为833333
    .AXI_ADDR_W  (`AXI_ADDR_WIDTH),  
    .AXI_DATA_W  (`AXI_DATA_WIDTH),  //can only config to 64 or 32
    .AXI_ID_W    (`AXI_ID_WIDTH),
    .INIT_FRAME_ENABLE           ("DISABLE"),                       //enable frame initial with CHAR,COLOR,BLANKING file
	.INIT_FRAME_CHAR_FILE_NAME   (""),      //this file is for frame init, can be nothing
    .INIT_FRAME_COLOR_FILE_NAME  (""),     //this file is for frame init, can be nothing
	.INIT_FRAME_BLINK_FILE_NAME  (""),		//this file is for frame init, can be nothing
    .INIT_CHAR_ROM_FILE_NAME     ("font.txt")               //this rom is for char's shape, must have it!  
)dut0_vga(
    .clk_i                      (clk),
    .clk25_i                    (clk25),
    .rst_i                      (rst),
    //----------------axi master interface--------------

    .m_axi_arvalid              (axi_ar.arvalid),
    .m_axi_arready              (axi_ar.arready),
    .m_axi_araddr               (axi_ar.araddr),
    .m_axi_arlen                (axi_ar.arlen),
    .m_axi_arsize               (axi_ar.arsize),
    .m_axi_arburst              (axi_ar.arburst),
    .m_axi_arid                 (axi_ar.arid),
    .m_axi_rvalid               (axi_r.rvalid),
    .m_axi_rready               (axi_r.rready),
    .m_axi_rid                  (axi_r.rid),
    .m_axi_rresp                (axi_r.rresp),
    .m_axi_rdata                (axi_r.rdata),
    .m_axi_rlast                (axi_r.rlast),
    //-----------------config signal-----------------
    .cfg_baseaddr               (64'h0),
    .cfg_en             (64'h1),
    //--------------vga display interface------------
    .vga_b_o                    (vga_b),
	.vga_g_o                    (vga_g),
	.vga_hs_o                   (vga_hs),
	.vga_r_o                    (vga_r),
	.vga_vs_o                   (vga_vs)
);

axi2mem #(
    .AXI_ID_WIDTH       (`AXI_ID_WIDTH),
    .AXI_ADDR_WIDTH     (`AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH     (`AXI_DATA_WIDTH),
    .AXI_USER_WIDTH     (0)
)dut1_sramc(
    .clk_i              (clk),    // Clock
    .rst_ni             (!rst),  // Asynchronous reset active low
    //--------------- axi4 bus(interface)-----------
    .s_axi_ar           (axi_ar),
    .s_axi_r            (axi_r),
    .s_axi_aw           (axi_aw),
    .s_axi_w            (axi_w),
    .s_axi_b            (axi_b),

    .req_o              (sram_req),
    .we_o               (sram_we),
    .addr_o             (sram_addr),
    .be_o               (sram_be),
    .user_o             (),//user no use
    .data_o             (sram_wdata),
    .user_i             (),//user no use
    .data_i             (sram_rdata)
);
//-------------------dut ends----------------------
sram_1rw_sync_wbe#(
    .NEED_INIT      (1),             //0: no init file ,1:init with INIT_FILE
    .INIT_FILE      (INIT_FILE),
    .DATA_WIDTH     (64),
    .DATA_DEPTH     (RAM_SIZE/8)
)sram(
    .clk            (clk),
    .addr           (sram_addr[OCRAM_ADDR_WIDTH-1:3]),
    .ce             (sram_req),
    .we             (sram_we),
    .datar          (sram_rdata),
    .dataw          (sram_wdata),
    .be             (sram_be)
);


endmodule