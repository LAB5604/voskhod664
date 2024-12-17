/**********************************************************
    1rw sync read sram
**********************************************************/
`include"timescale.v"
module sram_1rw_sync_read#(
    parameter DATA_WIDTH = 8,
              DATA_DEPTH = 1024
)(
    clk,
    addr,
    ce,
    we,
    datar,
    dataw
);
localparam ADDR_WIDTH=$clog2(DATA_DEPTH);

input                   clk;
input [ADDR_WIDTH-1:0]  addr;
input [DATA_WIDTH-1:0]  dataw;
input                   ce;
input                   we;
output reg [DATA_WIDTH-1:0]  datar;

reg [DATA_WIDTH-1:0] ram_cell [0:DATA_DEPTH-1];


always @(posedge clk) 
begin
    if(we & ce) begin
        ram_cell[addr] <= dataw;
    end
end

always @ (posedge clk)
begin
    if(ce)begin
        datar <= ram_cell[addr];
    end
end
endmodule