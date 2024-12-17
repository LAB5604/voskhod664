module axi_apb8_bridge #
(
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of input (slave) AXI interface data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of input (slave) AXI interface wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8
)(
    input  wire                        clk,
    input  wire                        rst,

    /*
     * AXI slave interface
     */
    input  wire [AXI_ID_WIDTH-1:0]     s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  wire [7:0]                  s_axi_awlen,
    input  wire [2:0]                  s_axi_awsize,
    input  wire [1:0]                  s_axi_awburst,
    input  wire                        s_axi_awlock,
    input  wire [3:0]                  s_axi_awcache,
    input  wire [2:0]                  s_axi_awprot,
    input  wire                        s_axi_awvalid,
    output wire                        s_axi_awready,
    input  wire [AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [AXI_STRB_WIDTH-1:0]   s_axi_wstrb,
    input  wire                        s_axi_wlast,
    input  wire                        s_axi_wvalid,
    output wire                        s_axi_wready,
    output wire [AXI_ID_WIDTH-1:0]     s_axi_bid,
    output wire [1:0]                  s_axi_bresp,
    output wire                        s_axi_bvalid,
    input  wire                        s_axi_bready,
    input  wire [AXI_ID_WIDTH-1:0]     s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire [7:0]                  s_axi_arlen,
    input  wire [2:0]                  s_axi_arsize,
    input  wire [1:0]                  s_axi_arburst,
    input  wire                        s_axi_arlock,
    input  wire [3:0]                  s_axi_arcache,
    input  wire [2:0]                  s_axi_arprot,
    input  wire                        s_axi_arvalid,
    output wire                        s_axi_arready,
    output wire [AXI_ID_WIDTH-1:0]     s_axi_rid,
    output wire [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output wire [1:0]                  s_axi_rresp,
    output wire                        s_axi_rlast,
    output wire                        s_axi_rvalid,
    input  wire                        s_axi_rready,

    /*
     * apb interface
     */
    output wire                        psel,   penable, pwrite,
    output wire [7:0]                  pwdata,
    output wire [ADDR_WIDTH-1:0]       paddr,
    input wire                         pready, pslverr,
    input wire  [7:0]                  prdata
);
    localparam AXIL_DATA_WIDTH = 8,
               AXIL_STRB_WIDTH = AXIL_DATA_WIDTH/8;

    wire [ADDR_WIDTH-1:0]           inter_axil_awaddr;
    wire [2:0]                      inter_axil_awprot;
    wire                            inter_axil_awvalid;
    wire                            inter_axil_awready;
    wire [AXIL_DATA_WIDTH-1:0]      inter_axil_wdata;
    wire [AXIL_STRB_WIDTH:0]        inter_axil_wstrb;
    wire                            inter_axil_wvalid;
    wire                            inter_axil_wready;
    wire [1:0]                      inter_axil_bresp;
    wire                            inter_axil_bvalid;
    wire                            inter_axil_bready;
    wire [ADDR_WIDTH:0]             inter_axil_araddr;
    wire [2:0]                      inter_axil_arprot;
    wire                            inter_axil_arvalid;
    wire                            inter_axil_arready;
    wire [AXIL_DATA_WIDTH:0]        inter_axil_rdata;
    wire [1:0]                      inter_axil_rresp;
    wire                            inter_axil_rvalid;
    wire                            inter_axil_rready;

    wire [ADDR_WIDTH-1:0]           reg_wr_addr;
    wire [AXIL_DATA_WIDTH-1:0]      reg_wr_data;
    wire [AXIL_STRB_WIDTH-1:0]      reg_wr_strb;
    wire                            reg_wr_en;
    wire                            reg_wr_wait;
    wire                            reg_wr_ack;
    wire [ADDR_WIDTH-1:0]           reg_rd_addr;
    wire                            reg_rd_en;
    wire [AXIL_DATA_WIDTH-1:0]      reg_rd_data;
    wire                            reg_rd_wait;
    wire                            reg_rd_ack;
axi_axil_adapter#(
    // Width of address bus in bits
    .ADDR_WIDTH                 (ADDR_WIDTH),
    // Width of input (slave) AXI interface data bus in bits
    .AXI_DATA_WIDTH             (AXI_DATA_WIDTH),
    // Width of input (slave) AXI interface wstrb (width of data bus in words)
    //.AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    .AXI_ID_WIDTH               (AXI_ID_WIDTH),
    // Width of output (master) AXI lite interface data bus in bits
    .AXIL_DATA_WIDTH            (8)             //convert axi to 8bit axi-lite
    // Width of output (master) AXI lite interface wstrb (width of data bus in words)
    //.AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // When adapting to a wider bus, re-pack full-width burst instead of passing through narrow burst if possible
    //.CONVERT_BURST = 1,
    // When adapting to a wider bus, re-pack all bursts instead of passing through narrow burst if possible
    //.CONVERT_NARROW_BURST = 0
)axi_axil_bridge(
    .clk                        (main_clk),
    .rst                        (main_rst),
    /*
     * AXI slave interface
     */
    .s_axi_awid                 (s_axi_awid),
    .s_axi_awaddr               (s_axi_awaddr),
    .s_axi_awlen                (s_axi_awlen),
    .s_axi_awsize               (s_axi_awsize),
    .s_axi_awburst              (s_axi_awburst),
    .s_axi_awlock               (s_axi_awlock),
    .s_axi_awcache              (s_axi_awcache),
    .s_axi_awprot               (s_axi_awprot),
    .s_axi_awvalid              (s_axi_awvalid),
    .s_axi_awready              (s_axi_awready),
    .s_axi_wdata                (s_axi_wdata),
    .s_axi_wstrb                (s_axi_wstrb),
    .s_axi_wlast                (s_axi_wlast),
    .s_axi_wvalid               (s_axi_wvalid),
    .s_axi_wready               (s_axi_wready),
    .s_axi_bid                  (s_axi_bid),
    .s_axi_bresp                (s_axi_bresp),
    .s_axi_bvalid               (s_axi_bvalid),
    .s_axi_bready               (s_axi_bready),
    .s_axi_arid                 (s_axi_arid),
    .s_axi_araddr               (s_axi_araddr),
    .s_axi_arlen                (s_axi_arlen),
    .s_axi_arsize               (s_axi_arsize),
    .s_axi_arburst              (s_axi_arburst),
    .s_axi_arlock               (s_axi_arlock),
    .s_axi_arcache              (s_axi_arcache),
    .s_axi_arprot               (s_axi_arprot),
    .s_axi_arvalid              (s_axi_arvalid),
    .s_axi_arready              (s_axi_arready),
    .s_axi_rid                  (s_axi_rid),
    .s_axi_rdata                (s_axi_rdata),
    .s_axi_rresp                (s_axi_rresp),
    .s_axi_rlast                (s_axi_rlast),
    .s_axi_rvalid               (s_axi_rvalid),
    .s_axi_rready               (s_axi_rready),

    /*
     * AXI lite master interface
     */
    .m_axil_awaddr              (inter_axil_awaddr),
    .m_axil_awprot              (inter_axil_awprot),
    .m_axil_awvalid             (inter_axil_awvalid),
    .m_axil_awready             (inter_axil_awready),
    .m_axil_wdata               (inter_axil_wdata),
    .m_axil_wstrb               (inter_axil_wstrb),
    .m_axil_wvalid              (inter_axil_wvalid),
    .m_axil_wready              (inter_axil_wready),
    .m_axil_bresp               (inter_axil_bresp),
    .m_axil_bvalid              (inter_axil_bvalid),
    .m_axil_bready              (inter_axil_bready),
    .m_axil_araddr              (inter_axil_araddr),
    .m_axil_arprot              (inter_axil_arprot),
    .m_axil_arvalid             (inter_axil_arvalid),
    .m_axil_arready             (inter_axil_arready),
    .m_axil_rdata               (inter_axil_rdata),
    .m_axil_rresp               (inter_axil_rresp),
    .m_axil_rvalid              (inter_axil_rvalid),
    .m_axil_rready              (inter_axil_rready)
);

axil_reg_if#(
    // Width of data bus in bits
    .DATA_WIDTH             (8),
    // Width of address bus in bits
    .ADDR_WIDTH             (ADDR_WIDTH),
    // Width of wstrb (width of data bus in words)
    // Timeout delay (cycles)
    .TIMEOUT                (64)            //TODO: 有些外设可能需要更多的超时时间，修改这里
)axil_reg(
    .clk                        (clk),
    .rst                        (rst),
    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr              (inter_axil_awaddr),
    .s_axil_awprot              (inter_axil_awprot),
    .s_axil_awvalid             (inter_axil_awvalid),
    .s_axil_awready             (inter_axil_awready),
    .s_axil_wdata               (inter_axil_wdata),
    .s_axil_wstrb               (inter_axil_wstrb),
    .s_axil_wvalid              (inter_axil_wvalid),
    .s_axil_wready              (inter_axil_wready),
    .s_axil_bresp               (inter_axil_bresp),
    .s_axil_bvalid              (inter_axil_bvalid),
    .s_axil_bready              (inter_axil_bready),
    .s_axil_araddr              (inter_axil_araddr),
    .s_axil_arprot              (inter_axil_arprot),
    .s_axil_arvalid             (inter_axil_arvalid),
    .s_axil_arready             (inter_axil_arready),
    .s_axil_rdata               (inter_axil_rdata),
    .s_axil_rresp               (inter_axil_rresp),
    .s_axil_rvalid              (inter_axil_rvalid),
    .s_axil_rready              (inter_axil_rready),
    /*
     * Register interface
     */
    .reg_wr_addr                (reg_wr_addr),
    .reg_wr_data                (reg_wr_data),
    .reg_wr_strb                (reg_wr_strb),
    .reg_wr_en                  (reg_wr_en),
    .reg_wr_wait                (reg_wr_wait),
    .reg_wr_ack                 (reg_wr_ack),
    .reg_rd_addr                (reg_rd_addr),
    .reg_rd_en                  (reg_rd_en),
    .reg_rd_data                (reg_rd_data),
    .reg_rd_wait                (reg_rd_wait),
    .reg_rd_ack                 (reg_rd_ack)
);
regif_apb#(
    // Width of data bus in bits
    .DATA_WIDTH     (AXIL_DATA_WIDTH),
    // Width of address bus in bits
    .ADDR_WIDTH     (ADDR_WIDTH)
)regif_apb(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    //   reg interface
    .reg_wr_addr                (reg_wr_addr),
    .reg_wr_data                (reg_wr_data),
    .reg_wr_strb                (reg_wr_strb),
    .reg_wr_en                  (reg_wr_en),
    .reg_wr_wait                (reg_wr_wait),
    .reg_wr_ack                 (reg_wr_ack),
    .reg_rd_addr                (reg_rd_addr),
    .reg_rd_en                  (reg_rd_en),
    .reg_rd_data                (reg_rd_data),
    .reg_rd_wait                (reg_rd_wait),
    .reg_rd_ack                 (reg_rd_ack),
    //   apb interface
    .psel                       (psel),
    .penable                    (penable), 
    .pwrite                     (pwrite),
    .pwdata                     (pwdata),
    .paddr                      (paddr),
    .pready                     (pready), 
    .pslverr                    (pslverr),
    .prdata                     (prdata)
);
endmodule