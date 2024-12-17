module char_ram #(
	parameter 	INIT_FRAME_ENABLE 			= "DISABLE",
				INIT_FRAME_CHAR_FILE_NAME 	= ""

)(
	//----------------A access port-----------------
	input wire 			aclock,
	input wire [11:0]   aaddress,
	input wire [7:0] 	awdata,	
	output reg [7:0]    ardata,  
	input wire          awrite,	
	//---------------vga read port------------------
	input wire          vclock,
	input wire [11:0]	vaddress,
	output reg [15:0]   vdata

);

reg [7:0] BRAM0 [2399:0];

reg [11:0] aaddr_reg,		vaddr_reg;

generate
	if(INIT_FRAME_ENABLE=="ENABLE")begin
		initial begin
			$readmemh(INIT_FRAME_CHAR_FILE_NAME, BRAM0);	//init char ram for first display
		end
	end
endgenerate


always@(posedge aclock)begin

	if(awrite)begin
		BRAM0[aaddress] <= awdata;
	end

	aaddr_reg <= aaddress;

	ardata    <= BRAM0[aaddr_reg];

end
//--------------------------viedo read port is another clock domain-----------------------
always@(posedge vclock)begin

	vaddr_reg <= vaddress;
	vdata <= BRAM0[vaddr_reg];

end

endmodule
