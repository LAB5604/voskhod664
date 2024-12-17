`timescale 1ns/100ps
`include "salyut1_soc_config.svh"
/******************************************************************************************

   Copyright (c) [2024] [JackPan, XiaoyuHong, KuiSun]
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

    This is a testbench for salyut1 soc, also for prv664 cpu

    Auth: Jack
    Date: 2024/1/15
    Desc: salyut1 soc和prv664 cpu的测试用testbench，当进行fpga移植的时候，也可以参考此文件中的例化接线

******************************************************************************************/
`define INIT_FILE       main.bin 

module fullsoc_tb();
    //localparam  INIT_FILE = "hex.txt";   //WARNING! Do NOT change the name
    localparam  C_S_AXI_ID_WIDTH = 12,
                C_S_AXI_ADDR_WIDTH=30,
                C_S_AXI_DATA_WIDTH=64;
    localparam  OCRAM_ADDR_WIDTH = 17;
reg clk100,     //100Mhz clock for simulation external DRAM controller 
    clk50,      //50Mhz clock for soc main clock (xbar, cpu, sram)
    clk25,      //25Mhz clock for soc vga system use
    rst;

`ifdef EXT_MEMORY
/********************************************************
    simulation external DRAM interface
********************************************************/
// Slave Interface Write Address Ports
    wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_awid;
    wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr;
    wire [7:0]                        s_axi_awlen;
    wire [2:0]                        s_axi_awsize;
    wire [1:0]                        s_axi_awburst;
    wire [0:0]                        s_axi_awlock;
    wire [3:0]                        s_axi_awcache;
    wire [2:0]                        s_axi_awprot;
    wire                              s_axi_awvalid;
    wire                              s_axi_awready;
     // Slave Interface Write Data Ports
    wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata;
    wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb;
    wire                              s_axi_wlast;
    wire                              s_axi_wvalid;
    wire                              s_axi_wready;
     // Slave Interface Write Response Ports
    wire                              s_axi_bready;
    wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_bid;
    wire [1:0]                        s_axi_bresp;
    wire                              s_axi_bvalid;
     // Slave Interface Read Address Ports
    wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_arid;
    wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr;
    wire [7:0]                        s_axi_arlen;
    wire [2:0]                        s_axi_arsize;
    wire [1:0]                        s_axi_arburst;
    wire [0:0]                        s_axi_arlock;
    wire [3:0]                        s_axi_arcache;
    wire [2:0]                        s_axi_arprot;
    wire                              s_axi_arvalid;
    wire                              s_axi_arready;
     // Slave Interface Read Data Ports
    wire                              s_axi_rready;
    wire [C_S_AXI_ID_WIDTH-1:0]       s_axi_rid;
    wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata;
    wire [1:0]                        s_axi_rresp;
    wire                              s_axi_rlast;
    wire                              s_axi_rvalid;
