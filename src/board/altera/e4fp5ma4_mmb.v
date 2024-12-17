/*********************************************************************************
Salyut1 SoC on E4FP5MA4 FPGA board!
Powered by Voskhod664 Arch
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 

    Auth: Jack.Pan
    Date: 2023/12/21
    Ver:  V1.0
    Desc: 
***********************************************************************************/
module e4fpm5ma4_mmb(
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
            ;
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

altera_pll #(
               .fractional_vco_multiplier("true"),
               .reference_clock_frequency("27.0 MHz"),
               .operation_mode("direct"),
               .number_of_clocks(1),
               .output_clock_frequency0("50 MHz"),
               .phase_shift0("0 ps"),
               .duty_cycle0(50),
               .pll_type("General"),
               .pll_subtype("General")
) pll_mainclk (
               .rst	(som_key),
               .outclk	(main_clk),
               .locked	(pll_lock),
               .fboutclk (),
               .fbclk	(1'b0),
               .refclk	(ext_clk_27m)
           );

altera_pll #(
               .fractional_vco_multiplier("true"),
               .reference_clock_frequency("27.0 MHz"),
               .operation_mode("direct"),
               .number_of_clocks(1),
               .output_clock_frequency0("25 MHz"),
               .phase_shift0("0 ps"),
               .duty_cycle0(50),
               .pll_type("General"),
               .pll_subtype("General")
) pll_pherpclk (
               .rst	(som_key),
               .outclk	(pherp_clk),
               .locked	(),
               .fboutclk (),
               .fbclk	(1'b0),
               .refclk	(ext_clk_27m)
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
    .mst_clk                (0),
    .mst_rst                (0),
    .mst_awvalid            (),
    .mst_awready            (0),
    .mst_awaddr             (),
    .mst_awlen              (),
    .mst_awsize             (),
    .mst_awburst            (),
    .mst_awlock             (),
    .mst_awcache            (),
    .mst_awprot             (),
    .mst_awqos              (),
    .mst_awregion           (),
    .mst_awid               (),
    .mst_wvalid             (),
    .mst_wready             (0),
    .mst_wlast              (),
    .mst_wdata              (),
    .mst_wstrb              (),
    .mst_bvalid             (0),
    .mst_bready             (),
    .mst_bid                (),
    .mst_bresp              (),
    .mst_arvalid            (),
    .mst_arready            (0),
    .mst_araddr             (),
    .mst_arlen              (),
    .mst_arsize             (),
    .mst_arburst            (),
    .mst_arlock             (),
    .mst_arcache            (),
    .mst_arprot             (),
    .mst_arqos              (),
    .mst_arregion           (),
    .mst_arid               (),
    .mst_rvalid             (0),
    .mst_rready             (),
    .mst_rid                (),
    .mst_rresp              (),
    .mst_rdata              (),
    .mst_rlast              (),
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


assign vga_psave_n = 1;
assign vga_sync_n  = 1;
assign vga_blank_n = 1;
endmodule