module axi_axil_bridge_rd #
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
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]       m_axil_araddr,
    output wire [2:0]                  m_axil_arprot,
    output wire                        m_axil_arvalid,
    input  wire                        m_axil_arready,
    input  wire [AXIL_DATA_WIDTH-1:0]  m_axil_rdata,
    input  wire [1:0]                  m_axil_rresp,
    input  wire                        m_axil_rvalid,
    output wire                        m_axil_rready
);

parameter AXI_ADDR_BIT_OFFSET = $clog2(AXI_STRB_WIDTH);
parameter AXIL_ADDR_BIT_OFFSET = $clog2(AXIL_STRB_WIDTH);

parameter STATE_WF_AR = 'h0,      //wait for ar from axi 
          STATE_AR    = 'h2,   //generate ar to axi-lite
          STATE_WF_R  = 'h4, //wait for r from axi-lite
          STATE_R     = 'h5, //generate r to axi
          STATE_ERR   = 'h7;//generate r with error to axi

reg [AXI_ID_WIDTH-1:0]      axi_id_reg; //store axi id when have axi access
reg [7:0]                   axi_arlen_reg;
reg [2:0]                   axi_arsize_reg;
reg [1:0]                   axi_arburst_reg;
reg [ADDR_WIDTH-1:0]        axi_addr_reg;

reg [1:0]                   axil_rresp_reg;
reg [AXIL_DATA_WIDTH-1:0]   axil_data_reg;

reg [3:0] state, state_next;

wire invalid_access;

//------------------state machine---------------------
always@(*)begin
    case(state)
        STATE_WF_AR:state_next = (s_axi_arvalid&invalid_access)? STATE_ERR: s_axi_arvalid ? STATE_AR : state;
        STATE_AR   :state_next = m_axil_arready ? STATE_WF_R : state;
        STATE_WF_R :state_next = m_axil_rvalid ? STATE_R : state;
        STATE_R    :state_next = s_axi_rready ? STATE_WF_AR : state;
        STATE_ERR  :state_next = s_axi_rready ? STATE_WF_AR : state;
        default: state_next = STATE_WF_AR;
    endcase
end
always@(posedge clk)begin
    if(rst)begin
        state <= STATE_WF_AR;
    end else begin
        state <= state_next;
    end
end
//----------------state machine end---------------------
always@(posedge clk)begin
    if(state==STATE_WF_AR)begin     //等待axi aw状态下将axi总线的aw信号全部缓冲
        axi_addr_reg <= s_axi_araddr;
        axi_id_reg   <= s_axi_arid;
        axi_arlen_reg <= s_axi_arlen;
        axi_arsize_reg<= s_axi_arsize;
        axi_arburst_reg<=s_axi_arburst;
    end
    if(state==STATE_WF_R)begin
        axil_rresp_reg<= m_axil_rresp;
        axil_data_reg <= m_axil_rdata;
    end
end

assign invalid_access = (axi_arlen_reg != 'd0) & (axi_arburst_reg!=2'b01);//FIXME: 没有检查awsize的值是否正确，会导致单拍访问的时候丢数据
//-----------------to axi-lite bus-------------------
//ar channel
assign m_axil_araddr = axi_addr_reg;
assign m_axil_arvalid= (state==STATE_AR);
//r channel
assign m_axil_rready = (state==STATE_R);
//-----------------to axi bus------------------------
//r channel
assign s_axi_rvalid = (state==STATE_R);
assign s_axi_rlast = s_axi_rvalid;  //only read one beat of data
assign s_axi_rid = axi_id_reg;
generate
    if(AXI_DATA_WIDTH > AXIL_DATA_WIDTH)begin: axi_ge_axil
        assign s_axi_rdata = axil_data_reg << (axi_addr_reg[AXI_ADDR_BIT_OFFSET-1:AXIL_ADDR_BIT_OFFSET] * AXIL_DATA_WIDTH);
    end else if(AXI_DATA_WIDTH==AXIL_DATA_WIDTH)begin:axi_eq_axil 
        assign s_axi_rdata = axil_data_reg;
    end else begin: axi_le_axil
        assign s_axi_rdata = axil_data_reg >> (axi_addr_reg[AXIL_ADDR_BIT_OFFSET-1:AXI_ADDR_BIT_OFFSET] * AXI_DATA_WIDTH);
    end
endgenerate
assign s_axi_rresp = (state==STATE_R)?axil_rresp_reg:(state==STATE_ERR)?2'b10:2'b00;
//ar channel
assign s_axi_arready = (state==STATE_WF_AR);

endmodule