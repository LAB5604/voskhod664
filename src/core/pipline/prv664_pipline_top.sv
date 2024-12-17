`include "prv664_define.svh"
`include "prv664_config.svh"
/**********************************************************************************************

   Copyright (c) [2022] [JackPan, XiaoyuHong, KuiSun]
   [Software Name] is licensed under Mulan PSL v2.
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
                                                                             
    Desc    : PRV664(voskhod664) pipline top file, MMU and Cache are NOT include
    Author  : JackPan
    Date    : 2023/7/13
    Version : 1.0 debug module csr include
              2.0 the difftest from Openxiangshan now ready to run
              2.1 fix some bugs when running Openxiangshan difftest

***********************************************************************************************/
module prv664_pipline_top#(
    parameter HARTID = 'h0
)(

    input wire                      clk_i,              //clock input, all the logic inside this module is posedge active
    input wire                      arst_i,             //async reset input, high active, ples make sure this signal is sync with clock
//---------------------------clint-----------------------------------------
    clint_interface.slave           clint_slave,
//--------------------------debug interface--------------------------------
    pipdebug_interface.slave        pipdebug_slave,
//-----------------------------to store buffer--------------------------
    sysmanage_interface.master      stb_manage_master,
//---------------------axi bus for ptw use----------------------------------
    axi_ar.master                   immu_axi_ar,
    axi_r.slave                     immu_axi_r,
    axi_ar.master                   dmmu_axi_ar,
    axi_r.slave                     dmmu_axi_r,
//-------------------instruction mmu and cache access port------------------
    axi_ar.master                   icache_axi_ar,
    axi_r.slave                     icache_axi_r,
//--------------------data mmu and cache access port------------------------
    axi_aw.master                   dcache_axi_aw,
    axi_w.master                    dcache_axi_w,
    axi_b.slave                     dcache_axi_b,
    axi_ar.master                   dcache_axi_ar,
    axi_r.slave                     dcache_axi_r

);
localparam  L1I_INDEXADDR_SIZE = $clog2(`L1I_LINE_NUM),
            L1D_INDEXADDR_SIZE = $clog2(`L1D_LINE_NUM);
//----------------------mmu flush req/ack-----------------
    wire                     immu_flush_req, dmmu_flush_req;
    wire                     immu_flush_ack, dmmu_flush_ack;
//-------------------pipline interfaces-------------------
    pip_flush_interface     pip_flush();
    sysinfo_interface       pip_sysinfo();              //system vaue interface, include csr value
    //----------------instruction fetch to decode-------------------------
    pip_ifu_interface       pip_ifu2decode();           //ifu to decode interface
    mmu_interface           pip_ifu2mmu();
    cache_access_interface  icache_mif();
    cache_return_interface  icache_sif();
    axi_aw                  icache_axi_aw();    
    axi_w                   icache_axi_w();
    axi_b                   icache_axi_b();
assign icache_axi_aw.awready = 0;               //icache dont use axi write channel
assign icache_axi_w.wready = 0;                 //so tie those signal to constant value
assign icache_axi_b.bvalid = 0;
    //----------------decode unit to rob and dispatch unit----------------
    pip_decode_interface    pip_decode2dispatch0();     //decode to dispatch interface
    pip_decode_interface    pip_decode2dispatch1();
    pip_rob_interface       pip_decode2rob0();
    pip_rob_interface       pip_decode2rob1();
    //-----------------dispatch unit to execute unit------------------
    pip_exu_interface       pip_dispatch2bru();
    pip_exu_interface       pip_dispatch2alu0();
    pip_exu_interface       pip_dispatch2alu1();
    pip_exu_interface       pip_dispatch2mdiv();
    pip_exu_interface       pip_dispatch2lsu();
    pip_exu_interface       pip_dispatch2fpu();
    pip_exu_interface       pip_dispatch2bypass();
    pip_exu_interface       pip_dispatch2sysmag();
    mmu_interface           pip_lsu2mmu();
    cache_access_interface  dcache_mif();
    cache_return_interface  dcache_sif();
    //-----------------memory subsystem control---------------------------
    wire                    icache_flush_req, dcache_flush_req;
    wire                    icache_flush_ack, dcache_flush_ack;
    wire [7:0]              last_inst_itag; 
    wire                    last_inst_valid;
    wire                    burnaccess;
    //-----------------from execute to writeback multiplex----------------
    pip_wb_interface        pip_bru2wb();
    pip_wb_interface        pip_alu02wb();
    pip_wb_interface        pip_alu12wb();
    pip_wb_interface        pip_mdiv2wb();
    pip_wb_interface        pip_fpu2wb();
    pip_wb_interface        pip_lsu2wb();
    pip_wb_interface        pip_bypass2wb();
    pip_wb_interface        pip_sysmag2wb();
    //----------------from writeback multiplex to rob----------------------
    pip_wb_interface        pip_wb2rob0();              //write back to rob0 
    pip_wb_interface        pip_wb2rob1();              //write back to rob1
    //----------------from rob to commit--------------------------------
    pip_robread_interface   pip_rob2cmt0();
    pip_robread_interface   pip_rob2cmt1();
