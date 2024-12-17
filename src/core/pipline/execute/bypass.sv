`include"prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) bypass unit in exe stage, direct bypass instruction to writeback
    Author  : Jack.Pan
    Date    : 2022/8/1
    Version : 0.0 file initial

***********************************************************************************************/
module bypass(
    input                           clk_i,
    input                           arst_i,
    pip_flush_interface.slave       flush_slave,

    pip_exu_interface.bypass_sif    bypass_sif,
    pip_wb_interface.master         bypass_mif      //connect to wrtie back interface
);
//-------------------from uop buffer----------------
    logic [7:0]         itag;
    logic               ren;
    logic               empty;                      //uop bugger is empty
    logic               valid;

fifo1r1w#(
    .DWID           (8),
    .DDEPTH         (2)
)alu_uop_buffer(
    .clk            (clk_i),
    .rst            (arst_i | flush_slave.flush),
    .ren            (ren),
    .wen            (bypass_sif.valid),
    .wdata          (bypass_sif.itag),
    .rdata          (itag),
    .full           (bypass_sif.full),
    .empty          (empty)
);
    
assign valid = !empty;
assign ren = !(bypass_mif.valid & !bypass_mif.ready);

always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        bypass_mif.valid <= 1'b0;
    end
    else if (flush_slave.flush)begin
        bypass_mif.valid <= 1'b0;
    end
    else begin
        case(bypass_mif.valid)
            1'b1: bypass_mif.valid <= bypass_mif.ready ? valid : bypass_mif.valid;
            1'b0: bypass_mif.valid <= valid;
            default: bypass_mif.valid <= 1'bx;
        endcase
    end
end

always_ff @( posedge clk_i ) begin
    if(!(bypass_mif.valid & !bypass_mif.ready))begin
        bypass_mif.itag <= itag;
    end
end

endmodule