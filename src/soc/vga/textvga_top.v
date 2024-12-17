`timescale 1ps/1ps
/*************************************************************************
	Name  : mini text vga card top file
	Author: Jack Pan
	Date  : 2022/4/1 
	Desc  : This is a mini text vga card, can display 16 colors and 8bit
	chars(e-ASCII), each character has tri part of color settings: front ground 
	color, back ground color, and blanking.

	To set these settings, three sram port is provided to connect to the bus:
	1:character ram, write to the ram to display an ASCII character on monitor, address range from 0~2399,
	(80 per line, 30 in vert)

	2:color ram, write to the ram to change the color of a charater, address range from 0~2399.
	each byte in this ram hold two part: front ground color and back ground color, [7:4] is fg color, [3:0] is bg color

	3:blink ram, write to the ram to change the blanking state of a charater, address range fram 0~299
	each byte in this ram can control 8 charaters' blanking state (1=blanking,0=no blanking)

	Have fun when using this text vga card in any design!

NOTEs: Timging of access fram ram
write:
    clk  :__/--\__/--\__/--\
    addr :--<addr0<addr1>
    wren :__/-----------\
    datai:--<data0<data1>

change log:
	2023/11/29 : added variable write port data width to support Salyut1 SoC VGA card
*************************************************************************/
`define CRTC_COLOR					//del this define to turn off the color
`define CRTC_BLANKING				//del this define to turn off the blanking (suggest not, blanking only use a little resources)

module textvga_top#(

	parameter   DATA_WIDTH                    = 64,								//32 or 64
				CHAR_ADDR_WIDTH               = $clog2(2400/(DATA_WIDTH/8)),
				BLK_ADDR_WIDTH                = $clog2(300/(DATA_WIDTH/8)),

    parameter 	INIT_FRAME_ENABLE             = "ENABLE",                       //enable frame initial with CHAR,COLOR,BLANKING file
				INIT_FRAME_CHAR_FILE_NAME     = "../rom/example_char.txt",      //this file is for frame init, can be nothing
    			INIT_FRAME_COLOR_FILE_NAME    = "../rom/example_color.txt",     //this file is for frame init, can be nothing
				INIT_FRAME_BLINK_FILE_NAME    = "../rom/example_blink.txt",		//this file is for frame init, can be nothing
    			INIT_CHAR_ROM_FILE_NAME       = "../rom/font.txt"               //this rom is for char's shape, must have it!  
				
)(

    input                       sysclk_i,           //system clock, can be any value
    input                       vgaclk_i,           //must use 25MHz for vga clock
    input                       rst_i,              //async reset
    input 		     [1:0]		pallete_select,     //select a pallete to use, default=00 is IBM PC/XT's color shape!
    ////////////system logic access port/////////////////
    input     wire   [CHAR_ADDR_WIDTH-1:0] 	charram_addr_i,     colorram_addr_i,
	input     wire   [BLK_ADDR_WIDTH-1:0]						blinkram_addr_i,
    input     wire              			charram_wren_i,     colorram_wren_i,	blinkram_wren_i,
    input     wire   [DATA_WIDTH-1:0]      	charram_data_i,     colorram_data_i,	blinkram_data_i,
	//////////// VGA //////////
	output		     [7:0]		vga_b_o,
	output		     [7:0]		vga_g_o,
	output		          		vga_hs_o,
	output		     [7:0]		vga_r_o,
	output		          		vga_vs_o

);



//=======================================================
//  REG/WIRE declarations
//=======================================================
	wire        sysrst,         vgarst;
	wire 		valid, 			vsync, 		hsync, 		v_en;
	wire [9:0] 	h_addr, 		v_addr;
	wire [11:0] char_frame_addr;
	wire [15:0] char_frame;
	wire [3:0] 	glyph_row_addr;
	wire [2:0] 	char_row;
	wire [7:0] 	glyph_row;

	wire [7:0] char_code,		char_color;
	wire [3:0] char_fg, 		char_bg;


assign char_fg = char_color[7:4];
assign char_bg = char_color[3:0];

//0 - 3 | 4 - 7 | 8 - 15
//FG    | BG    | Char


//=======================================================
//  Structural coding
//=======================================================

//--------------------resert sync module----------------------
reset_gen   systemrst_gen(
    .clk            (sysclk_i),
    .rst_async      (rst_i),
    .rst_sync       (sysrst)
);

reset_gen   vgarst_gen(
    .clk            (vgaclk_i),
    .rst_async      (rst_i),
    .rst_sync       (vgarst)
);


//Generate VGA timing signals
vga_controller vgacontrol(h_addr, v_addr, valid, vsync, hsync, v_en, vgarst, vgaclk_i);

//Generate character timing signals
char_row_counter charrowcounter(glyph_row_addr, char_row, char_frame_addr, v_en, valid, v_addr, vgaclk_i, vgarst);

//-----------------------char fram ram----------------------------
viedo_ram #(

	.INIT_FRAME_ENABLE              (INIT_FRAME_ENABLE),
	.INIT_FRAME_CHAR_FILE_NAME      (INIT_FRAME_CHAR_FILE_NAME),
	.BYTE_NUMBER					(2400),
    .DATA_WIDTH						(DATA_WIDTH)

)char_ram(
	//----------------A access port-----------------
	.aclock         (sysclk_i),

	.aaddress       (charram_addr_i),
	.awdata         (charram_data_i),
	.awrite         (charram_wren_i),

	//---------------vga read port------------------
	.vclock         (vgaclk_i),
	.vaddress       (char_frame_addr),
	.vdata          (char_code)

);
`ifdef  CRTC_COLOR

	viedo_ram #(

		.INIT_FRAME_ENABLE              (INIT_FRAME_ENABLE),
		.INIT_FRAME_CHAR_FILE_NAME      (INIT_FRAME_COLOR_FILE_NAME),
		.BYTE_NUMBER					(2400),
    	.DATA_WIDTH						(DATA_WIDTH)

	)color_ram(
		//----------------A access port-----------------
		.aclock         (sysclk_i),

		.aaddress       (colorram_addr_i),
		.awdata         (colorram_data_i),
		.awrite         (colorram_wren_i),

		//---------------vga read port------------------
		.vclock         (vgaclk_i),
		.vaddress       (char_frame_addr),
		.vdata          (char_color)

	);