//--------------------commit interface--------------------------
    flush_commit_interface  flush_commit();
    instr_commit_interface  instr_commit0();
    int_commit_interface    int_commit0();
    fp_commit_interface     fp_commit();
    csr_commit_interface    csr_commit();
    bpuupd_interface        bpu_commit();
    //---------------指令1提交接口，指令1仅提交整数----------------
    instr_commit_interface  instr_commit1();
    int_commit_interface    int_commit1();
//-------------------flush request from csr-----------------------
    wire                    csr_flush_req, csr_hold_req;
    wire [`XLEN-1:0]        csr_flush_newpc;
//-------------------i/f scoreboard read interface----------------

    scoreboard_update_interface     iscoreboard_update0();
    scoreboard_update_interface     iscoreboard_update1();
    scoreboard_update_interface     fscoreboard_update();
    wire [7:0]      igpr_id_flag                    [31:0];
    wire [7:0]      fgpr_id_flag                    [31:0];
    wire [31:0]     igpr_busy_flag, fgpr_busy_flag;
    cscoreboard_access_interface    cscoreboard_access();
    igpr_access_interface           igpr_access0();
    igpr_access_interface           igpr_access1();
    fgpr_access_interface           fgpr_access();
    csr_access_interface            csr_access();

`ifdef SIMULATION
    wire [`XLEN-1:0] test_reg [31:0];
    wire [`XLEN-1:0] test_csr [4095:0];
`endif

//////////////////////////////////////////////////////////////////
//         instruction front unit                               //
//////////////////////////////////////////////////////////////////
prv664_instr_front          ifu(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .sysinfo_slave              (pip_sysinfo),
    .bpuupd_slave               (bpu_commit),
    .mmuinterface_mif           (pip_ifu2mmu),
    .cacheinterface_result      (icache_sif),
    .pip_ifu_mif                (pip_ifu2decode)
);
prv664_mmu#(
    .INST                       (1)
)immu(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .sysinfo_slave              (pip_sysinfo),
    .mmuflush_req               (immu_flush_req),
    .mmuflush_ack               (immu_flush_ack),
    .mmu_burnaccess             (1'b0), 
    .last_inst_itag             (0),
    .last_inst_valid            (1'b0),
//------------------pipline access stream------------------------
    .mmu_access_sif             (pip_ifu2mmu),
    .cache_access_mif           (icache_mif),
//-------------------ptw access memory--------------------------
    .ptw_axi_ar                 (immu_axi_ar),
    .ptw_axi_r                  (immu_axi_r)
);
`ifdef PIP_ICACHE
    pip_icache_top#(
`else
    icache_top#(
`endif
    .CACHE_INDEXADDR_SIZE (L1I_INDEXADDR_SIZE)
)i_cache(
    .clk_i                  (clk_i),
    .srst_i                 (arst_i),
    //------------cpu manage interface-----------
    .cache_flush_req        (icache_flush_req),
    .cache_flush_ack        (icache_flush_ack),
    //------------cpu pipline interface-----------
    .cache_access_if        (icache_mif),
    .cache_return_if        (icache_sif),
    //------------axi interface-----------
    .cache_axi_ar           (icache_axi_ar),
    .cache_axi_r            (icache_axi_r),
    .cache_axi_aw           (icache_axi_aw),    //icache do NOT use write channel, so aw w b channle is connect to dummy
    .cache_axi_w            (icache_axi_w),
    .cache_axi_b            (icache_axi_b)
);
prv664_decode                   idu(

    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .pip_flush_sif              (pip_flush),
    .sysinfo_slave              (pip_sysinfo),
    .pip_ifu_sif                (pip_ifu2decode),       //slave interface of ifu
    .pip_rob_mif0               (pip_decode2rob0),
    .pip_rob_mif1               (pip_decode2rob1),
    .pip_decode_mif0            (pip_decode2dispatch0),
    .pip_decode_mif1            (pip_decode2dispatch1)

);

