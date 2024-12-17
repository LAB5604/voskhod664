`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 20211226                                                                          //
//  Author  : Jack.Pan                                                                          //
//  Desc    : BPU for prv664 processors, generate pc_next and manage BP                         //
//  Version : 3.1(Version 3 with BPU modified)                                                  //
//////////////////////////////////////////////////////////////////////////////////////////////////
module bpu(
    input wire clk_i,
    input wire arst_i,
//---------------------flush signals------------------------

    pip_flush_interface.slave   flush_slave,
//---------------------bpu update interface----------------

    bpuupd_interface.slave      bpuupd_slave,

//-------------------
    input wire [`XLEN-1:0]      pc,

    input wire                  pcgen_ready,
    output logic                bpu_busy,
    output logic [`XLEN-1:0]    pc_next,
    output logic [3:0]          validword

);

`ifdef  BPU_ON
//----------------------btb-----------------------------

    logic [`XLEN-1:0]   btb_rd_predictedpc_o;	        //从buffer中得到的预测PC
    logic [1:0]         btb_rd_groupoffset_o;
    logic [2:0]         btb_rd_branchtype_o;
    logic               btb_rd_predictedvalid_o;

btb                 #(
    .BTB_SIZE               (`BTB_SIZE)
)btb(

    .clk_i                          (clk_i), 
    .rst_i                          (arst_i),

    .btb_rd_pc_i                    (pc),
    .btb_rd_predictedpc_o           (btb_rd_predictedpc_o),
    .btb_rd_groupoffset_o           (btb_rd_groupoffset_o),
    .btb_rd_branchtype_o            (btb_rd_branchtype_o),
    .btb_rd_predictedvalid_o        (btb_rd_predictedvalid_o),

    .btb_wr_req_i                   (bpuupd_slave.valid & bpuupd_slave.wr_req),
    .btb_wr_pc_i                    (bpuupd_slave.wr_pc),
    .btb_wr_predictedpc_i           (bpuupd_slave.wr_predictedpc),
    .btb_wr_branchtype_i            (bpuupd_slave.wr_branchtype)

);
//----------------------pht----------------------------------

    logic [3:0]         pht_rd_predicted_o;             //预测跳转输出，标识为该fetch group中预测为跳转的指令

