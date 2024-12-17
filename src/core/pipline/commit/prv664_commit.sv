`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
/*********************************************************************************

   Copyright (c) [2022] [JackPan, XiaoyuHong, KuiSun]
   [prv664] is licensed under Mulan PSL v2.
   You can use this software according to the terms and conditions of the Mulan PSL v2. 
   You may obtain a copy of Mulan PSL v2 at:
            http://license.coscl.org.cn/MulanPSL2 
   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.  
   See the Mulan PSL v2 for more details.  

____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 

    Date    : 2024.1.16                                                                          
    Author  : Jack.Pan                                                                          
    Desc    : commit for prv664                                            
    Version : 2.0
    Log     : 1.0 2022/8/23 (提交级总线优化，将指令trap信息提交移至instr commit总线上) 
              2.0 2024/1/16 增加提交级宣告最后一条等待提交的指令，更新分支指令错误时的判定条件
********************************************************************************/
module prv664_commit(

    input wire                      clk_i,
    input wire                      arst_i,
    //------------------debug port----------------------------
    input wire                      debug_haltreq,
    //--------------last instruction announcment--------------
    output wire [7:0]               last_inst_itag,         //正在等待的最后一条指令的itag
    output wire                     last_inst_valid,        //正在等待的最后一条指令有效
    //------------------amo指令通知----------------------------
    sysinfo_interface.slave         sysinfo_slave,
    pip_flush_interface.slave       flush_slave,
    pip_robread_interface.slave     pip_robread_sif0,
    pip_robread_interface.slave     pip_robread_sif1,
    //-----------------------instruction 0 commit port---------------------
    flush_commit_interface.master    flush_commit_master,
    instr_commit_interface.master    instr_commit_master0,
    int_commit_interface.master      int_commit_master0,
    csr_commit_interface.master      csr_commit_master0,
    bpuupd_interface.master          bpu_commit_master,
    fp_commit_interface.master       fp_commit_master,           //only 1 fp commit master
    //-----------------------instruction 1 commit port----------------------
    instr_commit_interface.master    instr_commit_master1,
    int_commit_interface.master      int_commit_master1
    
);

    pip_robread_interface instr0();
    pip_robread_interface instr1();

commit_input_manage             commit_input_manage(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (flush_slave),
    .pip_robread_sif0           (pip_robread_sif0),
    .pip_robread_sif1           (pip_robread_sif1),
    .instr0                     (instr0),
    .instr1                     (instr1)
);
///////////////////////////////////////////////////////////////////////////
//                      branch check logic                               //
///////////////////////////////////////////////////////////////////////////

    logic [`XLEN-1:0]   expected_next_pc;                                           //下一个pc值，用于检查是否有分支错误

