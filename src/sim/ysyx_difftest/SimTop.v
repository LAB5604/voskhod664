/******************************************************************************************

   Copyright (c) [2023] [JackPan, XiaoyuHong, KuiSun]
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

    This is a demo SoC for prv664 core with difftest from Openxiangshan project
    
Address space:
    Total 32bit address width
    0x8000_0000~0xbfff_ffff : connect to outside axi(reset to 0x8000_0000)
    0xc000_0000~0xffff_ffff : NO USE
    0x0000_0000~0x3fff_ffff : 8bit io_space
    0x4000_0000~0x7fff_ffff : 64bit axi-lite io_space

Brief sch:
             ------------
            |    CPU     |
            -------------
                  |  4*axi
------------------------------------------------------------------------
|                              4x4 axi xbar                            |
------------------------------------------------------------------------
    | axi       |                  |                          |
-------------------------------------------------------------------------
| apb cluter| axilite  | ocram(connect to difftest) | dram(No connect)  |
-------------------------------------------------------------------------

******************************************************************************************/

`define AXI_TOP_INTERFACE(name) io_memAXI_0_``name
`timescale 1ns / 1ps



`define AXI_ADDR_WIDTH      32      
`define AXI_DATA_WIDTH      64
`define AXI_ID_WIDTH        12       //Must set to 8bit because salyut1 soc use 12bit-id width axi bus
`define AXI_USER_WIDTH      1


/* verilator lint_off PINMISSING */