`endif
/****************************************************
boot ram/rom, connected to soc's internal sram controller
mapped to 0x60000000 of salyut1 soc
*****************************************************/
    wire                            ocram_req;
    wire                            ocram_we;
    wire [30-1:0]                   ocram_addr;
    wire [7:0]                      ocram_be;
    wire [64-1:0]                   ocram_data_o;
    wire [64-1:0]                   ocram_data_i;
initial begin
    clk50 = 0;
    clk25 = 0;
    rst = 1;
    $display("INFO: start simulation");
#40 
    rst = 0;
end

always begin
#5 clk100 = ~clk100;//100MHz clock for simulate external memory 
end

always begin
#10 clk50 = ~clk50; //50MHz clock for simulate soc clock
end

always begin
#20 clk25=~clk25;   //25MHz clock for VGA and low-speed io use
end
/*          dut start          */
salyut1_soc_top#(
    .INIT_CHAR_ROM_FILE_NAME (),
    .INIT_FRAME_CHAR_FILE_NAME (),
    .INIT_FRAME_COLOR_FILE_NAME(),
    .INIT_FRAME_BLINK_FILE_NAME()
)dut(
    .main_clk               (clk50),        //cpu running clock and axi-lite system clock input
    .clk25m                 (clk25),          //25MHz clock for vga system and debug system
    .main_rst               (rst),        //sync reset input(sync to main clk)
    .pherp_clk              (clk25),       //clock for low speed device use (25MHz-50MHz suggested)
    .cpu_rst                (0),
    //-----------------core jtag interface-----------------
    .cpu_jtag_rstn          (1),
    .cpu_jtag_tms           (0),
    .cpu_jtag_tck           (0),
    .cpu_jtag_tdi           (0),
    .cpu_jtag_tdo           (),
    //-------------main memory access interface(AXI)-----------------
    `ifdef EXT_MEMORY
        .mst_clk                (clk100),
        .mst_rst                (rst),
        .mst_awvalid            (s_axi_awvalid),
        .mst_awready            (s_axi_awready),
        .mst_awaddr             (s_axi_awaddr),         //total 1G dram
        .mst_awlen              (s_axi_awlen),
        .mst_awsize             (s_axi_awsize),
        .mst_awburst            (s_axi_awburst),
        .mst_awlock             (s_axi_awlock),
        .mst_awcache            (s_axi_awcache),
        .mst_awprot             (s_axi_awprot),
        .mst_awqos              (),
        .mst_awregion           (),
        .mst_awid               (s_axi_awid),
        .mst_wvalid             (s_axi_wvalid),
        .mst_wready             (s_axi_wready),
        .mst_wlast              (s_axi_wlast),
        .mst_wdata              (s_axi_wdata),
        .mst_wstrb              (s_axi_wstrb),
        .mst_bvalid             (s_axi_bvalid),
        .mst_bready             (s_axi_bready),
        .mst_bid                (s_axi_bid),
        .mst_bresp              (s_axi_bresp),
        .mst_arvalid            (s_axi_arvalid),
        .mst_arready            (s_axi_arready),
        .mst_araddr             (s_axi_araddr),
        .mst_arlen              (s_axi_arlen),
        .mst_arsize             (s_axi_arsize),
        .mst_arburst            (s_axi_arburst),
        .mst_arlock             (s_axi_arlock),
        .mst_arcache            (s_axi_arcache),
        .mst_arprot             (s_axi_arprot),
        .mst_arqos              (),
        .mst_arregion           (),
        .mst_arid               (s_axi_arid),
        .mst_rvalid             (s_axi_rvalid),
        .mst_rready             (s_axi_rready),
        .mst_rid                (s_axi_rid),
        .mst_rresp              (s_axi_rresp),
        .mst_rdata              (s_axi_rdata),
        .mst_rlast              (s_axi_rlast),
    `endif
    //---------------sram----------------------
    .ocram_req                  (ocram_req),
    .ocram_we                   (ocram_we),
    .ocram_addr                 (ocram_addr),
    .ocram_be                   (ocram_be),
    .ocram_data_o               (ocram_data_o),
    .ocram_data_i               (ocram_data_i),
    //---------------VGA display---------------
    .vga_clk_o                      (),
	.vga_b_o                        (),
	.vga_g_o                        (),
	.vga_hs_o                       (),
	.vga_r_o                        (),
	.vga_vs_o                       (),
    //-------------UART0------------------
    // UART	signals
    .uart0_srx_pad_i                (1'b1),
    .uart0_stx_pad_o                (),
    .uart0_rts_pad_o                (),
    .uart0_cts_pad_i                (0),
    .uart0_dtr_pad_o                (),
    .uart0_dsr_pad_i                (0),
    .uart0_ri_pad_i                 (0),
    .uart0_dcd_pad_i                (0)
);
/*         dut end           */
/*        memorys                  */
ram_sim#(
        .NEED_INIT      (1),             //0: no init file ,1:init with INIT_FILE
        .INIT_FILE      (`INIT_FILE),
        .DATA_WIDTH     (64),
        .DATA_DEPTH     ((1<<OCRAM_ADDR_WIDTH)/8)
    )ocram(
        .clk            (clk50),
        .addr           (ocram_addr[OCRAM_ADDR_WIDTH-1:3]),
        .ce             (ocram_req),
        .we             (ocram_we),
        .datar          (ocram_data_o),
        .dataw          (ocram_data_i),
        .be             (ocram_be)
    );

`ifdef EXT_MEMORY
axi_ram #
(
    // Width of data bus in bits
    .DATA_WIDTH         (C_S_AXI_DATA_WIDTH),
    // Width of address bus in bits
    .ADDR_WIDTH         (C_S_AXI_ADDR_WIDTH),
    // Width of ID signal
    .ID_WIDTH           (C_S_AXI_ID_WIDTH),
    // Extra pipeline register on output
    .PIPELINE_OUTPUT    (0)
)axi_ram_sim(
    .clk                (clk100),
    .rst                (rst),

    .s_axi_awid         (s_axi_awid),
    .s_axi_awaddr       (s_axi_awaddr),
    .s_axi_awlen        (s_axi_awlen),
    .s_axi_awsize       (s_axi_awsize),
    .s_axi_awburst      (s_axi_awburst),
    .s_axi_awlock       (s_axi_awlock),
    .s_axi_awcache      (s_axi_awcache),
    .s_axi_awprot       (s_axi_awprot),
    .s_axi_awvalid      (s_axi_awvalid),
    .s_axi_awready      (s_axi_awready),
    .s_axi_wdata        (s_axi_wdata),
    .s_axi_wstrb        (s_axi_wstrb),
    .s_axi_wlast        (s_axi_wlast),
    .s_axi_wvalid       (s_axi_wvalid),
    .s_axi_wready       (s_axi_wready),
    .s_axi_bid          (s_axi_bid),
    .s_axi_bresp        (s_axi_bresp),
    .s_axi_bvalid       (s_axi_bvalid),
    .s_axi_bready       (s_axi_bready),
    .s_axi_arid         (s_axi_arid),
    .s_axi_araddr       (s_axi_araddr),
    .s_axi_arlen        (s_axi_arlen),
    .s_axi_arsize       (s_axi_arsize),
    .s_axi_arburst      (s_axi_arburst),
    .s_axi_arlock       (s_axi_arlock),
    .s_axi_arcache      (s_axi_arcache),
    .s_axi_arprot       (s_axi_arprot),
    .s_axi_arvalid      (s_axi_arvalid),
    .s_axi_arready      (s_axi_arready),
    .s_axi_rid          (s_axi_rid),
    .s_axi_rdata        (s_axi_rdata),
    .s_axi_rresp        (s_axi_rresp),
    .s_axi_rlast        (s_axi_rlast),
    .s_axi_rvalid       (s_axi_rvalid),
    .s_axi_rready       (s_axi_rready)
);
`endif
endmodule