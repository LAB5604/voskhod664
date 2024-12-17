`include"timescale.v"
module data_shift_r(
    input wire [127:0]  DATAi,
    input wire [3:0]    Offset_ADDR,
    output reg [127:0]  DATAo
);
    wire [63:0] shift0, shift1, shift2, shift3;

assign shift0 = Offset_ADDR[3] ? DATAi[127:64] : DATAi[63:0];       //高低64字节选择
assign shift1 = Offset_ADDR[2] ? {32'b0,shift0[63:32]} : shift0;    //高低32位选择
assign shift2 = Offset_ADDR[1] ? {48'b0,shift1[31:16]} : shift1;    //高低16位选择
assign shift3 = Offset_ADDR[0] ? {56'b0,shift2[15:8]} : shift2;     //高低8位选择
always@(*)begin
    DATAo = {DATAi[127:64],shift3};
end

endmodule