module SimTop(
    input                               clock,
    input                               reset,

    input  [63:0]                       io_logCtrl_log_begin,
    input  [63:0]                       io_logCtrl_log_end,
    input  [63:0]                       io_logCtrl_log_level,
    input                               io_perfInfo_clean,
    input                               io_perfInfo_dump,

    output                              io_uart_out_valid,
    output [7:0]                        io_uart_out_ch,
    output                              io_uart_in_valid,
    input  [7:0]                        io_uart_in_ch,

    input                               `AXI_TOP_INTERFACE(aw_ready),
    output                              `AXI_TOP_INTERFACE(aw_valid),
    output [`AXI_ADDR_WIDTH-1:0]        `AXI_TOP_INTERFACE(aw_bits_addr),
    output [2:0]                        `AXI_TOP_INTERFACE(aw_bits_prot),
    output [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(aw_bits_id),
    output [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(aw_bits_user),
    output [7:0]                        `AXI_TOP_INTERFACE(aw_bits_len),
    output [2:0]                        `AXI_TOP_INTERFACE(aw_bits_size),
    output [1:0]                        `AXI_TOP_INTERFACE(aw_bits_burst),
    output                              `AXI_TOP_INTERFACE(aw_bits_lock),
    output [3:0]                        `AXI_TOP_INTERFACE(aw_bits_cache),
    output [3:0]                        `AXI_TOP_INTERFACE(aw_bits_qos),
    
    input                               `AXI_TOP_INTERFACE(w_ready),
    output                              `AXI_TOP_INTERFACE(w_valid),
    output [`AXI_DATA_WIDTH-1:0]        `AXI_TOP_INTERFACE(w_bits_data)         [3:0],
    output [`AXI_DATA_WIDTH/8-1:0]      `AXI_TOP_INTERFACE(w_bits_strb),
    output                              `AXI_TOP_INTERFACE(w_bits_last),
    
    output                              `AXI_TOP_INTERFACE(b_ready),
    input                               `AXI_TOP_INTERFACE(b_valid),
    input  [1:0]                        `AXI_TOP_INTERFACE(b_bits_resp),
    input  [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(b_bits_id),
    input  [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(b_bits_user),

    input                               `AXI_TOP_INTERFACE(ar_ready),
    output                              `AXI_TOP_INTERFACE(ar_valid),
    output [`AXI_ADDR_WIDTH-1:0]        `AXI_TOP_INTERFACE(ar_bits_addr),
    output [2:0]                        `AXI_TOP_INTERFACE(ar_bits_prot),
    output [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(ar_bits_id),
    output [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(ar_bits_user),
    output [7:0]                        `AXI_TOP_INTERFACE(ar_bits_len),
    output [2:0]                        `AXI_TOP_INTERFACE(ar_bits_size),
    output [1:0]                        `AXI_TOP_INTERFACE(ar_bits_burst),
    output                              `AXI_TOP_INTERFACE(ar_bits_lock),
    output [3:0]                        `AXI_TOP_INTERFACE(ar_bits_cache),
    output [3:0]                        `AXI_TOP_INTERFACE(ar_bits_qos),
    
    output                              `AXI_TOP_INTERFACE(r_ready),
    input                               `AXI_TOP_INTERFACE(r_valid),
    input  [1:0]                        `AXI_TOP_INTERFACE(r_bits_resp),
    input  [`AXI_DATA_WIDTH-1:0]        `AXI_TOP_INTERFACE(r_bits_data)         [3:0],
    input                               `AXI_TOP_INTERFACE(r_bits_last),
    input  [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(r_bits_id),
    input  [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(r_bits_user)
);

    wire aw_ready;
    wire aw_valid;
    wire [`AXI_ADDR_WIDTH-1:0] aw_addr;
    wire [2:0] aw_prot;
    wire [`AXI_ID_WIDTH-1:0] aw_id;
    wire [`AXI_USER_WIDTH-1:0] aw_user;
    wire [7:0] aw_len;
    wire [2:0] aw_size;
    wire [1:0] aw_burst;
    wire aw_lock;
    wire [3:0] aw_cache;
    wire [3:0] aw_qos;
    wire [3:0] aw_region;

    wire w_ready;
    wire w_valid;
    wire [`AXI_DATA_WIDTH-1:0] w_data;
    wire [`AXI_DATA_WIDTH/8-1:0] w_strb;
    wire w_last;
    wire [`AXI_USER_WIDTH-1:0] w_user;
    
    wire b_ready;
    wire b_valid;
    wire [1:0] b_resp;
    wire [`AXI_ID_WIDTH-1:0] b_id;
    wire [`AXI_USER_WIDTH-1:0] b_user;

    wire ar_ready;
    wire ar_valid;
    wire [`AXI_ADDR_WIDTH-1:0] ar_addr;
    wire [2:0] ar_prot;
    wire [`AXI_ID_WIDTH-1:0] ar_id;
    wire [`AXI_USER_WIDTH-1:0] ar_user;
    wire [7:0] ar_len;
    wire [2:0] ar_size;
    wire [1:0] ar_burst;
    wire ar_lock;
    wire [3:0] ar_cache;
    wire [3:0] ar_qos;
    wire [3:0] ar_region;
    
    wire r_ready;
    wire r_valid;
    wire [1:0] r_resp;
    wire [`AXI_DATA_WIDTH-1:0] r_data;
    wire r_last;
    wire [`AXI_ID_WIDTH-1:0] r_id;
    wire [`AXI_USER_WIDTH-1:0] r_user;

    
    assign `AXI_TOP_INTERFACE(r_ready)              = r_ready;
    assign r_valid                                  = `AXI_TOP_INTERFACE(r_valid);
    assign r_resp                                   = `AXI_TOP_INTERFACE(r_bits_resp);
    assign r_data                                   = `AXI_TOP_INTERFACE(r_bits_data)[0];
    assign r_last                                   = `AXI_TOP_INTERFACE(r_bits_last);
    assign r_id                                     = `AXI_TOP_INTERFACE(r_bits_id);
    assign r_user                                   = `AXI_TOP_INTERFACE(r_bits_user);


    assign ar_ready                                 = `AXI_TOP_INTERFACE(ar_ready);
    assign `AXI_TOP_INTERFACE(ar_valid)             = ar_valid;
    assign `AXI_TOP_INTERFACE(ar_bits_addr)         = {1'b1,ar_addr[30:0]};     //NOTE!高位置1让cpu访问内存的范围始终在80000000以上，避免访问到错误的内存地址
    assign `AXI_TOP_INTERFACE(ar_bits_prot)         = ar_prot;
    assign `AXI_TOP_INTERFACE(ar_bits_id)           = ar_id;
    assign `AXI_TOP_INTERFACE(ar_bits_user)         = ar_user;
    assign `AXI_TOP_INTERFACE(ar_bits_len)          = ar_len;
    assign `AXI_TOP_INTERFACE(ar_bits_size)         = ar_size;
    assign `AXI_TOP_INTERFACE(ar_bits_burst)        = ar_burst;
    assign `AXI_TOP_INTERFACE(ar_bits_lock)         = ar_lock;
    assign `AXI_TOP_INTERFACE(ar_bits_cache)        = ar_cache;
    assign `AXI_TOP_INTERFACE(ar_bits_qos)          = ar_qos;
    

    assign aw_ready                                 = `AXI_TOP_INTERFACE(aw_ready);
    assign `AXI_TOP_INTERFACE(aw_valid)             = aw_valid;
    assign `AXI_TOP_INTERFACE(aw_bits_addr)         = {1'b1,aw_addr[30:0]};
    assign `AXI_TOP_INTERFACE(aw_bits_prot)         = aw_prot;
    assign `AXI_TOP_INTERFACE(aw_bits_id)           = aw_id;
    assign `AXI_TOP_INTERFACE(aw_bits_user)         = aw_user;
    assign `AXI_TOP_INTERFACE(aw_bits_len)          = aw_len;
    assign `AXI_TOP_INTERFACE(aw_bits_size)         = aw_size;
    assign `AXI_TOP_INTERFACE(aw_bits_burst)        = aw_burst;
    assign `AXI_TOP_INTERFACE(aw_bits_lock)         = aw_lock;
    assign `AXI_TOP_INTERFACE(aw_bits_cache)        = aw_cache;
    assign `AXI_TOP_INTERFACE(aw_bits_qos)          = aw_qos;
        
    assign w_ready = `AXI_TOP_INTERFACE(w_ready);
    assign `AXI_TOP_INTERFACE(w_valid) =w_valid;
    assign `AXI_TOP_INTERFACE(w_bits_data)[0] = w_data;
    assign `AXI_TOP_INTERFACE(w_bits_strb)= w_strb;
    assign `AXI_TOP_INTERFACE(w_bits_last) = w_last;

    assign `AXI_TOP_INTERFACE(b_ready)              = b_ready;
    assign b_valid                                  = `AXI_TOP_INTERFACE(b_valid);
    assign b_resp                                   = `AXI_TOP_INTERFACE(b_bits_resp);
    assign b_id                                     = `AXI_TOP_INTERFACE(b_bits_id);
    assign b_user                                   = `AXI_TOP_INTERFACE(b_bits_user);

salyut1_soc_top#(
    //parameter INIT_FILE = "hex.txt",
    //        // vga crtc bios initial file
    //          INIT_CHAR_ROM_FILE_NAME   = "font.txt",
    //          INIT_FRAME_CHAR_FILE_NAME ="",
    //          INIT_FRAME_COLOR_FILE_NAME="",
    //          INIT_FRAME_BLINK_FILE_NAME=""
)dut(
    .main_clk               (clock),        //cpu running clock input
    .clk25m                 (0),          //25MHz clock for vga system
    .main_rst               (reset),        //sync reset input
    .pherp_clk              (clock),
    .cpu_rst                (1'b0),         //不需要单独复位cpu，soc复位时会自动产生cpu复位信号
    //-----------------core jtag interface-----------------
    .cpu_jtag_rstn          (1),
    .cpu_jtag_tms           (0),
    .cpu_jtag_tck           (0),
    .cpu_jtag_tdi           (0),
    .cpu_jtag_tdo           (),
    //在仿真状态下，内部的OCRAM访问信号被引到外部，这样可以方便的进行difftest仿真
    .mst_clk              (clock),
    .mst_rst              (reset),
    .mst_awvalid          (aw_valid),
    .mst_awready          (aw_ready),
    .mst_awaddr           (aw_addr),         
    .mst_awlen            (aw_len),
    .mst_awsize           (aw_size),
    .mst_awburst          (aw_burst),
    .mst_awlock           (aw_lock),
    .mst_awcache          (aw_cache),
    .mst_awprot           (aw_prot),
    .mst_awqos            (aw_qos),
    .mst_awregion         (aw_region),
    .mst_awid             (aw_id),
    .mst_wvalid           (w_valid),
    .mst_wready           (w_ready),
    .mst_wlast            (w_last),
    .mst_wdata            (w_data),
    .mst_wstrb            (w_strb),
    .mst_bvalid           (b_valid),
    .mst_bready           (b_ready),
    .mst_bid              (b_id),
    .mst_bresp            (b_resp),
    .mst_arvalid          (ar_valid),
    .mst_arready          (ar_ready),
    .mst_araddr           (ar_addr),
    .mst_arlen            (ar_len),
    .mst_arsize           (ar_size),
    .mst_arburst          (ar_burst),
    .mst_arlock           (ar_lock),
    .mst_arcache          (ar_cache),
    .mst_arprot           (ar_prot),
    .mst_arqos            (ar_qos),
    .mst_arregion         (ar_region),
    .mst_arid             (ar_id),
    .mst_rvalid           (r_valid),
    .mst_rready           (r_ready),
    .mst_rid              (r_id),
    .mst_rresp            (r_resp),
    .mst_rdata            (r_data),
    .mst_rlast            (r_last),
    //---------------ocram controllor-----------
    //在模拟器仿真状态下，复位到0x80000000，因此程序不会从ocram中启动运行
    //---------------VGA display---------------
    .vga_clk_o(),
	.vga_b_o(),
	.vga_g_o(),
	.vga_hs_o(),
	.vga_r_o(),
	.vga_vs_o(),
    //-------------UART0------------------
    // UART	signals
    .uart0_srx_pad_i(),
    .uart0_stx_pad_o(),
    .uart0_rts_pad_o(),
    .uart0_cts_pad_i(),
    .uart0_dtr_pad_o(),
    .uart0_dsr_pad_i(),
    .uart0_ri_pad_i(),
    .uart0_dcd_pad_i()
);


endmodule