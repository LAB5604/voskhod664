/* when don't know how to use interface, check this file*/
module prv664_top_top(
    input wire          clk_i, arst_i,
    //-------------clint interface-----------------
    input wire          mei, sei, mti, msi,
    input wire [63:0]   mtime,
    //--------------jtag interface-----------------
    input wire          cpu_jtag_rstn,
    input wire          cpu_jtag_tms,
    input wire          cpu_jtag_tck,
    input wire          cpu_jtag_tdi,
    output wire         cpu_jtag_tdo,
    //--------------axi interface------------------
    output wire [4:0]               cpu_dbus_axi_awid,
    output wire [31:0]    		    cpu_dbus_axi_awaddr,
    output wire [7:0]               cpu_dbus_axi_awlen,
    output wire [2:0]               cpu_dbus_axi_awsize,
    output wire [1:0]               cpu_dbus_axi_awburst,
    output wire                     cpu_dbus_axi_awvalid,
    input  wire                     cpu_dbus_axi_awready,
//---------------------写数据通道-----------------------------
    output wire [63:0]  		    cpu_dbus_axi_wdata,
    output wire [7:0]  				cpu_dbus_axi_wstrb,
    output wire                     cpu_dbus_axi_wlast,
    output wire                     cpu_dbus_axi_wvalid,
    input  wire                     cpu_dbus_axi_wready,
//----------------------写回复通道-------------------------------	
    input  wire [4:0]               cpu_dbus_axi_bid,
    input  wire [1:0]               cpu_dbus_axi_bresp,
    input  wire                     cpu_dbus_axi_bvalid,
    output wire                     cpu_dbus_axi_bready,
//---------------------读地址通道-----------------------------------	
    output wire [4:0]               cpu_dbus_axi_arid,
    output wire [31:0]    		    cpu_dbus_axi_araddr,
    output wire [7:0]               cpu_dbus_axi_arlen,
    output wire [2:0]               cpu_dbus_axi_arsize,
    output wire [1:0]               cpu_dbus_axi_arburst,
    output wire                     cpu_dbus_axi_arvalid,
    input  wire                     cpu_dbus_axi_arready,
//----------------------读数据通道----------------------------------
    input  wire [4:0]               cpu_dbus_axi_rid,
    input  wire [63:0]  		    cpu_dbus_axi_rdata,
    input  wire [1:0]               cpu_dbus_axi_rresp,
    input  wire                     cpu_dbus_axi_rlast,
//  input  wire [RUSER_WIDTH-1:0]   i_AXI_ruser,
    input  wire                     cpu_dbus_axi_rvalid,
    output wire                     cpu_dbus_axi_rready,
//-------------------ibus----------------------------------
//---------------------读地址通道-----------------------------------	
    output wire [3:0]               cpu_ibus_axi_arid,
    output wire [31:0]    		    cpu_ibus_axi_araddr,
    output wire [7:0]               cpu_ibus_axi_arlen,
    output wire [2:0]               cpu_ibus_axi_arsize,
    output wire [1:0]               cpu_ibus_axi_arburst,
    output wire                     cpu_ibus_axi_arvalid,
    input  wire                     cpu_ibus_axi_arready,
//----------------------读数据通道----------------------------------
    input  wire [3:0]               cpu_ibus_axi_rid,
    input  wire [63:0]  		    cpu_ibus_axi_rdata,
    input  wire [1:0]               cpu_ibus_axi_rresp,
    input  wire                     cpu_ibus_axi_rlast,
//  input  wire [RUSER_WIDTH-1:0]   i_AXI_ruser,
    input  wire                     cpu_ibus_axi_rvalid,
    output wire                     cpu_ibus_axi_rready,
//-------------------immu------------------------------------
//---------------------读地址通道-----------------------------------	
    output wire [3:0]               cpu_immu_axi_arid,
    output wire [31:0]    		    cpu_immu_axi_araddr,
    output wire [7:0]               cpu_immu_axi_arlen,
    output wire [2:0]               cpu_immu_axi_arsize,
    output wire [1:0]               cpu_immu_axi_arburst,
    output wire                     cpu_immu_axi_arvalid,
    input  wire                     cpu_immu_axi_arready,
//----------------------读数据通道----------------------------------
    input  wire [3:0]               cpu_immu_axi_rid,
    input  wire [63:0]  		    cpu_immu_axi_rdata,
    input  wire [1:0]               cpu_immu_axi_rresp,
    input  wire                     cpu_immu_axi_rlast,
//  input  wire [RUSER_WIDTH-1:0]   i_AXI_ruser,
    input  wire                     cpu_immu_axi_rvalid,
    output wire                     cpu_immu_axi_rready,
//---------------------读地址通道-----------------------------------	
    output wire [3:0]               cpu_dmmu_axi_arid,
    output wire [31:0]    		    cpu_dmmu_axi_araddr,
    output wire [7:0]               cpu_dmmu_axi_arlen,
    output wire [2:0]               cpu_dmmu_axi_arsize,
    output wire [1:0]               cpu_dmmu_axi_arburst,
    output wire                     cpu_dmmu_axi_arvalid,
    input  wire                     cpu_dmmu_axi_arready,
//----------------------读数据通道----------------------------------
    input  wire [3:0]               cpu_dmmu_axi_rid,
    input  wire [63:0]  		    cpu_dmmu_axi_rdata,
    input  wire [1:0]               cpu_dmmu_axi_rresp,
    input  wire                     cpu_dmmu_axi_rlast,
//  input  wire [RUSER_WIDTH-1:0]   i_AXI_ruser,
    input  wire                     cpu_dmmu_axi_rvalid,
    output wire                     cpu_dmmu_axi_rready
);
clint_interface clint_interface();
assign clint_interface.mei=mei;
assign clint_interface.msi=msi;
assign clint_interface.mti=mti;
assign clint_interface.sei=sei;

