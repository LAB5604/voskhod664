`include "timescale.v"
`define SMPLFIFO
module fifo1r1w
#(
    parameter   DWID = 8,
                DDEPTH = 64
)
(
    input clk,rst,
    input ren,wen,
    input [DWID-1:0]wdata,
    output[DWID-1:0]rdata,
    output reg full,
    output empty
);
localparam CNTWID = $clog2(DDEPTH)+1;
reg empty_ff;
reg [CNTWID-1:0] wptr;
reg [CNTWID-1:0] rptr;
wire [CNTWID-1:0] wptr_next,rptr_next;
reg [DWID-1:0]memory[DDEPTH-1:0];
wire full_cmp,empty_cmp;
wire wen_internal,ren_internal;

assign wen_internal=wen;
assign ren_internal=ren;
assign full_cmp=(rptr_next=={!wptr_next[CNTWID-1],wptr_next[CNTWID-2:0]});
assign empty_cmp=(wptr_next==rptr_next);//_next
assign wptr_next=(full)?wptr:wptr+wen_internal;
assign rptr_next=(empty_ff)?rptr:rptr+ren_internal;
assign empty=empty_ff;

always@(posedge clk)//PTRs
begin
    if(rst) 
    begin
        wptr<=0;
        rptr<=0;
    end
    else
    begin
        if(wen_internal) 
            wptr<=wptr_next;
        else 
            wptr<=wptr;
        if(ren_internal)
            rptr<=rptr_next;
        else
            rptr<=rptr;
    end
end

assign rdata=memory[(empty_ff)?(rptr[CNTWID-2:0]-1):rptr[CNTWID-2:0]];

always@(posedge clk)//data
begin
    if(wen)
        memory[wptr[CNTWID-2:0]]<=wdata;
    else 
        memory[wptr[CNTWID-2:0]]<=memory[wptr[CNTWID-2:0]];
end

always@(posedge clk)//Full & Empty
begin
    if(rst) 
    begin
        full<=0;
        empty_ff<=1'b1;
    end
    else 
    begin
            full<=full_cmp;
            empty_ff<=empty_cmp;
    end
end

`ifdef FORMAL
    `ifdef SMPLFIFO
        `define ASSUME assume
    `else
        `define ASSUME assert
    `endif
    reg last_clk;
    initial 
    begin
        wptr<=0;rptr<=0;
        empty_ff<=1;full<=0;
        last_clk = 1'b0;
        restrict(rst);
    end
    always @($global_clock)
    begin
        assume(clk == !last_clk);
        last_clk<=clk;
        if (!$rose(clk))
        begin
            `ASSUME($stable(rst));
            `ASSUME($stable(wen));
            `ASSUME($stable(wdata));
            `ASSUME($stable(ren));
        end
    end
	    
`endif 

always@(posedge clk)begin
    if(full & wen)begin
        $display("ERR: FIFO cannot be write when full!");
        $stop();
    end
    //if(empty & ren)begin
    //    $display("ERR: FIFO cannot be read when empty");
    //    $stop();
    //end
end


endmodule