`include"timescale.v"
module sram_1r1w_async_read#(
    parameter DATA_WIDTH = 64,
              DATA_DEPTH = 1024
)(
    clkw,
    addrr,
    addrw,
    ce,
    we,
    datar,
    dataw
);
localparam ADDR_WIDTH=$clog2(DATA_DEPTH);

input                   clkw;
input [ADDR_WIDTH-1:0]  addrr,  addrw;
input [DATA_WIDTH-1:0]  dataw;
input                   ce;
input                   we;
output [DATA_WIDTH-1:0] datar;

reg [DATA_WIDTH-1:0] ram_cell [0:DATA_DEPTH-1];


always @(posedge clkw) 
begin
    if(we & ce) begin
        ram_cell[addrw] <= dataw;
    end
end
  
assign datar = ram_cell[addrr];


endmodule