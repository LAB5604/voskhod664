`include "timescale.v"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : rob core unit （refersh）
    Author  : Jack.Pan
    Date    : 2022/10/28
    Version : 0.0(file init)

***********************************************************************************************/
module rob_core
#(
    parameter DWIDTH  = 4,          //data width
              IDWIDTH = 8,          //tag width
              DEEPTH  = 4           //deepth
)(
//---------------------------clock and reset-----------------------
    input logic                 clk_i,
    input logic                 srst_i,
//-------------------------flush input-----------------------------
    input logic                 flush_i,
//---------------------------write port-----------------------------
    input logic                 wren_i,
    input logic                 wcomplete_i,
    input logic [IDWIDTH-1:0]   wtag_i,
    input logic [DWIDTH-1:0]    wdata_i,
    output logic [IDWIDTH-1:0]  wentrynum_o,
    output logic                full_o,
//---------------------------write port (CAM)-----------------------
//               only tag is matched can be write back in rob
    input logic                 cam_wren_i,
    input logic [IDWIDTH-1:0]   cam_wtag_i,
//    input logic [DWIDTH-1:0]    cam_wdata_i,
//---------------------------read port------------------------------
    input logic                 rden_i,
    output logic [IDWIDTH-1:0]  rentrynum_o,
    output logic [IDWIDTH-1:0]  rtag_o,
    output logic                rcomplete_o,
    output logic                rcancel_o,
    output logic [DWIDTH-1:0]   rdata_o,
    output logic                empty_o
);

    reg [IDWIDTH-1:0]       cnt;
    reg [IDWIDTH-1:0]       rptr;
    reg [IDWIDTH-1:0]       wptr;

    reg  [IDWIDTH-1:0]      tag             [DEEPTH-1:0];
    reg  [DWIDTH-1:0]       data            [DEEPTH-1:0];
    reg  [DEEPTH-1:0]       complete, cancel;

always_ff @( posedge clk_i) begin
    if(srst_i)begin
        cnt <= 'h0;
    end
    else begin
        case({rden_i,wren_i})
            2'b00 : cnt <= cnt;
            2'b01 : cnt <= cnt + 1;
            2'b10 : cnt <= cnt - 1;
            2'b11 : cnt <= cnt;
        endcase
    end

    if(srst_i)begin
        rptr <= 'h0;
    end
    else if(rden_i & !empty_o & !flush_i)begin
        rptr <= (rptr==(DEEPTH-1)) ? 'h0 : rptr + 1;
    end

    if(srst_i)begin
        wptr <= 'h0;
    end
    else if(wren_i & !full_o & !flush_i)begin
        wptr <= (wptr==(DEEPTH-1)) ? 'h0 : wptr + 1;
    end
end
genvar i;
generate
    for(i=0; i<DEEPTH; i=i+1 )begin:rob_entry
        always_ff @( posedge clk_i ) begin
            if(srst_i)begin
                tag[i]  <= 0;
                data[i] <= 0;
                complete[i]<= 0;
                cancel[i]  <= 0;
            end
            else if(wren_i & (wptr==i) & !full_o)begin  //第一次分配表项的时候，写入data和tag，将complete位置为需要的值
                tag[i] <= wtag_i;
                complete[i]<=wcomplete_i;
            end
            else if(rden_i & (rptr==i) & !empty_o)begin
                complete[i]<=1'b0;
            end
            else if(cam_wren_i & (cam_wtag_i==i))begin     //此表项对应的指令已经被成功回写，complete位置1
                complete[i]<=1'b1;
            end
            if(srst_i)begin
                cancel[i] <= 'b0;
            end
            else if(flush_i)begin
                cancel[i] <= 'b1;       //刷新的时候将此项的取消位置1
            end
            else if(wren_i & (wptr==i) & !full_o)begin
                cancel[i] <= 'b0;       //写入项的时候cancel位置0
            end
            if(wren_i & (wptr==i) & !full_o)begin
                data[i]<= wdata_i;
            end
        end
    end
endgenerate

assign full_o       = cnt == DEEPTH;
assign empty_o      = cnt == 'h0;
assign rtag_o       = tag[rptr];
assign rdata_o      = data[rptr];
assign rcomplete_o  = complete[rptr];
assign rcancel_o    = cancel[rptr];
assign wentrynum_o  = wptr;
assign rentrynum_o  = rptr;

endmodule