`include "prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
/*********************************************************************************

    Date    : 2022.9.6                                                                
    Author  : Jack.Pan                                                                          
    Desc    : csr unit for prv664                                            
    Version : 1.0 (fence指令处理目前已放到sysmag管线中)

********************************************************************************/
module csr_top#(
    parameter HARTID = 0
)(
    input wire                      clk_i,
    input wire                      arst_i,
    `ifdef SIMULATION
        output wire [`XLEN-1:0]     test_csr_out [4095:0],
    `endif
    //----------------------from debug module-------------------------------
    input wire                      debug_resumereq,
    input wire                      debug_csren,
    input wire [11:0]               debug_csrindex,
    input wire [`XLEN-1:0]          debug_csrwdata,
    output logic[`XLEN-1:0]         debug_csrrdata,
    output logic                    debug_halted,
    output logic                    debug_run,
    //----------------------csr flush request-------------------------------
    output logic                    csr_flush_req,
    output logic [`XLEN-1:0]        csr_flush_newpc,
    output logic                    csr_hold_req,
    //----------------------csr read port-----------------------------------
    csr_access_interface.slave      csr_access_slave,
    //----------------------control signals output--------------------------
    sysinfo_interface.master        sysinfo_master,
    //----------------------from clint--------------------------------------
    clint_interface.slave           clint_slave,
    //----------------------from commit stage-------------------------------
    instr_commit_interface.slave    instr_commit_slave0,    //1st instruction commit
    csr_commit_interface.slave      csr_commit_slave,
    instr_commit_interface.slave    instr_commit_slave1,    //2ed instruction commit
    //-----------------------------to store buffer--------------------------
    sysmanage_interface.master      stb_manage_master
);
/////////////////////////////////////////////////////////////////////////////
//                               csrs                                      //
/////////////////////////////////////////////////////////////////////////////
//-------------------Machine and supervisior trap setup---------------------
    wire [`XLEN-1:0] mstatus,  mie;                         //M模式Trap管理寄存器
    wire [`XLEN-1:0] sstatus,  sie;                         //S模式Trap管理寄存器
    wire [`XLEN-1:0] mtvec,    stvec; 
    wire [`XLEN-1:0] mideleg,  medeleg;
    wire [1:0]       privilege;
//--------------------Machine and Supervisior trap handle---------------------
    wire [`XLEN-1:0] mip;                                   //Machine and Supervisior mode interrupt pending
    wire [`XLEN-1:0] mscratch, mepc, mcause, mtval;
    wire [`XLEN-1:0] sscratch, sepc, scause, stval;
    wire [`XLEN-1:0] sip,   scounteren;
    wire [`XLEN-1:0] misa,  mcounteren;
//--------------------supervisior virtual translation-------------------------
    wire [`XLEN-1:0] satp;
//--------------------float point register------------------------------------
    wire [`XLEN-1:0] fcsr;
//--------------------performance counters-------------------------------------
    wire [`XLEN-1:0] mcycle,    minstret,   mcountinhibit;
    wire [`XLEN-1:0] pc;
//--------------------debug csrs-------------------------------------------------
    wire [`XLEN-1:0] dcsr, dscratch0, dscratch1, dpc;
//-------------------info csrs-----------------------------------------------
    wire [`XLEN-1:0] mhartid, mvendorid, marchid, mimpid;
/////////////////////////////////////////////////////////////////////////////
//                     fpu status update                                   //
/////////////////////////////////////////////////////////////////////////////
    wire             fp_update;                             //由counter模块识别当前提交的指令opcode，通知status寄存器更新fs域
/////////////////////////////////////////////////////////////////////////////
//                     flush request from module                           //
/////////////////////////////////////////////////////////////////////////////
    logic            fencemanage_flushreq;                  //指令类型为system产生的流水线刷新请求
    wire             traphandle_flushreq;
    wire [`XLEN-1:0] traphandle_flushpc;
    wire             debug_flushreq;
    wire [`XLEN-1:0] debug_flushpc;
    logic            ret_flushreq;                          //return指令产生的流水线刷新请求
    logic[`XLEN-1:0] ret_flushpc;

trap_handle                 trap_handle(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    //---------------interrupt from platform controller-----
    .clint_slave            (clint_slave),
    //---------------csr value output-----------------
    .mip                    (mip), 
    .sip                    (sip),
    .mscratch               (mscratch), 
    .mepc                   (mepc), 
    .mcause                 (mcause), 
    .mtval                  (mtval),
    .sscratch               (sscratch), 
    .sepc                   (sepc), 
    .scause                 (scause), 
    .stval                  (stval),
    //-----------write back to csr---------
    .csr_commit_valid       (csr_commit_slave.valid),
    .csrindex               (csr_commit_slave.csrindex),
    .csrdata                (csr_commit_slave.csrdata),
    .csren                  (csr_commit_slave.csren),
    //-----------trap commit---------------
    .instr_commit_valid     (instr_commit_slave0.valid),
    .trap_m                 (instr_commit_slave0.trap_m),
    .trap_s                 (instr_commit_slave0.trap_s),
    .trap_async             (instr_commit_slave0.trap_async),
    .trap_pc                (instr_commit_slave0.trap_pc),
    .trap_value             (instr_commit_slave0.trap_value),
    .trap_cause             (instr_commit_slave0.trap_cause)
);

trap_setup                  trap_setup(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    //-----------CSR value output----------
    .mstatus                (mstatus), 
    .misa                   (misa), 
    .mie                    (mie), 
    .mcounteren             (mcounteren),
    .sstatus                (sstatus),
    .sie                    (sie), 
    .scounteren             (scounteren),
    .mtvec                  (mtvec), 
    .stvec                  (stvec), 
    .mideleg                (mideleg), 
    .medeleg                (medeleg),
    .privilege              (privilege),
    //-----------write back to csr---------
    .csr_commit_valid       (csr_commit_slave.valid),
    .csrindex               (csr_commit_slave.csrindex),
    .csrdata                (csr_commit_slave.csrdata),
    .csren                  (csr_commit_slave.csren),
    .fp_update              (fp_update),
    .priv_update            (1'b0),
    .instr_commit_valid     (instr_commit_slave0.valid),
    .mret                   (csr_commit_slave.mret),
    .sret                   (csr_commit_slave.sret),
    .trap_s                 (instr_commit_slave0.trap_s),
    .trap_m                 (instr_commit_slave0.trap_m),
    .trap_async             (instr_commit_slave0.trap_async),
    .trap_cause             (instr_commit_slave0.trap_cause),
    //-----------flush request----------------
    .flush_req              (traphandle_flushreq),
    .flush_pc               (traphandle_flushpc)
);

inform#(
    .HARTID     (HARTID)
)inform(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    .mhartid                (mhartid), 
    .mvendorid              (mvendorid), 
    .marchid                (marchid), 
    .mimpid                 (mimpid)
);

counter             counter(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    //--------------commit------------------
    .valid                  (csr_commit_slave.valid),
    .csrindex               (csr_commit_slave.csrindex),
    .csrdata                (csr_commit_slave.csrdata),
    .csren                  (csr_commit_slave.csren),
    //-------------instr commit--------------
    .instr0_commit_valid    (instr_commit_slave0.valid),
    .instr0_commit_opcode   (instr_commit_slave0.opcode),
    .instr0_commit_pc       (instr_commit_slave0.pc),
    .instr1_commit_valid    (instr_commit_slave1.valid),
    .instr1_commit_opcode   (instr_commit_slave1.opcode),
    .instr1_commit_pc       (instr_commit_slave1.pc),
    .fp_update              (fp_update),
    .mcycle                 (mcycle),
    .minstret               (minstret),
    .mcountinhibit          (mcountinhibit),
    .pc                     (pc)
);

fpcsr               fpcsr(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    //-------------fp commit--------------------
    .valid                  (csr_commit_slave.valid),
    .csrindex               (csr_commit_slave.csrindex),
    .csrdata                (csr_commit_slave.csrdata),
    .csren                  (csr_commit_slave.csren),
    .fflagen                (csr_commit_slave.fflagen),
    .fflag                  (csr_commit_slave.fflag),
    //-------------csr out-------------------
    .fcsr                   (fcsr)
);

virtual_trans       virtual_trans(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    //--------------csr commit----------------
    .valid                  (csr_commit_slave.valid),
    .csrindex               (csr_commit_slave.csrindex),
    .csrdata                (csr_commit_slave.csrdata),
    .csren                  (csr_commit_slave.csren),
    .satp                   (satp)
);

always_comb begin
    case(instr_commit_slave0.opcode)
        `OPCODE_MISCMEM,`OPCODE_SYSTEM:fencemanage_flushreq = instr_commit_slave0.valid;
        default: fencemanage_flushreq = 0;
    endcase
    //     return request flush
    ret_flushreq = (csr_commit_slave.valid & (csr_commit_slave.mret | csr_commit_slave.sret));
    ret_flushpc  = csr_commit_slave.mret ? mepc : sepc;
end
///////////////////////////////////////////////////////////////////////
//                线程debug单元，当trap_d信号拉高时进入debug模式        //
///////////////////////////////////////////////////////////////////////
`ifdef DEBUG_EN
hart_debug                  hart_debug(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    //-------------debug port-------------------------
    .resumereq              (debug_resumereq),
    .debug_csren            (debug_csren),
    .debug_csrindex         (debug_csrindex),
    .debug_csrdata          (debug_csrwdata),
    .halted                 (debug_halted),
    .run                    (debug_run),
    //-------------commit port------------------------
    .valid                  (csr_commit_slave.valid),
    .csrindex               (csr_commit_slave.csrindex),
    .csrdata                (csr_commit_slave.csrdata),
    .csren                  (csr_commit_slave.csren),
    .trap_d                 (instr_commit_slave0.trap_d),
    .trap_dcause            (instr_commit_slave0.trap_dcause),
    .trap_pc                (instr_commit_slave0.trap_pc),
    .priv                   (privilege),
    //-------------instruction commit-----------------
    .instr_commit_valid     (instr_commit_slave0.valid),
    //--------------to commit stage to invalid trap debug----------
    .trapd_invalid          (sysinfo_master.trapd_invalid),
    //--------------debug csr out---------------------
    .dpc                    (dpc),
    .dscratch0              (dscratch0),
    .dscratch1              (dscratch1),
    .dcsr                   (dcsr),
    //--------------flush request---------------------
    .debug_flushpc          (debug_flushpc),
    .debug_holdreq          (csr_hold_req),
    .debug_flushreq         (debug_flushreq)
);
`else   //none debug unit install

    assign dpc         = 'h0;
    assign dcsr        = 'h0;
    assign dscratch0   = 'h0;
    assign dscratch1   = 'h0;
    assign debug_flushreq = 'h0;
    assign debug_flushpc = 'h0;
    assign debug_halted = 1'b0;
    assign csr_hold_req  = 'h0;
    assign sysinfo_master.trapd_invalid = 'h0;

`endif

//---------------------------------to sysinfo--------------------------------
always_comb begin
    sysinfo_master.mstatus = mstatus;
    sysinfo_master.sstatus = sstatus;
    sysinfo_master.dstatus = dcsr;
    sysinfo_master.mie     = mie;
    sysinfo_master.sie     = sie;
    sysinfo_master.mip     = mip;
    sysinfo_master.sip     = sip;
    sysinfo_master.mideleg = mideleg;
    sysinfo_master.medeleg = medeleg;
    sysinfo_master.satp    = satp;
    sysinfo_master.priv    = privilege;
    sysinfo_master.fcsr    = fcsr;
end

//---------------------------------to store buffer----------------------------
always_comb begin
    stb_manage_master.valid     = instr_commit_slave0.valid & !(instr_commit_slave0.trap_s | instr_commit_slave0.trap_m | instr_commit_slave0.trap_d);
    stb_manage_master.command   = instr_commit_slave0.itag;
end
//---------------------------------csr read port-------------------------------
    logic [11:0] csrindex;    
always_comb begin
    csrindex = debug_halted ? debug_csrindex : csr_access_slave.csrindex;   //流水线读csr接口和debug模块共享一个MUX 节约资源
    case(csrindex)
        `URW_FCSR_INDEX         :   csr_access_slave.csrdata = fcsr;
		`URO_CYCLE_INDEX		:	csr_access_slave.csrdata = mcycle;
		`URO_TIME_INDEX			:	csr_access_slave.csrdata = clint_slave.mtime;
		`URO_INSTRET_INDEX		:	csr_access_slave.csrdata = minstret;
		`SRW_SSTATUS_INDEX		:	csr_access_slave.csrdata = sstatus;
		`SRW_SIE_INDEX			:	csr_access_slave.csrdata = sie;
		`SRW_STVEC_INDEX		:	csr_access_slave.csrdata = stvec;
		`SRW_SCOUNTEREN_INDEX	:	csr_access_slave.csrdata = scounteren;
		`SRW_SSCRATCH_INDEX		:	csr_access_slave.csrdata = sscratch;
		`SRW_SEPC_INDEX			:	csr_access_slave.csrdata = sepc;
		`SRW_SCAUSE_INDEX		:	csr_access_slave.csrdata = scause;
		`SRW_STVAL_INDEX		:	csr_access_slave.csrdata = stval;
		`SRW_SIP_INDEX			:	csr_access_slave.csrdata = sip;
		`SRW_SATP_INDEX			:	csr_access_slave.csrdata = satp;
		`MRO_MVENDORID_INDEX	:	csr_access_slave.csrdata = mvendorid;
		`MRO_MARCHID_INDEX		:	csr_access_slave.csrdata = marchid;
		`MRO_MIMP_INDEX			:	csr_access_slave.csrdata = mimpid;
		`MRO_MHARDID_INDEX		:	csr_access_slave.csrdata = mhartid;
		`MRO_MISA_INDEX			:	csr_access_slave.csrdata = misa;
		`MRW_MSTATUS_INDEX		:	csr_access_slave.csrdata = mstatus;
		`MRW_MEDELEG_INDEX		:	csr_access_slave.csrdata = medeleg;
		`MRW_MIDELEG_INDEX		:	csr_access_slave.csrdata = mideleg;
		`MRW_MIE_INDEX			:	csr_access_slave.csrdata = mie;
		`MRW_MTVEC_INDEX		:	csr_access_slave.csrdata = mtvec;
		`MRW_MCOUNTEREN_INDEX	:	csr_access_slave.csrdata = mcounteren;
		`MRW_MSCRATCH_INDEX		:	csr_access_slave.csrdata = mscratch;
		`MRW_MEPC_INDEX			:	csr_access_slave.csrdata = mepc;
		`MRW_MCAUSE_INDEX		:	csr_access_slave.csrdata = mcause;
		`MRW_MTVAL_INDEX		:	csr_access_slave.csrdata = mtval;
		`MRW_MIP_INDEX			:	csr_access_slave.csrdata = mip;
		`MRW_MCYCLE_INDEX		:	csr_access_slave.csrdata = mcycle;
		`MRW_MINSTRET_INDEX		:	csr_access_slave.csrdata = minstret;
		`MRW_MCOUNTINHIBIT_INDEX:   csr_access_slave.csrdata = mcountinhibit;
        `DRW_DCSR_INDEX         :   csr_access_slave.csrdata = dcsr;
        `DRW_DPC_INDEX          :   csr_access_slave.csrdata = dpc;
        `DRW_DSCRATCH0_INDEX    :   csr_access_slave.csrdata = dscratch0;
        `DRW_DSCRATCH1_INDEX    :   csr_access_slave.csrdata = dscratch1;
			default				:	csr_access_slave.csrdata = 64'h0;
    endcase
    debug_csrrdata = csr_access_slave.csrdata;
end
//-----------------------------刷新请求逻辑------------------------
always_comb begin
    csr_flush_req = fencemanage_flushreq | traphandle_flushreq | debug_flushreq | ret_flushreq;
    csr_flush_newpc = debug_flushreq ? debug_flushpc : traphandle_flushreq ? traphandle_flushpc : ret_flushreq ?ret_flushpc:(instr_commit_slave0.pc+'h4);
end
//-----------------------------csr值输出----------------------------
`ifdef SIMULATION
assign test_csr_out[`URW_FCSR_INDEX         ]= fcsr;
assign test_csr_out[`URO_CYCLE_INDEX		]=mcycle;
assign test_csr_out[`URO_TIME_INDEX			]=clint_slave.mtime;
assign test_csr_out[`URO_INSTRET_INDEX		]=minstret;
assign test_csr_out[`SRW_SSTATUS_INDEX		]=sstatus;
assign test_csr_out[`SRW_SIE_INDEX			]=sie;
assign test_csr_out[`SRW_STVEC_INDEX		]=stvec;
assign test_csr_out[`SRW_SCOUNTEREN_INDEX	]=scounteren;
assign test_csr_out[`SRW_SSCRATCH_INDEX		]=sscratch;
assign test_csr_out[`SRW_SEPC_INDEX			]=sepc;
assign test_csr_out[`SRW_SCAUSE_INDEX		]=scause;
assign test_csr_out[`SRW_STVAL_INDEX		]=stval;
assign test_csr_out[`SRW_SIP_INDEX			]=sip;
assign test_csr_out[`SRW_SATP_INDEX			]=satp;
assign test_csr_out[`MRO_MVENDORID_INDEX	]=mvendorid;
assign test_csr_out[`MRO_MARCHID_INDEX		]=marchid;
assign test_csr_out[`MRO_MIMP_INDEX			]=mimpid;
assign test_csr_out[`MRO_MHARDID_INDEX		]=mhartid;
assign test_csr_out[`MRO_MISA_INDEX			]=misa;
assign test_csr_out[`MRW_MSTATUS_INDEX		]=mstatus;
assign test_csr_out[`MRW_MEDELEG_INDEX		]=medeleg;
assign test_csr_out[`MRW_MIDELEG_INDEX		]=mideleg;
assign test_csr_out[`MRW_MIE_INDEX			]=mie;
assign test_csr_out[`MRW_MTVEC_INDEX		]=mtvec;
assign test_csr_out[`MRW_MCOUNTEREN_INDEX	]=mcounteren;
assign test_csr_out[`MRW_MSCRATCH_INDEX		]=mscratch;
assign test_csr_out[`MRW_MEPC_INDEX			]=mepc;
assign test_csr_out[`MRW_MCAUSE_INDEX		]=mcause;
assign test_csr_out[`MRW_MTVAL_INDEX		]=mtval;
assign test_csr_out[`MRW_MIP_INDEX			]=mip;
assign test_csr_out[`MRW_MCYCLE_INDEX		]=mcycle;
assign test_csr_out[`MRW_MINSTRET_INDEX		]=minstret;
assign test_csr_out[`MRW_MCOUNTINHIBIT_INDEX]= mcountinhibit;
assign test_csr_out[`DRW_DCSR_INDEX         ]= dcsr;
assign test_csr_out[`DRW_DPC_INDEX          ]= dpc;
assign test_csr_out[`DRW_DSCRATCH0_INDEX    ]= dscratch0;
assign test_csr_out[`DRW_DSCRATCH1_INDEX    ]= dscratch1;
`endif

endmodule