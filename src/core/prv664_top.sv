 `include "prv664_define.svh"
 `include "prv664_config.svh"
 `include "riscv_define.svh"
 `include "prv664_bus_define.svh"
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
                                                                             
    Desc    : PRV664(voskhod664) top file
    Author  : JackPan
    Date    : 2023/12/15
    Version : 1.0

    Change log:
        20231106: internal xbar added
        20231215: change internal xbar connect, ibus now directly connected to icache

    Logic schmatic:
     _______________________
    |      CPU pipline     |
    -----------------------
    |      |      |      |     icache  dcache immu dmmu
    |    _____________________
    |   |   3m1s AXI xbar   |
    |   ---------------------
   ibus          | dbus
  (read only)      (read/write)

***********************************************************************************************/
module prv664_top#(
    parameter INIT_FILE = "hex.txt"             //Initial binary file for difftest use
)(
    input wire                  clk_i,
    input wire                  arst_i,
    clint_interface.slave       clint_sif,
    //-----------------core jtag interface-----------------
    input wire                  cpu_jtag_rstn,
    input wire                  cpu_jtag_tms,
    input wire                  cpu_jtag_tck,
    input wire                  cpu_jtag_tdi,
    output wire                 cpu_jtag_tdo,
    //------------------axi--------------------------------
    axi_ar.master               cpu_dbus_axi_ar,
    axi_r.slave                 cpu_dbus_axi_r,
    axi_aw.master               cpu_dbus_axi_aw,
    axi_w.master                cpu_dbus_axi_w,
    axi_b.slave                 cpu_dbus_axi_b,
    axi_ar.master               cpu_ibus_axi_ar,
    axi_r.slave                 cpu_ibus_axi_r

);

//----------------------------interface--------------------------------
    //------------------mmu access--------------------------
    axi_ar                      cpu_immu_axi_ar();
    axi_r                       cpu_immu_axi_r();
    axi_ar                      cpu_dmmu_axi_ar();
    axi_r                       cpu_dmmu_axi_r();
    wire [7:0]                  cpu_dmmu_axi_rid, cpu_immu_axi_rid;