prv664_dispatch                 dpu(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .pip_flush_sif              (pip_flush),          //flush signal
    .pip_decode_sif0            (pip_decode2dispatch0),
    .pip_decode_sif1            (pip_decode2dispatch1),
//--------------------read gpr, read csr, read scoreboard port-----------
    .igpr_access_master0        (igpr_access0),
    .igpr_access_master1        (igpr_access1),
    .fgpr_access_master         (fgpr_access),
    .csr_access_mster           (csr_access),
    .iscoreboard_update_master0 (iscoreboard_update0),
    .iscoreboard_update_master1 (iscoreboard_update1),
    .fscoreboard_update_master  (fscoreboard_update),
    .cscoreboard_access_master  (cscoreboard_access),       //csr scoreboard access
    .igpr_id_flag               (igpr_id_flag),             //目前来说没用
    .fgpr_id_flag               (fgpr_id_flag),             //目前来说没用
    .igpr_busy_flag             (igpr_busy_flag),
    .fgpr_busy_flag             (fgpr_busy_flag),
//--------------------dispatch port to next stage------------------
    .pip_dispbru_mif            (pip_dispatch2bru),
    .pip_dispalu0_mif           (pip_dispatch2alu0),       //fine, now we have two alu!
    .pip_dispalu1_mif           (pip_dispatch2alu1),
    .pip_dispmdiv_mif           (pip_dispatch2mdiv),
    .pip_dispfpu_mif            (pip_dispatch2fpu),
    .pip_displsu_mif            (pip_dispatch2lsu),
    .pip_dispbypass_mif         (pip_dispatch2bypass),
    .pip_dispsysman_mif         (pip_dispatch2sysmag)
);

/////////////////////////////////////////////////////////////////////////////////////////
//                                execute engine                                       //
/////////////////////////////////////////////////////////////////////////////////////////

bru             bru(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .bru_sif                    (pip_dispatch2bru),          //branch unit slave interface
    .bru_mif                    (pip_bru2wb)
);

alu             alu0(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .alu_sif                    (pip_dispatch2alu0),
    .alu_mif                    (pip_alu02wb)
);
alu             alu1(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .alu_sif                    (pip_dispatch2alu1),
    .alu_mif                    (pip_alu12wb)
);

lsu             #(
    .IDLEN                      (8)
)lsu(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .burnaccess                 (burnaccess),     //清空正在进行的访问
    .lsu_sif                    (pip_dispatch2lsu),
    .lsu_mif                    (pip_lsu2wb),
    .mmu_access_mif             (pip_lsu2mmu),
    .cacheinterface_result      (dcache_sif)
);
prv664_mmu                  dmmu(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .sysinfo_slave              (pip_sysinfo),
    .mmuflush_req               (dmmu_flush_req),
    .mmuflush_ack               (dmmu_flush_ack),
    .mmu_burnaccess             (burnaccess), 
    .last_inst_itag             (last_inst_itag),
    .last_inst_valid            (last_inst_valid),
//------------------pipline access stream------------------------
    .mmu_access_sif             (pip_lsu2mmu),
    .cache_access_mif           (dcache_mif),
//-------------------ptw access memory--------------------------
    .ptw_axi_ar                 (dmmu_axi_ar),
    .ptw_axi_r                  (dmmu_axi_r)
);
`ifdef PIP_DCACHE
    pip_dcache_top#(
`else
    dcache_top#(
