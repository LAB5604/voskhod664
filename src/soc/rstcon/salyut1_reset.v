`timescale 1ns/1ps
module salyut1_reset(
    input wire clk_main,
    input wire clk_cpu,
    input wire clk_pherp,
    input wire full_rst,        //reset all 
    input wire cpu_rst,         //reset cpu only (for load program)

    output wire mainclk_domain_rst,
    output wire cpu_domain_rst,
    output wire pherp_domain_rst
);

wire cpu_rst_int1, cpu_rst_int2;

reset_sequencer     reset_sequencer(
    .clk_a      (clk_pherp),
    .clk_b      (clk_main),
    .clk_c      (clk_cpu),
    .rst        (full_rst),
    // output rest sequence
    .rst_a      (pherp_domain_rst),
    .rst_b      (mainclk_domain_rst),
    .rst_c      (cpu_rst_int1)
);

reset_sync   cpu_reset_gen(
    .clk        (clk_cpu),
    .rst_async  (cpu_rst),
    .rst_sync   (cpu_rst_int2)
);

assign cpu_domain_rst =  cpu_rst_int1 | cpu_rst_int2;

endmodule