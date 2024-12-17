/*********************************************************************************
Salyut1 SoC on E4FPM7K325 FPGA board!
Powered by Voskhod664 Arch
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 

    Auth: Jack.Pan
    Date: 2023/8/15
    Ver:  V1.0
    Desc: 
***********************************************************************************/
module e4fpmk7_mmb(
//-----------------on motherboard------------
    ////sd card
    //inout sd_cd,
    //inout [3:0] sd_d,
    //inout sd_clk,
    //inout sd_cmd,
    ////cs534x i2s adc
    //output adc_rst_n,
    //output adc_mclk,
    //inout  adc_sclk,
    //inout  adc_lrck,
    //input  adc_sdout,
    //output [1:0] adc_mode,
    ////cs43xx i2s dac
    //output dac_sclk,
    //output dac_lrck,
    //output dac_sdin,
    //output dac_mclk,
    ////ps2 interface
    //inout ps2_clk_1,    ps2_clk_2,
    //inout ps2_data_1,   ps2_data_2,
    // uart interface
    input uart_rxd,
    output uart_txd,
    //vga interface
    output          vga_clk,
    output [7:0]    vga_blue, vga_green, vga_red,
    output          vga_sync_n,
    output          vga_psave_n,   //0:7123 in power save mode
    output          vga_blank_n, vga_hs, vga_vs,
    ////key
    //input [7:0]     key,
    ////but
    //input [7:0]     but,
    ////7-seg display
    //output          seg_g, seg_f, seg_e, seg_d, seg_c, seg_b, seg_a, seg_dp,
    //output [3:0]    seg_sel,
    ////led output
    output [7:0]    led,
    ////clock generate (CDCM 61002)
    //output [1:0]    clkgen_pr, clkgen_os,
    //output [2:0]    clkgen_od,
    ////gpio total 17*2
    //input [16:0]    gpio0, gpio1;
//--------------on SoM part----------------------
    ////eth phy
    //output          rgmii_reset_n,
    //inout           rgmii_mdio, rgmii_mdc,
    //input [3:0]     rgmii_rxd,
    //input           rgmii_rxck, rgmii_rxctl,
    //output          rgmii_txctl, rgmii_txck,
    //output[3:0]     rgmii_txd,
    ////  emmc
    //inout [7:0]     emmc_dq,
    //output          emmc_cmd, emmc_clk,emmc_rst_n,
    ////  user flash
    //output          qspi_cs_n,
    //inout [3:0]     qspi_dq,
    //output          qspi_sclk,
    //// user led & key
    output          som_led,
    input           som_key,
    // clock
    input       ext_clk_27m,
    input       refclk_200m_p,
    input       refclk_200m_n
    ////usb phy (device)
    //input       usbd_clk, usbd_dir, usbd_nxt, usbd_stp,
    //inout [7:0] usbd_dq,
    ////usb phy (host)
    //input       usbm_clk, usbm_dir, usbm_nxt, usbm_stp,
    //inout [7:0] usbm_dq,
    ////hdmi (or GPIO)
    //inout           hdmi_scl, hdmi_sck,
    //output [2:0]    tmds_l_p, tmds_l_n,
    //output          tmds_clk_p, tmds_clk_n,
    ////pwm vid (CAUTION WHEN USE THIS SIGNAL)
    //output          pwmvid      //when use pwmvid, the dcdc converter must be set to pwmvid-ctrl mode
    //                            //the default config is fixed 1V output
);
localparam INIT_FILE = "C:/Users/user/Documents/GitHub/voskhod664/csrc/demo_startup/startup64.txt",
           INIT_CHAR_ROM_FILE_NAME = "C:/Users/user/Documents/GitHub/voskhod664/synsrc/define_config_rom/font.txt",
           //INIT_FRAME_BLINK_FILE_NAME = "",
           //INIT_FRAME_CHAR_FILE_NAME = "",
           //INIT_FRAME_COLOR_FILE_NAME= "",
           C_S_AXI_ID_WIDTH = 4,
           C_S_AXI_ADDR_WIDTH=30,
           C_S_AXI_DATA_WIDTH=64;
/***************************************************************
                main PLL
main PLL generate system clock and VGA clock
****************************************************************/
wire                              pll_lock;      //main clock locked
wire                              CLKFBIN;
wire                              pherp_rst;
wire                              main_rst;
wire                              main_clk;      //main clock for soc use(CPU, Bridge runs on this freq)
wire                              clk25m;        //vga clock for soc

