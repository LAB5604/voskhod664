`timescale 1ns/1ps
module reset_sequencer(
    input wire clk_a,
    input wire clk_b,
    input wire clk_c,
    input wire rst,
    // output rest sequence
    output wire rst_a,
    output wire rst_b,
    output wire rst_c
);
/***********************************************************
    reset sequencer
    reset remove sequence:
    rst_a -> rst_b -> rst_c

************************************************************/

reset_sync   clka_rst(
    .clk        (clk_a),
    .rst_async  (rst),
    .rst_sync   (rst_a)
);

reset_sync   clkb_rst(
    .clk        (clk_b),
    .rst_async  (rst_a),
    .rst_sync   (rst_b)
);

reset_sync   clkc_rst(
    .clk        (clk_c),
    .rst_async  (rst_b),
    .rst_sync   (rst_c)
);

endmodule