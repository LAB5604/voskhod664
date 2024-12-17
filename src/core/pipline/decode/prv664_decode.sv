`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022                                                                              //
//  Author  : Jack.Pan                                                                          //
//  Desc    : Decode unit for prv664 pipline, decode instructions into micro-ops and push them  //
//            into rob and decode-queue                                                         //
//  Version : 0.0(file initialize)                                                              //
//////////////////////////////////////////////////////////////////////////////////////////////////
module prv664_decode(

    input wire                      clk_i,
    input wire                      arst_i,
//------------------flags------------------------------
//    output reg                      exclusive_flag,     //当前有一个互斥的指令
//------------------global flush signal----------------
    pip_flush_interface.slave       pip_flush_sif,
//------------------sysinfo signal---------------------
    sysinfo_interface.slave         sysinfo_slave,
//-------------------from last stage--------------------
    pip_ifu_interface.slave         pip_ifu_sif,       //slave interface of ifu
//--------------------to next stage--------------------
    pip_rob_interface.master        pip_rob_mif0,
    pip_rob_interface.master        pip_rob_mif1,
    pip_decode_interface.master     pip_decode_mif0,
    pip_decode_interface.master     pip_decode_mif1

);
/*********************************************************************************
                                    NOTE
    在每个fitchgroup中都会有最多4条指令，但decode单元一次只能同时解码两条，因此设置"_nextflag"标志位
    来指示需要将读指针移到fetchgroup的高两条指令。

    ptr的作用是确定发送出去译码的指令的顺序，考虑下面图示结构：
        ---> [ Decode queue 0 ]
        ---> [ Decode queue 1 ]
    在每个cycle中，decode完成的指令可能是一条或两条，如果是一次decode完成两个指令，则两条指令同时
    都可以被写进queue，但是，如果一次只有一条指令被decode（fetch group中只有一条指令有效）则需要按照
    0-1-0-1的顺序写进Decode queue 0和1中，这样在queue的输出端就可以根据写进去的先后顺序依次取出指令，
    避免引起顺序混乱。
    当每次写入1个指令时候，ptr会加1，写入两条指令时，ptr会加2。
    例：当前ptr=0，有两条指令A和B被decode（A在程序中的位置比B更靠前）：
        指令A应该被译码写入到Decode queue0中，B应该被写入到1中，这样在读出端可以根据先读0后读1的顺序
        保证A和B的发射顺序。
    例：当前ptr=1，其余情况和上例相同
        在ptr=1的情况下，说明之前只有一条指令写到了Decode queue 0中，假设此指令是C，那么queue中的指令
        排列情况是下图：
                --> [C]         #decode queue 0 
                --> []          #decode queue 1
        若不做处理，A写入到0，B写入到1，则queue中的排列情况：
                --> [AC]         #decode queue 0 
                --> [B]          #decode queue 1
        读出端按照约定顺序读出后，程序变成了：C-B-A，而我们希望的顺序是C-A-B，引起了错误。
        因此需要设置一个ptr来指示写的位置，指令A应该被写入Decode queue1中，B被写入0中：
                --> [BC]         #decode queue 0 
                --> [A]          #decode queue 1
        读出端按照约定顺序读出后，顺序为C-A-B，是正确的顺序。
***********************************************************************************/
//--------------------decode input manage will find out up to 2 instruction in a fetchgroup in one cycle---------
    
    logic [31:0]        instr       [1:0];
    logic [`XLEN-1:0]   instr_pc    [1:0];
    logic [1:0]         instr_valid;
    logic [1:0]         instr_ready;
    logic [1:0]         instr_is_exclusive;         //这条指令需要与其他指令互斥执行
    logic [7:0]         itag_next   [1:0];          //为当前正在译码的指令分配的itag

//--------------------互斥指令标志位-------------------------------------------

    reg                 exclusive_flag;

//--------------------push the micro-ops into rob/decode queue---------------
    logic               outif_empty, outif_full;

    decoder_interface   decode0_outif();   //decode0 micro-op output
    decoder_interface   decode1_outif();

decode_input_manage     decode_input_manage(
    .clk_i              (clk_i),
    .arst_i             (arst_i),
    .decode_input       (pip_ifu_sif),
    .pip_flush_sif      (pip_flush_sif),
    .instr0_o           (instr[0]),       
    .instr1_o           (instr[1]),
    .instr0_pc_o        (instr_pc[0]),       
    .instr1_pc_o        (instr_pc[1]),
    .instr0_valid_o     (instr_valid[0]), 
    .instr0_ready_i     (instr_ready[0]),
    .instr1_valid_o     (instr_valid[1]),
    .instr1_ready_i     (instr_ready[1])
);

