//Provide proper VGA vsync, hsync timings as well as a valid bit indicating if we're in addressable video time
//Also provides current h and v address and supports a reset
//
//Read the 10-bit addresses from h_addr and v_addr
//Read the valid bit from valid (Active HI)
//Read the vsync and hsync bits from vsync and hsync (Active HI)
//Initiate a reset by bringing reset HI. The controller will remain in the reset condition as long as reset is HI
//Provide a 25.175 MHz clock to clk
module vga_controller(h_addr, v_addr, valid, vsync, hsync, v_en, reset, clk);

output [9:0] h_addr, v_addr;
output valid, vsync, hsync;
input reset, clk;
//We need a line to enable v counter or not
output v_en;

//Horizontal and vertical counters
horiz_counter hcount(h_addr, v_en, clk, reset);
vert_counter vcount(v_addr, v_en, clk, reset);

//Three comparators to check hsync, vsync, and addressable video
check_horiz_sync checkhsync(hsync, h_addr, clk);
check_vert_sync checkvsync(vsync, v_addr, clk);
check_display checkd(valid, h_addr, v_addr, clk);

endmodule