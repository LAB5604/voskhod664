`include "salyut1_soc_config.svh"
`timescale 1ns/1ps
/******************************************************************************************

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

    This is a demo SoC for prv664 cpu
    
Address space:
    Total 32bit address width
    0x6000_0000~0x7fff_ffff : ocram&rom(reset to 0x6000_0000)
    0x8000_0000~0xffff_ffff : external ram axi interface connect to memory deivce
    0x0000_0000~0x2fff_ffff : 32bit axi-lite io space
    0x3000_0000~0x5fff_ffff : 64bit axi-lite io_space

Brief sch:
 ------------   -------------------    ----------------
|    CPU     | |uart debugger(opt)|   | CRTC(optional) |
-------------   ------------------     ---------------
      |2*axi        |1*axi                   | 1*axi(read only)   
-------------------------------------------------------
|                     4x4 axi xbar                    |
-------------------------------------------------------
    | axi         |            |                 |
-------------------------------------------
| axil32 cluter| axilite  | ocram | dram  |
-------------------------------------------

                    **NOTE**
1. 在一生一芯验证环境中使用SoC时候，修改cpu的config文件使cpu复位至80000000
2. 

******************************************************************************************/
module salyut1_soc_top#(
    parameter // vga crtc bios initial file
              INIT_CHAR_ROM_FILE_NAME   = "font.txt",
              INIT_FRAME_CHAR_FILE_NAME ="",
              INIT_FRAME_COLOR_FILE_NAME="",
              INIT_FRAME_BLINK_FILE_NAME=""
)(
    input wire                      main_clk,        //cpu running clock and axi-lite system clock input
    input wire                      clk25m,          //25MHz clock for vga system and debug system
    input wire                      main_rst,        //sync reset input(sync to main clk)
    input wire                      pherp_clk,       //clock for low speed device use (25MHz-50MHz suggested)
    input wire                      cpu_rst,         //only reset cpu core
    //-----------------core jtag interface-----------------
    input wire                      cpu_jtag_rstn,
    input wire                      cpu_jtag_tms,
    input wire                      cpu_jtag_tck,
    input wire                      cpu_jtag_tdi,
    output wire                     cpu_jtag_tdo,
    `ifdef DEBUG_UART
        input wire                  debug_uart_rx,
        output wire                 debug_uart_tx,
    `endif
    //-------------main memory access interface(AXI)-----------------
    `ifdef EXT_MEMORY
    //clock speed is synced with mst clk
        input                       mst_clk,
        input                       mst_rst,
        output                      mst_awvalid,
        input                       mst_awready,
        output [30              :0] mst_awaddr,         //total 2G dram
        output [8             -1:0] mst_awlen,
        output [3             -1:0] mst_awsize,
        output [2             -1:0] mst_awburst,
        output [2             -1:0] mst_awlock,
        output [4             -1:0] mst_awcache,
        output [3             -1:0] mst_awprot,
        output [4             -1:0] mst_awqos,
        output [4             -1:0] mst_awregion,
        output [`AXI_ID_WIDTH-1:0]  mst_awid,
        output                      mst_wvalid,
        input                       mst_wready,
        output                      mst_wlast,
        output [63:0]               mst_wdata,
        output [7:0]                mst_wstrb,
        input                       mst_bvalid,
        output                      mst_bready,
        input   [`AXI_ID_WIDTH-1:0] mst_bid,
        input   [2            -1:0] mst_bresp,
        output                      mst_arvalid,
        input                       mst_arready,
        output [30:0]               mst_araddr,
        output [8             -1:0] mst_arlen,
        output [3             -1:0] mst_arsize,
        output [2             -1:0] mst_arburst,
        output [2             -1:0] mst_arlock,
        output [4             -1:0] mst_arcache,
        output [3             -1:0] mst_arprot,
        output [4             -1:0] mst_arqos,
        output [4             -1:0] mst_arregion,
        output [`AXI_ID_WIDTH-1:0]  mst_arid,
        input                       mst_rvalid,
        output                      mst_rready,
        input   [`AXI_ID_WIDTH-1:0] mst_rid,
        input   [2            -1:0] mst_rresp,
        input   [64    -1:0]        mst_rdata,
        input                       mst_rlast,
    `endif
    //连接到外置的sram，系统启动时从此sram读取程序启动
    //系统集成时需要将外置的sram进行初始化
    output wire                     ocram_req,
    output wire                     ocram_we,
    output wire [30-1:0]            ocram_addr,
    output wire [7:0]               ocram_be,
    input wire [64-1:0]             ocram_data_o,
    output wire [64-1:0]            ocram_data_i,
    //---------------VGA display---------------
    output                          vga_clk_o,
	output		     [7:0]		    vga_b_o,
	output		     [7:0]		    vga_g_o,
	output		          		    vga_hs_o,
	output		     [7:0]		    vga_r_o,
	output		          		    vga_vs_o,
    //------------GPIOs---------------------
    output wire [64-1:0]            gpio_dir,
    output wire [64-1:0]            gpio_out,
    input wire  [64-1:0]            gpio_in,
    //-------------UART0------------------
    // UART	signals
    input 			        	    uart0_srx_pad_i,
    output 			        	    uart0_stx_pad_o,
    output 			        	    uart0_rts_pad_o,
    input 			        	    uart0_cts_pad_i,
    output 			        	    uart0_dtr_pad_o,
    input 			        	    uart0_dsr_pad_i,
    input 			        	    uart0_ri_pad_i,
    input 			        	    uart0_dcd_pad_i
);
    localparam EXT_AXI_ADDR_START = 32'h8000_0000,
               EXT_AXI_ADDR_END   = 32'hffff_ffff,
               OCRAM_ADDR_START   = 32'h6000_0000,
               OCRAM_ADDR_END     = 32'h7fff_ffff,
               AXIL32_ADDR_START  = 32'h0000_0000,
               AXIL32_ADDR_END    = 32'h2fff_ffff,
               AXIL64_ADDR_START  = 32'h3000_0000,
               AXIL64_ADDR_END    = 32'h5fff_ffff;

//--------------------soc reset control---------------------------
    wire                        pherp_domain_rst;
    wire                        mainclk_domain_rst;
    wire                        cpu_domain_rst;
//--------------------cpu clint interface--------------------------
    clint_interface             clint_if(); 
    wire [64-1:0]               crtc_base_addr;
    wire                        crtc_cfg_en;