`endif
//------------------------blink frame ram----------------------------------
`ifdef CRTC_BLANKING

	reg [2:0] blk_addr_del0, blk_addr_del1;	//delay address 2cycle to select bit from read data
	reg [1:0] blink_del;			//delay blink 2-cycle to bring it back to sync
	wire      char_blink;			//this char need blank acording to ram
	wire      blink;				//blink counter show that this char need blank
	wire [7:0]blk_ram_rdata;		//actual read data from ram

	blink_generator#(

		.BLINK_CYCLE_MS		(500)          //in ms

	)blink_generator(
		.vgaclk_i			(vgaclk_i),
		.vgarst_i			(vgarst),
		.blink				(blink)
	);

	viedo_ram#(

		.INIT_FRAME_CHAR_FILE_NAME		(INIT_FRAME_BLINK_FILE_NAME),
		.INIT_FRAME_ENABLE				(INIT_FRAME_ENABLE),
		.BYTE_NUMBER					(300),
    	.DATA_WIDTH						(DATA_WIDTH)

	)blink_ram(
		//-------------system port-------------
		.aclock         (sysclk_i),

		.aaddress       				(blinkram_addr_i),
		.awdata         				(blinkram_data_i),
		.awrite         				(blinkram_wren_i),
		
		.vclock							(vgaclk_i),
		.vaddress						(char_frame_addr),
		.vdata							(blk_ram_rdata)
	);

	assign char_blink = blk_ram_rdata[blk_addr_del1];

	always@( posedge vgaclk_i )begin
		blk_addr_del0 <= char_frame_addr[2:0];
		blk_addr_del1<= blk_addr_del0;

		blink_del[0] <= char_blink & blink;
		blink_del[1] <= blink_del[0];
	end

