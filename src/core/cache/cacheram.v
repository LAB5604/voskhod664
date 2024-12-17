`include"timescale.v"
/**************************************************************
    cacheram module with byte select signal
***************************************************************/
module cacheram#(
    parameter DEEPTH   = 2048,      //total=deepth * byte_num * 8 bit (in bits)
              BYTE_NUM = 16
)(
    clk,
    addr,
    ce,
    we,
    bsel,           //byte select
    datar,
    dataw
);
localparam ADDR_WIDTH=$clog2(DEEPTH),
           DATA_WIDTH= BYTE_NUM*8;

input wire                      clk, ce, we;
input wire [ADDR_WIDTH-1:0]     addr;
input wire [DATA_WIDTH -1:0]    dataw;
output wire [DATA_WIDTH-1:0]    datar;
input wire [BYTE_NUM-1:0]       bsel;

genvar i;
generate
    for(i=0;i<BYTE_NUM;i=i+1)begin:RAM_BLOCK
        sram_1rw_sync_read#(
            .DATA_WIDTH     (8),
            .DATA_DEPTH     (DEEPTH)
        )sram(
            .clk            (clk),
            .addr           (addr),
            .ce             (ce & bsel[i]),
            .we             (we & bsel[i]),
            .datar          (datar[(8*i+7):(8*i)]),
            .dataw          (dataw[(8*i+7):(8*i)])
        );
    end
endgenerate

endmodule