//--------------------------2 decode unit--------------------------
//         decode unit decode the instr into micro ops
decode                  decode0(
    .csr_tsr_i          (sysinfo_slave.mstatus[`STATUS_BIT_TSR]),
    .csr_tvm_i          (sysinfo_slave.mstatus[`STATUS_BIT_TVM]),
    .instr_i            (instr[0]),
    .instrpc_i          (instr_pc[0]),
    .instrpriv_i        (sysinfo_slave.priv),
    .instr_valid_i      (instr_valid[0]),
    .instr_pageflt_i    (pip_ifu_sif.errtype[`ERRORTYPE_BIT_LOADPAGEFLT]),
    .instr_accflt_i     (pip_ifu_sif.errtype[`ERRORTYPE_BIT_LOADACCFLT]),
    .instr_addrmis_i    (pip_ifu_sif.errtype[`ERRORTYPE_BIT_LOADADDRMIS]),
    .instr_id_i         (itag_next[0]),
//---------------------decode output-------------------
    .decode_mif         (decode0_outif)
);
decode                  decode1(
    .csr_tsr_i          (sysinfo_slave.mstatus[`STATUS_BIT_TSR]),
    .csr_tvm_i          (sysinfo_slave.mstatus[`STATUS_BIT_TVM]),
    .instr_i            (instr[1]),
    .instrpc_i          (instr_pc[1]),
    .instrpriv_i        (sysinfo_slave.priv),
    .instr_valid_i      (instr_valid[1]),
    .instr_pageflt_i    (pip_ifu_sif.errtype[`ERRORTYPE_BIT_LOADPAGEFLT]),
    .instr_accflt_i     (pip_ifu_sif.errtype[`ERRORTYPE_BIT_LOADACCFLT]),
    .instr_addrmis_i    (pip_ifu_sif.errtype[`ERRORTYPE_BIT_LOADADDRMIS]),
    .instr_id_i         (itag_next[1]),
//---------------------decode output-------------------
    .decode_mif         (decode1_outif)
);
//--------------------找到互斥的指令----------------------
always_comb begin
    case(decode0_outif.opcode)
        `OPCODE_AMO, `OPCODE_SYSTEM, `OPCODE_MISCMEM: instr_is_exclusive[0] = instr_valid[0];
        default : instr_is_exclusive[0] = 0;
    endcase
    case(decode1_outif.opcode)
        `OPCODE_AMO, `OPCODE_SYSTEM, `OPCODE_MISCMEM: instr_is_exclusive[1] = instr_valid[1];
        default : instr_is_exclusive[1] = 0;
    endcase
end
//--------------------push信号---------------------
always_comb begin
    if(!outif_full & instr_valid[0])begin    //if rob and decode queue have space
        if(instr_is_exclusive[0] /*| decode0_outif.irrevo*/)begin
            instr_ready[0] = outif_empty; //输出空了之后，即执行级无任何正在飞行的指令即可送去执行      
        end
        else begin
            instr_ready[0] = exclusive_flag ? outif_empty : 1'b1; //如果有互斥执行的flag，这条指令要等到执行级无任何正在飞行的指令
        end
    end
    else begin
        instr_ready[0] = 1'b0;
    end
    if(!outif_full & instr_valid[1])begin    //if rob and decode queue have space
        if(|instr_is_exclusive /*| decode1_outif.irrevo | decode0_outif.irrevo*/)begin
            instr_ready[1] = 1'b0;  //如果两条指令有一条是互斥的或是不能推测执行的，则这条指令不发往下一级
        end
        else begin
            instr_ready[1] = exclusive_flag ? 1'b0 : 1'b1;
        end
    end
    else begin
        instr_ready[1] = 1'b0;
    end
end
//---------------------flag更新---------------------------
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        exclusive_flag <= 0;
    end
    else if(pip_flush_sif.flush)begin
        exclusive_flag <= 0;
    end
    else if(instr_ready[0])begin
        exclusive_flag <= instr_is_exclusive[0];
    end
end
decode_output_manage        decode_output_manage(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .pip_flush_sif              (pip_flush_sif),
    //--------------from decoder----------------
    .decode0_sif                (decode0_outif),
    .decode1_sif                (decode1_outif),
    .push_en                    (instr_ready),
    .wentrynum                  (itag_next),
    .full                       (outif_full), 
    .empty                      (outif_empty),
    //--------------to next stage----------------
    .pip_rob_mif0               (pip_rob_mif0),
    .pip_rob_mif1               (pip_rob_mif1),
    .pip_decode_mif0            (pip_decode_mif0),
    .pip_decode_mif1            (pip_decode_mif1)
);
`ifdef SIMULATION
always begin
    #1
    if(!arst_i)begin
        if($isunknown(pip_ifu_sif.valid))begin
            $display("ERR: x or z is detected in bus: ifu to idu.");
            $stop(1);
        end
        if($isunknown(instr_ready))begin
            $display("ERR: x or z is detected in bus: idu to rob/dispatch.");
            $stop(1);
        end
    end
    if(instr_valid[1] & instr_ready[1] & instr_is_exclusive[1])begin
        $display("ERR: an exclusive instruction dispatched in wrong seq."); //指令1若是互斥指令，则需要等到指令0被派遣后才能被派遣
        $stop(1);
    end
    //if(instr_valid[1] & instr_ready[1] & decode1_outif.irrevo)begin
    //    $display("ERR: an unspeculative instruction dispatch in wrong req.");
    //    $stop(1);
    //end
end
`endif
endmodule