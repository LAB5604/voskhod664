/*    handshake dff slice          */
`timescale 1ns/1ps
module handshake_dff#(
    parameter DATA_WIDTH = 64
)(
    // clock and sync reset
    input wire                  clk_i,
    input wire                  rst_i,
    //  input 
    input wire [DATA_WIDTH-1:0] data_i,
    input wire                  valid_i,
    output wire                 ready_o,
    //output
    output reg [DATA_WIDTH-1:0] data_o,
    output reg                  valid_o,
    input wire                  ready_i
);

always@(posedge clk_i)begin
    if(rst_i)begin
        valid_o <= 1'b0;
    end
    else if(ready_o)begin
        valid_o <= valid_i;
    end
end

always@(posedge clk_i)begin
    if(ready_o & valid_i)begin
        data_o <= data_i;
    end
end

assign ready_o = !valid_o | ready_i;



endmodule