always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        expected_next_pc <= `PC_RESET;
    end
    else if(flush_slave.flush)begin
        expected_next_pc <= flush_slave.newpc;
    end
    else begin
        case({(instr1.valid & instr1.ready), (instr0.valid & instr0.ready)})
            2'b01: expected_next_pc <= instr0.jump ? instr0.branchaddr : (instr0.pc + 'h4);
            2'b11: expected_next_pc <= instr1.pc + 'h4;
            default : expected_next_pc <= expected_next_pc;     //this is a bad commit sequence
        endcase
    end
end
///////////////////////////////////////////////////////////////////////////
//                      instruction commit logic                         //
///////////////////////////////////////////////////////////////////////////
    logic               instr0_commit_valid,                instr1_commit_valid;    //instruction 0 is ready to commit
    //-----------------instr flush commit port-----------------
    logic               instr0_flush_commit_valid;
    logic [`XLEN-1:0]   instr0_flush_commit_newpc;
    //-----------------instr commit port signals---------------
    logic [`XLEN-1:0]   instr0_instr_commit_pc,             instr1_instr_commit_pc;
    logic [7:0]         instr0_instr_commit_itag,           instr1_instr_commit_itag;
    logic [4:0]         instr0_instr_commit_opcode,         instr1_instr_commit_opcode;
    logic               instr0_instr_commit_mmio,           instr1_instr_commit_mmio;
    logic               instr0_instr_commit_trap_m;
    logic               instr0_instr_commit_trap_s;
    logic               instr0_instr_commit_trap_async;
    logic [`XLEN-1:0]   instr0_instr_commit_trap_cause;
    logic [`XLEN-1:0]   instr0_instr_commit_trap_value;
    logic [`XLEN-1:0]   instr0_instr_commit_trap_pc;
    logic               instr0_instr_commit_trap_d;
    logic [3:0]         instr0_instr_commit_trap_dcause;
    //----------------int commit port signals------------------
    logic               instr0_int_commit_wren,             instr1_int_commit_wren;
    logic [`XLEN-1:0]   instr0_int_commit_data,             instr1_int_commit_data;
    logic [4:0]         instr0_int_commit_rdindex,          instr1_int_commit_rdindex;
    //----------------csr update port---------------------------
    logic               instr0_csr_commit_wren;
    logic [`XLEN-1:0]   instr0_csr_commit_data;
    logic [11:0]        instr0_csr_commit_csrindex;
    logic               instr0_csr_commit_mret;
    logic               instr0_csr_commit_sret;
    logic [4:0]         instr0_csr_commit_fflag;
    logic               instr0_csr_commit_fflagen;
    //---------------fp commit port----------------------------
    logic               instr0_fp_commit_wren;
    logic [`XLEN-1:0]   instr0_fp_commit_data;
    logic [4:0]         instr0_fp_commit_rdindex;
    //----------------bpu updata port--------------------------
    logic               instr0_bpuupd_wr_req;				    //写请求信号
    logic [`XLEN-1:0]   instr0_bpuupd_wr_pc;			        //要写入的分支PC
    logic [`XLEN-1:0]   instr0_bpuupd_wr_predictedpc;		    //要写入的预测PC
    logic [2:0]         instr0_bpuupd_wr_branchtype;            //要写入的分支类型
    logic               instr0_bpuupd_wr_predictbit;            //要写入的预测位
    
    logic               hold;                                   //要求指令0停止提交
    logic [1:0]         instr_pc_check, instr_exc_check;        //指令pc检查，指令异常检查 1：有错误。 0：无错误
                         
trap_manage                 trap_manage(
    .priv                   (sysinfo_slave.priv),
    .csr_mideleg            (sysinfo_slave.mideleg),
    .csr_medeleg            (sysinfo_slave.medeleg),
    .csr_mstatus            (sysinfo_slave.mstatus),
    .csr_sstatus            (sysinfo_slave.sstatus),
    .csr_mie                (sysinfo_slave.mie),
    .csr_sie                (sysinfo_slave.sie),
    .csr_dstatus            (sysinfo_slave.dstatus),
    .csr_mip                (sysinfo_slave.mip),
    .trapd_invalid          (sysinfo_slave.trapd_invalid | instr0.irrevo),  //当前指令不进入debug模式，详见hart_debug文件
    .trapi_invalid          (instr0.irrevo),
    .haltreq                (debug_haltreq),
    .load_acc_flt           (instr0.load_acc_flt), 
    .load_addr_mis          (instr0.load_addr_mis), 
    .load_page_flt          (instr0.load_page_flt),
    .store_acc_flt          (instr0.store_acc_flt), 
    .store_addr_mis         (instr0.store_addr_mis),
    .store_page_flt         (instr0.store_page_flt),
    .instr_accflt           (instr0.instr_accflt),
    .instr_pageflt          (instr0.instr_pageflt),
    .instr_addrmis          (instr0.instr_addrmis),
    .ecall                  (instr0.ecall),
    .ebreak                 (instr0.ebreak),
    .illins                 (instr0.illins),
    .trap_m                 (instr0_instr_commit_trap_m),
    .trap_s                 (instr0_instr_commit_trap_s),
    .trap_async             (instr0_instr_commit_trap_async),
    .trap_cause             (instr0_instr_commit_trap_cause),
    .trap_d                 (instr0_instr_commit_trap_d),
    .trap_dcause            (instr0_instr_commit_trap_dcause)
);
/////////////////////////////////////////////////////////////////////
//                          指令0检查逻辑                           //                  
/////////////////////////////////////////////////////////////////////
    always_comb begin
        if(instr0.valid & instr0.complete)begin
            instr_exc_check[0]          = (instr0_instr_commit_trap_m | instr0_instr_commit_trap_s | instr0_instr_commit_trap_d);
        end
        else begin
            instr_exc_check[0]          = 1'b0;
        end
    end
assign instr0_flush_commit_newpc   = expected_next_pc;
assign instr_pc_check[0] = instr0.valid & (instr0.pc != expected_next_pc);
assign instr0_flush_commit_valid = instr_pc_check[0];
/////////////////////////////////////////////////////////////////////
//                                                                 //
//                          指令0提交逻辑                           //
//                                                                 //
/////////////////////////////////////////////////////////////////////
    always_comb begin
        if(instr0.valid & instr0.complete & !instr_pc_check[0])begin
            instr0_commit_valid = 1'b1;
            instr0.ready        = 1'b1;
        end
        else begin
            instr0_commit_valid = 1'b0;
            instr0.ready        = 1'b0;
        end

        if(instr0.valid & instr0.complete)begin
            case(instr0.opcode)
                `OPCODE_BRANCH, `OPCODE_JAL, `OPCODE_JALR, `OPCODE_MISCMEM, `OPCODE_SYSTEM, `OPCODE_AMO:hold = 1;
                default : hold = instr_exc_check[0] | instr_pc_check[0] | sysinfo_slave.dstatus[`DCSR_BIT_STEP]; // step=1时，处理器变成单提交
            endcase
        end
        else begin
            hold = 1;               //指令0没有准备好时，指令1也不能提交
        end
        //---------------指令提交---------------------
        instr0_instr_commit_pc          = instr0.pc;
        instr0_instr_commit_itag        = instr0.itag;
        instr0_instr_commit_opcode      = instr0.opcode;
        instr0_instr_commit_mmio        = instr0.mmio;
        instr0_instr_commit_trap_pc     = instr0.pc;
        case(instr0_instr_commit_trap_cause)
            `CAUSE_BREAKPOINT : instr0_instr_commit_trap_value = instr0.pc;
            `CAUSE_LOAD_PAGE_FLT, `CAUSE_LOAD_ACC_FLT, `CAUSE_LOAD_ADDR_MIS, `CAUSE_STOR_PAGE_FLT, `CAUSE_STOR_ACC_FLT, `CAUSE_STOR_ADDR_MIS: instr0_instr_commit_trap_value = instr0.csrdata;
            default : instr0_instr_commit_trap_value = 'h0;
        endcase
        //-------------csr提交--------------- 
        instr0_csr_commit_wren          = instr0.csren;
        instr0_csr_commit_csrindex      = instr0.csrindex;
        instr0_csr_commit_data          = instr0.csrdata;
        instr0_csr_commit_mret          = instr0.mret;
        instr0_csr_commit_sret          = instr0.sret;
        instr0_csr_commit_fflag         = instr0.fflag;
        instr0_csr_commit_fflagen       = instr0.fflagen; 
        //-------------浮点提交----------------
        instr0_fp_commit_wren           = instr0.frden;
        instr0_fp_commit_data           = instr0.data;
        instr0_fp_commit_rdindex        = instr0.frdindex;
        //------------------整数提交------------------
        instr0_int_commit_data          = instr0.data;
        instr0_int_commit_rdindex       = instr0.rdindex;
        instr0_int_commit_wren          = instr0.rden;
        //-----------------bpu提交---------------------
        case(instr0.opcode)
            `OPCODE_BRANCH, `OPCODE_JAL, `OPCODE_JALR : instr0_bpuupd_wr_req = 1'b1;
            default : instr0_bpuupd_wr_req = 1'b0;
        endcase
        instr0_bpuupd_wr_pc             = instr0.pc;
        instr0_bpuupd_wr_predictedpc    = instr0.branchaddr;
        instr0_bpuupd_wr_branchtype     = instr0.branchtype;
        instr0_bpuupd_wr_predictbit     = instr0.jump;

    end

    always_ff @( posedge clk_i or posedge arst_i) begin
        if(arst_i)begin
            instr_commit_master0.valid  <= 1'b0;
            csr_commit_master0.valid    <= 1'b0;
            int_commit_master0.valid    <= 1'b0;
            fp_commit_master.valid      <= 1'b0;
            bpu_commit_master.valid     <= 1'b0;
            flush_commit_master.valid   <= 1'b0;
        end
        else if(flush_slave.flush)begin
            instr_commit_master0.valid  <= 1'b0;
            csr_commit_master0.valid    <= 1'b0;
            int_commit_master0.valid    <= 1'b0;
            fp_commit_master.valid      <= 1'b0;
            bpu_commit_master.valid     <= 1'b0;
            flush_commit_master.valid   <= 1'b0;
        end
        else begin
            instr_commit_master0.valid  <= instr0_commit_valid;
            csr_commit_master0.valid    <= instr0_commit_valid & !instr_exc_check[0];
            int_commit_master0.valid    <= instr0_commit_valid & !instr_exc_check[0];
            fp_commit_master.valid      <= instr0_commit_valid & !instr_exc_check[0];
            bpu_commit_master.valid     <= instr0_commit_valid & !instr_exc_check[0];
            flush_commit_master.valid   <= instr0_flush_commit_valid;
        end
    end
    always_ff@(posedge clk_i)begin
        instr_commit_master0.pc         <= instr0_instr_commit_pc;
        instr_commit_master0.itag       <= instr0_instr_commit_itag;
        instr_commit_master0.opcode     <= instr0_instr_commit_opcode;
        instr_commit_master0.trap_m     <= instr0_instr_commit_trap_m;
        instr_commit_master0.trap_s     <= instr0_instr_commit_trap_s;
        instr_commit_master0.trap_async <= instr0_instr_commit_trap_async;
        instr_commit_master0.trap_cause <= instr0_instr_commit_trap_cause;
        instr_commit_master0.trap_value <= instr0_instr_commit_trap_value;
        instr_commit_master0.trap_pc    <= instr0_instr_commit_trap_pc;
        instr_commit_master0.trap_d     <= instr0_instr_commit_trap_d;
        instr_commit_master0.trap_dcause<= instr0_instr_commit_trap_dcause;
        instr_commit_master0.mmio       <= instr0_instr_commit_mmio;

        csr_commit_master0.csren        <= instr0_csr_commit_wren;
        csr_commit_master0.csrindex     <= instr0_csr_commit_csrindex;
        csr_commit_master0.csrdata      <= instr0_csr_commit_data;
        csr_commit_master0.mret         <= instr0_csr_commit_mret;
        csr_commit_master0.sret         <= instr0_csr_commit_sret;
        csr_commit_master0.fflag        <= instr0_csr_commit_fflag;
        csr_commit_master0.fflagen      <= instr0_csr_commit_fflagen;

        int_commit_master0.wren         <= instr0_int_commit_wren;
        int_commit_master0.rdindex      <= instr0_int_commit_rdindex;
        int_commit_master0.data         <= instr0_int_commit_data;

        bpu_commit_master.wr_req        <= instr0_bpuupd_wr_req;
        bpu_commit_master.wr_predictbit <= instr0_bpuupd_wr_predictbit;
        bpu_commit_master.wr_branchtype <= instr0_bpuupd_wr_branchtype;
        bpu_commit_master.wr_pc         <= instr0_bpuupd_wr_pc;
        bpu_commit_master.wr_predictedpc<= instr0_bpuupd_wr_predictedpc;

        fp_commit_master.wren           <= instr0_fp_commit_wren;
        fp_commit_master.data           <= instr0_fp_commit_data;
        fp_commit_master.rdindex        <= instr0_fp_commit_rdindex;

        flush_commit_master.newpc       <= instr0_flush_commit_newpc;
    end
