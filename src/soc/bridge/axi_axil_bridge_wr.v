module axi_axil_bridge_wr #
(
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of input (slave) AXI interface data bus in bits
    parameter AXI_DATA_WIDTH = 32,
    // Width of input (slave) AXI interface wstrb (width of data bus in words)
    parameter AXI_STRB_WIDTH = (AXI_DATA_WIDTH/8),
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8,
    // Width of output (master) AXI lite interface data bus in bits
    parameter AXIL_DATA_WIDTH = 32,
    // Width of output (master) AXI lite interface wstrb (width of data bus in words)
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    // When adapting to a wider bus, re-pack full-width burst instead of passing through narrow burst if possible
    parameter CONVERT_BURST = 1,
    // When adapting to a wider bus, re-pack all bursts instead of passing through narrow burst if possible
    parameter CONVERT_NARROW_BURST = 0
)
(
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

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]       m_axil_awaddr,
    output wire [2:0]                  m_axil_awprot,
    output wire                        m_axil_awvalid,
    input  wire                        m_axil_awready,
    output wire [AXIL_DATA_WIDTH-1:0]  m_axil_wdata,
    output wire [AXIL_STRB_WIDTH-1:0]  m_axil_wstrb,
    output wire                        m_axil_wvalid,
    input  wire                        m_axil_wready,
    input  wire [1:0]                  m_axil_bresp,
    input  wire                        m_axil_bvalid,
    output wire                        m_axil_bready
);

parameter AXI_ADDR_BIT_OFFSET = $clog2(AXI_STRB_WIDTH);
parameter AXIL_ADDR_BIT_OFFSET = $clog2(AXIL_STRB_WIDTH);

parameter STATE_WF_AW = 'h0,      //wait for aw from axi 
          STATE_WF_W  = 'h1,   //wait for w from axi
          STATE_AW    = 'h2,   //generate aw to axi-lite
          STATE_W     = 'h3, // generate w to axi-lite
          STATE_WF_B  = 'h4, //wait for b from axi-lite
          STATE_B     = 'h5, //generate b to axi
          STATE_ERR   = 'h7;

reg [AXI_ID_WIDTH-1:0]      axi_id_reg; //store axi id when have axi access
reg [7:0]                   axi_awlen_reg;
reg [2:0]                   axi_awsize_reg;
reg [1:0]                   axi_awburst_reg;
reg [AXI_DATA_WIDTH-1:0]    axi_data_reg;
reg [ADDR_WIDTH-1:0]        axi_addr_reg;
reg [AXI_STRB_WIDTH-1:0]    axi_strb_reg;
reg [1:0]                   axil_bresp_reg;

reg [3:0] state, state_next;

wire invalid_access;

//------------------state machine---------------------
always@(*)begin
    case(state)
        STATE_WF_AW:state_next = s_axi_awvalid ? STATE_WF_W : state;
        STATE_WF_W :state_next = (s_axi_wvalid&invalid_access) ? STATE_ERR : s_axi_wvalid ? STATE_AW : state;
        STATE_AW   :state_next = m_axil_awready ? STATE_W : state;
        STATE_W    :state_next = m_axil_wready ? STATE_WF_B : state;
        STATE_WF_B :state_next = m_axil_bvalid ? STATE_B : state;
        STATE_B    :state_next = s_axi_bready ? STATE_WF_AW : state;
        STATE_ERR  :state_next = s_axi_bready ? STATE_WF_AW : state;
        default: state_next = STATE_WF_AW;
    endcase
end
always@(posedge clk)begin
    if(rst)begin
        state <= STATE_WF_AW;
    end else begin
        state <= state_next;
    end
end
//----------------state machine end---------------------
always@(posedge clk)begin
    if(state==STATE_WF_AW)begin     //等待axi aw状态下将axi总线的aw信号全部缓冲
        axi_addr_reg <= s_axi_awaddr;
        axi_id_reg   <= s_axi_awid;
        axi_awlen_reg <= s_axi_awlen;
        axi_awsize_reg<= s_axi_awsize;
        axi_awburst_reg<=s_axi_awburst;
    end
    if(state==STATE_WF_W)begin      //等待axi w状态下将axi总线的w信号全部缓冲
        axi_data_reg <= s_axi_wdata;
        axi_strb_reg <= s_axi_wstrb;
    end
    if(state==STATE_WF_B)begin
        axil_bresp_reg <= m_axil_bresp;
    end
end
assign invalid_access = (axi_awlen_reg != 'd0) & (axi_awburst_reg!=2'b01);//FIXME: 没有检查awsize的值是否正确，会导致单拍访问的时候丢数据
//-----------------------to axi-lite bus----------------------
//w channel
generate 
    if(AXI_DATA_WIDTH > AXIL_DATA_WIDTH)begin:axi_gt_axil
        assign m_axil_wdata = axi_data_reg>>(axi_addr_reg[AXI_ADDR_BIT_OFFSET-1:AXIL_ADDR_BIT_OFFSET] * AXIL_DATA_WIDTH);
        assign m_axil_wstrb = axi_strb_reg>>(axi_addr_reg[AXI_ADDR_BIT_OFFSET-1:AXIL_ADDR_BIT_OFFSET] * AXIL_STRB_WIDTH);
    end else if(AXI_DATA_WIDTH==AXIL_DATA_WIDTH)begin:axi_eq_axil
        assign m_axil_wdata = axi_data_reg;
        assign m_axil_wstrb = axi_strb_reg;
    end else begin:axi_le_axil
        assign m_axil_wdata = axi_data_reg<<(axi_addr_reg[AXIL_ADDR_BIT_OFFSET-1:AXI_ADDR_BIT_OFFSET] * AXI_DATA_WIDTH);
        assign m_axil_wstrb = axi_strb_reg<<(axi_addr_reg[AXIL_ADDR_BIT_OFFSET-1:AXI_ADDR_BIT_OFFSET] * AXI_STRB_WIDTH);
    end
endgenerate
assign m_axil_wvalid = (state==STATE_W);
//aw channel
assign m_axil_awaddr = axi_addr_reg;
assign m_axil_awvalid= (state==STATE_AW);
//b channel
assign m_axil_bready = (state==STATE_WF_B);

//------------------------to axi bus----------------------------
//aw channel
assign s_axi_awready = (state==STATE_WF_AW);
//w channel
assign s_axi_wready = (state==STATE_WF_W);
//b channel
assign s_axi_bresp = (state==STATE_B)?axil_bresp_reg:(state==STATE_ERR)?2'b10:2'b00;
assign s_axi_bid = axi_id_reg;
assign s_axi_bvalid = (state==STATE_B);

endmodule