//--------------------cpu axi interface----------------------------
    //axi_aw                    cpu_ibus_axi_aw();
    axi_ar                      cpu_ibus_axi_ar();
    //axi_w                     cpu_ibus_axi_w();
    //axi_b                     cpu_ibus_axi_b();
    axi_r                       cpu_ibus_axi_r();
    wire [`AXI_ID_WIDTH-1:0]    cpu_ibus_axi_rid;
    axi_aw                      cpu_dbus_axi_aw();  
    axi_ar                      cpu_dbus_axi_ar(); 
    axi_w                       cpu_dbus_axi_w();
    axi_b                       cpu_dbus_axi_b();
    wire [`AXI_ID_WIDTH-1:0]    cpu_dbus_axi_bid;
    axi_r                       cpu_dbus_axi_r();
    wire [`AXI_ID_WIDTH-1:0]    cpu_dbus_axi_rid;       //NOTE: sys_axi_* is system interface name, axi_* is core interface name
//--------------------vga ctrl axi interface-----------------
    sys_axi_ar                  vga_axi_ar();
    sys_axi_r                   vga_axi_r();
//--------------------debug axi interface--------------------
    sys_axi_aw      debug_axi_aw();
    sys_axi_ar      debug_axi_ar();
    sys_axi_w       debug_axi_w();
    sys_axi_b       debug_axi_b();
    sys_axi_r       debug_axi_r();
//--------------------ocram axi interface--------------------
    sys_axi_aw      ocram_axi_aw();
    sys_axi_ar      ocram_axi_ar();
    sys_axi_w       ocram_axi_w();
    sys_axi_b       ocram_axi_b();
    sys_axi_r       ocram_axi_r();
//--------------------External mamory--------------------------
`ifndef EXT_MEMORY
    assign mst_arready = 1'b0;
    assign mst_awready = 1'b0;
    assign mst_wready = 1'b0;
    assign mst_rvalid = 1'b0;
    assign mst_bvalid = 1'b0;
`endif
//--------------------axil cluster signal----------------------
    sys_axi_aw      axilcluster0_axi_aw();
    sys_axi_ar      axilcluster0_axi_ar();
    sys_axi_w       axilcluster0_axi_w();
    sys_axi_b       axilcluster0_axi_b();
    sys_axi_r       axilcluster0_axi_r();
    wire [7:0]      axilcluster0_axil_awaddr;
    wire [2:0]      axilcluster0_axil_awprot;
    wire            axilcluster0_axil_awvalid;
    wire            axilcluster0_axil_awready;
    wire [63:0]     axilcluster0_axil_wdata;
    wire [7:0]      axilcluster0_axil_wstrb;
    wire            axilcluster0_axil_wvalid;
    wire            axilcluster0_axil_wready;
    wire [1:0]      axilcluster0_axil_bresp;
    wire            axilcluster0_axil_bvalid;
    wire            axilcluster0_axil_bready;
    wire [7:0]      axilcluster0_axil_araddr;
    wire [2:0]      axilcluster0_axil_arprot;
    wire            axilcluster0_axil_arvalid;
    wire            axilcluster0_axil_arready;
    wire [63:0]     axilcluster0_axil_rdata;
    wire [1:0]      axilcluster0_axil_rresp;
    wire            axilcluster0_axil_rvalid;
    wire            axilcluster0_axil_rready;
//--------------------axil32 cluster signal----------------------
    sys_axi_aw      axil32cluster0_axi_aw();
    sys_axi_ar      axil32cluster0_axi_ar();
    sys_axi_w       axil32cluster0_axi_w();
    sys_axi_b       axil32cluster0_axi_b();
    sys_axi_r       axil32cluster0_axi_r();
    wire [29:0]     axil32cluster0_axil_awaddr;
    wire [2:0]      axil32cluster0_axil_awprot;
    wire            axil32cluster0_axil_awvalid;
    wire            axil32cluster0_axil_awready;
    wire [31:0]     axil32cluster0_axil_wdata;
    wire [7:0]      axil32cluster0_axil_wstrb;
    wire            axil32cluster0_axil_wvalid;
    wire            axil32cluster0_axil_wready;
    wire [1:0]      axil32cluster0_axil_bresp;
    wire            axil32cluster0_axil_bvalid;
    wire            axil32cluster0_axil_bready;
    wire [29:0]     axil32cluster0_axil_araddr;
    wire [2:0]      axil32cluster0_axil_arprot;
    wire            axil32cluster0_axil_arvalid;
    wire            axil32cluster0_axil_arready;
    wire [31:0]     axil32cluster0_axil_rdata;
    wire [1:0]      axil32cluster0_axil_rresp;
    wire            axil32cluster0_axil_rvalid;
    wire            axil32cluster0_axil_rready;

/************************************************************

            reset control unit

*************************************************************/
salyut1_reset           salyut1_reset_con(
    .clk_main               (main_clk),
    .clk_cpu                (main_clk),
    .clk_pherp              (pherp_clk),
    .full_rst               (main_rst),        //reset all 
    .cpu_rst                (cpu_rst),         //reset cpu only (for load program)

    .mainclk_domain_rst     (mainclk_domain_rst),
    .cpu_domain_rst         (cpu_domain_rst),
    .pherp_domain_rst       (pherp_domain_rst)
);
/************************************************************

            PRV664 CPU core (use 2 bus master)

*************************************************************/
prv664_top#(
    .INIT_FILE                  ()
)prv664_core(
    .clk_i                      (main_clk),
    .arst_i                     (cpu_domain_rst),
    .clint_sif                  (clint_if),
    //-----------------core jtag interface-----------------
    .cpu_jtag_rstn              (cpu_jtag_rstn),
    .cpu_jtag_tms               (cpu_jtag_tms),
    .cpu_jtag_tck               (cpu_jtag_tck),
    .cpu_jtag_tdi               (cpu_jtag_tdi),
    .cpu_jtag_tdo               (cpu_jtag_tdo),
    //------------------axi--------------------------------
    .cpu_dbus_axi_ar            (cpu_dbus_axi_ar),
    .cpu_dbus_axi_r             (cpu_dbus_axi_r),
    .cpu_dbus_axi_aw            (cpu_dbus_axi_aw),
    .cpu_dbus_axi_w             (cpu_dbus_axi_w),
    .cpu_dbus_axi_b             (cpu_dbus_axi_b),
    .cpu_ibus_axi_ar            (cpu_ibus_axi_ar),
    .cpu_ibus_axi_r             (cpu_ibus_axi_r)
);
/*************************************************************
                    CPU core end
*************************************************************/
/*************************************************************
                    VGA display
                    VGA display use 1master port of crossbar
*************************************************************/
`ifdef TXT_CRTC
axi_vga_top#(
    .REFERSH_DELAY          (8333333),   //两次刷新的间隔，50MHz sys时钟下 60Hz刷新间隔为833333
    .AXI_ADDR_W             (32),  
    .AXI_DATA_W             (64),  //can only config to 64 or 32
    .AXI_ID_W               (12),
    .INIT_FRAME_ENABLE          (0),                                //enable frame initial with CHAR,COLOR,BLANKING file
	.INIT_FRAME_CHAR_FILE_NAME  (INIT_FRAME_CHAR_FILE_NAME),      //this file is for frame init, can be nothing
    .INIT_FRAME_COLOR_FILE_NAME (INIT_FRAME_COLOR_FILE_NAME),     //this file is for frame init, can be nothing
	.INIT_FRAME_BLINK_FILE_NAME (INIT_FRAME_BLINK_FILE_NAME),		//this file is for frame init, can be nothing
    .INIT_CHAR_ROM_FILE_NAME    (INIT_CHAR_ROM_FILE_NAME)               //this rom is for char's shape, must have it!   
)vga_ctrl(
    .clk_i                  (main_clk),
    .clk25_i                (clk25m),
    .rst_i                  (mainclk_domain_rst),
    //----------------axi master interface--------------
    .m_axi_arvalid          (vga_axi_ar.arvalid),
    .m_axi_arready          (vga_axi_ar.arready),
    .m_axi_araddr           (vga_axi_ar.araddr),
    .m_axi_arlen            (vga_axi_ar.arlen),
    .m_axi_arsize           (vga_axi_ar.arsize),
    .m_axi_arburst          (vga_axi_ar.arburst),
    .m_axi_arid             (vga_axi_ar.arid),
    .m_axi_rvalid           (vga_axi_r.rvalid),
    .m_axi_rready           (vga_axi_r.rready),
    .m_axi_rid              ({4'b0,vga_axi_r.rid[7:0]}),
    .m_axi_rresp            (vga_axi_r.rresp),
    .m_axi_rdata            (vga_axi_r.rdata),
    .m_axi_rlast            (vga_axi_r.rlast),
    //-------------axi lite slave interface-------------------
    .cfg_baseaddr           (crtc_base_addr),
    .cfg_en                 (crtc_cfg_en),
    //--------------vga display interface------------
    .vga_b_o                (vga_b_o),
	.vga_g_o                (vga_g_o),
	.vga_hs_o               (vga_hs_o),
	.vga_r_o                (vga_r_o),
	.vga_vs_o               (vga_vs_o)
);
`else //no use of this bus
    assign vga_axi_ar.arvalid = 1'b0;
    assign vga_axi_r.rready = 1'b0;
`endif
/*************************************************************
                    VGA display end
*************************************************************/
/************************************************************
                    SoC debug port
*************************************************************/
`ifdef DEBUG_UART
uart2axi4 #(
    // clock frequency
    .CLK_FREQ       (25000000),     // clk frequency, Unit : Hz
    // UART format
    .BAUD_RATE      (115200),       // Unit : Hz
    .PARITY         ("NONE"),       // "NONE", "ODD", or "EVEN"
    // AXI4 config
    .BYTE_WIDTH     (8),            // data width (bytes)
    .A_WIDTH        (32)            // address width (bits)
) (
    .rstn           (!mainclk_domain_rst),
    .clk            (clk25m),
    // AXI4 master ----------------------
    .awready        (debug_axi_aw.awready),  // AW
    .awvalid        (debug_axi_aw.awvalid),
    .awaddr         (debug_axi_aw.awaddr),
    .awlen          (debug_axi_aw.awlen),
    .wready         (debug_axi_w.wready),   // W
    .wvalid         (debug_axi_w.wvalid),
    .wlast          (debug_axi_w.wlast),
    .wdata          (debug_axi_w.wdata),
    .bready         (debug_axi_b.bready),   // B
    .bvalid         (debug_axi_b.bvalid),
    .arready        (debug_axi_ar.arready),  // AR
    .arvalid        (debug_axi_ar.arvalid),
    .araddr         (debug_axi_ar.araddr),
    .arlen          (debug_axi_ar.arlen),
    .rready         (debug_axi_r.rready),   // R
    .rvalid         (debug_axi_r.rvalid),
    .rlast          (debug_axi_r.rlast),
    .rdata          (debug_axi_r.rdata),
    // UART ----------------------
    .i_uart_rx      (debug_uart_rx),
    .o_uart_tx      (debug_uart_tx)
);
`else
    assign debug_axi_aw.awvalid = 1'b0;
    assign debug_axi_w.wvalid   = 1'b0;
    assign debug_axi_b.bready   = 1'b0;
    assign debug_axi_ar.arvalid = 1'b0;
    assign debug_axi_r.rready   = 1'b0;
`endif
/*************************************************************
                    AXI crossbar 
*************************************************************/
axicb_crossbar_top#(
        ///////////////////////////////////////////////////////////////////////
        // Global configuration
        ///////////////////////////////////////////////////////////////////////

        // Address width in bits
        .AXI_ADDR_W         (`AXI_ADDR_WIDTH),
        // ID width in bits
        .AXI_ID_W           (`AXI_ID_WIDTH),   //CPU need 8bit id width, 4bit for bridge tag, total 12bit
        // Data width in bits
        .AXI_DATA_W         (`AXI_DATA_WIDTH),   //DO NOT TOUCH IT!

        // Number of master(s)
        //parameter MST_NB = 4,           use default config
        // Number of slave(s) 
        //parameter SLV_NB = 4,           use default config

        // Switching logic pipelining (0 deactivate, 1 enable)
        //parameter MST_PIPELINE = 0,     use default config
        //parameter SLV_PIPELINE = 0,     use default config

        // STRB support:
        //   - 0: contiguous wstrb (store only 1st/last dataphase)
        //   - 1: full wstrb transport
        //STRB_MODE = 1,                  use default config

        // AXI Signals Supported:
        //   - 0: AXI4-lite
        //   - 1: AXI
        .AXI_SIGNALING      (1),

        // USER fields transport enabling (0 deactivate, 1 activate)
        //parameter USER_SUPPORT = 0,     use default config
        // USER fields width in bits
        //AXI_AUSER_W = 1,
        //AXI_WUSER_W = 1,
        //AXI_BUSER_W = 1,
        //AXI_RUSER_W = 1,

        // Timeout configuration in clock cycles, applied to all channels
        //parameter TIMEOUT_VALUE = 10000,
        // Activate the timer to avoid deadlock
        //parameter TIMEOUT_ENABLE = 1,


        ///////////////////////////////////////////////////////////////////////
        //
        // Master agent configurations:
        //
        //   - MSTx_CDC: implement input CDC stage, 0 or 1
        //
        //   - MSTx_OSTDREQ_NUM: maximum number of requests a master can
        //                       store internally
        //
        //   - MSTx_OSTDREQ_SIZE: size of an outstanding request in dataphase
        //
        //   - MSTx_PRIORITY: priority applied to this master in the arbitrers,
        //                    from 0 to 3 included
        //   - MSTx_ROUTES: routing from the master to the slaves allowed in
        //                  the switching logic. Bit 0 for slave 0, bit 1 for
        //                  slave 1, ...
        //
        //   - MSTx_ID_MASK : A mask applied in slave completion channel to
        //                    determine which master to route back the
        //                    BRESP/RRESP completions.
        //
        //   - MSTx_RW: Slect if the interface is 
        //         - Read/Write (=0)
        //         - Read-only (=1) 
        //         - Write-only (=2)
        //
        // The size of a master's internal buffer is equal to:
        //
        // SIZE = AXI_DATA_W * MSTx_OSTDREQ_NUM * MSTx_OSTDREQ_SIZE (in bits)
        //
        ///////////////////////////////////////////////////////////////////////


        ///////////////////////////////////////////////////////////////////////
        // Master 0 configuration
        ///////////////////////////////////////////////////////////////////////

        //parameter MST0_CDC = 0,
        //parameter MST0_OSTDREQ_NUM = 4,
        //parameter MST0_OSTDREQ_SIZE = 1,
        //parameter MST0_PRIORITY = 0,
        //parameter [SLV_NB-1:0] MST0_ROUTES = 4'b1_1_1_1,
        .MST0_ID_MASK   ('h100),
        //parameter MST0_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 1 configuration
        ///////////////////////////////////////////////////////////////////////

        .MST1_CDC       (0),        
        //parameter MST1_OSTDREQ_NUM = 4,
        //parameter MST1_OSTDREQ_SIZE = 1,
        //parameter MST1_PRIORITY = 0,
        //parameter [SLV_NB-1:0] MST1_ROUTES = 4'b1_1_1_1,
        .MST1_ID_MASK   ('h200),
        //parameter MST1_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 2 configuration
        ///////////////////////////////////////////////////////////////////////

        .MST2_CDC       (0),        
        //parameter MST2_OSTDREQ_NUM = 4,
        //parameter MST2_OSTDREQ_SIZE = 1,
        //parameter MST2_PRIORITY = 0,
        //parameter [SLV_NB-1:0] MST2_ROUTES = 4'b1_1_1_1,
        .MST2_ID_MASK   ('h400),
        //parameter MST2_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 3 configuration
        ///////////////////////////////////////////////////////////////////////

        //parameter MST3_CDC = 0,
        //parameter MST3_OSTDREQ_NUM = 4,
        //parameter MST3_OSTDREQ_SIZE = 1,
        //parameter MST3_PRIORITY = 0,
        //parameter [SLV_NB-1:0] MST3_ROUTES = 4'b1_1_1_1,
        .MST3_ID_MASK   ('h800),
        //parameter MST3_RW = 0,


        ///////////////////////////////////////////////////////////////////////
        //
        // Slave agent configurations:
        //
        //   - SLVx_CDC: implement input CDC stage, 0 or 1
        //
        //   - SLVx_OSTDREQ_NUM: maximum number of requests slave can
        //                       store internally
        //
        //   - SLVx_OSTDREQ_SIZE: size of an outstanding request in dataphase
        //
        //   - SLVx_START_ADDR: Start address allocated to the slave, in byte
        //
        //   - SLVx_END_ADDR: End address allocated to the slave, in byte
        //
        //   - SLVx_KEEP_BASE_ADDR: Keep the absolute address of the slave in
        //     the memory map. Default to 0.
        //
        // The size of a slave's internal buffer is equal to:
        //
        //   AXI_DATA_W * SLVx_OSTDREQ_NUM * SLVx_OSTDREQ_SIZE (in bits)
        //
        // A request is routed to a slave if:
        //
        //   START_ADDR <= ADDR <= END_ADDR
        //
        ///////////////////////////////////////////////////////////////////////


        ///////////////////////////////////////////////////////////////////////
        // Slave 0 configuration
        ///////////////////////////////////////////////////////////////////////

        .SLV0_CDC           (0),
        .SLV0_START_ADDR    (OCRAM_ADDR_START),    
        .SLV0_END_ADDR      (OCRAM_ADDR_END),
        //parameter SLV0_OSTDREQ_NUM = 4,
        //parameter SLV0_OSTDREQ_SIZE = 1,
        //parameter SLV0_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 1 configuration
        ///////////////////////////////////////////////////////////////////////

        .SLV1_CDC           (1),
        .SLV1_START_ADDR    (EXT_AXI_ADDR_START),//slave1 connect to external memory controller, need CDC
        .SLV1_END_ADDR      (EXT_AXI_ADDR_END),
        //parameter SLV1_OSTDREQ_NUM = 4,
        //parameter SLV1_OSTDREQ_SIZE = 1,
        //parameter SLV1_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 2 configuration
        ///////////////////////////////////////////////////////////////////////

        .SLV2_CDC           (1),        //axil32 connect to low-speed pherp
        .SLV2_START_ADDR    (AXIL32_ADDR_START),
        .SLV2_END_ADDR      (AXIL32_ADDR_END),
        //parameter SLV2_OSTDREQ_NUM = 4,
        //parameter SLV2_OSTDREQ_SIZE = 1,
        //parameter SLV2_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 3 configuration
        ///////////////////////////////////////////////////////////////////////

        //parameter SLV3_CDC = 0,
        .SLV3_START_ADDR    (AXIL64_ADDR_START),
        .SLV3_END_ADDR      (AXIL64_ADDR_END)
        //parameter SLV3_OSTDREQ_NUM = 4,
        //parameter SLV3_OSTDREQ_SIZE = 1,
        //parameter SLV3_KEEP_BASE_ADDR = 0
)main_xbar(
        ///////////////////////////////////////////////////////////////////////
        // Interconnect global interface
        ///////////////////////////////////////////////////////////////////////

        .aclk                   (main_clk),
        .aresetn                (!mainclk_domain_rst),
        .srst                   (mainclk_domain_rst),

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 0 interface
        ///////////////////////////////////////////////////////////////////////

        .slv0_aclk              (main_clk),
        .slv0_aresetn           (!mainclk_domain_rst),
        .slv0_srst              (mainclk_domain_rst),
        .slv0_awvalid           (cpu_dbus_axi_aw.awvalid),
        .slv0_awready           (cpu_dbus_axi_aw.awready),
        .slv0_awaddr            (cpu_dbus_axi_aw.awaddr),
        .slv0_awlen             (cpu_dbus_axi_aw.awlen),
        .slv0_awsize            (cpu_dbus_axi_aw.awsize),
        .slv0_awburst           (cpu_dbus_axi_aw.awburst),
        .slv0_awlock            (cpu_dbus_axi_aw.awlock),
        .slv0_awcache           (cpu_dbus_axi_aw.awcache),
        .slv0_awprot            (cpu_dbus_axi_aw.awprot),
        .slv0_awqos             (cpu_dbus_axi_aw.awqos),
        .slv0_awregion          (cpu_dbus_axi_aw.awregion),
        .slv0_awid              ({4'h1,cpu_dbus_axi_aw.awid}), //TODO: 因为桥不能自动打tag，因此在这里需要手动打tag
        .slv0_awuser            (0),
        .slv0_wvalid            (cpu_dbus_axi_w.wvalid),
        .slv0_wready            (cpu_dbus_axi_w.wready),
        .slv0_wlast             (cpu_dbus_axi_w.wlast),
        .slv0_wdata             (cpu_dbus_axi_w.wdata),
        .slv0_wstrb             (cpu_dbus_axi_w.wstrb),
        .slv0_wuser             (0),
        .slv0_bvalid            (cpu_dbus_axi_b.bvalid),
        .slv0_bready            (cpu_dbus_axi_b.bready),
        .slv0_bid               (cpu_dbus_axi_bid),
        .slv0_bresp             (cpu_dbus_axi_b.bresp),
        .slv0_buser             (),
        .slv0_arvalid           (cpu_dbus_axi_ar.arvalid),
        .slv0_arready           (cpu_dbus_axi_ar.arready),
        .slv0_araddr            (cpu_dbus_axi_ar.araddr),
        .slv0_arlen             (cpu_dbus_axi_ar.arlen),
        .slv0_arsize            (cpu_dbus_axi_ar.arsize),
        .slv0_arburst           (cpu_dbus_axi_ar.arburst),
        .slv0_arlock            (cpu_dbus_axi_ar.arlock),
        .slv0_arcache           (cpu_dbus_axi_ar.arcache),
        .slv0_arprot            (cpu_dbus_axi_ar.arprot),
        .slv0_arqos             (cpu_dbus_axi_ar.arqos),
        .slv0_arregion          (cpu_dbus_axi_ar.arregion),
        .slv0_arid              ({4'h1,cpu_dbus_axi_ar.arid}),
        .slv0_aruser            (0),
        .slv0_rvalid            (cpu_dbus_axi_r.rvalid),
        .slv0_rready            (cpu_dbus_axi_r.rready),
        .slv0_rid               (cpu_dbus_axi_rid),
        .slv0_rresp             (cpu_dbus_axi_r.rresp),
        .slv0_rdata             (cpu_dbus_axi_r.rdata),
        .slv0_rlast             (cpu_dbus_axi_r.rlast),
        .slv0_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 1 interface
        ///////////////////////////////////////////////////////////////////////

        .slv1_aclk              (main_clk),
        .slv1_aresetn           (!mainclk_domain_rst),
        .slv1_srst              (mainclk_domain_rst),
        .slv1_awvalid           (0),
        .slv1_awready           (),
        .slv1_awaddr            (0),
        .slv1_awlen             (0),
        .slv1_awsize            (0),
        .slv1_awburst           (0),
        .slv1_awlock            (0),
        .slv1_awcache           (0),
        .slv1_awprot            (0),
        .slv1_awqos             (0),
        .slv1_awregion          (0),
        .slv1_awid              (0),
        .slv1_awuser            (0),
        .slv1_wvalid            (0),
        .slv1_wready            (),
        .slv1_wlast             (0),
        .slv1_wdata             (0),
        .slv1_wstrb             (0),
        .slv1_wuser             (0),
        .slv1_bvalid            (),
        .slv1_bready            (0),
        .slv1_bid               (),
        .slv1_bresp             (),
        .slv1_buser             (),
        .slv1_arvalid           (cpu_ibus_axi_ar.arvalid),
        .slv1_arready           (cpu_ibus_axi_ar.arready),
        .slv1_araddr            (cpu_ibus_axi_ar.araddr),
        .slv1_arlen             (cpu_ibus_axi_ar.arlen),
        .slv1_arsize            (cpu_ibus_axi_ar.arsize),
        .slv1_arburst           (cpu_ibus_axi_ar.arburst),
        .slv1_arlock            (cpu_ibus_axi_ar.arlock),
        .slv1_arcache           (cpu_ibus_axi_ar.arcache),
        .slv1_arprot            (cpu_ibus_axi_ar.arprot),
        .slv1_arqos             (cpu_ibus_axi_ar.arqos),
        .slv1_arregion          (cpu_ibus_axi_ar.arregion),
        .slv1_arid              ({4'h2,cpu_ibus_axi_ar.arid}),
        .slv1_aruser            (0),
        .slv1_rvalid            (cpu_ibus_axi_r.rvalid),
        .slv1_rready            (cpu_ibus_axi_r.rready),
        .slv1_rid               (cpu_ibus_axi_rid),
        .slv1_rresp             (cpu_ibus_axi_r.rresp),
        .slv1_rdata             (cpu_ibus_axi_r.rdata),
        .slv1_rlast             (cpu_ibus_axi_r.rlast),
        .slv1_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 2 interface
        ///////////////////////////////////////////////////////////////////////

        .slv2_aclk              (main_clk),
        .slv2_aresetn           (!mainclk_domain_rst),
        .slv2_srst              (mainclk_domain_rst),
        .slv2_awvalid           (0),
        .slv2_awready           (),
        .slv2_awaddr            (0),
        .slv2_awlen             (0),
        .slv2_awsize            (0),
        .slv2_awburst           (0),
        .slv2_awlock            (0),
        .slv2_awcache           (0),
        .slv2_awprot            (0),
        .slv2_awqos             (0),
        .slv2_awregion          (0),
        .slv2_awid              (0),
        .slv2_awuser            (0),
        .slv2_wvalid            (0),
        .slv2_wready            (),
        .slv2_wlast             (0),
        .slv2_wdata             (0),
        .slv2_wstrb             (0),
        .slv2_wuser             (0),
        .slv2_bvalid            (),
        .slv2_bready            (0),
        .slv2_bid               (),
        .slv2_bresp             (),
        .slv2_buser             (),
        .slv2_arvalid           (vga_axi_ar.arvalid),
        .slv2_arready           (vga_axi_ar.arready),
        .slv2_araddr            (vga_axi_ar.araddr),
        .slv2_arlen             (vga_axi_ar.arlen),
        .slv2_arsize            (vga_axi_ar.arsize),
        .slv2_arburst           (vga_axi_ar.arburst),
        .slv2_arlock            (0),
        .slv2_arcache           (0),
        .slv2_arprot            (0),
        .slv2_arqos             (0),
        .slv2_arregion          (0),
        .slv2_arid              ({4'h4,vga_axi_ar.arid[7:0]}),
        .slv2_aruser            (0),
        .slv2_rvalid            (vga_axi_r.rvalid),
        .slv2_rready            (vga_axi_r.rready),
        .slv2_rid               (vga_axi_r.rid),
        .slv2_rresp             (vga_axi_r.rresp),
        .slv2_rdata             (vga_axi_r.rdata),
        .slv2_rlast             (vga_axi_r.rlast),
        .slv2_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 3 interface
        ///////////////////////////////////////////////////////////////////////

        .slv3_aclk              (main_clk),
        .slv3_aresetn           (!mainclk_domain_rst),
        .slv3_srst              (mainclk_domain_rst),
        .slv3_awvalid           (debug_axi_aw.awvalid),
        .slv3_awready           (debug_axi_aw.awready),
        .slv3_awaddr            (debug_axi_aw.awaddr),
        .slv3_awlen             (debug_axi_aw.awlen),
        .slv3_awsize            (3'b010),   //64bit width
        .slv3_awburst           (2'b01),    //INCR mode
        .slv3_awlock            (0),
        .slv3_awcache           (0),
        .slv3_awprot            (0),
        .slv3_awqos             (0),
        .slv3_awregion          (0),
        .slv3_awid              (0),    //set id = 0
        .slv3_awuser            (0),
        .slv3_wvalid            (debug_axi_w.wvalid),
        .slv3_wready            (debug_axi_w.wready),
        .slv3_wlast             (debug_axi_w.wlast),
        .slv3_wdata             (debug_axi_w.wdata),
        .slv3_wstrb             (debug_axi_w.wstrb),
        .slv3_wuser             (0),
        .slv3_bvalid            (debug_axi_b.bvalid),
        .slv3_bready            (debug_axi_b.bready),
        .slv3_bid               (),
        .slv3_bresp             (),
        .slv3_buser             (),
        .slv3_arvalid           (debug_axi_ar.arvalid),
        .slv3_arready           (debug_axi_ar.arready),
        .slv3_araddr            (debug_axi_ar.araddr),
        .slv3_arlen             (debug_axi_ar.arlen),
        .slv3_arsize            (3'b010),   //size = 64bit
        .slv3_arburst           (2'b01),    //INCR
        .slv3_arlock            (0),
        .slv3_arcache           (0),
        .slv3_arprot            (0),
        .slv3_arqos             (0),
        .slv3_arregion          (0),
        .slv3_arid              (0),
        .slv3_aruser            (0),
        .slv3_rvalid            (debug_axi_r.rvalid),
        .slv3_rready            (debug_axi_r.rready),
        .slv3_rid               (),
        .slv3_rresp             (),
        .slv3_rdata             (debug_axi_r.rdata),
        .slv3_rlast             (debug_axi_r.rlast),
        .slv3_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 0 interface
        ///////////////////////////////////////////////////////////////////////
        .mst0_aclk              (main_clk),
        .mst0_aresetn           (!mainclk_domain_rst),
        .mst0_srst              (mainclk_domain_rst),
        .mst0_awvalid           (ocram_axi_aw.awvalid),
        .mst0_awready           (ocram_axi_aw.awready),
        .mst0_awaddr            (ocram_axi_aw.awaddr),
        .mst0_awlen             (ocram_axi_aw.awlen),
        .mst0_awsize            (ocram_axi_aw.awsize),
        .mst0_awburst           (ocram_axi_aw.awburst),
        .mst0_awlock            (ocram_axi_aw.awlock),
        .mst0_awcache           (ocram_axi_aw.awcache),
        .mst0_awprot            (ocram_axi_aw.awprot),
        .mst0_awqos             (ocram_axi_aw.awqos),
        .mst0_awregion          (ocram_axi_aw.awregion),
        .mst0_awid              (ocram_axi_aw.awid),
        .mst0_awuser            (),                     //NO user signal used
        .mst0_wvalid            (ocram_axi_w.wvalid),
        .mst0_wready            (ocram_axi_w.wready),
        .mst0_wlast             (ocram_axi_w.wlast),
        .mst0_wdata             (ocram_axi_w.wdata),
        .mst0_wstrb             (ocram_axi_w.wstrb),
        .mst0_wuser             (),
        .mst0_bvalid            (ocram_axi_b.bvalid),
        .mst0_bready            (ocram_axi_b.bready),
        .mst0_bid               (ocram_axi_b.bid),
        .mst0_bresp             (ocram_axi_b.bresp),
        .mst0_buser             (),
        .mst0_arvalid           (ocram_axi_ar.arvalid),
        .mst0_arready           (ocram_axi_ar.arready),
        .mst0_araddr            (ocram_axi_ar.araddr),
        .mst0_arlen             (ocram_axi_ar.arlen),
        .mst0_arsize            (ocram_axi_ar.arsize),
        .mst0_arburst           (ocram_axi_ar.arburst),
        .mst0_arlock            (ocram_axi_ar.arlock),
        .mst0_arcache           (ocram_axi_ar.arcache),
        .mst0_arprot            (ocram_axi_ar.arprot),
        .mst0_arqos             (ocram_axi_ar.arqos),
        .mst0_arregion          (ocram_axi_ar.arregion),
        .mst0_arid              (ocram_axi_ar.arid),
        .mst0_aruser            (),
        .mst0_rvalid            (ocram_axi_r.rvalid),
        .mst0_rready            (ocram_axi_r.rready),
        .mst0_rid               (ocram_axi_r.rid),
        .mst0_rresp             (ocram_axi_r.rresp),
        .mst0_rdata             (ocram_axi_r.rdata),
        .mst0_rlast             (ocram_axi_r.rlast),
        .mst0_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 1 interface
        ///////////////////////////////////////////////////////////////////////

        .mst1_aclk              (mst_clk),
        .mst1_aresetn           (!mst_rst),
        .mst1_srst              (mst_rst),
        .mst1_awvalid           (mst_awvalid),
        .mst1_awready           (mst_awready),
        .mst1_awaddr            (mst_awaddr),
        .mst1_awlen             (mst_awlen),
        .mst1_awsize            (mst_awsize),
        .mst1_awburst           (mst_awburst),
        .mst1_awlock            (mst_awlock),
        .mst1_awcache           (mst_awcache),
        .mst1_awprot            (mst_awprot),
        .mst1_awqos             (mst_awqos),
        .mst1_awregion          (mst_awregion),
        .mst1_awid              (mst_awid),
        .mst1_awuser            (),                 //NO user signal to main memory
        .mst1_wvalid            (mst_wvalid),
        .mst1_wready            (mst_wready),
        .mst1_wlast             (mst_wlast),
        .mst1_wdata             (mst_wdata),
        .mst1_wstrb             (mst_wstrb),
        .mst1_wuser             (),
        .mst1_bvalid            (mst_bvalid),
        .mst1_bready            (mst_bready),
        .mst1_bid               (mst_bid),
        .mst1_bresp             (mst_bresp),
        .mst1_buser             (),
        .mst1_arvalid           (mst_arvalid),
        .mst1_arready           (mst_arready),
        .mst1_araddr            (mst_araddr),
        .mst1_arlen             (mst_arlen),
        .mst1_arsize            (mst_arsize),
        .mst1_arburst           (mst_arburst),
        .mst1_arlock            (mst_arlock),
        .mst1_arcache           (mst_arcache),
        .mst1_arprot            (mst_arprot),
        .mst1_arqos             (mst_arqos),
        .mst1_arregion          (mst_arregion),
        .mst1_arid              (mst_arid),
        .mst1_aruser            (),
        .mst1_rvalid            (mst_rvalid),
        .mst1_rready            (mst_rready),
        .mst1_rid               (mst_rid),
        .mst1_rresp             (mst_rresp),
        .mst1_rdata             (mst_rdata),
        .mst1_rlast             (mst_rlast),
        .mst1_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 2 interface
        ///////////////////////////////////////////////////////////////////////

        .mst2_aclk              (pherp_clk),
        .mst2_aresetn           (!pherp_domain_rst),
        .mst2_srst              (pherp_domain_rst),
        .mst2_awvalid           (axil32cluster0_axi_aw.awvalid),
        .mst2_awready           (axil32cluster0_axi_aw.awready),
        .mst2_awaddr            (axil32cluster0_axi_aw.awaddr),
        .mst2_awlen             (axil32cluster0_axi_aw.awlen),
        .mst2_awsize            (axil32cluster0_axi_aw.awsize),
        .mst2_awburst           (axil32cluster0_axi_aw.awburst),
        .mst2_awlock            (axil32cluster0_axi_aw.awlock),
        .mst2_awcache           (axil32cluster0_axi_aw.awcache),
        .mst2_awprot            (axil32cluster0_axi_aw.awprot),
        .mst2_awqos             (axil32cluster0_axi_aw.awqos),
        .mst2_awregion          (axil32cluster0_axi_aw.awregion),
        .mst2_awid              (axil32cluster0_axi_aw.awid),
        .mst2_awuser            (),
        .mst2_wvalid            (axil32cluster0_axi_w.wvalid),
        .mst2_wready            (axil32cluster0_axi_w.wready),
        .mst2_wlast             (axil32cluster0_axi_w.wlast),
        .mst2_wdata             (axil32cluster0_axi_w.wdata),
        .mst2_wstrb             (axil32cluster0_axi_w.wstrb),
        .mst2_wuser             (),
        .mst2_bvalid            (axil32cluster0_axi_b.bvalid),
        .mst2_bready            (axil32cluster0_axi_b.bready),
        .mst2_bid               (axil32cluster0_axi_b.bid),
        .mst2_bresp             (axil32cluster0_axi_b.bresp),
        .mst2_buser             (),
        .mst2_arvalid           (axil32cluster0_axi_ar.arvalid),
        .mst2_arready           (axil32cluster0_axi_ar.arready),
        .mst2_araddr            (axil32cluster0_axi_ar.araddr),
        .mst2_arlen             (axil32cluster0_axi_ar.arlen),
        .mst2_arsize            (axil32cluster0_axi_ar.arsize),
        .mst2_arburst           (axil32cluster0_axi_ar.arburst),
        .mst2_arlock            (axil32cluster0_axi_ar.arlock),
        .mst2_arcache           (axil32cluster0_axi_ar.arcache),
        .mst2_arprot            (axil32cluster0_axi_ar.arprot),
        .mst2_arqos             (axil32cluster0_axi_ar.arqos),
        .mst2_arregion          (axil32cluster0_axi_ar.arregion),
        .mst2_arid              (axil32cluster0_axi_ar.arid),
        .mst2_aruser            (),
        .mst2_rvalid            (axil32cluster0_axi_r.rvalid),
        .mst2_rready            (axil32cluster0_axi_r.rready),
        .mst2_rid               (axil32cluster0_axi_r.rid),
        .mst2_rresp             (axil32cluster0_axi_r.rresp),
        .mst2_rdata             (axil32cluster0_axi_r.rdata),
        .mst2_rlast             (axil32cluster0_axi_r.rlast),
        .mst2_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 3 interface
        ///////////////////////////////////////////////////////////////////////
        .mst3_aclk              (main_clk),
        .mst3_aresetn           (!mainclk_domain_rst),
        .mst3_srst              (mainclk_domain_rst),
        .mst3_awvalid           (axilcluster0_axi_aw.awvalid),
        .mst3_awready           (axilcluster0_axi_aw.awready),
        .mst3_awaddr            (axilcluster0_axi_aw.awaddr),
        .mst3_awlen             (axilcluster0_axi_aw.awlen),
        .mst3_awsize            (axilcluster0_axi_aw.awsize),
        .mst3_awburst           (axilcluster0_axi_aw.awburst),
        .mst3_awlock            (axilcluster0_axi_aw.awlock),
        .mst3_awcache           (axilcluster0_axi_aw.awcache),
        .mst3_awprot            (axilcluster0_axi_aw.awprot),
        .mst3_awqos             (axilcluster0_axi_aw.awqos),
        .mst3_awregion          (axilcluster0_axi_aw.awregion),
        .mst3_awid              (axilcluster0_axi_aw.awid),
        .mst3_awuser            (),
        .mst3_wvalid            (axilcluster0_axi_w.wvalid),
        .mst3_wready            (axilcluster0_axi_w.wready),
        .mst3_wlast             (axilcluster0_axi_w.wlast),
        .mst3_wdata             (axilcluster0_axi_w.wdata),
        .mst3_wstrb             (axilcluster0_axi_w.wstrb),
        .mst3_wuser             (),
        .mst3_bvalid            (axilcluster0_axi_b.bvalid),
        .mst3_bready            (axilcluster0_axi_b.bready),
        .mst3_bid               (axilcluster0_axi_b.bid),
        .mst3_bresp             (axilcluster0_axi_b.bresp),
        .mst3_buser             (),
        .mst3_arvalid           (axilcluster0_axi_ar.arvalid),
        .mst3_arready           (axilcluster0_axi_ar.arready),
        .mst3_araddr            (axilcluster0_axi_ar.araddr),
        .mst3_arlen             (axilcluster0_axi_ar.arlen),
        .mst3_arsize            (axilcluster0_axi_ar.arsize),
        .mst3_arburst           (axilcluster0_axi_ar.arburst),
        .mst3_arlock            (axilcluster0_axi_ar.arlock),
        .mst3_arcache           (axilcluster0_axi_ar.arcache),
        .mst3_arprot            (axilcluster0_axi_ar.arprot),
        .mst3_arqos             (axilcluster0_axi_ar.arqos),
        .mst3_arregion          (axilcluster0_axi_ar.arregion),
        .mst3_arid              (axilcluster0_axi_ar.arid),
        .mst3_aruser            (),
        .mst3_rvalid            (axilcluster0_axi_r.rvalid),
        .mst3_rready            (axilcluster0_axi_r.rready),
        .mst3_rid               (axilcluster0_axi_r.rid),
        .mst3_rresp             (axilcluster0_axi_r.rresp),
        .mst3_rdata             (axilcluster0_axi_r.rdata),
        .mst3_rlast             (axilcluster0_axi_r.rlast),
        .mst3_ruser             ()
);
/*************************************************************
                    AXI crossbar end
*************************************************************/
//           TODO: 此桥不支持自动打tag，因此需要手动剥离高4位tag
assign cpu_dbus_axi_r.rid = cpu_dbus_axi_rid[7:0];
assign cpu_dbus_axi_b.bid = cpu_dbus_axi_bid[7:0];
assign cpu_ibus_axi_r.rid = cpu_ibus_axi_rid[7:0];
/*****************************************************************************

            On chip static memory controller(also use as boot rom)

******************************************************************************/
`ifndef YSYX_DIFFTEST      //如果不是在YSYX状态下，将会使用soc内置的sram控制器
axi2mem #(
    .AXI_ID_WIDTH           (`AXI_ID_WIDTH),    //ID and ADDR width MUST BE set to interface define
    .AXI_ADDR_WIDTH         (`AXI_ADDR_WIDTH),  //
    .AXI_DATA_WIDTH         (64),
    .AXI_USER_WIDTH         (0)
)axi_sram_controller(
    .clk_i                  (main_clk),    // Clock
    .rst_ni                 (!mainclk_domain_rst),  // Asynchronous reset active low
    //--------------- axi4 bus(interface)-----------
    .s_axi_ar               (ocram_axi_ar),
    .s_axi_r                (ocram_axi_r),
    .s_axi_aw               (ocram_axi_aw),
    .s_axi_w                (ocram_axi_w),
    .s_axi_b                (ocram_axi_b),

    .req_o                  (ocram_req),
    .we_o                   (ocram_we),
    .addr_o                 (ocram_addr),
    .be_o                   (ocram_be),
    .user_o                 (),
    .data_o                 (ocram_data_i),
    .user_i                 (0),
    .data_i                 (ocram_data_o)
);

`endif
/*************************************************************************
            OCRAM module end
**************************************************************************/
`ifdef ENABLE_PHERP     //打开外设开关。若打开此开关，部分综合器可能无法综合其中的开源部分
/*************************************************************************

            axi to axi-lite bridge
    1st bridge: axi64 -> axilite64 full clock speed
    2st bridge:axi64 -> axilite32  use prep clock speed

**************************************************************************/
axi_axil_bridge#(
    // Width of address bus in bits
    .ADDR_WIDTH                 (30),
    // Width of input (slave) AXI interface data bus in bits
    .AXI_DATA_WIDTH             (64),
    // Width of input (slave) AXI interface wstrb (width of data bus in words)
    //.AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    .AXI_ID_WIDTH               (`AXI_ID_WIDTH),
    // Width of output (master) AXI lite interface data bus in bits
    .AXIL_DATA_WIDTH            (64)
    // Width of output (master) AXI lite interface wstrb (width of data bus in words)
    //.AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // When adapting to a wider bus, re-pack full-width burst instead of passing through narrow burst if possible
    //.CONVERT_BURST = 1,
    // When adapting to a wider bus, re-pack all bursts instead of passing through narrow burst if possible
    //.CONVERT_NARROW_BURST = 0
)axi_axil_bridge(
    .clk                        (main_clk),
    .rst                        (mainclk_domain_rst),

    /*
     * AXI slave interface
     */
    .s_axi_awid                 (axilcluster0_axi_aw.awid),
    .s_axi_awaddr               (axilcluster0_axi_aw.awaddr),
    .s_axi_awlen                (axilcluster0_axi_aw.awlen),
    .s_axi_awsize               (axilcluster0_axi_aw.awsize),
    .s_axi_awburst              (axilcluster0_axi_aw.awburst),
    .s_axi_awlock               (axilcluster0_axi_aw.awlock),
    .s_axi_awcache              (axilcluster0_axi_aw.awcache),
    .s_axi_awprot               (axilcluster0_axi_aw.awprot),
    .s_axi_awvalid              (axilcluster0_axi_aw.awvalid),
    .s_axi_awready              (axilcluster0_axi_aw.awready),
    .s_axi_wdata                (axilcluster0_axi_w.wdata),
    .s_axi_wstrb                (axilcluster0_axi_w.wstrb),
    .s_axi_wlast                (axilcluster0_axi_w.wlast),
    .s_axi_wvalid               (axilcluster0_axi_w.wvalid),
    .s_axi_wready               (axilcluster0_axi_w.wready),
    .s_axi_bid                  (axilcluster0_axi_b.bid),
    .s_axi_bresp                (axilcluster0_axi_b.bresp),
    .s_axi_bvalid               (axilcluster0_axi_b.bvalid),
    .s_axi_bready               (axilcluster0_axi_b.bready),
    .s_axi_arid                 (axilcluster0_axi_ar.arid),
    .s_axi_araddr               (axilcluster0_axi_ar.araddr),
    .s_axi_arlen                (axilcluster0_axi_ar.arlen),
    .s_axi_arsize               (axilcluster0_axi_ar.arsize),
    .s_axi_arburst              (axilcluster0_axi_ar.arburst),
    .s_axi_arlock               (axilcluster0_axi_ar.arlock),
    .s_axi_arcache              (axilcluster0_axi_ar.arcache),
    .s_axi_arprot               (axilcluster0_axi_ar.arprot),
    .s_axi_arvalid              (axilcluster0_axi_ar.arvalid),
    .s_axi_arready              (axilcluster0_axi_ar.arready),
    .s_axi_rid                  (axilcluster0_axi_r.rid),
    .s_axi_rdata                (axilcluster0_axi_r.rdata),
    .s_axi_rresp                (axilcluster0_axi_r.rresp),
    .s_axi_rlast                (axilcluster0_axi_r.rlast),
    .s_axi_rvalid               (axilcluster0_axi_r.rvalid),
    .s_axi_rready               (axilcluster0_axi_r.rready),

    /*
     * AXI lite master interface
     */
    .m_axil_awaddr              (axilcluster0_axil_awaddr),
    .m_axil_awprot              (axilcluster0_axil_awprot),
    .m_axil_awvalid             (axilcluster0_axil_awvalid),
    .m_axil_awready             (axilcluster0_axil_awready),
    .m_axil_wdata               (axilcluster0_axil_wdata),
    .m_axil_wstrb               (axilcluster0_axil_wstrb),
    .m_axil_wvalid              (axilcluster0_axil_wvalid),
    .m_axil_wready              (axilcluster0_axil_wready),
    .m_axil_bresp               (axilcluster0_axil_bresp),
    .m_axil_bvalid              (axilcluster0_axil_bvalid),
    .m_axil_bready              (axilcluster0_axil_bready),
    .m_axil_araddr              (axilcluster0_axil_araddr),
    .m_axil_arprot              (axilcluster0_axil_arprot),
    .m_axil_arvalid             (axilcluster0_axil_arvalid),
    .m_axil_arready             (axilcluster0_axil_arready),
    .m_axil_rdata               (axilcluster0_axil_rdata),
    .m_axil_rresp               (axilcluster0_axil_rresp),
    .m_axil_rvalid              (axilcluster0_axil_rvalid),
    .m_axil_rready              (axilcluster0_axil_rready)
);

axi_axil_bridge#(
    // Width of address bus in bits
    .ADDR_WIDTH                 (30),
    // Width of input (slave) AXI interface data bus in bits
    .AXI_DATA_WIDTH             (64),
    // Width of input (slave) AXI interface wstrb (width of data bus in words)
    //.AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    .AXI_ID_WIDTH               (`AXI_ID_WIDTH),
    // Width of output (master) AXI lite interface data bus in bits
    .AXIL_DATA_WIDTH            (32)
    // Width of output (master) AXI lite interface wstrb (width of data bus in words)
    //.AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // When adapting to a wider bus, re-pack full-width burst instead of passing through narrow burst if possible
    //.CONVERT_BURST = 1,
    // When adapting to a wider bus, re-pack all bursts instead of passing through narrow burst if possible
    //.CONVERT_NARROW_BURST = 0
)axi_axil32_bridge(
    .clk                        (pherp_clk),
    .rst                        (pherp_domain_rst),

    /*
     * AXI slave interface
     */
    .s_axi_awid                 (axil32cluster0_axi_aw.awid),
    .s_axi_awaddr               (axil32cluster0_axi_aw.awaddr),
    .s_axi_awlen                (axil32cluster0_axi_aw.awlen),
    .s_axi_awsize               (axil32cluster0_axi_aw.awsize),
    .s_axi_awburst              (axil32cluster0_axi_aw.awburst),
    .s_axi_awlock               (axil32cluster0_axi_aw.awlock),
    .s_axi_awcache              (axil32cluster0_axi_aw.awcache),
    .s_axi_awprot               (axil32cluster0_axi_aw.awprot),
    .s_axi_awvalid              (axil32cluster0_axi_aw.awvalid),
    .s_axi_awready              (axil32cluster0_axi_aw.awready),
    .s_axi_wdata                (axil32cluster0_axi_w.wdata),
    .s_axi_wstrb                (axil32cluster0_axi_w.wstrb),
    .s_axi_wlast                (axil32cluster0_axi_w.wlast),
    .s_axi_wvalid               (axil32cluster0_axi_w.wvalid),
    .s_axi_wready               (axil32cluster0_axi_w.wready),
    .s_axi_bid                  (axil32cluster0_axi_b.bid),
    .s_axi_bresp                (axil32cluster0_axi_b.bresp),
    .s_axi_bvalid               (axil32cluster0_axi_b.bvalid),
    .s_axi_bready               (axil32cluster0_axi_b.bready),
    .s_axi_arid                 (axil32cluster0_axi_ar.arid),
    .s_axi_araddr               (axil32cluster0_axi_ar.araddr),
    .s_axi_arlen                (axil32cluster0_axi_ar.arlen),
    .s_axi_arsize               (axil32cluster0_axi_ar.arsize),
    .s_axi_arburst              (axil32cluster0_axi_ar.arburst),
    .s_axi_arlock               (axil32cluster0_axi_ar.arlock),
    .s_axi_arcache              (axil32cluster0_axi_ar.arcache),
    .s_axi_arprot               (axil32cluster0_axi_ar.arprot),
    .s_axi_arvalid              (axil32cluster0_axi_ar.arvalid),
    .s_axi_arready              (axil32cluster0_axi_ar.arready),
    .s_axi_rid                  (axil32cluster0_axi_r.rid),
    .s_axi_rdata                (axil32cluster0_axi_r.rdata),
    .s_axi_rresp                (axil32cluster0_axi_r.rresp),
    .s_axi_rlast                (axil32cluster0_axi_r.rlast),
    .s_axi_rvalid               (axil32cluster0_axi_r.rvalid),
    .s_axi_rready               (axil32cluster0_axi_r.rready),

    /*
     * AXI lite master interface
     */
    .m_axil_awaddr              (axil32cluster0_axil_awaddr),
    .m_axil_awprot              (axil32cluster0_axil_awprot),
    .m_axil_awvalid             (axil32cluster0_axil_awvalid),
    .m_axil_awready             (axil32cluster0_axil_awready),
    .m_axil_wdata               (axil32cluster0_axil_wdata),
    .m_axil_wstrb               (axil32cluster0_axil_wstrb),
    .m_axil_wvalid              (axil32cluster0_axil_wvalid),
    .m_axil_wready              (axil32cluster0_axil_wready),
    .m_axil_bresp               (axil32cluster0_axil_bresp),
    .m_axil_bvalid              (axil32cluster0_axil_bvalid),
    .m_axil_bready              (axil32cluster0_axil_bready),
    .m_axil_araddr              (axil32cluster0_axil_araddr),
    .m_axil_arprot              (axil32cluster0_axil_arprot),
    .m_axil_arvalid             (axil32cluster0_axil_arvalid),
    .m_axil_arready             (axil32cluster0_axil_arready),
    .m_axil_rdata               (axil32cluster0_axil_rdata),
    .m_axil_rresp               (axil32cluster0_axil_rresp),
    .m_axil_rvalid              (axil32cluster0_axil_rvalid),
    .m_axil_rready              (axil32cluster0_axil_rready)
);
/****************************************************************
                axi to axi-lite beidge module end
*****************************************************************/
//------------------32bit axi lite perp--------------------
axil_uart_top               axil_16550_uart(
	.clk_i                      (pherp_clk),
    .rst_i                      (pherp_domain_rst), 
	// Wishbone signals
	.s_axil_awaddr              (axil32cluster0_axil_awaddr),
    .s_axil_awprot              (axil32cluster0_axil_awprot),
    .s_axil_awvalid             (axil32cluster0_axil_awvalid),
    .s_axil_awready             (axil32cluster0_axil_awready),
    .s_axil_wdata               (axil32cluster0_axil_wdata),
    .s_axil_wstrb               (axil32cluster0_axil_wstrb),
    .s_axil_wvalid              (axil32cluster0_axil_wvalid),
    .s_axil_wready              (axil32cluster0_axil_wready),
    .s_axil_bresp               (axil32cluster0_axil_bresp),
    .s_axil_bvalid              (axil32cluster0_axil_bvalid),
    .s_axil_bready              (axil32cluster0_axil_bready),
    .s_axil_araddr              (axil32cluster0_axil_araddr),
    .s_axil_arprot              (axil32cluster0_axil_arprot),
    .s_axil_arvalid             (axil32cluster0_axil_arvalid),
    .s_axil_arready             (axil32cluster0_axil_arready),
    .s_axil_rdata               (axil32cluster0_axil_rdata),
    .s_axil_rresp               (axil32cluster0_axil_rresp),
    .s_axil_rvalid              (axil32cluster0_axil_rvalid),
    .s_axil_rready              (axil32cluster0_axil_rready),
	.int_o                      (), // TODO: 串口中断未接入interrupt request
	// UART	signals
	// serial input/output
	.stx_pad_o                  (uart0_stx_pad_o), 
	.srx_pad_i                  (uart0_srx_pad_i),
	// modem signals
	.rts_pad_o                  (uart0_rts_pad_o), 
	.cts_pad_i                  (uart0_cts_pad_i), 
	.dtr_pad_o                  (uart0_dtr_pad_o), 
	.dsr_pad_i                  (uart0_dsr_pad_i), 
	.ri_pad_i                   (uart0_ri_pad_i), 
	.dcd_pad_i                  (uart0_dcd_pad_i)
);
//------------------axi lite perp--------------------------
axil_xlic#(
    // Width of data bus in bits
    .DATA_WIDTH         (64),
    // Width of address bus in bits
    .ADDR_WIDTH         (8)
    // Width of wstrb (width of data bus in words)
    //.STRB_WIDTH = (DATA_WIDTH/8),
    // Timeout delay (cycles)
    //.TIMEOUT = 4
)axil_xlic(
    .clk                (main_clk),
    .rst                (mainclk_domain_rst),
    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr      (axilcluster0_axil_awaddr),
    .s_axil_awprot      (axilcluster0_axil_awprot),
    .s_axil_awvalid     (axilcluster0_axil_awvalid),
    .s_axil_awready     (axilcluster0_axil_awready),
    .s_axil_wdata       (axilcluster0_axil_wdata),
    .s_axil_wstrb       (axilcluster0_axil_wstrb),
    .s_axil_wvalid      (axilcluster0_axil_wvalid),
    .s_axil_wready      (axilcluster0_axil_wready),
    .s_axil_bresp       (axilcluster0_axil_bresp),
    .s_axil_bvalid      (axilcluster0_axil_bvalid),
    .s_axil_bready      (axilcluster0_axil_bready),
    .s_axil_araddr      (axilcluster0_axil_araddr),
    .s_axil_arprot      (axilcluster0_axil_arprot),
    .s_axil_arvalid     (axilcluster0_axil_arvalid),
    .s_axil_arready     (axilcluster0_axil_arready),
    .s_axil_rdata       (axilcluster0_axil_rdata),
    .s_axil_rresp       (axilcluster0_axil_rresp),
    .s_axil_rvalid      (axilcluster0_axil_rvalid),
    .s_axil_rready      (axilcluster0_axil_rready),
    .crtc_base_addr     (crtc_base_addr),
    .crtc_cfg_en        (crtc_cfg_en),
    .mti                (clint_if.mti),               //machine mode timer interrupt
    .gpio_dir           (gpio_dir),
    .gpio_out           (gpio_out),
    .gpio_in            (gpio_in)
);
assign clint_if.mei=0;          //TODO: clint 目前仅接入了最要紧部分的信号
assign clint_if.sei =0;
assign clint_if.msi =0;
assign clint_if.mtime =0;
`else 
assign axil32cluster0_axi_aw.awready = 1'b0;
assign axil32cluster0_axi_ar.arready = 1'b0;
assign axil32cluster0_axi_w.wready = 1'b0;
assign axil32cluster0_axi_r.rvalid = 1'b0;
assign axil32cluster0_axi_b.bvalid = 1'b0;

assign axilcluster0_axi_aw.awready = 1'b0;
assign axilcluster0_axi_ar.arready = 1'b0;
assign axilcluster0_axi_w.wready = 1'b0;
assign axilcluster0_axi_r.rvalid = 1'b0;
assign axilcluster0_axi_b.bvalid = 1'b0;

`endif

endmodule