axi_ar cpu_dbus_axi_ar();
assign cpu_dbus_axi_arid=cpu_dbus_axi_ar.arid;
assign cpu_dbus_axi_araddr=cpu_dbus_axi_ar.araddr;
assign cpu_dbus_axi_arlen=cpu_dbus_axi_ar.arlen;
assign cpu_dbus_axi_arsize=cpu_dbus_axi_ar.arsize;
assign cpu_dbus_axi_arburst=cpu_dbus_axi_ar.arburst;
// cpu_dbus_axi_ar.arlock;
//assign cpu_dbus_axi_ar.arcache;
//cpu_dbus_axi_ar.arprot;
//assign cpu_dbus_axi_ar.arqos;
//assign cpu_dbus_axi_ar.arregion;
assign cpu_dbus_axi_arvalid=cpu_dbus_axi_ar.arvalid;
assign cpu_dbus_axi_ar.arready=cpu_dbus_axi_arready;

axi_r cpu_dbus_axi_r();
assign cpu_dbus_axi_r.rid=cpu_dbus_axi_rid;
assign cpu_dbus_axi_r.rdata=cpu_dbus_axi_rdata;
assign cpu_dbus_axi_r.rresp=cpu_dbus_axi_rresp;
assign cpu_dbus_axi_r.rlast=cpu_dbus_axi_rlast;
assign cpu_dbus_axi_r.rvalid=cpu_dbus_axi_rvalid;
assign cpu_dbus_axi_rready= cpu_dbus_axi_r.rready;

axi_aw cpu_dbus_axi_aw();
assign cpu_dbus_axi_awid=cpu_dbus_axi_aw.awid;
assign cpu_dbus_axi_awaddr=cpu_dbus_axi_aw.awaddr;
assign cpu_dbus_axi_awlen=cpu_dbus_axi_aw.awlen;
assign cpu_dbus_axi_awsize=cpu_dbus_axi_aw.awsize;
assign cpu_dbus_axi_awburst=cpu_dbus_axi_aw.awburst;
//cpu_dbus_axi_aw.awlock;
//cpu_dbus_axi_aw.awcache;
//cpu_dbus_axi_aw.awprot;
//cpu_dbus_axi_aw.awqos;
//cpu_dbus_axi_aw.awregion;
assign cpu_dbus_axi_awvalid=cpu_dbus_axi_aw.awvalid;
assign cpu_dbus_axi_aw.awready=cpu_dbus_axi_awready;

axi_w cpu_dbus_axi_w();
assign cpu_dbus_axi_wdata=cpu_dbus_axi_w.wdata;
assign cpu_dbus_axi_wstrb=cpu_dbus_axi_w.wstrb;
assign cpu_dbus_axi_wlast=cpu_dbus_axi_w.wlast;
assign cpu_dbus_axi_wvalid=cpu_dbus_axi_w.wvalid;
assign cpu_dbus_axi_w.wready=cpu_dbus_axi_wready;

axi_b cpu_dbus_axi_b();
assign cpu_dbus_axi_b.bid = cpu_dbus_axi_bid;
assign cpu_dbus_axi_b.bresp=cpu_dbus_axi_bresp;
assign cpu_dbus_axi_b.bvalid=cpu_dbus_axi_bvalid;
assign cpu_dbus_axi_bready=cpu_dbus_axi_b.bready;

axi_ar cpu_ibus_axi_ar();
assign cpu_ibus_axi_arid=cpu_ibus_axi_ar.arid;
assign cpu_ibus_axi_araddr=cpu_ibus_axi_ar.araddr;
assign cpu_ibus_axi_arlen=cpu_ibus_axi_ar.arlen;
assign cpu_ibus_axi_arsize=cpu_ibus_axi_ar.arsize;
assign cpu_ibus_axi_arburst=cpu_ibus_axi_ar.arburst;
// cpu_ibus_axi_ar.arlock;
//assign cpu_ibus_axi_ar.arcache;
//cpu_ibus_axi_ar.arprot;
//assign cpu_ibus_axi_ar.arqos;
//assign cpu_ibus_axi_ar.arregion;
assign cpu_ibus_axi_arvalid=cpu_ibus_axi_ar.arvalid;
assign cpu_ibus_axi_ar.arready=cpu_ibus_axi_arready;

