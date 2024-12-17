// synopsys translate_off
`include "timescale.v"
// synopsys translate_on
`include "uart_defines.vh"
 
module uart_axil (
    input wire clk, 
    input wire rst_i, 
// axi-lite 32bit interface
    input  wire [`UART_ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output wire                   s_axil_awready,
    input  wire [32-1:0]          s_axil_wdata,
    input  wire [4-1:0]           s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output wire                   s_axil_wready,
    output wire [1:0]             s_axil_bresp,
    output wire                   s_axil_bvalid,
    input  wire                   s_axil_bready,
    input  wire [`UART_ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output wire                   s_axil_arready,
    output wire [32-1:0]          s_axil_rdata,
    output wire [1:0]             s_axil_rresp,
    output wire                   s_axil_rvalid,
    input  wire                   s_axil_rready,
// to internal wishbone bus
	output wire [4:0]             wb_adr_int,
    output wire [7:0]             wb_dat8_i, 
    input wire  [7:0]             wb_dat8_o, 
    input wire  [32-1:0]          wb_dat32_o,
	output wire                   we_o, 
    output wire                   re_o // Write and read enable output for the core
);

    wire [`UART_ADDR_WIDTH-1:0]  reg_wr_addr;
    wire [32-1:0]           reg_wr_data;
    wire [4-1:0]            reg_wr_strb;
    wire                    reg_wr_en;
    wire                    reg_wr_ack;
    wire [`UART_ADDR_WIDTH-1:0]  reg_rd_addr;
    wire                    reg_rd_en;
    wire [32-1:0]           reg_rd_data;
    wire                    reg_rd_ack;

axil_reg_if#(
    // Width of data bus in bits
    .DATA_WIDTH             (32),
    // Width of address bus in bits
    .ADDR_WIDTH             (`UART_ADDR_WIDTH),
    // Width of wstrb (width of data bus in words)
    // Timeout delay (cycles)
    .TIMEOUT                (4)
)axil_reg(
    .clk                        (clk),
    .rst                        (rst_i),
    /*
     * AXI-Lite slave interface
     */
    .s_axil_awaddr              (s_axil_awaddr),
    .s_axil_awprot              (s_axil_awprot),
    .s_axil_awvalid             (s_axil_awvalid),
    .s_axil_awready             (s_axil_awready),
    .s_axil_wdata               (s_axil_wdata),
    .s_axil_wstrb               (s_axil_wstrb),
    .s_axil_wvalid              (s_axil_wvalid),
    .s_axil_wready              (s_axil_wready),
    .s_axil_bresp               (s_axil_bresp),
    .s_axil_bvalid              (s_axil_bvalid),
    .s_axil_bready              (s_axil_bready),
    .s_axil_araddr              (s_axil_araddr),
    .s_axil_arprot              (s_axil_arprot),
    .s_axil_arvalid             (s_axil_arvalid),
    .s_axil_arready             (s_axil_arready),
    .s_axil_rdata               (s_axil_rdata),
    .s_axil_rresp               (s_axil_rresp),
    .s_axil_rvalid              (s_axil_rvalid),
    .s_axil_rready              (s_axil_rready),
    /*
     * Register interface
     */
    .reg_wr_addr                (reg_wr_addr),
    .reg_wr_data                (reg_wr_data),
    .reg_wr_strb                (reg_wr_strb),
    .reg_wr_en                  (reg_wr_en),
    .reg_wr_wait                (0),
    .reg_wr_ack                 (reg_wr_ack),
    .reg_rd_addr                (reg_rd_addr),
    .reg_rd_en                  (reg_rd_en),
    .reg_rd_data                (reg_rd_data),
    .reg_rd_wait                (0),
    .reg_rd_ack                 (reg_rd_ack)
);
assign we_o = reg_wr_en & reg_wr_strb[0];
assign wb_dat8_i = reg_wr_data[7:0];
assign wb_adr_int= reg_wr_en ? reg_wr_addr[`UART_ADDR_WIDTH-1:2] : reg_rd_en ? reg_rd_addr[`UART_ADDR_WIDTH-1:2]:0;
assign reg_wr_ack = reg_wr_en;
assign re_o = reg_rd_en;
assign reg_rd_data= wb_dat8_o;
assign reg_rd_ack = reg_rd_en;

endmodule