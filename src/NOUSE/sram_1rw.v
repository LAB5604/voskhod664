//This is generic SRAM model 

(* blackbox *)module sram_1rw
#(
    parameter   DATA_WIDTH=64,
                DATA_DEPTH=1024,
                OUTPUT_STYLE="NO_REG",//NO_REG | OLATCH | OUTFF
                USE_BSEL=1'b1
)
(
    clk,
    addr,
    we,
    bsel,
    datar,
    dataw
);
localparam ADDR_WIDTH=$clog2(DATA_DEPTH);

input clk;
input [ADDR_WIDTH-1:0]addr;
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

always @(posedge clk) 
begin
    if(ce & we) 
    begin
        ram_cell[addr] <= (dataw & bwen) | (ram_cell[addr] & ~bwen);
    end
    if(ce)
    begin
        addr_reg<=addr;
        ce_reg<=ce;
    end
end

generate
    case(OUTPUT_STYLE)
    "NO_REG":
    begin
        assign datar=(ce&(!we))?ram_cell[addr_reg]:$random;
    end
    "OLATCH":
    begin
        reg [DATA_WIDTH-1:0]OLATCH;
        always@(ce&(!we))
            if(ce&(!we))OLATCH=ram_cell[addr_reg];
            else OLATCH=OLATCH;
        assign datar=OLATCH;
    end
    "OUTREG":
    begin
        reg [DATA_WIDTH-1:0]OREG;
        always@(clk)
            if(ce&(!we))OREG<=ram_cell[addr_reg];
            else OREG=OREG;
        assign datar=OREG;
    end
    endcase
endgenerate


endmodule