assign last_inst_itag = instr0.itag;    //宣告instr0，即当前等待提交的最后一条指令的itag
assign last_inst_valid= instr0.valid & !instr_pc_check[0];//最后一条指令有效，只有当这条指令的pc正确时，才会被宣告最后一条等待提交的指令
/////////////////////////////////////////////////////////////////////
//                          指令1检查逻辑                           //
/////////////////////////////////////////////////////////////////////
    always_comb begin
        if(instr0.valid & instr0.complete & instr1.valid & instr1.complete)begin
            instr_pc_check[1]           = instr0.jump ? (instr1.pc != instr0.branchaddr) : (instr1.pc != instr0.pc + 'd4);
            instr_exc_check[1]          = (instr1.load_acc_flt|instr1.load_addr_mis|instr1.load_page_flt|
                                            instr1.store_acc_flt|instr1.store_addr_mis|instr1.store_page_flt|
                                            instr1.instr_accflt| instr1.instr_pageflt| instr1.instr_addrmis|
                                            instr1.mret|instr1.sret|instr1.illins|instr1.ecall);
        end
        else begin
            instr_pc_check[1]           = 1'b0;
            instr_exc_check[1]          = 1'b0;
        end
    end
/////////////////////////////////////////////////////////////////////
//                                                                 //
//                          指令1提交逻辑                           //
//  指令1仅提交整数                                                 //
/////////////////////////////////////////////////////////////////////

    always_comb begin
        if(instr1.valid & instr1.complete & !instr_pc_check[1] & !instr_exc_check[1])begin
            if(hold)begin
                instr1_commit_valid = 0;
                instr1.ready        = 0;
            end
            else begin
                case(instr1.opcode)
                    `OPCODE_OPIMM,`OPCODE_OPIMM32,`OPCODE_OP,`OPCODE_OP32,`OPCODE_LUI,      //指令1的提交接口对opcode限制较为严格
                    `OPCODE_AUIPC,`OPCODE_LOAD:                                             //只有这些opcode允许被提交
                    begin
                        instr1_commit_valid = 1'b1;
                        instr1.ready        = instr1_commit_valid;
                    end
                    default : 
                    begin 
                        instr1_commit_valid = 0;
                        instr1.ready = 0;
                    end
                endcase
            end
        end
        else begin
            instr1_commit_valid = 0;
            instr1.ready = 0;
        end
        //------------指令提交-----------------
        instr1_instr_commit_pc          = instr1.pc;
        instr1_instr_commit_itag        = instr1.itag;
        instr1_instr_commit_opcode      = instr1.opcode;
        instr1_instr_commit_mmio        = instr1.mmio;
        //------------整数提交---------------
        instr1_int_commit_wren          = instr1.rden;
        instr1_int_commit_data          = instr1.data;
        instr1_int_commit_rdindex       = instr1.rdindex;
    end

    always_ff @( posedge clk_i or posedge arst_i) begin
        if(arst_i)begin
            instr_commit_master1.valid   <= 1'b0;
            int_commit_master1.valid     <= 1'b0;
        end
        else if(flush_slave.flush)begin
            instr_commit_master1.valid   <= 1'b0;
            int_commit_master1.valid     <= 1'b0;
        end
        else begin
            instr_commit_master1.valid   <= instr1_commit_valid;
            int_commit_master1.valid     <= instr1_commit_valid & !instr_exc_check[1];
        end
    end
    always_ff@(posedge clk_i)begin
        instr_commit_master1.pc         <= instr1_instr_commit_pc;
        instr_commit_master1.itag       <= instr1_instr_commit_itag;
        instr_commit_master1.opcode     <= instr1_instr_commit_opcode;
        instr_commit_master1.mmio       <= instr1_instr_commit_mmio;

        int_commit_master1.wren         <= instr1_int_commit_wren;
        int_commit_master1.rdindex      <= instr1_int_commit_rdindex;
        int_commit_master1.data         <= instr1_int_commit_data;

    end
//----------------------instr1不会产生任何trap-----------------------
assign instr_commit_master1.trap_m      = 1'b0;
assign instr_commit_master1.trap_s      = 1'b0;
assign instr_commit_master1.trap_async  = 1'b0;
assign instr_commit_master1.trap_cause  = 'h0;
assign instr_commit_master1.trap_value  = 'h0;
assign instr_commit_master1.trap_pc     = 'h0;
assign instr_commit_master1.trap_d      = 'h0;
assign instr_commit_master1.trap_dcause = 'h0;
//---------------------------assert语句---------------------------------
`ifdef SIMULATION
always begin
    #1
    if(!arst_i)begin
        if($isunknown(instr0_commit_valid)==1)begin
            $display("ERR:x or z is dected in bus: commit.");
            $stop(1);
        end
        if($isunknown(instr1_commit_valid)==1)begin
            $display("ERR:x or z is dected in bus: commit.");
            $stop(1);
        end
        if($isunknown(instr0_instr_commit_trap_m)|$isunknown(instr0_instr_commit_trap_s)|$isunknown(instr0_instr_commit_trap_d))begin
            $display("ERR:x or z is dected in bus:commit.trap");
        end
    end
end
`endif
endmodule