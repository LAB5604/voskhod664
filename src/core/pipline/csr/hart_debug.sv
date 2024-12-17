`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022/9/4                                                                          //
//  Author  : Jack.Pan                                                                          //
//  Desc    : hart debug unit for PRV664 processor                                              //
//  Version : 0.0(Orignal)                                                                      //
//////////////////////////////////////////////////////////////////////////////////////////////////
module hart_debug(
    input wire              clk_i,   arst_i,
    //-------------debug port-------------------------
    input wire              resumereq,
    input wire              debug_csren,
    input wire [11:0]       debug_csrindex,
    input wire [`XLEN-1:0]  debug_csrdata,
    output logic            halted, run,
    //-------------commit port------------------------
    input wire              valid,
    input wire              csren,
    input wire [11:0]       csrindex,
    input wire [`XLEN-1:0]  csrdata,
    input wire              trap_d,
    input wire [3:0]        trap_dcause,
    input wire [`XLEN-1:0]  trap_pc,
    input wire [1:0]        priv,
    //-------------instruction commit-----------------
    input wire              instr_commit_valid,
    //--------------to commit stage to invalid trap debug----------
    output logic            trapd_invalid,
    //--------------debug csr out---------------------
    output logic [`XLEN-1:0]dpc, dscratch0, dscratch1, dcsr,
    //--------------flush request---------------------
    output logic [`XLEN-1:0]debug_flushpc,
    output logic            debug_holdreq,      //hold ifu to stop instruction fetch
    output logic            debug_flushreq
);
localparam RUN = 'h0,       //RUN state
           WFC = 'h1,       //wait for the first commit
           HALTED='h2;      //HALT state

    reg [1:0] machine_state;

//----------------debug mode csrs----------------------

    reg       ebreakm, ebreaks, ebreaku, step;
    reg [2:0] cause;
    reg [1:0] prv;

always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        machine_state <= RUN;
    end
    else begin
        case(machine_state)
            RUN : machine_state <= (valid & trap_d) ? HALTED : machine_state;
            WFC : machine_state <= instr_commit_valid ? RUN : machine_state;    //在等待提交状态，提交一条指令后则视为已恢复运行
            HALTED:machine_state<= resumereq ? WFC : machine_state;
        default : machine_state <= RUN;
        endcase
    end
end
//----------------dcsr logic------------------
always_ff @( posedge clk_i or posedge arst_i ) begin : blockName
    if(arst_i)begin
        ebreakm <= `DCSR_EBREAM_INIT;
        ebreaks <= `DCSR_EBREAS_INIT;
        ebreaku <= `DCSR_EBREAU_INIT;
        step    <= 'h0;
        cause   <= 'h0;
    end
    else if(valid)begin
        if(trap_d)begin
            cause   <= trap_dcause;
            prv     <= priv;
        end
        else if(csren&(csrindex==`DRW_DCSR_INDEX))begin
            ebreakm <= csrdata[`DCSR_BIT_EBREAKM];
            ebreaks <= csrdata[`DCSR_BIT_EBREAKS];
            ebreaku <= csrdata[`DCSR_BIT_EBREAKU];
            step    <= csrdata[`DCSR_BIT_STEP];
            cause   <= csrdata[`DCSR_BIT_CAUSE_HI : `DCSR_BIT_CAUSE_LO];
            prv     <= csrdata[`DCSR_BIT_PRV_HI : `DCSR_BIT_PRV_LO];
        end
    end
    else if(debug_csren&(debug_csrindex==`DRW_DCSR_INDEX))begin
        ebreakm <= debug_csrdata[`DCSR_BIT_EBREAKM];
        ebreaks <= debug_csrdata[`DCSR_BIT_EBREAKS];
        ebreaku <= debug_csrdata[`DCSR_BIT_EBREAKU];
        step    <= debug_csrdata[`DCSR_BIT_STEP];
        cause   <= debug_csrdata[`DCSR_BIT_CAUSE_HI : `DCSR_BIT_CAUSE_LO];
    end
end
//    bits:  63:32 |  31:28   |27:16|   15  |  14  |  13  |   12   |11:9| 8:6 | 5:3 |  2 | 1:0 |
//   define:   0   | xdebugver| 0   |ebreakm|  0   |ebreaks|ebreaku| 0  |cause|  0  |step| prv |
assign dcsr={32'b0,  4'h4,  12'h0,   ebreakm, 1'b0, ebreaks,ebreaku,3'b0,cause, 3'b0,step, prv};
//---------------dpc logic---------------------
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        dpc <= 'h0;
    end
    else if(valid)begin
        if(trap_d)begin
            dpc <= trap_pc;
        end
        else if(csren&(csrindex==`DRW_DPC_INDEX))begin
            dpc <= csrdata;
        end
    end
    else if(debug_csren&(debug_csrindex==`DRW_DPC_INDEX))begin
        dpc <= debug_csrdata;
    end
end
//---------------dscratch----------------------
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        dscratch0 <= 'h0;
    end
    else if(valid&csren&(csrindex==`DRW_DSCRATCH0_INDEX))begin
        dscratch0 <= csrdata;
    end
    if(arst_i)begin
        dscratch1 <= 'h0;
    end
    else if(valid&csren&(csrindex==`DRW_DSCRATCH1_INDEX))begin
        dscratch1 <= csrdata;
    end
end
//处理器进入debug模式后，dpc更新为提交的指令的pc，这条指令被当作未执行的指令，当返回后这条指令会被重执行一遍
//此时需要跳过这条指令，避免在单步模式下重复进入debug模式
assign trapd_invalid = (machine_state==WFC) & !instr_commit_valid;
//---------------------刷新请求、hold请求------------------------
assign debug_holdreq = (machine_state==HALTED);             //在停止模式下停掉指令前端，避免功耗浪费
assign debug_flushreq= ((machine_state==RUN) & trap_d) |    //从run模式更新到debug模式时，刷新流水线
                       ((machine_state==HALTED) & resumereq);
assign debug_flushpc = dpc;

assign halted= (machine_state==HALTED);
assign run  = (machine_state==RUN);

endmodule