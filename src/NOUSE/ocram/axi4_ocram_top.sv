module axi4_ocram_top#(
    parameter   ID_WIDTH = 8,   //NO touch
                DATA_WIDTH=64,  //NO touch
                ADDR_WIDTH=32,  //NO touch
                STRB_WIDTH=(DATA_WIDTH/8)
)(
    input wire clk, rst,
    /******** AXI总线信号 ********/
    //写地址通道
	input      [ID_WIDTH-1:0]   awid,
	input	   [ADDR_WIDTH-1:0] awaddr,
	input	   [7:0]            awlen,
	input	   [2:0]            awsize,
	input	   [1:0]	        awburst,
//	input	  	                awlock,
//	input	   [3:0]	        awcache,
//	input	   [2:0]	        awprot,
//	input	   [3:0]	        awqos,
//	input	   [3:0]            awregion,
//	input	   [USER_WIDTH-1:0]	awuser,
	input	 	                awvalid,
	output    	                awready,
	//写数据通道                
//	input	   [ID_WIDTH-1:0]   wid,
	input	   [DATA_WIDTH-1:0] wdata,
	input	   [STRB_WIDTH-1:0] wstrb,
	input		                wlast,
//	input	   [USER_WIDTH-1:0]	wuser,
	input	  	                wvalid,
	output    	                wready,
	//写响应通道                
	output     [ID_WIDTH-1:0]   bid,
	output     [1:0]            bresp,
//	output     [USER_WIDTH-1:0]	buser,
	output    	                bvalid,
	input	  	                bready,
	//读地址地址                
	input	   [ID_WIDTH-1:0]   arid,
	input	   [ADDR_WIDTH-1:0] araddr,
	input	   [7:0]            arlen,
	input	   [2:0]	        arsize,
	input	   [1:0]	        arburst,
//	input	  	                arlock,
//	input	   [3:0]	        arcache,
//	input	   [2:0]            arprot,
//	input	   [3:0]	        arqos,
//	input	   [3:0]	        arregion,
//	input	   [USER_WIDTH-1:0]	aruser,
	input	  	                arvalid,
	output    	                arready,
	//读数据通道                
	output     [ID_WIDTH-1:0]	rid,
	output     [DATA_WIDTH-1:0]	rdata,
	output     [1:0]	        rresp,
	output    	                rlast,
//	output     [USER_WIDTH-1:0] ruser,
	output                      rvalid,
	input	 	                rready,
    //             sramc interface
    output wire                 sram_cs,
    output wire                 sram_we,
    output wire [ADDR_WIDTH-1:0]sram_addr,
    output wire [7:0]			sram_din,
    input  wire [7:0]			sram_dout
);
    wire [31:0] paddr;
    wire [7:0]  pwdata, prdata;
    wire        penable, psel, pstrb, pwrite, pready;
mkaxi64apb8_bridge          bridge(
    .CLK                (clk),
	.RST_N              (!rst),

	.AXI4_AWVALID       (awvalid),
	.AXI4_AWID          (awid),
	.AXI4_AWADDR        (awaddr),
	.AXI4_AWLEN         (awlen),
	.AXI4_AWSIZE        (awsize),
	.AXI4_AWBURST       (awburst),
	.AXI4_AWLOCK        (0),
	.AXI4_AWCACHE       (0),
	.AXI4_AWPROT        (0),
	.AXI4_AWQOS         (0),
	.AXI4_AWREGION      (0),
	.AXI4_AWREADY       (awready),

	.AXI4_WVALID        (wvalid),
	.AXI4_WDATA         (wdata),
	.AXI4_WSTRB         (wstrb),
	.AXI4_WLAST         (wlast),
	.AXI4_WREADY        (wready),

	.AXI4_BVALID        (bvalid),
	.AXI4_BID           (bid),
	.AXI4_BRESP         (bresp),
	.AXI4_BREADY        (bready),

	.AXI4_ARVALID       (arvalid),
	.AXI4_ARID          (arid),
	.AXI4_ARADDR        (araddr),
	.AXI4_ARLEN         (arlen),
	.AXI4_ARSIZE        (arsize),
	.AXI4_ARBURST       (arburst),
	.AXI4_ARLOCK        (0),
	.AXI4_ARCACHE       (0),
	.AXI4_ARPROT        (0),
	.AXI4_ARQOS         (0),
	.AXI4_ARREGION      (0),
	.AXI4_ARREADY       (arready),

	.AXI4_RVALID        (rvalid),
	.AXI4_RID           (rid),
	.AXI4_RDATA         (rdata),
	.AXI4_RRESP         (rresp),
	.AXI4_RLAST         (rlast),
	.AXI4_RREADY        (rready),

	.APB_PADDR          (paddr),
	.APB_PROT           (),
	.APB_PENABLE        (penable),
	.APB_PWRITE         (pwrite),
	.APB_PWDATA         (pwdata),
	.APB_PSTRB          (pstrb),
	.APB_PSEL           (psel),
	.APB_PREADY         (pready),
	.APB_PRDATA         (prdata),
	.APB_PSLVERR        (0)
);
apb_sramc			sramc(
    .clk                (clk),
    .rstn               (!rst),
    .psel               (psel),
    .penable            (penable),
    .paddr              (paddr),
    .pwrite             (pwrite),
    .pwdata             (pwdata),
    .pready             (pready),
    .prdata             (prdata),
    //----------sram interface---------------
    .sram_cs            (sram_cs),
    .sram_we            (sram_we),
    .sram_addr          (sram_addr),
    .sram_din           (sram_din),
    .sram_dout          (sram_dout)
);
endmodule