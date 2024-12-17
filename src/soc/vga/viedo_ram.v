module viedo_ram #(
	parameter 	INIT_FRAME_ENABLE 			= "DISABLE",
				INIT_FRAME_CHAR_FILE_NAME 	= "",
    parameter   BYTE_NUMBER = 2400, //total byte number
                DATA_WIDTH = 64,    //write port data width:64 or 32
                ADDR_WIDTH = $clog2(BYTE_NUMBER/(DATA_WIDTH/8)),
                RADDR_WIDTH= $clog2(BYTE_NUMBER)
)(
	//----------------A access port-----------------
	input wire 			        aclock,
	input wire [ADDR_WIDTH-1:0] aaddress,
	input wire [DATA_WIDTH-1:0] awdata,	
	input wire                  awrite,	
	//---------------vga read port------------------
	input wire                  vclock,
	input wire [RADDR_WIDTH-1:0]vaddress,
	output wire[7:0]            vdata

);
localparam DATA_DEEPTH = BYTE_NUMBER/(DATA_WIDTH/8);

reg [DATA_WIDTH-1:0]BRAM0 [DATA_DEEPTH-1:0];

reg [ADDR_WIDTH-1:0]aaddr_reg;
reg [11:0]          vaddr_reg;
reg [3:0]           vaddr_offset_reg1, vaddr_offset_reg2;
reg [DATA_WIDTH-1:0]vdata_temp;

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

end
//--------------------------viedo read port is another clock domain-----------------------
always@(posedge vclock)begin

    vaddr_offset_reg1 <= vaddress[3:0];
    vaddr_offset_reg2 <= vaddr_offset_reg1;
end
generate
    if(DATA_WIDTH==64)begin //写数据口宽度为64
		always @(posedge vclock) begin
			vaddr_reg <= vaddress[RADDR_WIDTH-1:3];
	    	vdata_temp <= BRAM0[vaddr_reg];
		end
    end else begin
		always @(posedge vclock) begin
        	vaddr_reg <= vaddress[RADDR_WIDTH-1:2];
	    	vdata_temp <= BRAM0[vaddr_reg];
		end
    end
endgenerate


//--------------输出口根据字节偏移量从较宽的数据口选择特定字节---------------
generate
    if(DATA_WIDTH==64)begin
        assign vdata = vdata_temp[(8*vaddr_offset_reg2[2:0])+:8];
    end else begin
        assign vdata = vdata_temp[(8*vaddr_offset_reg2[1:0])+:8];
    end
endgenerate

endmodule
