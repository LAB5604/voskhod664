//This is generic SRAM model for 
`include"timescale.v"
(* blackbox *)module sram_1r1w
#(
    parameter   DATA_WIDTH=64,
                DATA_DEPTH=1024,
                OUTPUT_STYLE="NO_REG",//NO_REG | OLATCH | OUTFF
                USE_BSEL=1'b1
)
(
    clkr,
    clkw,
    addrr,
    addrw,
    ce,
    we,
    bsel,
    datar,
    dataw
);
localparam ADDR_WIDTH=$clog2(DATA_DEPTH);

input clkr,clkw;
input [ADDR_WIDTH-1:0]addrr,addrw;
input [DATA_WIDTH-1:0]dataw;
input ce;
input we;
input [DATA_WIDTH-1:0]bsel;
output [DATA_WIDTH-1:0]datar;

reg [DATA_WIDTH-1:0] ram_cell [0:DATA_DEPTH-1];
reg [ADDR_WIDTH-1:0] addr_reg;
reg ce_reg;
wire [DATA_WIDTH-1:0]bwen;
assign bwen=(USE_BSEL)?bsel:{DATA_DEPTH{we}};

always @(posedge clkw) 
begin
    if(we) begin
        ram_cell[addrw] <= (dataw & bwen) | (ram_cell[addrw] & ~bwen);
    end
end
always@(posedge clkr)
begin
    addr_reg<=addrr;
    ce_reg<=ce;
end
    

generate
    case(OUTPUT_STYLE)
    "NO_REG":
    begin
        assign datar=(ce)?ram_cell[addr_reg]:$random;
    end
    "OLATCH":
    begin
        reg [DATA_WIDTH-1:0]OLATCH;
        always@(ce)
            if(ce)OLATCH=ram_cell[addr_reg];
            else OLATCH=OLATCH;
        assign datar=OLATCH;
    end
    "OUTREG":
    begin
        reg [DATA_WIDTH-1:0]OREG;
        always@(clkr)
            if(ce)OREG<=ram_cell[addr_reg];
            else OREG=OREG;
        assign datar=OREG;
    end
    endcase
endgenerate


endmodule