`else

	wire [1:0] blink_del = 2'b00;		//NO BLINK!

`endif

//------------------------a rom store chars' shape-------------------------
//
glyph_rom#(

    .INIT_CHAR_ROM_FILE_NAME    (INIT_CHAR_ROM_FILE_NAME)

)glyph_rom_inst(

	.addra 		    ( {char_code, glyph_row_addr} ),
	.doa            ( glyph_row ),
	.clka 		    ( vgaclk_i ),
	.rsta           ( vgarst )

);
//TODO: Glyph row is an entire row late

//Data comes through char_row_counter -> char_ram -> glyph_rom. By then, it's already old
//Delay through 4 registers to bring it into sync with VGA timing which is delayed below
//reg [2:0] char_row_del0, char_row_del1, char_row_del2, char_row_del3;
reg [2:0] char_row_del [3:0];
initial begin
	char_row_del[0] = 3'b0;
	char_row_del[1] = 3'b0;
	char_row_del[2] = 3'b0;
	char_row_del[3] = 3'b0;
end
always @(posedge vgaclk_i) begin
	char_row_del[0] <= char_row;
	char_row_del[1] <= char_row_del[0];
	char_row_del[2] <= char_row_del[1];
	char_row_del[3] <= char_row_del[2];
end

//glyph_row contains the current row of the current glyph
//char_row counts from 0 to 7 to go through the row
//pixel contains the current pixel that should be drawn (on or off)
wire pixel;
assign pixel = (char_row_del[3] == 3'h0) ? glyph_row[7] :
					(char_row_del[3] == 3'h1) ? glyph_row[6] :
					(char_row_del[3] == 3'h2) ? glyph_row[5] :
					(char_row_del[3] == 3'h3) ? glyph_row[4] :
					(char_row_del[3] == 3'h4) ? glyph_row[3] :
					(char_row_del[3] == 3'h5) ? glyph_row[2] :
					(char_row_del[3] == 3'h6) ? glyph_row[1] :
					glyph_row[0];

	wire [7:0] R, G, B;

`ifdef CRTC_COLOR
//Use a pallette controller to do all the multiplexing for the pallettes
	pallette_controller pallette_controller(vgaclk_i, R, G, B, char_fg, char_bg, pallete_select);

`else 

	assign R = 8'b1111_0000;
	assign B = 8'b1111_0000;
	assign G = 8'b1111_0000;

`endif

//Delay the VGA timing signals through one register each to bring them back into sync
reg [3:0] valid_del, hsync_del, vsync_del;
initial begin
	valid_del = 2'b0;
	hsync_del = 2'b0;
	vsync_del = 2'b0;
end
always @(posedge vgaclk_i) begin
	valid_del[0] <= valid;
	valid_del[1] <= valid_del[0];
	valid_del[2] <= valid_del[1];
	valid_del[3] <= valid_del[2];

	hsync_del[0] <= hsync;
	hsync_del[1] <= hsync_del[0];
	hsync_del[2] <= hsync_del[1];
	hsync_del[3] <= hsync_del[2];

	vsync_del[0] <= vsync;
	vsync_del[1] <= vsync_del[0];
	vsync_del[2] <= vsync_del[1];
	vsync_del[3] <= vsync_del[2];
end

//Assign R G and B based off whether we're in the valid region, if a pixel should be drawn, and what color that pixel should be
assign vga_r_o[7:4] = valid_del[3] ? ((pixel & !blink_del[1]) ? R[7:4] : R[3:0]) : 4'b0;
assign vga_r_o[3:0] = 0;

assign vga_g_o[7:4] = valid_del[3] ? ((pixel & !blink_del[1]) ? G[7:4] : G[3:0]) : 4'b0;
assign vga_g_o[3:0] = 0;

assign vga_b_o[7:4] = valid_del[3] ? ((pixel & !blink_del[1]) ? B[7:4] : B[3:0]) : 4'b0;
assign vga_b_o[3:0] = 0;

//Assign HS and VS signals from their delayed versions
assign vga_hs_o = hsync_del[3];
assign vga_vs_o = vsync_del[3];

endmodule