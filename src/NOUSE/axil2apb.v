module axil2apb#(
    parameter AWID = 32,
              AXIL_DWID = 64,
              AXIL_STRB_WIDTH = AXIL_DWID/8,
              APB_DWID = 8
)(
    input wire                          clk_i,
    input wire                          rst_i,
    //----------axi lite-----------
    input wire [AWID-1:0]             s_axil_awaddr,
    input wire [2:0]                  s_axil_awprot,
    input wire                        s_axil_awvalid,
    output wire                        s_axil_awready,
    input wire [AXIL_DWID-1:0]        s_axil_wdata,
    input wire [AXIL_STRB_WIDTH-1:0]  s_axil_wstrb,
    input wire                        s_axil_wvalid,
    output wire                        s_axil_wready,
    output wire [1:0]                  s_axil_bresp,
    output wire                        s_axil_bvalid,
    input wire                        s_axil_bready,
    input wire [AWID-1:0]             s_axil_araddr,
    input wire [2:0]                  s_axil_arprot,
    input wire                        s_axil_arvalid,
    output wire                        s_axil_arready,
    output wire [AXIL_DWID-1:0]        s_axil_rdata,
    output wire [1:0]                  s_axil_rresp,
    output wire                        s_axil_rvalid,
    input wire                        s_axil_rready,
    //----------------apb interface-------------------
    input wire                        psel,   penable, pwrite,
    input wire [APB_DWID:0]           pwdata,
    input wire [AWID-1:0]             paddr,
    input wire                         pready, pslverr,
    input wire  [APB_DWID:0]           prdata

);
localparam LOOP_COUNT = AXIL_DWID/APB_DWID,
           STATE_IDLE = 4'h0,
           STATE_AW   = 4'h1,//receive address from aw channel
           STATE_W    = 4'h2,//receive data from w channel
           STATE_WRITE= 4'h3,//perform write access to apb bus
           STATE_B    = 4'h4,//response to axi-lite bus
           STATE_AR   = 4'h5,//receive address from ar channel
           STATE_READ = 4'h6,//perform read access to apb bus
           STATE_R    = 4'h7;//response to axi-lite bus
localparam APB_STATE_IDLE = 2'h0,
           APB_STATE_SETUP=2'h1,
           APB_STATE_ENABLE=2'h2;

//------------axi-lite access register-------------
reg [AXIL_DWID-1:0]     axil_awdata, axil_ardata;
reg [AWID-1:0]          axil_awaddr, axil_araddr;
reg [AXIL_STRB_WIDTH-1:0] axil_wstrb;
//------------APB access control FSM-----------
reg [1:0] apb_state, apb_state_next;
reg       access_next, access_finial;
reg [3:0] access_count;
//------------FSM---------------
reg [3:0] state, state_next;

always @(posedge clk_i) begin
    if(rst_i)begin
        state <= STATE_IDLE;
    end else begin
        state <= state_next;
    end
end

always@(*)begin
    case(state)
        STATE_IDLE : state_next <= s_axil_awvalid ? STATE_AW : s_axil_arvalid ? STATE_AR : state;
        STATE_AW   : state_next <= STATE_W;
        STATE_W    : state_next <= s_axil_wvalid ? STATE_WRITE : state;
        STATE_WRITE: state_next <= access_finial ? STATE_B : state;
        STATE_B    : state_next <= s_axil_bready ? STATE_IDLE : state;
        STATE_AR   : state_next <= STATE_READ;
        STATE_READ : state_next <= access_finial ? STATE_R : state;
        STATE_R    : state_next <= s_axil_rready ? STATE_IDLE : state;
        default:
    endcase
end
//---------------APB state machine---------------
always @(posedge clk_i) begin
    if(rst_i)begin
        apb_state <= APB_STATE_IDLE;
    end else begin
        apb_state <= apb_state_next;
    end
end
always@(*)begin
    case(apb_state)
        APB_STATE_IDLE:begin
            if((state==STATE_READ)|(state==STATE_WRITE))begin
                apb_state_next = access_next ? APB_STATE_IDLE : APB_STATE_SETUP;
            end else begin
                apb_state_next = APB_STATE_IDLE;
            end
        end
        APB_STATE_SETUP: apb_state_next = APB_STATE_ENABLE;
        APB_STATE_ENABLE:apb_state_next = pready ? APB_STATE_IDLE : apb_state; 
        default:
    endcase
end
//产生access_next信号，此信号用于指示进入下一个访问或者跳过当前访问
always@(*)begin
    if(state==STATE_READ)begin
        access_next = (apb_state==APB_STATE_ENABLE)&pready;
    end else if(state==STATE_WRITE)begin
        access_next = (apb_state==APB_STATE_ENABLE)&pready | (!axil_wstrb[access_count]);
    end
end
//产生access final信号，此信号用于指示是否已经完成访问
always@(*)begin
    if(access_next & (access_count==LOOP_COUNT-1))begin
        access_finial = 1;
    end else begin
        access_finial = 0;
    end
end

endmodule