`endif
    .CACHE_INDEXADDR_SIZE (L1D_INDEXADDR_SIZE)
)d_cache(
    .clk_i                  (clk_i),
    .srst_i                 (arst_i),
    //------------cpu manage interface-----------
    .cache_flush_req        (dcache_flush_req),
    .cache_flush_ack        (dcache_flush_ack),
    .cache_burnaccess       (burnaccess),
    .last_inst_itag         (last_inst_itag),
    .last_inst_valid        (last_inst_valid),
    //------------cpu pipline interface-----------
    .cache_access_if        (dcache_mif),
    .cache_return_if        (dcache_sif),
    //------------axi interface-----------
    .cache_axi_ar           (dcache_axi_ar),
    .cache_axi_r            (dcache_axi_r),
    .cache_axi_aw           (dcache_axi_aw),
    .cache_axi_w            (dcache_axi_w),
    .cache_axi_b            (dcache_axi_b)
);
bypass          bypass(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .bypass_sif                 (pip_dispatch2bypass),
    .bypass_mif                 (pip_bypass2wb)
);
sysmanage       sysman(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .sysmag_sif                 (pip_dispatch2sysmag),
    .sysmag_mif                 (pip_sysmag2wb),
    //----------to sys manage bus--------
    .icache_flush_req           (icache_flush_req),
    .dcache_flush_req           (dcache_flush_req),
    .immu_flush_req             (immu_flush_req),
    .dmmu_flush_req             (dmmu_flush_req),
    .icache_flush_ack           (icache_flush_ack),
    .dcache_flush_ack           (dcache_flush_ack),
    .immu_flush_ack             (immu_flush_ack),
    .dmmu_flush_ack             (dmmu_flush_ack)
);
/////////////////////////////////////////////////
//               mdiv unit                     //
/////////////////////////////////////////////////
mdiv                mdiv(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .mdiv_sif                   (pip_dispatch2mdiv),
    .mdiv_mif                   (pip_mdiv2wb)
);
/////////////////////////////////////////////////
//               fp unit                       //
/////////////////////////////////////////////////
`ifdef FPU_ON
fpu_top             fpu(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    //系统信息，包含fcsr信息
    .sysinfo_slave              (pip_sysinfo),
    //access fgpr 
    .fgpr_access_slave          (fgpr_access),
    //from dpu to fpu
    .fpu_sif                    (pip_dispatch2fpu),
    .fpu_mif                    (pip_fpu2wb)
);
`else   //FPU未接入，将full信号和valid信号接0
assign pip_dispatch2fpu.full = 'b0;
assign pip_fpu2wb.valid      = 'b0;
`endif
prv664_writeback                wb_multiplexer(
    .bru_wb_sif                 (pip_bru2wb),
    .sysmag_wb_sif              (pip_sysmag2wb),
    .alu0_wb_sif                (pip_alu02wb),
    .alu1_wb_sif                (pip_alu12wb),
    .mdiv_wb_sif                (pip_mdiv2wb),
    .fpu_wb_sif                 (pip_fpu2wb),
    .lsu_wb_sif                 (pip_lsu2wb),
    .bypass_wb_sif              (pip_bypass2wb),
    .wbu_mif0                   (pip_wb2rob0),
    .wbu_mif1                   (pip_wb2rob1)
);
//TODO: writeback对lsu的接口必须always ready，因为从lsu写回的过程没有握手

/////////////////////////////////////////////////////////////////////////////////////////
//                                    rob0 & 1                                         //
/////////////////////////////////////////////////////////////////////////////////////////
//TODO: rob的写回接口信号必须always ready
prv664_rob#(
    .ROB_NUM                    (1'b0)      //0号ROB
)rob0(

    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .pip_rob_interface          (pip_decode2rob0),
    .rob_writeback_port         (pip_wb2rob0),
    .pip_robread_interface      (pip_rob2cmt0)

);
prv664_rob#(
    .ROB_NUM                    (1'b1)  //1号ROB
)rob1(

    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_slave                (pip_flush),
    .pip_rob_interface          (pip_decode2rob1),
    .rob_writeback_port         (pip_wb2rob1),
    .pip_robread_interface      (pip_rob2cmt1)

);
/////////////////////////////////////////////////////////////////////////////////////////
//                                commit unit                                          //
/////////////////////////////////////////////////////////////////////////////////////////
prv664_commit               commit(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .debug_haltreq              (pipdebug_slave.haltreq),           //由调试器的halt请求，直接作用于提交级
    .sysinfo_slave              (pip_sysinfo),
    .flush_slave                (pip_flush),
    .pip_robread_sif0           (pip_rob2cmt0),
    .pip_robread_sif1           (pip_rob2cmt1),
    .last_inst_itag             (last_inst_itag),
    .last_inst_valid            (last_inst_valid),
    //-----------------------instruction 0 commit port---------------------
    .flush_commit_master        (flush_commit),
    .instr_commit_master0       (instr_commit0),
    .int_commit_master0         (int_commit0),
    .csr_commit_master0         (csr_commit),
    .bpu_commit_master          (bpu_commit),
    .fp_commit_master           (fp_commit),
    //-----------------------instruction 1 commit port----------------------
    .instr_commit_master1       (instr_commit1),
    .int_commit_master1         (int_commit1)
);

