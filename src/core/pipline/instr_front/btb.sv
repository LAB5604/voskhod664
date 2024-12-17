`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
module btb
#(
    parameter BTB_SIZE = 32
)(

//-------------------Global SIgnal----------------
    input  logic                clk_i, rst_i,
//------------------read port1---------------------
    input  logic [`XLEN-1:0]    btb_rd_pc_i,					//输入PC
    output logic [`XLEN-1:0]    btb_rd_predictedpc_o,	        //从buffer中得到的预测PC
    output logic [1:0]          btb_rd_groupoffset_o,
    output logic [2:0]          btb_rd_branchtype_o,
    output logic                btb_rd_predictedvalid_o,
//----------------IDU write and check port--------
    input logic                 btb_wr_req_i,				    //写请求信号
    input logic [`XLEN-1:0]     btb_wr_pc_i,					//要写入的分支PC
    input logic [`XLEN-1:0]     btb_wr_predictedpc_i,		    //要写入的预测PC
    input logic [2:0]           btb_wr_branchtype_i	            //要写入的分支类型

);
    localparam  BUFFER_ADDR_LEN = $clog2(BTB_SIZE) + 1;
    localparam  TAG_LEN         = 24-BUFFER_ADDR_LEN;

    reg [TAG_LEN-1:0]   tag_pc          [BTB_SIZE-1:0];
    reg [1:0]           groupoffset     [BTB_SIZE-1:0];
    reg [2:0]           branchtype      [BTB_SIZE-1:0];
    reg [`XLEN-1:0]     predicted_pc    [BTB_SIZE-1:0];
    reg                 predicted_valid [BTB_SIZE-1:0];

    wire [TAG_LEN-1:0]          rd_pc_tag;                      //在直接映射中，tag长度仅取一部分长度即可，可以节约逻辑资源
    wire [BUFFER_ADDR_LEN-1:0]  rd_pc_index;
    wire [1:0]                  rd_pc_offset;
    wire [1:0]                  rd_pc_groupoffset;

    wire [TAG_LEN-1:0]          wr_pc_tag;
    wire [BUFFER_ADDR_LEN-1:0]  wr_pc_index;
    wire [1:0]                  wr_pc_offset;                   //4字对齐指令内部偏移，不用
    wire [1:0]                  wr_pc_groupoffset;              //该分支指令处于此group的偏移量

assign {rd_pc_tag, rd_pc_index, rd_pc_groupoffset, rd_pc_offset}=btb_rd_pc_i;
assign {wr_pc_tag, wr_pc_index, wr_pc_groupoffset, wr_pc_offset}=btb_wr_pc_i;

always@(*)begin

   btb_rd_predictedpc_o     = predicted_pc[rd_pc_index];
   btb_rd_branchtype_o      = branchtype[rd_pc_index];
   btb_rd_groupoffset_o     = groupoffset[rd_pc_index];

   if(predicted_valid[rd_pc_index] & (rd_pc_tag==tag_pc[rd_pc_index]))begin
       btb_rd_predictedvalid_o = 1'b1;
   end
   else begin
       btb_rd_predictedvalid_o = 1'b0;
   end
end

integer i;
always@(posedge clk_i)begin
    if(rst_i)begin
        for(i=0; i<BTB_SIZE; i=i+1)begin
            tag_pc[i]           <=0;
            predicted_pc[i]     <=0;
            branchtype[i]       <=0;
            predicted_valid[i]  <=0;
        end
    end
    else if(btb_wr_req_i)begin
        tag_pc[wr_pc_index]         <= wr_pc_tag;
        groupoffset[wr_pc_index]    <= wr_pc_groupoffset;
        predicted_pc[wr_pc_index]   <= btb_wr_predictedpc_i;
        branchtype[wr_pc_index]     <= btb_wr_branchtype_i;
        predicted_valid[wr_pc_index]<=1'b1;
    end
end

endmodule