/****************************************************************
    DDR3-AXI controller
DDR3 interface use ui_clk as clock
****************************************************************/
wire                              mmcm_locked;          //memory controller locked
wire                              init_calib_complete;  //init done
wire                              ui_clk;
wire                              ui_clk_sync_rst;
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
wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   s_axi_wstrb;
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
//---------------PLL for xilinx FPGA---------------------------
   // PLLE2_BASE: Base Phase Locked Loop (PLL)
   //             Kintex-7
   // Xilinx HDL Language Template, version 2019.2
   PLLE2_BASE #(
      .BANDWIDTH("OPTIMIZED"),  // OPTIMIZED, HIGH, LOW
      .CLKFBOUT_MULT(25),        // Multiply value for all CLKOUT, (2-64)
      .CLKFBOUT_PHASE(0.0),     // Phase offset in degrees of CLKFB, (-360.000-360.000).
      .CLKIN1_PERIOD(0.0),      // Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      // CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for each CLKOUT (1-128)
      .CLKOUT0_DIVIDE(9),
      .CLKOUT1_DIVIDE(27),
      .CLKOUT2_DIVIDE(1),
      .CLKOUT3_DIVIDE(1),
      .CLKOUT4_DIVIDE(1),
      .CLKOUT5_DIVIDE(1),
      // CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for each CLKOUT (0.001-0.999).
      .CLKOUT0_DUTY_CYCLE(0.5),
      .CLKOUT1_DUTY_CYCLE(0.5),
      .CLKOUT2_DUTY_CYCLE(0.5),
      .CLKOUT3_DUTY_CYCLE(0.5),
      .CLKOUT4_DUTY_CYCLE(0.5),
      .CLKOUT5_DUTY_CYCLE(0.5),
      // CLKOUT0_PHASE - CLKOUT5_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
      .CLKOUT0_PHASE(0.0),
      .CLKOUT1_PHASE(0.0),
      .CLKOUT2_PHASE(0.0),
      .CLKOUT3_PHASE(0.0),
      .CLKOUT4_PHASE(0.0),
      .CLKOUT5_PHASE(0.0),
      .DIVCLK_DIVIDE(1),        // Master division value, (1-56)
      .REF_JITTER1(0.0),        // Reference input jitter in UI, (0.000-0.999).
      .STARTUP_WAIT("FALSE")    // Delay DONE until PLL Locks, ("TRUE"/"FALSE")
   )
   PLLE2_BASE_inst (
      // Clock Outputs: 1-bit (each) output: User configurable clock outputs
      .CLKOUT0      (main_clk),   // 1-bit output for main clock (75MHz)
      .CLKOUT1      (clk25m),   // 1-bit output for 25MHz VGA clock
      .CLKOUT2      (),   // 1-bit output: CLKOUT2
      .CLKOUT3      (),   // 1-bit output: CLKOUT3
      .CLKOUT4      (),   // 1-bit output: CLKOUT4
      .CLKOUT5      (),   // 1-bit output: CLKOUT5
      // Feedback Clocks: 1-bit (each) output: Clock feedback ports
      .CLKFBOUT     (CLKFBIN), // 1-bit output: Feedback clock
      .LOCKED       (pll_lock),     // 1-bit output: LOCK
      .CLKIN1       (ext_clk_27m),     // 1-bit input: Input clock
      // Control Ports: 1-bit (each) input: PLL control ports
      .PWRDWN       (1'b0),     // 1-bit input: Power-down
      .RST          (som_key),           // 1-bit input: Reset
      // Feedback Clocks: 1-bit (each) input: Clock feedback ports
      .CLKFBIN      (CLKFBIN)    // 1-bit input: Feedback clock
   );
/*******************************************************************
                reset sync
reset timing: pherp_rst -> main_rst
********************************************************************/
reset_gen       mainclk_reset_sync(
    .clk        (main_clk),
    .rst_async  (pherp_rst),
    .rst_sync   (main_rst)
);
reset_gen       pherp_reset_sync(
    .clk        (clk25m),
    .rst_async  (~pll_lock),
    .rst_sync   (pherp_rst)
);
/*******************************************************************
                    Salyut1 SoC 
********************************************************************/
salyut1_soc_top#(
    .INIT_FILE      (INIT_FILE),
    .INIT_CHAR_ROM_FILE_NAME (INIT_CHAR_ROM_FILE_NAME),
    .INIT_FRAME_CHAR_FILE_NAME (),
    .INIT_FRAME_COLOR_FILE_NAME(),
    .INIT_FRAME_BLINK_FILE_NAME()
)salyut1_soc(
    .main_clk               (main_clk),        //cpu running clock input
    .clk25m                 (clk25m),          //25MHz clock for vga system
    .main_rst               (main_rst),        //sync reset input
    .pherp_clk              (clk25m),
    .pherp_rst              (pherp_rst),
    //-----------------core jtag interface-----------------
    .cpu_jtag_rstn          (1),
    .cpu_jtag_tms           (0),
    .cpu_jtag_tck           (0),
    .cpu_jtag_tdi           (0),
    .cpu_jtag_tdo           (),
    //-------------main memory access interface(AXI)-----------------
    .mst_clk                (ui_clk),
    .mst_rst                (ui_clk_sync_rst),
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
    //---------------VGA display---------------
    .vga_clk_o                      (vga_clk),
	.vga_b_o                        (vga_blue),
	.vga_g_o                        (vga_green),
	.vga_hs_o                       (vga_hs),
	.vga_r_o                        (vga_red),
	.vga_vs_o                       (vga_vs),
    //-------------UART0------------------
    // UART	signals
    .uart0_srx_pad_i                (uart_rxd),
    .uart0_stx_pad_o                (uart_txd),
    .uart0_rts_pad_o                (),
    .uart0_cts_pad_i                (0),
    .uart0_dtr_pad_o                (),
    .uart0_dsr_pad_i                (0),
    .uart0_ri_pad_i                 (0),
    .uart0_dcd_pad_i                (0)
);
/**************************************************************
    DDR3 controller with AXI4 interface
***************************************************************/
mig_7series_0       u_mig_7series_0 (
    // Memory interface ports
    .ddr3_addr                      (ddr3_addr),  // output [14:0]		ddr3_addr
    .ddr3_ba                        (ddr3_ba),  // output [2:0]		ddr3_ba
    .ddr3_cas_n                     (ddr3_cas_n),  // output			ddr3_cas_n
    .ddr3_ck_n                      (ddr3_ck_n),  // output [0:0]		ddr3_ck_n
    .ddr3_ck_p                      (ddr3_ck_p),  // output [0:0]		ddr3_ck_p
    .ddr3_cke                       (ddr3_cke),  // output [0:0]		ddr3_cke
    .ddr3_ras_n                     (ddr3_ras_n),  // output			ddr3_ras_n
    .ddr3_reset_n                   (ddr3_reset_n),  // output			ddr3_reset_n
    .ddr3_we_n                      (ddr3_we_n),  // output			ddr3_we_n
    .ddr3_dq                        (ddr3_dq),  // inout [63:0]		ddr3_dq
    .ddr3_dqs_n                     (ddr3_dqs_n),  // inout [7:0]		ddr3_dqs_n
    .ddr3_dqs_p                     (ddr3_dqs_p),  // inout [7:0]		ddr3_dqs_p
    .init_calib_complete            (init_calib_complete),  // output			init_calib_complete
	.ddr3_cs_n                      (ddr3_cs_n),  // output [0:0]		ddr3_cs_n
    .ddr3_dm                        (ddr3_dm),  // output [7:0]		ddr3_dm
    .ddr3_odt                       (ddr3_odt),  // output [0:0]		ddr3_odt
    // Application interface ports
    .ui_clk                         (ui_clk),  // output			ui_clk
    .ui_clk_sync_rst                (ui_clk_sync_rst),  // output			ui_clk_sync_rst
    .mmcm_locked                    (mmcm_locked),  // output			mmcm_locked
    .aresetn                        (!som_key),  // input			aresetn
    .app_sr_req                     (1'b0),  // input			this pint should tied to 0
    .app_ref_req                    (1'b0),  // input			app_ref_req
    .app_zq_req                     (1'b0),  // input			app_zq_req
    .app_sr_active                  (),  // output			app_sr_active
    .app_ref_ack                    (),  // output			app_ref_ack
    .app_zq_ack                     (),  // output			app_zq_ack
    // Slave Interface Write Address Ports
    .s_axi_awid                     (s_axi_awid),  // input [3:0]			s_axi_awid
    .s_axi_awaddr                   ({1'b0,s_axi_awaddr}),  // input [30:0]			s_axi_awaddr
    .s_axi_awlen                    (s_axi_awlen),  // input [7:0]			s_axi_awlen
    .s_axi_awsize                   (s_axi_awsize),  // input [2:0]			s_axi_awsize
    .s_axi_awburst                  (s_axi_awburst),  // input [1:0]			s_axi_awburst
    .s_axi_awlock                   (s_axi_awlock),  // input [0:0]			s_axi_awlock
    .s_axi_awcache                  (s_axi_awcache),  // input [3:0]			s_axi_awcache
    .s_axi_awprot                   (s_axi_awprot),  // input [2:0]			s_axi_awprot
    .s_axi_awqos                    (s_axi_awqos),  // input [3:0]			s_axi_awqos
    .s_axi_awvalid                  (s_axi_awvalid),  // input			s_axi_awvalid
    .s_axi_awready                  (s_axi_awready),  // output			s_axi_awready
    // Slave Interface Write Data Ports
    .s_axi_wdata                    (s_axi_wdata),  // input [63:0]			s_axi_wdata
    .s_axi_wstrb                    (s_axi_wstrb),  // input [7:0]			s_axi_wstrb
    .s_axi_wlast                    (s_axi_wlast),  // input			s_axi_wlast
    .s_axi_wvalid                   (s_axi_wvalid),  // input			s_axi_wvalid
    .s_axi_wready                   (s_axi_wready),  // output			s_axi_wready
    // Slave Interface Write Response Ports
    .s_axi_bid                      (s_axi_bid),  // output [3:0]			s_axi_bid
    .s_axi_bresp                    (s_axi_bresp),  // output [1:0]			s_axi_bresp
    .s_axi_bvalid                   (s_axi_bvalid),  // output			s_axi_bvalid
    .s_axi_bready                   (s_axi_bready),  // input			s_axi_bready
    // Slave Interface Read Address Ports
    .s_axi_arid                     (s_axi_arid),  // input [3:0]			s_axi_arid
    .s_axi_araddr                   ({1'b0,s_axi_araddr}),  // input [30:0]			s_axi_araddr
    .s_axi_arlen                    (s_axi_arlen),  // input [7:0]			s_axi_arlen
    .s_axi_arsize                   (s_axi_arsize),  // input [2:0]			s_axi_arsize
    .s_axi_arburst                  (s_axi_arburst),  // input [1:0]			s_axi_arburst
    .s_axi_arlock                   (s_axi_arlock),  // input [0:0]			s_axi_arlock
    .s_axi_arcache                  (s_axi_arcache),  // input [3:0]			s_axi_arcache
    .s_axi_arprot                   (s_axi_arprot),  // input [2:0]			s_axi_arprot
    .s_axi_arqos                    (s_axi_arqos),  // input [3:0]			s_axi_arqos
    .s_axi_arvalid                  (s_axi_arvalid),  // input			s_axi_arvalid
    .s_axi_arready                  (s_axi_arready),  // output			s_axi_arready
    // Slave Interface Read Data Ports
    .s_axi_rid                      (s_axi_rid),  // output [3:0]			s_axi_rid
    .s_axi_rdata                    (s_axi_rdata),  // output [63:0]			s_axi_rdata
    .s_axi_rresp                    (s_axi_rresp),  // output [1:0]			s_axi_rresp
    .s_axi_rlast                    (s_axi_rlast),  // output			s_axi_rlast
    .s_axi_rvalid                   (s_axi_rvalid),  // output			s_axi_rvalid
    .s_axi_rready                   (s_axi_rready),  // input			s_axi_rready
    // System Clock Ports
    .sys_clk_p                      (refclk_200m_p),  // input				sys_clk_p
    .sys_clk_n                      (refclk_200m_n),  // input				sys_clk_n
    .sys_rst                        (som_key) // input sys_rst
);
assign led[0] = pll_lock;
assign led[1] = mmcm_locked;
assign led[2] = init_calib_complete;

assign vga_psave_n = 1;
assign vga_sync_n  = 1;
assign vga_blank_n = 1;
endmodule