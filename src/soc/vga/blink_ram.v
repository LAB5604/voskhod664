module blink_ram#(

    parameter   INIT_FRAME_BLINK_FILE_NAME = "",
                INIT_FRAME_ENABLE          = "DISABLE"

)(
    //-------------system port-------------
    input wire          sysclk_i,
    input wire          vgaclk_i,
    input wire          rst_i,
    input wire [8:0]    blinkram_addr_i,
    input wire [7:0]    blinkram_data_i,
    input wire          blinkram_wren_i,
    output reg [7:0]    blinkram_data_o,
    //--------------vga port---------------
    input wire          vclock,
    input wire [11:0]   vaddress,
    output wire         vblink
);
    reg [7:0] BRAM [299:0];     //total 300*8=2400 charicters

    reg [11:0]  addr_reg,    vaddr_reg;
    reg [2:0]   vaddr_del;
    reg [7:0]   vdata;         //8bit data read from this ram

generate
	if(INIT_FRAME_ENABLE=="ENABLE")begin
		initial begin
			$readmemh(INIT_FRAME_BLINK_FILE_NAME, BRAM);	//init blinking ram for first display
		end
	end
endgenerate

//----------------------------system side read/write port-------------------------------
always@( posedge sysclk_i )begin

    if(blinkram_wren_i)begin
        BRAM[blinkram_addr_i] <= blinkram_data_i;
    end

    addr_reg <= blinkram_addr_i;

    blinkram_data_o <= BRAM[addr_reg];

end

//------------------------------vga side read---------------------------------
always@( posedge vgaclk_i)begin

    vaddr_reg <= vaddress;
    vaddr_del <= vaddr_reg[2:0];
    vdata     <= BRAM[vaddr_reg[11:3]];

end

assign vblink = vdata[vaddr_del];

endmodule