pht                 #(
    .PHT_SIZE                       (`PHT_SIZE)
)pht(

    .clk_i                          (clk_i), 
    .rst_i                          (arst_i),
    .pht_rd_pc_i                    (pc),
    .pht_rd_predicted_o             (pht_rd_predicted_o),
    .pht_wr_req_i                   (bpuupd_slave.valid & bpuupd_slave.wr_req),
    .pht_wr_pc_i                    (bpuupd_slave.wr_pc),
    .pht_wr_predictbit_i            (bpuupd_slave.wr_predictbit)

);
//---------------------ras-----------------------------------

    logic               ras_push_i;
    logic               ras_pop_i;
    logic               ras_empty_o;

    logic [`XLEN-1:0]   ras_addr_i;
    logic [`XLEN-1:0]   ras_addr_o;

ras                         #(
    .WIDTH                         (`XLEN),
    .DEEPTH                         (`RAS_SIZE)
)ras(

    .clk_i                          (clk_i),
    .rst_i                          (arst_i),

    .ras_push_i                     (ras_push_i),
    .ras_pop_i                      (ras_pop_i),
    .ras_empty_o                    (ras_empty_o),
    .ras_full_o                     (),
    .ras_addr_i                     (ras_addr_i),
    .ras_addr_o                     (ras_addr_o)

);

    logic [3:0] validword_by_pc;            //由pc直接产生的validword
    logic [3:0] branch_instr;               //在这一个fetchgroup（对齐的4-word）中，分支指令的数量
    logic [3:0] branch_instr_ingroup;       //在pc范围内的分支指令


always_comb begin
    //---------------valid word mark by pc-------------
    case(pc[3:2])
        2'b00 : validword_by_pc = 4'b1111;
        2'b01 : validword_by_pc = 4'b1110;
        2'b10 : validword_by_pc = 4'b1100;
        2'b11 : validword_by_pc = 4'b1000;
        default:validword_by_pc = 4'bxxxx;
    endcase
    //--------------branch instr marked by pht and btb-------------
    if(pht_rd_predicted_o[0] & btb_rd_predictedvalid_o & (btb_rd_groupoffset_o==2'h0))begin         //当前fetchgroup中第0条指令为分支指令
        branch_instr = btb_rd_branchtype_o[`BTB_BIT_RETURN] ? (ras_empty_o ? 4'b0000 : 4'b0001) : 4'b0001;
    end
    else if(pht_rd_predicted_o[1] & btb_rd_predictedvalid_o & (btb_rd_groupoffset_o==2'h1))begin     //当前fetchgroup中第1条指令为分支指令
        branch_instr = btb_rd_branchtype_o[`BTB_BIT_RETURN] ? (ras_empty_o ? 4'b0000 : 4'b0010) : 4'b0010;
    end
    else if(pht_rd_predicted_o[2] & btb_rd_predictedvalid_o & (btb_rd_groupoffset_o==2'h2))begin     //当前fetchgroup中第2条指令为分支指令
        branch_instr = btb_rd_branchtype_o[`BTB_BIT_RETURN] ? (ras_empty_o ? 4'b0000 : 4'b0100) : 4'b0100;
    end
    else if(pht_rd_predicted_o[3] & btb_rd_predictedvalid_o & (btb_rd_groupoffset_o==2'h3))begin     //当前fetchgroup中第3条指令为分支指令
        branch_instr = btb_rd_branchtype_o[`BTB_BIT_RETURN] ? (ras_empty_o ? 4'b0000 : 4'b1000) : 4'b1000;
    end
    else begin
        branch_instr = 4'b0000;     //无事发生
    end

    branch_instr_ingroup = validword_by_pc & branch_instr;      //落在取指范围内的分支指令
    //-----------valid word--------------------------
    case(branch_instr_ingroup)
        4'b0001 : validword = validword_by_pc & 4'b0001;
        4'b0010 : validword = validword_by_pc & 4'b0011;
        4'b0100 : validword = validword_by_pc & 4'b0111;
        4'b1000 : validword = validword_by_pc & 4'b1111;
        default : validword = validword_by_pc & 4'b1111;
    endcase
    //---------------pc next and ras operting--------------
    if(flush_slave.flush)begin
        pc_next         = flush_slave.newpc;
        ras_push_i      = 0;
        ras_pop_i       = 0;
        ras_addr_i      = 'hx;
    end
    else if(pcgen_ready)begin
        pc_next         = (|branch_instr_ingroup) ? (btb_rd_branchtype_o[`BTB_BIT_RETURN] ? ras_addr_o : btb_rd_predictedpc_o) : ({pc[`XLEN-1:4], 4'h0} + 'h10);
        ras_push_i      = (|branch_instr_ingroup) & btb_rd_branchtype_o[`BTB_BIT_CALL];
        ras_pop_i       = (|branch_instr_ingroup) & btb_rd_branchtype_o[`BTB_BIT_RETURN];
        case(branch_instr_ingroup)
            4'b0001 : ras_addr_i = {pc[`XLEN-1:4], 4'h0} + 'h4;
            4'b0010 : ras_addr_i = {pc[`XLEN-1:4], 4'h0} + 'h8;
            4'b0100 : ras_addr_i = {pc[`XLEN-1:4], 4'h0} + 'hC;
            4'b1000 : ras_addr_i = {pc[`XLEN-1:4], 4'h0} + 'h10;
            default : ras_addr_i = 'hx;
        endcase
    end
    else begin
        pc_next         = pc;
        ras_push_i      = 0;
        ras_pop_i       = 0;
        ras_addr_i      = 'hx;
    end

end

`else

always_comb begin
    case(pc[3:2])
        2'h0:   validword = 4'b1111;
        2'h1:   validword = 4'b1110;
        2'h2:   validword = 4'b1100;
        2'h3:   validword = 4'b1000;
    default :   validword = 4'bxxxx;
    endcase
    if(flush_slave.flush)begin
        pc_next = flush_slave.newpc;
    end
    else begin
        pc_next = pcgen_ready ? ({pc[`XLEN-1:4], 4'h0} + 'h10) : pc;
    end
end

`endif

assign bpu_busy = bpuupd_slave.valid & bpuupd_slave.wr_req;

endmodule