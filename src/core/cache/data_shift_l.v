`include"timescale.v"
module data_shift_l(
    input wire [3:0]    Offset_ADDR,
    input wire [63:0]   DATAi,
    input wire [1:0]    SIZEi,              //00:8bit 01:16bit 10:32bit 11:64bit
    output reg          MisAligned,         //当前访问不对齐
    output wire [15:0]  BSELo,
    output wire [127:0] DATAo
);
    localparam SIZE_8BIT = 2'b00,
               SIZE_16BIT= 2'b01,
               SIZE_32BIT= 2'b10,
               SIZE_64BIT= 2'b11;

    wire [127:0] shift0, shift1, shift2;
    reg  [15:0]  bsel_base;
    wire [15:0]  bsel0, bsel1, bsel2;
//---------------------生成移位后的数据----------------------
assign shift0 = Offset_ADDR[0] ? {56'b0,DATAi,8'b0} : {64'b0, DATAi};
assign shift1 = Offset_ADDR[1] ? {shift0[111:0],16'b0} : shift0;
assign shift2 = Offset_ADDR[2] ? {shift1[95:0],32'b0} : shift1;
assign DATAo  = Offset_ADDR[3] ? {shift2[63:0],64'b0} : shift2;
//------------------生成字节掩码-----------------------------
always@(*)begin
    case(SIZEi)
        SIZE_8BIT: bsel_base = 16'b00000000_00000001;
        SIZE_16BIT: bsel_base = 16'b00000000_00000011;
        SIZE_32BIT: bsel_base = 16'b00000000_00001111;
        SIZE_64BIT: bsel_base = 16'b00000000_11111111;
      default: bsel_base = 16'hx;
    endcase
end
assign bsel0 = Offset_ADDR[0] ? {bsel_base[14:0],1'b0} : bsel_base;
assign bsel1 = Offset_ADDR[1] ? {bsel0[13:0],2'b0} : bsel0;
assign bsel2 = Offset_ADDR[2] ? {bsel1[11:0],4'b0} : bsel1;
assign BSELo = Offset_ADDR[3] ? {bsel2[7:0],8'b0} : bsel2;
//产生不对齐信号
always@(*)begin
    case(SIZEi)
        SIZE_8BIT  : MisAligned = 1'b0; 
        SIZE_16BIT : MisAligned = (Offset_ADDR[0] != 1'b0);
        SIZE_32BIT : MisAligned = (Offset_ADDR[1:0] != 2'b00);
        SIZE_64BIT : MisAligned = (Offset_ADDR[2:0] != 3'b000);
    default  : MisAligned = 1'b1;
    endcase
end

endmodule