assign cpu_dmmu_axi_r.rid = {4'b0,cpu_dmmu_axi_rid[3:0]};
assign cpu_immu_axi_r.rid = {4'b0,cpu_immu_axi_rid[3:0]};
    //------------------cache memory access------------------
    axi_aw                      dcache_axi_aw();
    axi_w                       dcache_axi_w();
    axi_b                       dcache_axi_b();
    axi_ar                      dcache_axi_ar();
    axi_r                       dcache_axi_r();
    wire [7:0]                  dcache_axi_bid, dcache_axi_rid;
assign dcache_axi_b.bid = {4'b0,dcache_axi_bid[3:0]};   //去掉高4bit路由id
assign dcache_axi_r.rid = {4'b0,dcache_axi_rid[3:0]};


    pipdebug_interface          debug_if();     //cpu jtag-core 

    sysmanage_interface stb_manage_if();
assign stb_manage_if.ready = 0;                 //不需要使用store buffer

//`ifdef SIMULATION
//    test_commit_interface       test_commit0();
//    test_commit_interface       test_commit1();
//    wire [`XLEN-1:0]    dut_ireg    [31:0];
//    wire [`XLEN-1:0]    dut_csr     [4095:0];
//`endif
//----------------------------cpu debug interface----------------------
`ifdef DEBUG_EN
 jtag_top           jtag_top(
    .clk                (clk_i),
    .jtag_rst_n         (arst_i),
    .jtag_pin_TCK       (cpu_jtag_tck),
    .jtag_pin_TMS       (cpu_jtag_tms),
    .jtag_pin_TDI       (cpu_jtag_tdi),
    .jtag_pin_TDO       (cpu_jtag_tdo),
    .debug_master_if    (debug_if)
);
`else 
assign debug_if.haltreq = 0;
assign debug_if.csrwr = 0;
assign debug_if.igprwr = 0;
assign debug_if.fgprwr = 0;
`endif
//----------------------------cpu pipline------------------------------
prv664_pipline_top              pipline(

    .clk_i                  (clk_i),              //clock input, all the logic inside this module is posedge active
    .arst_i                 (arst_i),             //async reset input, high active, ples make sure this signal is sync with clock
//`ifdef SIMULATION
//    .test_commit_m0         (test_commit0),
//    .test_commit_m1         (test_commit1),
//    .test_reg_out           (dut_ireg),
//    .test_csr_out           (dut_csr),
//`endif
//---------------------------clint-----------------------------------------
    .clint_slave            (clint_sif),
//--------------------------debug interface--------------------------------
    .pipdebug_slave         (debug_if),
//-----------------------------to store buffer--------------------------
    .stb_manage_master      (stb_manage_if),            //current no stb installed
//-----------------------ptw axi--------------------------------------
    .immu_axi_ar            (cpu_immu_axi_ar),
    .immu_axi_r             (cpu_immu_axi_r),
    .dmmu_axi_ar            (cpu_dmmu_axi_ar),
    .dmmu_axi_r             (cpu_dmmu_axi_r),
//-------------------instruction mmu and cache access port------------------
    .icache_axi_ar          (cpu_ibus_axi_ar),
    .icache_axi_r           (cpu_ibus_axi_r),
    .dcache_axi_aw          (dcache_axi_aw),
    .dcache_axi_w           (dcache_axi_w),
    .dcache_axi_b           (dcache_axi_b),
    .dcache_axi_ar          (dcache_axi_ar),
    .dcache_axi_r           (dcache_axi_r)
);

//--------------------------core internal xbar-----------------------
axicb_crossbar_top#(
        ///////////////////////////////////////////////////////////////////////
        // Global configuration
        ///////////////////////////////////////////////////////////////////////

        // Address width in bits
        .AXI_ADDR_W         (`PADDR),
        // ID width in bits
        .AXI_ID_W           (`BUS_ID_W),
        // Data width in bits
        .AXI_DATA_W         (64),   //DO NOT TOUCH IT!

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
        .MST0_ROUTES    (4'b0_0_0_1),
        .MST0_ID_MASK   ('h10),
        //parameter MST0_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 1 configuration
        ///////////////////////////////////////////////////////////////////////

        .MST1_CDC       (0),        
        //parameter MST1_OSTDREQ_NUM = 4,
        //parameter MST1_OSTDREQ_SIZE = 1,
        //parameter MST1_PRIORITY = 0,
        .MST1_ROUTES    (4'b0_0_0_1),
        .MST1_ID_MASK   ('h20),
        //parameter MST1_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 2 configuration
        ///////////////////////////////////////////////////////////////////////

        .MST2_CDC       (0),        
        //parameter MST2_OSTDREQ_NUM = 4,
        //parameter MST2_OSTDREQ_SIZE = 1,
        //parameter MST2_PRIORITY = 0,
        .MST2_ROUTES    (4'b0_0_0_1),
        .MST2_ID_MASK   ('h40),
        //parameter MST2_RW = 0,

        ///////////////////////////////////////////////////////////////////////
        // Master 3 configuration
        ///////////////////////////////////////////////////////////////////////

        //parameter MST3_CDC = 0,
        //parameter MST3_OSTDREQ_NUM = 4,
        //parameter MST3_OSTDREQ_SIZE = 1,
        //parameter MST3_PRIORITY = 0,
        .MST3_ROUTES    (4'b0_0_0_1),
        .MST3_ID_MASK   ('h80),
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

        //parameter SLV0_CDC = 0,
        .SLV0_START_ADDR    (0),
        .SLV0_END_ADDR      (64'hffff_ffff_ffff_ffff),
        //parameter SLV0_OSTDREQ_NUM = 4,
        //parameter SLV0_OSTDREQ_SIZE = 1,
        //parameter SLV0_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 1 configuration
        ///////////////////////////////////////////////////////////////////////

        //parameter SLV1_CDC = 0,
        .SLV1_START_ADDR    (0),
        .SLV1_END_ADDR      (0),
        //parameter SLV1_OSTDREQ_NUM = 4,
        //parameter SLV1_OSTDREQ_SIZE = 1,
        //parameter SLV1_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 2 configuration
        ///////////////////////////////////////////////////////////////////////

        //parameter SLV2_CDC = 0,
        .SLV2_START_ADDR    (0),
        .SLV2_END_ADDR      (0),
        //parameter SLV2_OSTDREQ_NUM = 4,
        //parameter SLV2_OSTDREQ_SIZE = 1,
        //parameter SLV2_KEEP_BASE_ADDR = 0,

        ///////////////////////////////////////////////////////////////////////
        // Slave 3 configuration
        ///////////////////////////////////////////////////////////////////////

        //parameter SLV3_CDC = 0,
        .SLV3_START_ADDR    (0),
        .SLV3_END_ADDR      (0)
        //parameter SLV3_OSTDREQ_NUM = 4,
        //parameter SLV3_OSTDREQ_SIZE = 1,
        //parameter SLV3_KEEP_BASE_ADDR = 0
)main_xbar(
        ///////////////////////////////////////////////////////////////////////
        // Interconnect global interface
        ///////////////////////////////////////////////////////////////////////

        .aclk                   (clk_i),
        .aresetn                (!arst_i),
        .srst                   (arst_i),

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 0 interface
        ///////////////////////////////////////////////////////////////////////

        .slv0_aclk              (clk_i),
        .slv0_aresetn           (!arst_i),
        .slv0_srst              (arst_i),
        .slv0_awvalid           (dcache_axi_aw.awvalid),
        .slv0_awready           (dcache_axi_aw.awready),
        .slv0_awaddr            (dcache_axi_aw.awaddr),
        .slv0_awlen             (dcache_axi_aw.awlen),
        .slv0_awsize            (dcache_axi_aw.awsize),
        .slv0_awburst           (dcache_axi_aw.awburst),
        .slv0_awlock            (dcache_axi_aw.awlock),
        .slv0_awcache           (dcache_axi_aw.awcache),
        .slv0_awprot            (dcache_axi_aw.awprot),
        .slv0_awqos             (dcache_axi_aw.awqos),
        .slv0_awregion          (dcache_axi_aw.awregion),
        .slv0_awid              ({4'h1,dcache_axi_aw.awid[3:0]}), //TODO: 因为桥不能自动打tag，因此在这里需要手动打tag
        .slv0_awuser            (0),
        .slv0_wvalid            (dcache_axi_w.wvalid),
        .slv0_wready            (dcache_axi_w.wready),
        .slv0_wlast             (dcache_axi_w.wlast),
        .slv0_wdata             (dcache_axi_w.wdata),
        .slv0_wstrb             (dcache_axi_w.wstrb),
        .slv0_wuser             (0),
        .slv0_bvalid            (dcache_axi_b.bvalid),
        .slv0_bready            (dcache_axi_b.bready),
        .slv0_bid               (dcache_axi_bid),
        .slv0_bresp             (dcache_axi_b.bresp),
        .slv0_buser             (),
        .slv0_arvalid           (dcache_axi_ar.arvalid),
        .slv0_arready           (dcache_axi_ar.arready),
        .slv0_araddr            (dcache_axi_ar.araddr),
        .slv0_arlen             (dcache_axi_ar.arlen),
        .slv0_arsize            (dcache_axi_ar.arsize),
        .slv0_arburst           (dcache_axi_ar.arburst),
        .slv0_arlock            (dcache_axi_ar.arlock),
        .slv0_arcache           (dcache_axi_ar.arcache),
        .slv0_arprot            (dcache_axi_ar.arprot),
        .slv0_arqos             (dcache_axi_ar.arqos),
        .slv0_arregion          (dcache_axi_ar.arregion),
        .slv0_arid              ({4'h1,dcache_axi_ar.arid[3:0]}),
        .slv0_aruser            (0),
        .slv0_rvalid            (dcache_axi_r.rvalid),
        .slv0_rready            (dcache_axi_r.rready),
        .slv0_rid               (dcache_axi_rid),
        .slv0_rresp             (dcache_axi_r.rresp),
        .slv0_rdata             (dcache_axi_r.rdata),
        .slv0_rlast             (dcache_axi_r.rlast),
        .slv0_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 1 interface
        ///////////////////////////////////////////////////////////////////////

        .slv1_aclk              (clk_i),
        .slv1_aresetn           (!arst_i),
        .slv1_srst              (arst_i),
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
        .slv1_arvalid           (1'b0),
        .slv1_arready           (),
        .slv1_araddr            (),
        .slv1_arlen             (),
        .slv1_arsize            (),
        .slv1_arburst           (),
        .slv1_arlock            (),
        .slv1_arcache           (),
        .slv1_arprot            (),
        .slv1_arqos             (),
        .slv1_arregion          (),
        .slv1_arid              (),
        .slv1_aruser            (),
        .slv1_rvalid            (),
        .slv1_rready            (1'b0),
        .slv1_rid               (),
        .slv1_rresp             (),
        .slv1_rdata             (),
        .slv1_rlast             (),
        .slv1_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 2 interface
        ///////////////////////////////////////////////////////////////////////

        .slv2_aclk              (clk_i),
        .slv2_aresetn           (!arst_i),
        .slv2_srst              (arst_i),
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
        .slv2_arvalid           (cpu_immu_axi_ar.arvalid),
        .slv2_arready           (cpu_immu_axi_ar.arready),
        .slv2_araddr            (cpu_immu_axi_ar.araddr),
        .slv2_arlen             (cpu_immu_axi_ar.arlen),
        .slv2_arsize            (cpu_immu_axi_ar.arsize),
        .slv2_arburst           (cpu_immu_axi_ar.arburst),
        .slv2_arlock            (cpu_immu_axi_ar.arlock),
        .slv2_arcache           (cpu_immu_axi_ar.arcache),
        .slv2_arprot            (cpu_immu_axi_ar.arprot),
        .slv2_arqos             (cpu_immu_axi_ar.arqos),
        .slv2_arregion          (cpu_immu_axi_ar.arregion),
        .slv2_arid              ({4'h4,cpu_immu_axi_ar.arid[3:0]}),
        .slv2_aruser            (0),
        .slv2_rvalid            (cpu_immu_axi_r.rvalid),
        .slv2_rready            (cpu_immu_axi_r.rready),
        .slv2_rid               (cpu_immu_axi_rid),
        .slv2_rresp             (cpu_immu_axi_r.rresp),
        .slv2_rdata             (cpu_immu_axi_r.rdata),
        .slv2_rlast             (cpu_immu_axi_r.rlast),
        .slv2_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Master Agent 3 interface
        ///////////////////////////////////////////////////////////////////////

        .slv3_aclk              (clk_i),
        .slv3_aresetn           (!arst_i),
        .slv3_srst              (arst_i),
        .slv3_awvalid           (0),
        .slv3_awready           (),
        .slv3_awaddr            (0),
        .slv3_awlen             (0),
        .slv3_awsize            (0),
        .slv3_awburst           (0),
        .slv3_awlock            (0),
        .slv3_awcache           (0),
        .slv3_awprot            (0),
        .slv3_awqos             (0),
        .slv3_awregion          (0),
        .slv3_awid              (0),
        .slv3_awuser            (0),
        .slv3_wvalid            (0),
        .slv3_wready            (),
        .slv3_wlast             (0),
        .slv3_wdata             (0),
        .slv3_wstrb             (0),
        .slv3_wuser             (0),
        .slv3_bvalid            (),
        .slv3_bready            (0),
        .slv3_bid               (),
        .slv3_bresp             (),
        .slv3_buser             (),
        .slv3_arvalid           (cpu_dmmu_axi_ar.arvalid),
        .slv3_arready           (cpu_dmmu_axi_ar.arready),
        .slv3_araddr            (cpu_dmmu_axi_ar.araddr),
        .slv3_arlen             (cpu_dmmu_axi_ar.arlen),
        .slv3_arsize            (cpu_dmmu_axi_ar.arsize),
        .slv3_arburst           (cpu_dmmu_axi_ar.arburst),
        .slv3_arlock            (cpu_dmmu_axi_ar.arlock),
        .slv3_arcache           (cpu_dmmu_axi_ar.arcache),
        .slv3_arprot            (cpu_dmmu_axi_ar.arprot),
        .slv3_arqos             (cpu_dmmu_axi_ar.arqos),
        .slv3_arregion          (cpu_dmmu_axi_ar.arregion),
        .slv3_arid              ({4'h8,cpu_dmmu_axi_ar.arid[3:0]}),
        .slv3_aruser            (0),
        .slv3_rvalid            (cpu_dmmu_axi_r.rvalid),
        .slv3_rready            (cpu_dmmu_axi_r.rready),
        .slv3_rid               (cpu_dmmu_axi_rid),
        .slv3_rresp             (cpu_dmmu_axi_r.rresp),
        .slv3_rdata             (cpu_dmmu_axi_r.rdata),
        .slv3_rlast             (cpu_dmmu_axi_r.rlast),
        .slv3_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 0 interface
        ///////////////////////////////////////////////////////////////////////

        .mst0_aclk              (clk_i),
        .mst0_aresetn           (!arst_i),
        .mst0_srst              (arst_i),
        .mst0_awvalid           (cpu_dbus_axi_aw.awvalid),
        .mst0_awready           (cpu_dbus_axi_aw.awready),
        .mst0_awaddr            (cpu_dbus_axi_aw.awaddr),
        .mst0_awlen             (cpu_dbus_axi_aw.awlen),
        .mst0_awsize            (cpu_dbus_axi_aw.awsize),
        .mst0_awburst           (cpu_dbus_axi_aw.awburst),
        .mst0_awlock            (cpu_dbus_axi_aw.awlock),
        .mst0_awcache           (cpu_dbus_axi_aw.awcache),
        .mst0_awprot            (cpu_dbus_axi_aw.awprot),
        .mst0_awqos             (cpu_dbus_axi_aw.awqos),
        .mst0_awregion          (cpu_dbus_axi_aw.awregion),
        .mst0_awid              (cpu_dbus_axi_aw.awid),
        .mst0_awuser            (),
        .mst0_wvalid            (cpu_dbus_axi_w.wvalid),
        .mst0_wready            (cpu_dbus_axi_w.wready),
        .mst0_wlast             (cpu_dbus_axi_w.wlast),
        .mst0_wdata             (cpu_dbus_axi_w.wdata),
        .mst0_wstrb             (cpu_dbus_axi_w.wstrb),
        .mst0_wuser             (),
        .mst0_bvalid            (cpu_dbus_axi_b.bvalid),
        .mst0_bready            (cpu_dbus_axi_b.bready),
        .mst0_bid               (cpu_dbus_axi_b.bid),
        .mst0_bresp             (cpu_dbus_axi_b.bresp),
        .mst0_buser             (),
        .mst0_arvalid           (cpu_dbus_axi_ar.arvalid),
        .mst0_arready           (cpu_dbus_axi_ar.arready),
        .mst0_araddr            (cpu_dbus_axi_ar.araddr),
        .mst0_arlen             (cpu_dbus_axi_ar.arlen),
        .mst0_arsize            (cpu_dbus_axi_ar.arsize),
        .mst0_arburst           (cpu_dbus_axi_ar.arburst),
        .mst0_arlock            (cpu_dbus_axi_ar.arlock),
        .mst0_arcache           (cpu_dbus_axi_ar.arcache),
        .mst0_arprot            (cpu_dbus_axi_ar.arprot),
        .mst0_arqos             (cpu_dbus_axi_ar.arqos),
        .mst0_arregion          (cpu_dbus_axi_ar.arregion),
        .mst0_arid              (cpu_dbus_axi_ar.arid),
        .mst0_aruser            (),
        .mst0_rvalid            (cpu_dbus_axi_r.rvalid),
        .mst0_rready            (cpu_dbus_axi_r.rready),
        .mst0_rid               (cpu_dbus_axi_r.rid),
        .mst0_rresp             (cpu_dbus_axi_r.rresp),
        .mst0_rdata             (cpu_dbus_axi_r.rdata),
        .mst0_rlast             (cpu_dbus_axi_r.rlast),
        .mst0_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 1 interface
        ///////////////////////////////////////////////////////////////////////

        .mst1_aclk              (1'b0),
        .mst1_aresetn           (1'b0),
        .mst1_srst              (1'b0),
        .mst1_awvalid           (),
        .mst1_awready           (1'b1),
        .mst1_awaddr            (),
        .mst1_awlen             (),
        .mst1_awsize            (),
        .mst1_awburst           (),
        .mst1_awlock            (),
        .mst1_awcache           (),
        .mst1_awprot            (),
        .mst1_awqos             (),
        .mst1_awregion          (),
        .mst1_awid              (),
        .mst1_awuser            (),                 //NO user signal to main memory
        .mst1_wvalid            (),
        .mst1_wready            (1'b1),
        .mst1_wlast             (),
        .mst1_wdata             (),
        .mst1_wstrb             (),
        .mst1_wuser             (),
        .mst1_bvalid            (1'b0),
        .mst1_bready            (),
        .mst1_bid               (),
        .mst1_bresp             (),
        .mst1_buser             (),
        .mst1_arvalid           (),
        .mst1_arready           (1'b1),
        .mst1_araddr            (),
        .mst1_arlen             (),
        .mst1_arsize            (),
        .mst1_arburst           (),
        .mst1_arlock            (),
        .mst1_arcache           (),
        .mst1_arprot            (),
        .mst1_arqos             (),
        .mst1_arregion          (),
        .mst1_arid              (),
        .mst1_aruser            (),
        .mst1_rvalid            (1'b0),
        .mst1_rready            (),
        .mst1_rid               (),
        .mst1_rresp             (),
        .mst1_rdata             (),
        .mst1_rlast             (),
        .mst1_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 2 interface
        ///////////////////////////////////////////////////////////////////////

        .mst2_aclk              (),
        .mst2_aresetn           (),
        .mst2_srst              (),
        .mst2_awvalid           (),
        .mst2_awready           (),
        .mst2_awaddr            (),
        .mst2_awlen             (),
        .mst2_awsize            (),
        .mst2_awburst           (),
        .mst2_awlock            (),
        .mst2_awcache           (),
        .mst2_awprot            (),
        .mst2_awqos             (),
        .mst2_awregion          (),
        .mst2_awid              (),
        .mst2_awuser            (),
        .mst2_wvalid            (),
        .mst2_wready            (),
        .mst2_wlast             (),
        .mst2_wdata             (),
        .mst2_wstrb             (),
        .mst2_wuser             (),
        .mst2_bvalid            (),
        .mst2_bready            (),
        .mst2_bid               (),
        .mst2_bresp             (),
        .mst2_buser             (),
        .mst2_arvalid           (),
        .mst2_arready           (),
        .mst2_araddr            (),
        .mst2_arlen             (),
        .mst2_arsize            (),
        .mst2_arburst           (),
        .mst2_arlock            (),
        .mst2_arcache           (),
        .mst2_arprot            (),
        .mst2_arqos             (),
        .mst2_arregion          (),
        .mst2_arid              (),
        .mst2_aruser            (),
        .mst2_rvalid            (),
        .mst2_rready            (),
        .mst2_rid               (),
        .mst2_rresp             (),
        .mst2_rdata             (),
        .mst2_rlast             (),
        .mst2_ruser             (),

        ///////////////////////////////////////////////////////////////////////
        // Slave Agent 3 interface
        ///////////////////////////////////////////////////////////////////////
        .mst3_aclk              (clk_i),
        .mst3_aresetn           (!arst_i),
        .mst3_srst              (arst_i),
        .mst3_awvalid           (),
        .mst3_awready           (1'b0),
        .mst3_awaddr            (),
        .mst3_awlen             (),
        .mst3_awsize            (),
        .mst3_awburst           (),
        .mst3_awlock            (),
        .mst3_awcache           (),
        .mst3_awprot            (),
        .mst3_awqos             (),
        .mst3_awregion          (),
        .mst3_awid              (),
        .mst3_awuser            (),
        .mst3_wvalid            (),
        .mst3_wready            (1'b0),
        .mst3_wlast             (),
        .mst3_wdata             (),
        .mst3_wstrb             (),
        .mst3_wuser             (),
        .mst3_bvalid            (1'b0),
        .mst3_bready            (),
        .mst3_bid               (),
        .mst3_bresp             (),
        .mst3_buser             (),
        .mst3_arvalid           (),
        .mst3_arready           (1'b0),
        .mst3_araddr            (),
        .mst3_arlen             (),
        .mst3_arsize            (),
        .mst3_arburst           (),
        .mst3_arlock            (),
        .mst3_arcache           (),
        .mst3_arprot            (),
        .mst3_arqos             (),
        .mst3_arregion          (),
        .mst3_arid              (),
        .mst3_aruser            (),
        .mst3_rvalid            (1'b0),
        .mst3_rready            (),
        .mst3_rid               (),
        .mst3_rresp             (),
        .mst3_rdata             (),
        .mst3_rlast             (),
        .mst3_ruser             ()
);
//--------------------simulation use--------------------------------
//`ifdef SIMULATION 
//    fullv_difftest#(
//        .XLEN                   (64),
//        .PROG_FILE              (INIT_FILE)
//    )fullv_difftest(
//        .clk_i                  (clk_i),
//        .arst_i                 (arst_i),
//    //--------------dut 寄存器值输入-------------
//        .dut_ireg               (dut_ireg),
//        .dut_mepc               (dut_csr[`MRW_MEPC_INDEX]), 
//        .dut_mstatus            (dut_csr[`MRW_MSTATUS_INDEX]),
//        .dut_mtval              (dut_csr[`MRW_MTVAL_INDEX]),
//    //--------------dut 指令提交端口-------------
//        .test_commit0           (test_commit0),
//        .test_commit1           (test_commit1)
//    );
//    initial begin
//        $display("INFO:fullv-difftest now active.");
//    end
//`endif

endmodule