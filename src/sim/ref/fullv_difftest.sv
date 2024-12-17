`timescale 1ps/1ps
/**********************************************************************************************
                                                                     
    Desc    : full verilog difftest for riscv processor
    Author  : Jack.Pan
    Date    : 2023/7/3
    Version : 0.0

***********************************************************************************************/
module fullv_difftest#(
    parameter   XLEN        = 64,
                TRACE_DEEPTH= 64,           //trace 64 instructions MAX
                PROG_FILE   = "hex.txt"
)(
    input wire                  clk_i, arst_i,
//--------------dut 寄存器值输入-------------
    input wire [XLEN-1:0]       dut_ireg [31:0],
    input wire [XLEN-1:0]       dut_mepc, dut_mstatus, dut_mtval,   //TODO: 目前只检查这三个寄存器
//--------------dut 指令提交端口-------------
    test_commit_interface.slave test_commit0,
    test_commit_interface.slave test_commit1
);
//trace使用的寄存器
//    reg [XLEN-1:0] trace_ram [TRACE_DEEPTH-1:0];    //TODO: 以后把trace加上
//    reg [XLEN-1:0] trace_cnt, trace_ptr;
//指令值提交寄存器
//从dut提交的信息在这里被打一拍，而后与参考模型的提交数据进行对比
    reg [XLEN-1:0] r_commit_pc[1:0];
    reg [1:0]      r_commit_valid;
    reg [1:0]      r_commit_trapm, r_commit_traps, r_commit_trapd;    //提交的这条指令存在异常，不会被diff比较
//参考模型控制信号
    wire [7:0]      ref_step;
//参考模型的值
    wire [XLEN-1:0] ref_ireg [31:0];
    wire [XLEN-1:0] ref_mstatus, ref_mtval, ref_mepc;
    wire [XLEN-1:0] ref_pc;             //参考模型目前已提交的指令的位置
initial begin
    r_commit_valid = 0;     //开始时清零
    //trace_cnt = 0;
    //trace_ptr = 0;
end
always@(posedge clk_i)begin
    r_commit_pc[0] <= test_commit0.pc;
    r_commit_pc[1] <= test_commit1.pc;
    r_commit_valid[0] <= test_commit0.valid;
    r_commit_valid[1] <= test_commit1.valid;    //TODO:异常提交以后要补上
    r_commit_trapm[0] <= 0;
    r_commit_trapm[1] <= 0;
    r_commit_traps[0] <= 0;
    r_commit_traps[1] <= 0;
    r_commit_trapd[0] <= 0;
    r_commit_trapd[1] <= 0;
end
//-----------------------ref module-----------------------------
assign ref_step = test_commit0.valid + test_commit1.valid;
virtual_rv#(
    .PROG_FILE      (PROG_FILE),
    .XLEN           (XLEN)
)ref_module(
//-----------------control port-----------------------
    .clk_i          (clk_i),
    .arst_i         (arst_i),
    .valid_i        (test_commit0.valid | test_commit1.valid),
    .step_num_i     (ref_step),
//-----------------register out-----------------------
    .pc             (),             //NO use
    .pc_commited    (ref_pc),       //pc指向下一条指令的地址，pc-commit指向当前已提交指令的地址
    .r0(ref_ireg[0]),.r1(ref_ireg[1]),.r2(ref_ireg[2]),.r3(ref_ireg[3]),
    .r4(ref_ireg[4]),.r5(ref_ireg[5]),.r6(ref_ireg[6]),.r7(ref_ireg[7]),
    .r8(ref_ireg[8]),.r9(ref_ireg[9]),.r10(ref_ireg[10]),.r11(ref_ireg[11]),
    .r12(ref_ireg[12]),.r13(ref_ireg[13]),.r14(ref_ireg[14]),.r15(ref_ireg[15]),
    .r16(ref_ireg[16]),.r17(ref_ireg[17]),.r18(ref_ireg[18]),.r19(ref_ireg[19]),
    .r20(ref_ireg[20]),.r21(ref_ireg[21]),.r22(ref_ireg[22]),.r23(ref_ireg[23]),
    .r24(ref_ireg[24]),.r25(ref_ireg[25]),.r26(ref_ireg[26]),.r27(ref_ireg[27]),
    .r28(ref_ireg[28]),.r29(ref_ireg[29]),.r30(ref_ireg[30]),.r31(ref_ireg[31]),
    //-----------csr----------------
    .csr_mstatus(ref_mstatus), .csr_mtval(ref_mtval), .csr_mtvec(), .csr_mcause(), .csr_mepc(ref_mepc), .csr_mie() 
);
//----------------fullv difftest logic----------------------
always@(negedge clk_i)begin     //下降沿检查寄存器是否相等
    if(|r_commit_valid)begin
        if(r_commit_valid[1])begin
            if(r_commit_pc[1]!=ref_pc)begin
                $display("ERR:wrong commit seq, right=0x%h wrong=0x%h",ref_pc,r_commit_pc[1]);
                finish();
            end
        end
        else if(r_commit_valid[0])begin
            if(r_commit_pc[0]!=ref_pc)begin
                $display("ERR:wrong commit seq, right=0x%h wrong=0x%h",ref_pc,r_commit_pc[0]);
                finish();
            end
        end
        ireg_compare();
        csr_compare();
    end
end
////////////////////////////////////////////////////////////
//                 task to compare ireg                   //
////////////////////////////////////////////////////////////
integer j = 0;
task ireg_compare();
begin
    for(j=0;j<32;j=j+1)begin
        if(dut_ireg[j]!=ref_ireg[j])begin
            $display("ERR:r%d has wrong value at pc=0x%h",j,ref_pc);        //如果dut运行值和模型不一致，则停止仿真
            $display("    right=0x%h,wrong=0x%h",ref_ireg[j],dut_ireg[j]);
            finish();
        end
        else if($isunknown(dut_ireg[j]) | $isunknown(ref_ireg[j]))begin
            $display("ERR:r%d has x or z value at pc=0x%h",j,ref_pc);       //如果有x出现，停止仿真，仿真case中应该避免x出现
        end
    end
end
endtask
/////////////////////////////////////////////////////////////
//               task to compare csrs                      //
/////////////////////////////////////////////////////////////
task csr_compare();
begin
    if(dut_mepc != ref_mepc)begin
        $display("ERR:mepc has wrong value at pc=0x%h",j,ref_pc);
        $display("    right=0x%h,wrong=0x%h",ref_mepc,dut_mepc);
        finish();
    end
    if(dut_mstatus != ref_mstatus)begin
        $display("ERR:mstatus has wrong value at pc=0x%h",j,ref_pc);
        $display("    right=0x%h,wrong=0x%h",ref_mstatus,dut_mstatus);
        finish();
    end
    if(dut_mtval != ref_mtval)begin
        $display("ERR:mtval has wrong value at pc=0x%h",j,ref_pc);
        $display("    right=0x%h,wrong=0x%h",ref_mtval,dut_mtval);
        finish();
    end
    //TODO: 目前只对比三个csr寄存器
end
endtask
/////////////////////////////////////////////////////////////
//                     task when end                       //
/////////////////////////////////////////////////////////////
task finish();
begin
    $display("INFO:fv-difftest stop.");
    $finish(1); 
end
endtask

endmodule