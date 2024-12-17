`include "prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022/8/30                                                                         //
//  Author  : Jack.Pan                                                                          //
//  Desc    : Trap Handle unit for PRV664 processor                                             //
//  Version : 0.0(Orignal)                                                                      //
//////////////////////////////////////////////////////////////////////////////////////////////////
module trap_handle(
    input wire              clk_i, arst_i,        //clock and global reset
    //---------------interrupt from platform controller-----
    clint_interface.slave   clint_slave,
    //---------------csr value output-----------------
    output wire [`XLEN-1:0] mip, sip,
    output reg  [`XLEN-1:0] mscratch, mepc, mcause, mtval,
    output reg  [`XLEN-1:0] sscratch, sepc, scause, stval,
    //-----------write back to csr---------
    input wire              csr_commit_valid,                  //valid=1时下面的提交才有效
    input wire [11:0]       csrindex,
    input wire [`XLEN-1:0]  csrdata,
    input wire              csren,
    //-----------Trap value input----------
    input wire              instr_commit_valid,
    input wire              trap_m, trap_s, trap_async,
    input wire [`XLEN-1:0]  trap_pc, trap_value, trap_cause
);
//---------------mip and sip---------------------
    //seip有两个寄存器组成：seip1是真实的外部中断，seip2是被读写的外部中断
    //S模式的中断等待信息是被M模式读写的
    reg ip_meip, ip_msip, ip_mtip, ip_seip1, ip_seip2, ip_ssip, ip_stip;
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        ip_seip2<= 1'b0;
        ip_ssip <= 1'b0;
        ip_stip <= 1'b0;
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex==`MRW_MIP_INDEX))begin
            ip_seip2<= csrdata[`CAUSE_SEI];
            ip_stip <= csrdata[`CAUSE_STI];
            ip_ssip <= csrdata[`CAUSE_SSI];
        end
    end
end
    //M模式的中断，和S模式的外部中断是外部中断控制器发出的，内部只读
always_ff@(posedge clk_i)begin
    ip_meip <= clint_slave.mei;
    ip_msip <= clint_slave.msi;
    ip_mtip <= clint_slave.mti;
    ip_seip1<= clint_slave.sei;
end
assign mip = {52'b0,ip_meip,1'b0,(ip_seip1|ip_seip2),1'b0,ip_mtip,1'b0,ip_stip,1'b0,ip_msip,1'b0,ip_ssip,1'b0};
assign sip = {54'b0,(ip_seip1|ip_seip2),3'b0,ip_stip,3'b0,ip_ssip,1'b0};
//-------------mscratch and sscratch--------------
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        mscratch <= 'h0;
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex==`MRW_MSCRATCH_INDEX))begin
            mscratch <= csrdata;
        end
    end
end
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        sscratch <= 'h0;
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex==`SRW_SSCRATCH_INDEX))begin
            sscratch <= csrdata;
        end
    end
end
//-------------mepc and sepc-----------------
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        mepc <= 'h0;
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex == `MRW_MEPC_INDEX))begin
            mepc <= csrdata;
        end
    end
    else if(instr_commit_valid)begin
        if(trap_m)begin
            mepc <= trap_pc;
        end
    end
end
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        sepc <= 'h0;
    end
    else if( csr_commit_valid)begin
        if(csren&(csrindex == `SRW_SEPC_INDEX))begin
            sepc <= csrdata;
        end
    end
    else if(instr_commit_valid)begin
        if(trap_s)begin
            sepc <= trap_pc;
        end
    end
end
//--------------mcause and scause----------------
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        mcause <= 'h0;
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex==`MRW_MCAUSE_INDEX))begin
            mcause <= csrdata;
        end
    end
    else if(instr_commit_valid)begin
        if(trap_m)begin
            mcause <=  {trap_async, trap_cause[62:0]};
        end
    end
end
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        scause <= 'h0;
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex==`SRW_SCAUSE_INDEX))begin
            scause <= csrdata;
        end
    end
    else if(instr_commit_valid)begin
        if(trap_s)begin
            scause <= {trap_async, trap_cause[62:0]};
        end
    end
end
//-----------------tval--------------------------
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        mtval <= 'h0;
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex==`MRW_MTVAL_INDEX))begin
            mtval <= csrdata;
        end
    end
    else if(instr_commit_valid)begin
        if(trap_m)begin
            mtval <= trap_value;
        end
    end
end
always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        stval <= 'h0;
    end
    else if(csr_commit_valid)begin
        if(csren&(csrindex==`SRW_STVAL_INDEX))begin
            stval <= csrdata;
        end
    end
    else if(instr_commit_valid)begin
        if(trap_s)begin
            stval <= trap_value;
        end 
    end
end

endmodule
