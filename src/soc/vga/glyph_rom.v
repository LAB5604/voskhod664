// char glyph rom for textvga
// if this module has some synx problem, you can follow the user guide to replace module
// As far as I know, Quartus and Anlogic's EDA suppor $readmemh to generate ROM !
module glyph_rom#(
    parameter INIT_CHAR_ROM_FILE_NAME = ""
)(
    input wire        clka,
    input wire        rsta,
    input wire [11:0] addra,
    output reg [7:0]  doa
);
reg [11:0] addr_reg;
reg [7:0] BRAM [4095:0];

initial begin
    $readmemh(INIT_CHAR_ROM_FILE_NAME, BRAM);
end

always@(posedge clka)begin
    addr_reg <= addra;
    doa <= BRAM[addr_reg];
end

endmodule