module sram_1rw_sync_wbe#(
    parameter 
    NEED_INIT  = 0,             //0: no init file ,1:init with INIT_FILE
    INIT_FILE  = "FILE.txt",
    DATA_WIDTH = 64,
    DATA_DEPTH = 1024
)(
    clk,
    addr,
    ce,
    we,
    datar,
    dataw,
    be
);
localparam ADDR_WIDTH=$clog2(DATA_DEPTH);

input                   clk;
input [ADDR_WIDTH-1:0]  addr;
input [DATA_WIDTH-1:0]  dataw;
input                   ce;
input                   we;
input [DATA_WIDTH/8-1:0]be;
output reg [DATA_WIDTH-1:0]  datar;

// (* RAM_STYLE="BLOCK" *)
reg [DATA_WIDTH-1:0] mem[DATA_DEPTH-1:0];

integer i=0;

always@(posedge clk)begin
    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
        if (ce & we & be[i]) begin
            mem[addr][8*i +: 8] <= dataw[8*i +: 8];
        end
    end
end

always @(posedge clk ) begin
    if(ce & !we)begin
        datar <= mem[addr];
    end
end

generate
    
if(NEED_INIT>0)begin:INIT_RAM
initial begin
    $readmemh(INIT_FILE, mem);
end
end
endgenerate

endmodule