/////////////////////////////////////////////////////////////////////////////////////////
//                                regfile                                              //
/////////////////////////////////////////////////////////////////////////////////////////
prv664_regfile#(
    .DATA_WIDTH                 (`XLEN)
)int_regfile(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
`ifdef SIMULATION
    .test_reg_out               (test_reg),
`endif
    //--------------------------2 read port-------------------
    // each read port have 2 register read port
    .port0_rs1index             (igpr_access0.rs1index),
    .port0_rs2index             (igpr_access0.rs2index),
    .port0_rs1data              (igpr_access0.rs1data),
    .port0_rs2data              (igpr_access0.rs2data),
    .port1_rs1index             (igpr_access1.rs1index),
    .port1_rs2index             (igpr_access1.rs2index),
    .port1_rs1data              (igpr_access1.rs1data),
    .port1_rs2data              (igpr_access1.rs2data),
    //-------------------------2 commit port--------------------
    .port0_rdindex              (int_commit0.rdindex),
    .port1_rdindex              (int_commit1.rdindex),
    .port0_rddata               (int_commit0.data),
    .port1_rddata               (int_commit1.data),
    .port0_valid                (int_commit0.valid & int_commit0.wren),
    .port1_valid                (int_commit1.valid & int_commit1.wren),
    //-------------------------debug port------------------------
    .halted                     (pipdebug_slave.halted),
    .debug_rsindex              (pipdebug_slave.igprindex),
    .debug_rsdata               (pipdebug_slave.igprrdata)
);
/////////////////////////////////////////////////////////////////////////////////////////
//                                scoreboard                                           //
/////////////////////////////////////////////////////////////////////////////////////////
prv664_iscoreboard#(
    .RNM                        (`RNM)
)iscoreboard(

    .clk_i                      (clk_i),
    .srst_i                     (arst_i | pip_flush.flush),
    .iscoreboard_update_slave0  (iscoreboard_update0),
    .iscoreboard_update_slave1  (iscoreboard_update1),
    .busy_flag                  (igpr_busy_flag),
    .id_flag                    (igpr_id_flag),
    .commit0_valid              (int_commit0.valid),      
    .commit0_wren               (int_commit0.wren),
    .commit0_rdindex            (int_commit0.rdindex),    
    .commit0_itag               (instr_commit0.itag),
    .commit1_valid              (int_commit1.valid),
    .commit1_wren               (int_commit1.wren),
    .commit1_rdindex            (int_commit1.rdindex),
    .commit1_itag               (instr_commit1.itag)

);
prv664_fscoreboard#(
    .RNM                        (`RNM)
)fscoreboard(

    .clk_i                      (clk_i),
    .srst_i                     (arst_i | pip_flush.flush),
    .fscoreboard_update_slave   (fscoreboard_update),
    .busy_flag                  (fgpr_busy_flag),
    .id_flag                    (fgpr_id_flag),
    .commit0_valid              (fp_commit.valid),
    .commit0_wren               (fp_commit.wren),
    .commit0_rdindex            (fp_commit.rdindex),
    .commit0_itag               (instr_commit0.itag)

);

    logic       csr_busy, fcsr_busy;        //csr is busy or fcsr is busy

always_ff @( posedge clk_i or posedge arst_i) begin
    if(arst_i)begin
        csr_busy <= 'h0;
    end
    else if(pip_flush.flush)begin
        csr_busy <= 'b0;
    end
    else if(cscoreboard_access.write & cscoreboard_access.csren)begin
        csr_busy <= 'b1;    //当csr指令被执行后，csr占用位置1
    end
    else if(csr_commit.valid & csr_commit.csren)begin
        csr_busy <= 'b0;
    end

    if(arst_i)begin
        fcsr_busy <= 'b0;
    end
    else if(pip_flush.flush)begin
        fcsr_busy <= 'b0;
    end
    else if(cscoreboard_access.write & cscoreboard_access.fflagen)begin
        fcsr_busy <= 'b1;
    end
    else if(instr_commit0.valid & csr_commit.fflagen)begin                   //浮点指令提交成功，清除浮点寄存器占用位
        fcsr_busy <= 'b0;
    end
end
assign cscoreboard_access.csr_busy = csr_busy;
assign cscoreboard_access.fcsr_busy= fcsr_busy;
/////////////////////////////////////////////////////////////////////////////////////////
//                                commit to fp regfile                                 //
/////////////////////////////////////////////////////////////////////////////////////////
                                            //TODO:在fpu和龙后追加fp寄存器组
/////////////////////////////////////////////////////////////////////////////////////////
//                                commit to csr                                        //
/////////////////////////////////////////////////////////////////////////////////////////
csr_top#(
    .HARTID                     (HARTID)
)csr(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    `ifdef SIMULATION
        .test_csr_out           (test_csr),
    `endif
    //----------------------from debug module-------------------------------
    .debug_resumereq            (pipdebug_slave.resumereq),             //调试器可以访问csr单元中的部分寄存器，
    .debug_csren                (pipdebug_slave.csrwr),                 //并且可以从csr的这些信号中获得cpu运行信息
    .debug_csrindex             (pipdebug_slave.csrindex),
    .debug_csrwdata             (pipdebug_slave.csrwdata),
    .debug_csrrdata             (pipdebug_slave.csrrdata),
    .debug_halted               (pipdebug_slave.halted),                //通知调试器当前pipline已经停止
    .debug_run                  (pipdebug_slave.run),                   //通知调试器当前pipline正在运行
    //----------------------csr flush request-------------------------------
    .csr_flush_req              (csr_flush_req),
    .csr_flush_newpc            (csr_flush_newpc),
    .csr_hold_req               (csr_hold_req),
    //----------------------csr read port-----------------------------------
    .csr_access_slave           (csr_access),
    //----------------------control signals output--------------------------
    .sysinfo_master             (pip_sysinfo),
    //----------------------from clint--------------------------------------
    .clint_slave                (clint_slave),
    //----------------------from commit stage-------------------------------
    .instr_commit_slave0        (instr_commit0),
    .csr_commit_slave           (csr_commit),
    .instr_commit_slave1        (instr_commit1),
    //-----------------------------to store buffer--------------------------
    .stb_manage_master          (stb_manage_master)
);

/////////////////////////////////////////////////////////////////////////////////////////
//                                pipline flush manage                                 //
/////////////////////////////////////////////////////////////////////////////////////////
prv664_flush_manage             flush_generate(
    .flush_master                   (pip_flush),
    //----------------指令提交的流水线刷新请求------------------
    .instr_flush_req                (flush_commit.valid),
    .instr_flush_pc                 (flush_commit.newpc),
    //-----------------csr的流水线刷新请求----------------------
    .csr_flush_req                  (csr_flush_req),
    .csr_hold_req                   (csr_hold_req),
    .csr_flush_pc                   (csr_flush_newpc)
);
//////////////////////////////////////////////////////////////////////////////////////////
//                     assert                                                           //
//////////////////////////////////////////////////////////////////////////////////////////
//always@(posedge clk_i or posedge arst_i)begin
//    if(arst_i)begin
//        reset_info: assert(1==1) $info("INFO:core reset");
//    end
//    else begin
//        lsu_wb_check: assert(pip_lsu2wb.valid & !pip_lsu2wb.ready) $error("ERR:lsu write back valid but not ready"); 
//    end
//end
/////////////////////////////////////////////////////////////////////////////////////////
//                                difftest commit port                                 //
/////////////////////////////////////////////////////////////////////////////////////////
//`ifdef SIMULATION   //TODO:在之后加入更多test接口
//always_comb begin
//    test_commit_m0.valid = instr_commit0.valid;
//    test_commit_m0.pc    = instr_commit0.pc;
//    test_commit_m1.valid = instr_commit1.valid;
//    test_commit_m1.pc    = instr_commit1.pc;
//end
//`endif                     fullv difftest 已经完成所有使命，现在接入dpi-c仿真！

`ifdef YSYX_DIFFTEST
    //reg类型的信号让提交延后一拍，确保difftest不会爆炸
    reg [63:0] InstrPC0,        InstrPC1;
    reg [63:0] InstrCommit0,    InstrCommit1;
    reg [63:0] exceptionPC;
    reg [63:0] intrNO;
    reg [63:0] cause;

    reg        CommitValid0,    CommitValid1;
    reg [7:0]  index0,          index1;
    reg        skip0,           skip1;
    reg        isRVC0,          isRVC1;
    reg        scFailed0,       scFailed1;
    reg        wen0,            wen1;
    reg [ 7:0] wdest0,          wdest1;
    reg [63:0] wdata0,          wdata1;

    //TrapEvent 
    wire [63:0] trap_pc;
    wire trap_valid;
    wire [7:0]trap_code;
    wire [63:0] cycleCnt;
    wire [63:0] instrCnt;

    assign trap_valid   = (instr_commit0.opcode==`OPCODE_HALT)&instr_commit0.valid;
    assign trap_pc      = instr_commit0.pc;
    assign trap_code    = test_reg[10];

    assign cycleCnt = test_csr[`MRW_MCYCLE_INDEX];
    assign instrCnt = test_csr[`MRW_MINSTRET_INDEX];

    always @(posedge clk_i) //THIS IS THE DIFFTEST COMMIT BLOCK
    begin
        if(instr_commit0.valid)begin
            InstrPC0 <= instr_commit0.pc;
            InstrCommit0<=instr_commit0.opcode;
            wen0     <= int_commit0.valid & int_commit0.wren;
            wdest0   <= int_commit0.rdindex;
            wdata0   <= int_commit0.data;
        end else begin
            InstrPC0 <= 0;
            InstrCommit0<=0;
            wen0     <= 0;
            wdest0   <= 0;
            wdata0   <= 0;
        end
        if(instr_commit1.valid)begin
            InstrPC1 <= instr_commit1.pc;
            InstrCommit1<=instr_commit1.opcode;
            wen1     <= int_commit1.valid & int_commit0.wren;
            wdest1   <= int_commit1.rdindex;
            wdata1   <= int_commit1.data;
        end else begin
            InstrPC1 <= 0;
            InstrCommit1<=0;
            wen1     <= 0;
            wdest1   <= 0;
            wdata1   <= 0;
        end

        if(instr_commit0.valid & (instr_commit0.trap_m | instr_commit0.trap_s) & instr_commit0.trap_async)begin
            intrNO <= instr_commit0.trap_cause;
        end else begin
            intrNO <= 0;
        end
        if(instr_commit0.valid & (instr_commit0.trap_m | instr_commit0.trap_s) & !instr_commit0.trap_async)begin
            cause <= instr_commit0.trap_cause;
        end else begin
            cause <= 0;
        end
        exceptionPC <= instr_commit0.trap_pc;
        CommitValid0<= instr_commit0.valid;
        CommitValid1<= instr_commit1.valid;
        //TrapEvent<=1'b0;
        skip0       <=instr_commit0.mmio;
        skip1       <=instr_commit1.mmio;
        isRVC0      <=1'b0;
        isRVC1      <=1'b0;
        scFailed0   <=1'b0;
        scFailed1   <=1'b0;
        //if(CMT_csren & (CMT_csrindex==`YSYX210152_urw_print_index))begin
        //    $write("%C",CMT_data2);     //TODO: 0x6a print register not imp
        //end
    end
