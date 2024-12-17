module apb_cluster_top#(
    parameter INIT_CHAR_ROM_FILE_NAME = "font.txt",
              INIT_FRAME_CHAR_FILE_NAME  = "char.txt",
              INIT_FRAME_COLOR_FILE_NAME = "color.txt",
              INIT_FRAME_BLINK_FILE_NAME = "blink.txt"
)(
    input wire                      clk25m,     //25Mhz reference clock for VGA display
    input wire                      pclk,
    input wire                      presetn,
    input wire [31:0]               paddr,
    input wire                      psel, penable, pwrite,
    input wire [7:0]                pwdata,
    output wire                     pready, pslverr,
    output wire [7:0]               prdata,
    //-------------VGA display------------
    output  wire                    vga_clk_o,
	output	wire     [7:0]		    vga_b_o,
	output	wire     [7:0]		    vga_g_o,
	output	wire          		    vga_hs_o,
	output	wire     [7:0]		    vga_r_o,
	output	wire          		    vga_vs_o,
    //-------------UART0------------------
    // UART	signals
    input 	wire	        	    uart0_srx_pad_i,
    output 	wire	        	    uart0_stx_pad_o,
    output 	wire	        	    uart0_rts_pad_o,
    input 	wire	        	    uart0_cts_pad_i,
    output 	wire	        	    uart0_dtr_pad_o,
    input 	wire	        	    uart0_dsr_pad_i,
    input 	wire	        	    uart0_ri_pad_i,
    input 	wire	        	    uart0_dcd_pad_i
);
    //-------------------uart access--------------------
    wire        uart_psel,      vga_psel;
    wire        uart_penable,   vga_penable;
    wire        uart_pwrite,    vga_pwrite;
    wire [2:0]  uart_paddr;
    wire [13:0]                 vga_paddr;
    wire [7:0]  uart_pwdata,    vga_pwdata;
    wire [7:0]  uart_prdata,    vga_prdata;
    wire        uart_pready,    vga_pready;
    wire        uart_pslverr,   vga_pslverr;
