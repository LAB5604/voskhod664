/**********************************************************************************************

   Copyright (c) [2023] [JackPan]
   [prv664] is licensed under Mulan PSL v2.
   You can use this software according to the terms and conditions of the Mulan PSL v2. 
   You may obtain a copy of Mulan PSL v2 at:
            http://license.coscl.org.cn/MulanPSL2 
   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.  
   See the Mulan PSL v2 for more details.  

                                                                             
    Desc    : e4fpm7k325 7-seg scanner
    Author  : JackPan
    Date    : 2023/8/26
    Version : 0.0

***********************************************************************************************/
module seg7_scanner#(
    parameter DIV_RATE = 9;     //clock divide rate for scanner, when use on board 27MHz input clock, RATE=9 is recommended
)(
    input wire          clk_i,
    input wire          test,
    input wire [15:0]   hex_to_display,
    output [3:0]        seg_sel,
    output reg [6:0]    seg_display
);

    reg [23:0]          div_reg;
    wire                scan_clk;
    //----------------scan logic------------------
    reg [1:0]           scan_counter;
    wire [3:0]          hex_in;         //input for hex-7seg decoder
    wire [6:0]          display;

always@(posedge scan_clk)begin
    scan_counter = scan_counter+1;
end
always@(posedge clk_i)begin
    div_reg <= div_reg+1;
end 
assign scan_clk=div_reg[DIV_RATE];

//------------------7seg decode scan logic------------------------
always@(*)begin
    case(scan_counter)
        2'b00: hex_in = hex_to_display[3:0];
        2'b01: hex_in = hex_to_display[7:4];
        2'b10: hex_in = hex_to_display[11:8];
        2'b11: hex_in = hex_to_display[15:12];
    endcase
end

seg7_decode     seg7_decode(
    .test       (test),
    .blank      (0),
    .in         (hex_in),
    .hex        (display)	//highactive g f e d c b a 
);
always @(posedge clk_i) begin
    seg_display <= display;
    seg_sel     <= 1<<scan_counter;
end

endmodule

module seg7_decode(

input wire test,
input wire blank,
input wire [3:0]in,
output reg [6:0]hex	//highactive g f e d c b a 
);

always@(*)begin
	if(blank)begin
		hex <= 7'b111_1111;	//blank
	end
	else begin
	case({test,in})
		5'b1xxxx	:	hex <= 7'b111_1111;
		5'b00000 	:	hex <= 7'b011_1111;
		5'b00001	:	hex <= 7'b000_0110;
		5'b00010	:	hex <= 7'b101_1011;
		5'b00011	:	hex <= 7'b100_1111;
		5'b00100	:   hex <= 7'b110_0110;
		5'b00101	:	hex <= 7'b110_1101;
		5'b00110	:   hex <= 7'b111_1101;
		5'b00111	:	hex <= 7'b000_0111;
		5'b01000	:	hex <= 7'b111_1111;
		5'b01001	:   hex <= 7'b110_1111;
		5'b01010	:   hex <= 7'b111_0111;
		5'b01011	:	hex <= 7'b111_1100;
		5'b01100	:	hex <= 7'b011_1001;
		5'b01101	:	hex <= 7'b101_1110; 
		5'b01110	:	hex <= 7'b111_1001;
		5'b01111	:   hex <= 7'b111_0001;
	default : hex <= 7'b000_0000;
	endcase
	end
end

endmodule