`endif
//----------------Debug information output-----------------
//`ifdef STUCK_AUTO_STOP
//reg [`YSYX210152_XLEN-1:0] dummy_cycle_cnt;
//always@(posedge clk_i)begin
//    if(CMT_valid & `YSYX210152_DEBUG_RUN)begin
//        $display("Kernel RUN: CMT PC=%h, priv=%h, CMT data=%h, wen=%h, CMT dest=%h",CMT_pc, CMT_priv, CMT_data1, CMT_GPRwen, CMT_GPRwindex);
//    end
//    else begin
//        if(dummy_cycle_cnt>5000)begin
//            $display("Kernel ERROR: No instr commit in 5000 cycle, stop YSYX210152_Simulation");
//            $finish;
//            $display("mstatus:%h, sstatus:%h, mepc:%h, sepc:%h", mstatus, sstatus, mepc, sepc);
//            $display("mtval:%h, stval:%h, mtvec:%h, stvec:%h", mtval, stval, mtvec, stvec);
//            $display("mcause:%h, scause:%h, satp:%h",mcause, scause, satp);
//            $display("mip:%h, mie:%h, mscratch:%h, sscratch:%h", mip, mie, mscratch, sscratch);
//            $display("mideleg:%h, medeleg:%h, mcycle:%h, minstret:%h", mideleg, medeleg, cycleCnt, instrCnt);
//        end
//    end
//    if(CMT_valid)begin
//        if(CMT_trap_m)begin
//            $display("Kernel INFO: Trap target mode is M, Async=%h, cause=%h, epc=%h",CMT_trap_async, CMT_trap_cause, CMT_trap_pc);
//        end
//        else if(CMT_trap_s)begin
//            $display("Kernel INFO: Trap target mode is S, Async=%h, cause=%h, epc=%h",CMT_trap_async, CMT_trap_cause, CMT_trap_pc);
//        end
//    end
//
//    if(CMT_valid)begin
//        dummy_cycle_cnt <= 0;
//    end
//    else begin
//        dummy_cycle_cnt <= dummy_cycle_cnt + 1;
//    end
//end
//`endif
`ifdef YSYX_DIFFTEST
//-----------------Kernel Difftest Debug Information-------------------
/*verilator lint_off PINMISSING*/
DifftestInstrCommit Instr_Commit_0
(
    .clock                  (clk_i),
    .coreid                 (8'h00),
    .index                  (8'h00),
    .valid                  (CommitValid0),  //TODO: 双提交问题
    .pc                     (InstrPC0),
    .instr                  (InstrCommit0),
    .skip                   (skip0),
    .isRVC                  (isRVC0),
    .scFailed               (scFailed0),
    .wen                    (wen0),
    .wdest                  (wdest0),
    .wdata                  (wdata0)
);
DifftestInstrCommit Instr_Commit_1
(
    .clock                  (clk_i),
    .coreid                 (8'h00),
    .index                  (8'h01),
    .valid                  (CommitValid1),
    .pc                     (InstrPC1),
    .instr                  (InstrCommit1),
    .skip                   (skip1),
    .isRVC                  (isRVC1),
    .scFailed               (scFailed1),
    .wen                    (wen1),
    .wdest                  (wdest1),
    .wdata                  (wdata1)
);
DifftestArchIntRegState IntRegCommit(
    .clock(clk_i),
    .coreid(8'h00),
    .gpr_0(test_reg[0]),
    .gpr_1(test_reg[1]),
    .gpr_2(test_reg[2]),
    .gpr_3(test_reg[3]),
    .gpr_4(test_reg[4]),
    .gpr_5(test_reg[5]),
    .gpr_6(test_reg[6]),
    .gpr_7(test_reg[7]),
    .gpr_8(test_reg[8]),
    .gpr_9(test_reg[9]),
    .gpr_10(test_reg[10]),
    .gpr_11(test_reg[11]),
    .gpr_12(test_reg[12]),
    .gpr_13(test_reg[13]),
    .gpr_14(test_reg[14]),
    .gpr_15(test_reg[15]),
    .gpr_16(test_reg[16]),
    .gpr_17(test_reg[17]),
    .gpr_18(test_reg[18]),
    .gpr_19(test_reg[19]),
    .gpr_20(test_reg[20]),
    .gpr_21(test_reg[21]),
    .gpr_22(test_reg[22]),
    .gpr_23(test_reg[23]),
    .gpr_24(test_reg[24]),
    .gpr_25(test_reg[25]),
    .gpr_26(test_reg[26]),
    .gpr_27(test_reg[27]),
    .gpr_28(test_reg[28]),
    .gpr_29(test_reg[29]),
    .gpr_30(test_reg[30]),
    .gpr_31(test_reg[31])
);

DifftestCSRState CSRCommit(
    .clock                  (clk_i),
    .coreid                 (8'h00),
    .priviledgeMode         (pip_sysinfo.priv),
    .mstatus                (test_csr[`MRW_MSTATUS_INDEX]),
    .sstatus                (test_csr[`SRW_SSTATUS_INDEX]),
    .mepc                   (test_csr[`MRW_MEPC_INDEX]),
    .sepc                   (test_csr[`SRW_SEPC_INDEX]),
    .mtval                  (test_csr[`MRW_MTVAL_INDEX]),
    .stval                  (test_csr[`SRW_STVAL_INDEX]),
    .mtvec                  (test_csr[`MRW_MTVEC_INDEX]),
    .stvec                  (test_csr[`SRW_STVEC_INDEX]),
    .mcause                 (test_csr[`MRW_MCAUSE_INDEX]),
    .scause                 (test_csr[`SRW_SCAUSE_INDEX]),
    .satp                   (test_csr[`SRW_SATP_INDEX]),
    .mip                    (64'h0),                //不接mip
    .mie                    (test_csr[`MRW_MIE_INDEX]),
    .mscratch               (test_csr[`MRW_MSCRATCH_INDEX]),
    .sscratch               (test_csr[`SRW_SSCRATCH_INDEX]),
    .mideleg                (test_csr[`MRW_MIDELEG_INDEX]),
    .medeleg                (test_csr[`MRW_MEDELEG_INDEX])
);
DifftestArchEvent ArchEventCommit(
    .clock                  (clk_i),
    .coreid                 (8'h00),
    .intrNO                 (intrNO),               //由异步异常产生的错误号，非0触发
    .cause                  (cause),                //由同步异常产生的错误号，非0触发
    .exceptionPC            (exceptionPC)
);
DifftestTrapEvent TrapEventCommit(
    .clock                  (clk_i),
    .coreid                 (8'h00),
    .valid                  (trap_valid),
    .code                   (trap_code),
    .pc                     (trap_pc),
    .cycleCnt               (cycleCnt),
    .instrCnt               (instrCnt)
);
//wire [63:0] InstrBuf;
//assign InstrBuf=ram_read_helper(1'b1, InstrPC);
//assign InstrCommit=(InstrPC[3])?InstrBuf[63:32]:InstrBuf[31:0];
/*verilator lint_on PINMISSING*/
`endif
endmodule