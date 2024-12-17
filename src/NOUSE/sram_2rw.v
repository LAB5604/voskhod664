//This is generic SRAM model 

(* blackbox *)module sram_2rw
#(
    parameter   DATA_WIDTH=64,
                DATA_DEPTH=1024,
                OUTPUT_STYLEA="NO_REG",//NO_REG | OLATCH | OUTFF
                USE_BSELA=1'b1,
                OUTPUT_STYLEB="NO_REG",//NO_REG | OLATCH | OUTFF
                USE_BSELB=1'b1
)
(
    clka,
    addr_a,
    ce_a,
    we_a,
    bsel_a,
    datar_a,
    dataw_a,
    clkb,
    addr_b,
    ce_b,
    we_b,
    bsel_b,
    datar_b,
    dataw_b,
);
localparam ADDR_WIDTH=$clog2(DATA_DEPTH);

input clka,clkb;
input [ADDR_WIDTH-1:0]addr_a,addr_b;
input [DATA_WIDTH-1:0]dataw_a,dataw_b;
input ce_a,ce_b;
input we_a,we_b;
input [DATA_WIDTH-1:0]bsel_a,bsel_b;
output [DATA_WIDTH-1:0]datar_a,datar_b;

reg [DATA_WIDTH-1:0] ram_cell [0:DATA_DEPTH-1];

reg [ADDR_WIDTH-1:0] addr_reg_a,addr_reg_b;
reg ce_reg_a,ce_reg_b;
wire [DATA_WIDTH-1:0]bwen_a,bwen_b;
//RW PORT A

assign bwen_a=(USE_BSELA)?bsel_a:{DATA_DEPTH{we_a}};

always @(posedge clka) 
begin
    if(ce_a & we_a) 
    begin
        ram_cell[addr_a] <= (dataw_a & bwen_a) | (ram_cell[addr_a] & ~bwen_a);
    end
    if(ce_a)
    begin
        addr_reg_a<=addr_a;
        ce_reg_a<=ce_a;
    end
end

generate
    case(OUTPUT_STYLEA)
    "NO_REG":
    begin
        assign datar_a=(ce_a&(!we_a))?ram_cell[addr_reg_a]:$random;
    end
    "OLATCH":
    begin
        reg [DATA_WIDTH-1:0]OLATCH_a;
        always@(ce_a&(!we_a))
            if(ce_a&(!we_a))OLATCH_a=ram_cell[addr_reg_a];
            else OLATCH=OLATCH_a;
        assign datar_a=OLATCH;
    end
    "OUTREG":
    begin
        reg [DATA_WIDTH-1:0]OREG_a;
        always@(clka)
            if(ce_a&(!we_a))OREG_a<=ram_cell[addr_reg_a];
            else OREG_a=OREG_a;
        assign datar_a=OREG_a;
    end
    endcase
endgenerate

//RW PORT B

assign bwen_b=(USE_BSELB)?bsel_b:{DATA_DEPTH{we_b}};

always @(posedge clkb) 
begin
    if(ce_b & we_b) 
    begin
        ram_cell[addr_b] <= (dataw_b & bwen_b) | (ram_cell[addr_b] & ~bwen_b);
    end
    if(ce_b)
    begin
        addr_reg_b<=addr_b;
        ce_reg_b<=ce_b;
    end
end

generate
    case(OUTPUT_STYLEA)
    "NO_REG":
    begin
        assign datar_b=(ce_b&(!we_b))?ram_cell[addr_reg_b]:$random;
    end
    "OLATCH":
    begin
        reg [DATA_WIDTH-1:0]OLATCH_b;
        always@(ce_b&(!we_b))
            if(ce_b&(!we_b))OLATCH_b=ram_cell[addr_reg_b];
            else OLATCH_b=OLATCH_b;
        assign datar_b=OLATCH_b;
    end
    "OUTREG":
    begin
        reg [DATA_WIDTH-1:0]OREG_b;
        always@(clkb)
            if(ce_b&(!we_b))OREG_b<=ram_cell[addr_reg_b];
            else OREG_b=OREG_b;
        assign datar_b=OREG_b;
    end
    endcase
endgenerate

endmodule