apb_busmux#(
    //parameter DWID = 8,     //databus width
    //          AWID = 32,    //addressbus width
    //          SLV0_START_ADDR= 'h0000,    UART
    //          SLV0_END_ADDR =  'h0FFF,
    //          SLV1_START_ADDR= 'h1000,
    //          SLV1_END_ADDR  = 'h1FFF,
    //          SLV2_START_ADDR= 'h2000,
    //          SLV2_END_ADDR =  'h2FFF,
    //          SLV3_START_ADDR= 'h3000,
    //          SLV3_END_ADDR =  'h3FFF,
    //          SLV4_START_ADDR= 'h4000,
    //          SLV4_END_ADDR =  'h4FFF,
    //          SLV5_START_ADDR= 'h5000,
    //          SLV5_END_ADDR =  'h5FFF,
    //          SLV6_START_ADDR= 'h6000,
    //          SLV6_END_ADDR =  'h6FFF,
              .SLV7_START_ADDR  ('h8000),  //text mode VGA display
              .SLV7_END_ADDR    ('hAFFF),
              .NULL_START_ADDR  ('hB000)          //from slave7 end to 32bit end always is null device, ack ready with no error
    //          NULL_END_ADDR   = 'hFFFFFFFF
)busmux(
    .slv_psel               (psel), 
    .slv_penable            (penable), 
    .slv_pwrite             (pwrite),
    .slv_pwdata             (pwdata),
    .slv_paddr              (paddr),
    .slv_pready             (pready), 
    .slv_pslverr            (pslverr),
    .slv_prdata             (prdata),
    //---------slave0--------------
    .mst0_psel              (uart_psel), 
    .mst0_penable           (uart_penable), 
    .mst0_pwrite            (uart_pwrite),
    .mst0_pwdata            (uart_pwdata),
    .mst0_paddr             (uart_paddr),   //bit from 3~31 is ignored
    .mst0_pready            (uart_pready), 
    .mst0_pslverr           (uart_pslverr),
    .mst0_prdata            (uart_prdata),
    //---------slave1--------------
    .mst1_psel              (),
    .mst1_penable           (),
    .mst1_pwrite            (),
    .mst1_pwdata            (),
    .mst1_paddr             (),
    .mst1_pready            (0),
    .mst1_pslverr           (0),
    .mst1_prdata            (0),
    //---------slave2--------------
    .mst2_psel              (),
    .mst2_penable           (),
    .mst2_pwrite            (),
    .mst2_pwdata            (),
    .mst2_paddr             (),
    .mst2_pready            (0),
    .mst2_pslverr           (0),
    .mst2_prdata            (0),
    //---------slave3--------------
    .mst3_psel              (),
    .mst3_penable           (),
    .mst3_pwrite            (),
    .mst3_pwdata            (),
    .mst3_paddr             (),
    .mst3_pready            (0),
    .mst3_pslverr           (0),
    .mst3_prdata            (0),
    //---------slave4--------------
    .mst4_psel              (),
    .mst4_penable           (),
    .mst4_pwrite            (),
    .mst4_pwdata            (),
    .mst4_paddr             (),
    .mst4_pready            (0),
    .mst4_pslverr           (0),
    .mst4_prdata            (0),
    //---------slave5--------------
    .mst5_psel              (), 
    .mst5_penable           (),
    .mst5_pwrite            (),
    .mst5_pwdata            (),
    .mst5_paddr             (),
    .mst5_pready            (0),
    .mst5_pslverr           (0),
    .mst5_prdata            (0),
    //---------slave6--------------
    .mst6_psel              (),
    .mst6_penable           (),
    .mst6_pwrite            (),
    .mst6_pwdata            (),
    .mst6_paddr             (),
    .mst6_pready            (0),
    .mst6_pslverr           (0),
    .mst6_prdata            (0),
    //---------slave7--------------
    .mst7_psel              (vga_psel),
    .mst7_penable           (vga_penable),
    .mst7_pwrite            (vga_pwrite),
    .mst7_pwdata            (vga_pwdata),
    .mst7_paddr             (vga_paddr),        //bit from 14~31 is ignored
    .mst7_pready            (vga_pready),
    .mst7_pslverr           (vga_pslverr),
    .mst7_prdata            (vga_prdata)
);
//--------------------------UART0------------------------------
uart_top            uart0(
	.wb_clk_i       (pclk),
	.wb_rst_i       (!presetn), 
    .wb_adr_i       (uart_paddr), 
    .wb_dat_i       (uart_pwdata),
    .wb_dat_o       (uart_prdata),
    .wb_we_i        (uart_pwrite),
    .wb_stb_i       (uart_penable),
    .wb_cyc_i       (uart_psel),
    .wb_ack_o       (uart_pready),
    .wb_sel_i       (uart_psel),        //here we wont use byte select since this is an 8-bit bus
	.stx_pad_o      (uart0_stx_pad_o),
    .srx_pad_i      (uart0_srx_pad_i),
	.rts_pad_o      (uart0_rts_pad_o), 
    .cts_pad_i      (uart0_cts_pad_i), 
    .dtr_pad_o      (uart0_dtr_pad_o), 
    .dsr_pad_i      (uart0_dsr_pad_i), 
    .ri_pad_i       (uart0_ri_pad_i), 
    .dcd_pad_i      (uart0_dcd_pad_i)
);
//-----------------------basic vga display---------------------
wb_textvga_top#(
    .INIT_CHAR_ROM_FILE_NAME    (INIT_CHAR_ROM_FILE_NAME),
    .INIT_FRAME_ENABLE          ("ENABLE"),
    .INIT_FRAME_CHAR_FILE_NAME  (INIT_FRAME_CHAR_FILE_NAME),
    .INIT_FRAME_COLOR_FILE_NAME (INIT_FRAME_COLOR_FILE_NAME),
    .INIT_FRAME_BLINK_FILE_NAME (INIT_FRAME_BLINK_FILE_NAME)
)crtc(
    .sysclk_i                   (pclk),           //system clock, can be any value
    .clk25m                     (clk25m),             //25mhz reference clock for vga
    .rst_i                      (!presetn),              //async reset
    .pallete_select             (2'b00),     //select a pallete to use, default=00 is IBM PC/XT's color shape!
    ////////////wishbone 8bit bus//////////////
    //            wishbone is sync with sysclk_i
    .wb_cyc_i                   (vga_psel),
    .wb_stb_i                   (vga_penable),
    .wb_we_i                    (vga_pwrite),
    .wb_adr_i                   (vga_paddr),
    .wb_dat_i                   (vga_pwdata),
    .wb_dat_o                   (vga_prdata),
    .wb_ack_o                   (vga_pready),
    //////////// VGA //////////
    .vga_clk_o                  (vga_clk_o),
	.vga_b_o                    (vga_b_o),
	.vga_g_o                    (vga_g_o),
	.vga_hs_o                   (vga_hs_o),
	.vga_r_o                    (vga_r_o),
	.vga_vs_o                   (vga_vs_o)
);
endmodule