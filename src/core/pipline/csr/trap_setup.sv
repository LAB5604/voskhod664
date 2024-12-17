`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
///////////////////////////////////////////////////////////////////////////
//                  trap setup unit for prv664                           //
//     Date: 2022/8/30                                                   //
//     Author: Jack.Pan                                                  //
//     Version: 0.0(Original)                                            //
///////////////////////////////////////////////////////////////////////////
module trap_setup(
    input wire              clk_i, arst_i,        //clock and global reset 
    //-----------CSR value output----------
    output wire [`XLEN-1:0] mstatus, misa, mie, mcounteren,    //M模式Trap管理寄存器
    output wire [`XLEN-1:0] sstatus,       sie, scounteren,    //S模式Trap管理寄存器
    output reg  [`XLEN-1:0] mtvec, stvec, mideleg, medeleg,
    output  reg [1:0]       privilege,
    //-----------write back to csr---------
    input wire              csr_commit_valid,
    input wire [11:0]       csrindex,
    input wire [`XLEN-1:0]  csrdata,
    input wire              csren,
    //-------------fpu update------------------------
    input wire              fp_update,
    //-----------privilege update request from Debug Unit------------
    input wire              priv_update,
    //------------return--------------------
    input wire              instr_commit_valid, //指令提交有效，为1时表示mret sret trap信号有效
    input wire              mret, sret,
    //-----------trap-----------------------
    input wire              trap_s, trap_m,      //trap targert to M or S mode
    input wire              trap_async,
    input wire [`XLEN-1:0]  trap_cause,
    //-----------flush req--------------------
    output logic            flush_req,
    output logic[`XLEN-1:0] flush_pc
);

//---------------mstatus and sstatus---------------------
    reg         status_tsr,     status_tw,      status_tvm, status_mxr, status_sum, status_mpriv, status_spp;
    reg         status_mpie,    status_spie,    status_mie, status_sie, status_sd;
    reg [1:0]   status_mpp,     status_fs,      status_uxl, status_sxl; 
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        status_tsr  <= 1'b0;
        status_tw   <= 1'b0;
        status_tvm  <= 1'b0;
        status_mxr  <= 1'b0;
        status_sum  <= 1'b0;
        status_mpriv<= 1'b0;
        status_mpp  <= 2'b00;
        status_spp  <= 1'b0;
        status_mpie <= 1'b0;
        status_spie <= 1'b0;
        status_mie  <= 1'b0;
        status_sie  <= 1'b0;
        privilege   <= `MACHINE;
    end
    else if(priv_update)begin
        privilege <= csrdata[1:0];
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex==`MRW_MSTATUS_INDEX))begin        //write to mstatus\
            status_sxl  <= csrdata[35:34];
            status_uxl  <= csrdata[33:32];
            status_tsr  <= csrdata[`STATUS_BIT_TSR];
            status_tw   <= csrdata[`STATUS_BIT_TW];
            status_tvm  <= csrdata[`STATUS_BIT_TVM];
            status_mxr  <= csrdata[`STATUS_BIT_MXR];
            status_sum  <= csrdata[`STATUS_BIT_SUM];
            status_mpriv<= csrdata[17];
            status_mpp  <= csrdata[`STATUS_BIT_MPP_HI:`STATUS_BIT_MPP_LO];
            status_spp  <= csrdata[`STATUS_BIT_SPP];
            status_mpie <= csrdata[`STATUS_BIT_MPIE];
            status_spie <= csrdata[`STATUS_BIT_SPIE];
            status_mie  <= csrdata[`STATUS_BIT_MIE];
            status_sie  <= csrdata[`STATUS_BIT_SIE];
        end
        else if(csrindex == `SRW_SSTATUS_INDEX)begin   //write to sstatus
            status_uxl  <= csrdata[33:32];
            status_mxr  <= csrdata[`STATUS_BIT_MXR];
            status_sum  <= csrdata[`STATUS_BIT_SUM];
            status_spp  <= csrdata[`STATUS_BIT_SPP];
            status_spie <= csrdata[`STATUS_BIT_SPIE];
            status_sie  <= csrdata[`STATUS_BIT_SIE];
        end
        else if(mret)begin
            status_mie <= status_mpie;
            status_mpie<= 1'b1;
            status_mpp <= 2'b00;
            privilege  <= status_mpp;
        end
        else if(sret)begin
            status_sie <= status_spie;
            status_spie<= 1'b1;
            status_spp <= 1'b0;
            privilege  <= status_spp ? `SUPERVISIOR : `USER;
        end
    end
    else if(instr_commit_valid)begin
        if(trap_m)begin                    //跳转到M模式进行处理
            status_mpie<= status_mie;
            status_mie <= 1'b0;
            status_mpp <= privilege;
            privilege  <= `MACHINE;
        end
        else if(trap_s)begin                    //跳转到S模式进行处理
            status_spie<= status_sie;
            status_sie <= 1'b0;
            status_spp <= privilege[0];
            privilege  <= `SUPERVISIOR;
        end
    end 
end
//--------------------FS domain update--------------------------
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        status_fs <= `FS_OFF;
    end
    else if(csr_commit_valid)begin
        if(fp_update)begin
            status_fs <= `FS_DIRTY;
        end
        else if(csren&((csrindex==`MRW_MSTATUS_INDEX)|(csrindex==`SRW_SSTATUS_INDEX)))begin
            status_fs <= csrdata[`STATUS_BIT_FS_HI:`STATUS_BIT_FS_LO];
        end
    end
end
always_comb begin
    status_sd = (status_fs==2'b11);
end
//status register:
//         bit:   |   63   |62:38| 37 | 36 |   35:34  |   33:32  |31:23|    22   |   21    |    20    |    19    |    18    |      17    |16:15| 14:13  |  12:11   |10:9|    8      |     7     |  6 |     5     |  4 |    3     |  2 |    1     | 0
//    function:   |   SD   |WPRI | MBE| SBE|    SXL   |    UXL   |WPRI |   TSR   |   TW    |    TVM   |   MXR    |    SUM   |     MPRV   | XS  |   FS   |   MPP    |MPRI|    SPP    |    MPIE   | UBE|    SPIE   |WPRI|    MIE   |WPRI|    SIE   |WPRI
assign mstatus = {status_sd,25'b0,1'b0,1'b0,status_sxl,status_uxl,9'b0,status_tsr,status_tw,status_tvm,status_mxr,status_sum,status_mpriv,2'b0,status_fs,status_mpp,2'b00,status_spp,status_mpie,1'b0,status_spie,1'b0,status_mie,1'b0,status_sie,1'b0};
assign sstatus = {status_sd,         29'b0            ,status_uxl,                 12'b0              ,status_mxr,status_sum,     1'b0   ,2'b0,status_fs,   2'b0   ,2'b00,status_spp,        2'b0    ,status_spie,        3'b0        ,status_sie,1'b0};
//-----------------mie & sie--------------------
    reg ie_msie, ie_mtie, ie_meie;
    reg ie_ssie, ie_stie, ie_seie;
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        ie_ssie<=	'b0;
		ie_msie<=	'b0;
		ie_stie<=	'b0;
		ie_mtie<=	'b0;
		ie_seie<=	'b0;
		ie_meie<=   'b0;
    end
    else if(csr_commit_valid&csren)begin
        if(csrindex == `MRW_MIE_INDEX)begin
            ie_ssie<=	csrdata[`CAUSE_SSI];
		    ie_msie<=	csrdata[`CAUSE_MSI];
		    ie_stie<=	csrdata[`CAUSE_STI];
		    ie_mtie<=	csrdata[`CAUSE_MTI];
		    ie_seie<=	csrdata[`CAUSE_SEI];
		    ie_meie<=   csrdata[`CAUSE_MEI];
        end
        else if(csrindex == `SRW_SIE_INDEX)begin
            ie_ssie<=	csrdata[`CAUSE_SSI];
		    ie_stie<=	csrdata[`CAUSE_STI];
		    ie_seie<=	csrdata[`CAUSE_SEI];
        end
    end
