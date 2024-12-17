//           异步复位-同步释放发生器
//              源自prv564，ASIC Proven!
`timescale 1ns/1ps
module reset_sync(
    input wire  clk,
    input wire  rst_async,
    output wire rst_sync
);
reg rst_s1,rst_s2;
always @ (posedge clk or posedge rst_async)
begin
    if (rst_async) begin
        rst_s1 <= 1'b1;
        rst_s2 <= 1'b1;
    end
    else begin
        rst_s1 <= 1'b0;
        rst_s2 <= rst_s1;
    end
end
assign rst_sync = rst_s2;

endmodule