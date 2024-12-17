//Switch between each pallette based on the state of select
// this module need 2-cycle delay for sync
module pallette_controller(
	input clk, 
	output reg [7:0] R, 
	output reg [7:0] G, 
	output reg [7:0] B, 
	input [3:0] fg, 
	input [3:0] bg, 
	input [1:0] select);
	//Arrays for multiplexing between
	wire [7:0] RED [3:0];
	wire [7:0] GREEN [3:0];
	wire [7:0] BLUE [3:0];

	reg [7:0] R_delay, G_delay, B_delay;
	
	color_pallette1 color_pallette1(RED[0], GREEN[0], BLUE[0], fg, bg);
	color_pallette2 color_pallette2(RED[1], GREEN[1], BLUE[1], fg, bg);
	color_pallette3 color_pallette3(RED[2], GREEN[2], BLUE[2], fg, bg);
	color_pallette4 color_pallette4(RED[3], GREEN[3], BLUE[3], fg, bg);

always@(posedge clk)begin
	R_delay <= RED[select];
	R       <= R_delay;
	G_delay <= GREEN[select];
	G       <= G_delay;
	B_delay <= BLUE[select];
	B       <= B_delay;
end
endmodule