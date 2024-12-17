`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022/9/3                                                                          //
//  Author  : Jack.Pan                                                                          //
//  Desc    : counter csrs for PRV664 processor                                                 //
//  Version : 0.0(Orignal)                                                                      //
//////////////////////////////////////////////////////////////////////////////////////////////////
module counter(
    input wire              clk_i,
    input wire              arst_i,
    //--------------commit------------------
    input wire              valid,
    input wire              csren,
    input wire [11:0]       csrindex,
    input wire [`XLEN-1:0]  csrdata,
    //-------------instr commit--------------
    input wire              instr0_commit_valid,
    input wire [4:0]        instr0_commit_opcode,
    input wire [`XLEN-1:0]  instr0_commit_pc,
    input wire              instr1_commit_valid,
    input wire [4:0]        instr1_commit_opcode,
    input wire [`XLEN-1:0]  instr1_commit_pc,
    //-------------浮点指令提交，用于更新fs域----------------
    output logic            fp_update,
    //-------------csr out--------------------
    output reg [`XLEN-1:0]  mcycle, minstret,pc,
    output wire [`XLEN-1:0] mcountinhibit
);
    reg cy, ir;
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        cy <= 1'b1;     //默认情况下，周期计数和指令计数都开，如果需要将低功耗，则需要程序关掉这两个bit
        ir <= 1'b1;
    end
    else if(valid&csren&(csrindex==`MRW_MCOUNTINHIBIT_INDEX))begin
        cy <= csrdata[`MCOUNTINHIBIT_BIT_CY];
        ir <= csrdata[`MCOUNTINHIBIT_BIT_IR];
    end
end

//------------------performanch counters---------------------
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        mcycle <= 'h0;
    end
    else if(valid & csren & (csrindex==`MRW_MCYCLE_INDEX))begin
        mcycle <= csrdata;
    end
    else if(cy)begin
        mcycle <= mcycle + 1;
    end

    if(arst_i)begin
        minstret <= 'h0;
    end
    else if(valid & csren & (csrindex==`MRW_MINSTRET_INDEX))begin
        minstret <= csrdata;
    end
    else if(ir)begin
        minstret <= minstret + instr0_commit_valid + instr1_commit_valid;
    end
end
//-----------------当前正在提交的pc------------------------------
always_ff @( posedge clk_i ) begin
    if(instr0_commit_valid & instr1_commit_valid)begin  //当前为双提交，pc更新为第二条提交的指令的pc
        pc <= instr1_commit_pc;
    end
    else if(instr0_commit_valid)begin                   //当前为单提交
        pc <= instr0_commit_pc;
    end
end
//----------------fp update logic------------------------------
always_comb begin
    if(instr0_commit_valid)begin
        case(instr0_commit_opcode)
            `OPCODE_MADD,`OPCODE_MSUB,`OPCODE_NMSUB,`OPCODE_NMADD,`OPCODE_OPFP: fp_update = 1'b1;
        default : fp_update = 1'b0;
        endcase
    end
    else begin
        fp_update = 1'b0;
    end
end

endmodule