end
assign mie = {52'b0,ie_meie,1'b0,ie_seie,1'b0,ie_mtie,1'b0,ie_stie,1'b0,ie_msie,1'b0,ie_ssie,1'b0};
assign sie = {54'b0,ie_seie,3'b0,ie_stie,3'b0,ie_ssie,1'b0};
//---------------mtvec and stvec-----------------

always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        stvec <= 'h0;
        mtvec <= 'h0;
    end
    else if(csr_commit_valid&csren)begin
        if(csrindex == `MRW_MTVEC_INDEX)begin
            mtvec <= csrdata;
        end
        else if(csrindex == `SRW_STVEC_INDEX)begin
            stvec <= csrdata;
        end
    end
end
//----------------ideleg and edeleg----------------
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        mideleg <= 'h0;
        medeleg <= 'h0;
    end
    else if(csr_commit_valid&csren)begin
        if(csrindex == `MRW_MEDELEG_INDEX)begin
            medeleg <= csrdata;
        end
        else if(csrindex == `MRW_MIDELEG_INDEX)begin
            mideleg <= csrdata;
        end
    end
end

//---------------counteren---------------------------
reg mcounteren_CY, mcounteren_TM, mcounteren_IR;
reg scounteren_CY, scounteren_TM, scounteren_IR;
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        mcounteren_CY <= 1'b0;
        mcounteren_TM <= 1'b0;
        mcounteren_IR <= 1'b0;
        scounteren_CY <= 1'b0;
        scounteren_TM <= 1'b0;
        scounteren_IR <= 1'b0;
    end
    else if(csr_commit_valid&csren)begin
        if(csrindex == `MRW_MCOUNTEREN_INDEX)begin
            mcounteren_CY <= csrdata[0];
            mcounteren_TM <= csrdata[1];
            mcounteren_IR <= csrdata[2];
        end
        else if(csrindex == `SRW_SCOUNTEREN_INDEX)begin
            scounteren_CY <= csrdata[0];
            scounteren_TM <= csrdata[1];
            scounteren_IR <= csrdata[2];
        end
    end
end
assign mcounteren = {61'b0, mcounteren_IR, mcounteren_TM, mcounteren_CY};
assign scounteren = {61'b0, scounteren_IR, scounteren_TM, scounteren_CY};
assign misa       = 64'b00000000_00000000_00000000_00000000_00000000_00001010_00010001_00101001;
//					__________________________________________________________PONMLKJI_HGFEDCBA
//------------------------pipline flush request from trap_setup module------------------
always_comb begin
    flush_req = instr_commit_valid & (trap_s | trap_m);
    if(trap_m)begin
        if(trap_async & (mtvec[1:0]==2'h1))begin            //向量模式跳转
            flush_pc = {mtvec[63:2],2'b0} + {trap_cause[61:0],2'b00};
        end
        else begin
            flush_pc = {mtvec[63:2],2'b0};
        end
    end
    else if(trap_s)begin
        if(trap_async & (stvec[1:0]==2'h1))begin            //向量模式跳转
            flush_pc = {stvec[63:2],2'b0} + {trap_cause[61:0],2'b00};
        end
        else begin
            flush_pc = {stvec[63:2],2'b0};
        end
    end
    else begin
        flush_pc = 'hx;
    end
end
endmodule
