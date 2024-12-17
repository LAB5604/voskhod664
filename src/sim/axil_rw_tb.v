`include "timescale.v"
/*****************************************************
        axi lite simple read/write test tb
    generate 1 read 1write test to check axil design
********************************************************/
module axil_rw_tb();
localparam STATE_AR = 4'h0,
           STATE_R  = 4'h1,
           STATE_AW = 4'h2,
           STATE_W  = 4'h3,
           STATE_B  = 4'h4,
            STATE_IDLE = 4'h5;
//----------------test state machine----------------------
    reg [3:0] state;

    reg clk, rst;
//-----------------axi lite signal----------------------
    reg  [29:0]     axil_awaddr;
    reg  [2:0]      axil_awprot;
    reg             axil_awvalid;
    wire            axil_awready;
    reg  [31:0]     axil_wdata;
    reg  [7:0]      axil_wstrb;
    reg             axil_wvalid;
    wire            axil_wready;
    wire [1:0]      axil_bresp;
    wire            axil_bvalid;
    reg             axil_bready;
    reg  [29:0]     axil_araddr;
    reg  [2:0]      axil_arprot;
    reg             axil_arvalid;
    wire            axil_arready;
    wire [31:0]     axil_rdata;
    wire [1:0]      axil_rresp;
    wire            axil_rvalid;
    reg             axil_rready;

initial begin
    clk = 0; rst = 1;
    state = STATE_AR;
#10 rst = 0;
end

always@(posedge clk or posedge rst)begin
    if(rst)begin
        state <= STATE_AW;
    end else begin
        case(state)
            STATE_AW : state <= axil_awready ? STATE_W : state;
            STATE_W  : state <= axil_wready ? STATE_B : state;
            STATE_B  : state <= axil_bvalid ? STATE_AR : state;
            STATE_AR : state <= axil_arready ? STATE_R : state;
            STATE_R  : begin 
                state <= axil_rvalid ? STATE_IDLE : state;
                $stop();
            end
        endcase
    end
end
// AR channel signal
always@(*) begin
    if(state==STATE_AR)begin
        axil_araddr  = 32'hC;
        axil_arprot  = 0;
        axil_arvalid = 1'b1;
    end else begin
        axil_araddr  = 32'hC;
        axil_arprot  = 0;
        axil_arvalid = 1'b0;
    end
end
// R channel
always@(*) begin
    if(state==STATE_R)begin
        axil_rready = 1'b1;
    end else begin
        axil_rready = 1'b0;
    end
end
// AW channel
always@(*) begin
    if(state==STATE_AW)begin
        axil_awaddr = 32'hC;
        axil_awprot = 0;
        axil_awvalid=1'b1;
    end else begin
        axil_awaddr = 32'hC;
        axil_awprot = 0;
        axil_awvalid=1'b0;
    end
end
// W channel
always@(*) begin
    if(state==STATE_W)begin
        axil_wdata = 32'h7;
        axil_wstrb = 4'hf;
        axil_wvalid=1'b1;
    end else begin
        axil_wdata = 32'h7;
        axil_wstrb = 4'hf;
        axil_wvalid=1'b0;
    end
end
// B channel
always@(*) begin
    if(state==STATE_B)begin
        axil_bready = 1'b1;
    end else begin
        axil_bready = 1'b0;
    end
end

always begin
    #5 
        clk = ~clk;     //generate clock speed
end

axil_uart_top               dut(
	.clk_i                      (clk),
    .rst_i                      (rst), 
	// Wishbone signals
	.s_axil_awaddr              (axil_awaddr),
    .s_axil_awprot              (axil_awprot),
    .s_axil_awvalid             (axil_awvalid),
    .s_axil_awready             (axil_awready),
    .s_axil_wdata               (axil_wdata),
    .s_axil_wstrb               (axil_wstrb),
    .s_axil_wvalid              (axil_wvalid),
    .s_axil_wready              (axil_wready),
    .s_axil_bresp               (axil_bresp),
    .s_axil_bvalid              (axil_bvalid),
    .s_axil_bready              (axil_bready),
    .s_axil_araddr              (axil_araddr),
    .s_axil_arprot              (axil_arprot),
    .s_axil_arvalid             (axil_arvalid),
    .s_axil_arready             (axil_arready),
    .s_axil_rdata               (axil_rdata),
    .s_axil_rresp               (axil_rresp),
    .s_axil_rvalid              (axil_rvalid),
    .s_axil_rready              (axil_rready),
	.int_o                      (), // TODO: 串口中断未接入interrupt request
	// UART	signals
	// serial input/output
	.stx_pad_o                  (), 
	.srx_pad_i                  (1'b0),
	// modem signals
	.rts_pad_o                  (), 
	.cts_pad_i                  (1'b0), 
	.dtr_pad_o                  (), 
	.dsr_pad_i                  (1'b0), 
	.ri_pad_i                   (1'b0), 
	.dcd_pad_i                  (1'b0)
);


endmodule