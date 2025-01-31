//Store the colors for color pallete 2 and output the correct RGB value based on fg and bg value
module color_pallette2(output [7:0] R, output [7:0] G, output [7:0] B, input [3:0] fg, input [3:0] bg);

//Different Color Palettes
//https://www.fountainware.com/EXPL/vga_color_palettes.htm

//Standard pallette:
wire [11:0] pallette [15:0]; //Array of RGB values so we can do multiplexing
//                     RGB
assign pallette[0] = 12'h000;
assign pallette[1] = 12'h111;
assign pallette[2] = 12'h222;
assign pallette[3] = 12'h333;
assign pallette[4] = 12'h444;
assign pallette[5] = 12'h555;
assign pallette[6] = 12'h666;
assign pallette[7] = 12'h777;
assign pallette[8] = 12'h888;
assign pallette[9] = 12'h999;
assign pallette[10] = 12'hAAA;
assign pallette[11] = 12'hBBB;
assign pallette[12] = 12'hCCC;
assign pallette[13] = 12'hDDD;
assign pallette[14] = 12'hEEE;
assign pallette[15] = 12'hFFF;

wire [11:0] pallette_fg, pallette_bg;
//Index into the array to make a multiplexer
assign pallette_fg = pallette[fg];
assign pallette_bg = pallette[bg];

assign R = {pallette_fg[11:8], pallette_bg[11:8]};
assign G = {pallette_fg[7:4], pallette_bg[7:4]};
assign B = {pallette_fg[3:0], pallette_bg[3:0]};

endmodule