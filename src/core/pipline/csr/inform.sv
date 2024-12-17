`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022/8/30                                                                         //
//  Author  : Jack.Pan                                                                          //
//  Desc    : Inform csrs for PRV664 processor                                                  //
//  Version : 0.0(Orignal)                                                                      //
//////////////////////////////////////////////////////////////////////////////////////////////////
module inform
#(
    parameter HARTID = 64'h0
)(
    input wire              clk_i, arst_i,
    output wire [`XLEN-1:0] mhartid, mvendorid, marchid, mimpid
);

assign mhartid      = HARTID;
assign mvendorid    = "KOROLEV";
assign marchid      = "VOSKHOD";
assign mimpid       = 64'h0;

endmodule