axi_r cpu_ibus_axi_r();
assign cpu_ibus_axi_r.rid=cpu_ibus_axi_rid;
assign cpu_ibus_axi_r.rdata=cpu_ibus_axi_rdata;
assign cpu_ibus_axi_r.rresp=cpu_ibus_axi_rresp;
assign cpu_ibus_axi_r.rlast=cpu_ibus_axi_rlast;
assign cpu_ibus_axi_r.rvalid=cpu_ibus_axi_rvalid;
assign cpu_ibus_axi_rready= cpu_ibus_axi_r.rready;

axi_ar cpu_dmmu_axi_ar();
assign cpu_dmmu_axi_arid=cpu_dmmu_axi_ar.arid;
assign cpu_dmmu_axi_araddr=cpu_dmmu_axi_ar.araddr;
assign cpu_dmmu_axi_arlen=cpu_dmmu_axi_ar.arlen;
assign cpu_dmmu_axi_arsize=cpu_dmmu_axi_ar.arsize;
assign cpu_dmmu_axi_arburst=cpu_dmmu_axi_ar.arburst;
// cpu_dmmu_axi_ar.arlock;
//assign cpu_dmmu_axi_ar.arcache;
//cpu_dmmu_axi_ar.arprot;
//assign cpu_dmmu_axi_ar.arqos;
//assign cpu_dmmu_axi_ar.arregion;
assign cpu_dmmu_axi_arvalid=cpu_dmmu_axi_ar.arvalid;
assign cpu_dmmu_axi_ar.arready=cpu_dmmu_axi_arready;

axi_r cpu_dmmu_axi_r();
assign cpu_dmmu_axi_r.rid=cpu_dmmu_axi_rid;
assign cpu_dmmu_axi_r.rdata=cpu_dmmu_axi_rdata;
assign cpu_dmmu_axi_r.rresp=cpu_dmmu_axi_rresp;
assign cpu_dmmu_axi_r.rlast=cpu_dmmu_axi_rlast;
assign cpu_dmmu_axi_r.rvalid=cpu_dmmu_axi_rvalid;
assign cpu_dmmu_axi_rready= cpu_dmmu_axi_r.rready;

axi_ar cpu_immu_axi_ar();
assign cpu_immu_axi_arid=cpu_immu_axi_ar.arid;
assign cpu_immu_axi_araddr=cpu_immu_axi_ar.araddr;
assign cpu_immu_axi_arlen=cpu_immu_axi_ar.arlen;
assign cpu_immu_axi_arsize=cpu_immu_axi_ar.arsize;
assign cpu_immu_axi_arburst=cpu_immu_axi_ar.arburst;
// cpu_immu_axi_ar.arlock;
//assign cpu_immu_axi_ar.arcache;
//cpu_immu_axi_ar.arprot;
//assign cpu_immu_axi_ar.arqos;
//assign cpu_immu_axi_ar.arregion;
assign cpu_immu_axi_arvalid=cpu_immu_axi_ar.arvalid;
assign cpu_immu_axi_ar.arready=cpu_immu_axi_arready;

axi_r cpu_immu_axi_r();
assign cpu_immu_axi_r.rid=cpu_immu_axi_rid;
assign cpu_immu_axi_r.rdata=cpu_immu_axi_rdata;
assign cpu_immu_axi_r.rresp=cpu_immu_axi_rresp;
assign cpu_immu_axi_r.rlast=cpu_immu_axi_rlast;
assign cpu_immu_axi_r.rvalid=cpu_immu_axi_rvalid;
assign cpu_immu_axi_rready= cpu_immu_axi_r.rready;

prv664_top      core(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    .clint_sif              (clint_interface),
    //-----------------core jtag interface-----------------
    .cpu_jtag_rstn          (cpu_jtag_rstn),
    .cpu_jtag_tms           (cpu_jtag_tms),
    .cpu_jtag_tck           (cpu_jtag_tck),
    .cpu_jtag_tdi           (cpu_jtag_tdi),
    .cpu_jtag_tdo           (cpu_jtag_tdo),
    //------------------axi--------------------------------
    .cpu_dbus_axi_ar        (cpu_dbus_axi_ar),
    .cpu_dbus_axi_r         (cpu_dbus_axi_r),
    .cpu_dbus_axi_aw        (cpu_dbus_axi_aw),
    .cpu_dbus_axi_w         (cpu_dbus_axi_w),
    .cpu_dbus_axi_b         (cpu_dbus_axi_b),
    .cpu_ibus_axi_ar        (cpu_ibus_axi_ar),
    .cpu_ibus_axi_r         (cpu_ibus_axi_r),
    //------------------mmu access--------------------------
    .cpu_immu_axi_ar        (cpu_immu_axi_ar),
    .cpu_immu_axi_r         (cpu_immu_axi_r),
    .cpu_dmmu_axi_ar        (cpu_dmmu_axi_ar),
    .cpu_dmmu_axi_r         (cpu_dmmu_axi_r)
);


endmodule