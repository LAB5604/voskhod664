`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
/*************************************************************************************

    Date    : 2023.1.28                                                                    
    Author  : Jack.Pan                                                                          
    Desc    : trap manage for prv664, 管理指令的异常，产生异常信号                                            
    Version : 1.1(当处理器进入debug模式时，不会trap进入m或者s模式)   

********************************************************************************/
module trap_manage(

    input wire [1:0]        priv,
    input wire [`XLEN-1:0]  csr_mideleg, csr_medeleg, csr_mstatus, csr_sstatus, csr_mie, csr_sie,
    input wire [`XLEN-1:0]  csr_dstatus, csr_mip,
    input wire              trapd_invalid, trapi_invalid, haltreq,  //不trap进入debug模式、不trap进中断
    //---------------exception input-------------------
    input wire              load_acc_flt, load_addr_mis, load_page_flt,
    input wire              store_acc_flt, store_addr_mis, store_page_flt,
    input wire              instr_accflt,   instr_pageflt,  instr_addrmis,
    input wire              ecall, ebreak,  illins,
    //
    output logic            trap_m, trap_s,trap_async,
    output logic [`XLEN-1:0]trap_cause,
    output logic            trap_d,
    output logic [`XLEN-1:0]trap_dcause

);
/**********************************************************
                    代码结构
指令异常---->cause_code---->
            cause_valid--->target_priv
**********************************************************/

    logic [`XLEN-1:0]   cause_code;                         //编码产生的cause code
    logic               cause_valid, cause_async;           //

    logic [1:0]         target_priv;                        //目标异常权限

////////////////////////////////////////////////////////
//              cause code encode                     //
////////////////////////////////////////////////////////
always_comb begin
    //--------同步异常有最高的处理优先级--------
    if(instr_pageflt)begin                        //instruction page fault
        cause_code = `CAUSE_INST_PAGE_FLT;
        cause_async= 0;
    end
    else if(instr_accflt)begin                    //instruction access fault
        cause_code = `CAUSE_INST_ACC_FLT;
        cause_async= 0;
    end
    else if(illins)begin                       //illegal instruction 
        cause_code = `CAUSE_INST_ILL_INS;
        cause_async= 0;
    end
    else if(instr_addrmis)begin                   //instruction address misaligned
        cause_code = `CAUSE_INST_ADDR_MIS;
        cause_async= 0;
    end
    else if(ecall)begin                         //Environment call
        case(priv)
            `MACHINE    : cause_code = `CAUSE_ECALL_M;
            `SUPERVISIOR: cause_code = `CAUSE_ECALL_S;
            `USER       : cause_code = `CAUSE_ECALL_U;
            default     : cause_code = 'hx;
        endcase
        cause_async= 0;
    end
    else if(ebreak)begin                        //Environment Break point
        cause_code = `CAUSE_BREAKPOINT;
        cause_async= 0;
    end
    else if(load_addr_mis)begin                   //Load address misaligned
        cause_code = `CAUSE_LOAD_ADDR_MIS;
        cause_async= 0;
    end
    else if(store_addr_mis)begin                  //Store address misaligned
        cause_code = `CAUSE_STOR_ADDR_MIS;
        cause_async= 0;
    end
    else if(load_page_flt)begin                   //Load page fault
        cause_code = `CAUSE_LOAD_PAGE_FLT;
        cause_async= 0;
    end
    else if(store_page_flt)begin                  //Store page fault
        cause_code = `CAUSE_STOR_PAGE_FLT;
        cause_async= 0;
    end
    else if(load_acc_flt)begin
        cause_code = `CAUSE_LOAD_ACC_FLT;
        cause_async= 0;
    end
    else if(store_acc_flt)begin
        cause_code = `CAUSE_STOR_ACC_FLT;
        cause_async= 0;
    end
    //----------NMI中断具有第二高优先级----------
    else if(csr_mip[`CAUSE_NMI])begin                   //NMI power lost
        cause_code = `CAUSE_NMI;
        cause_async= 1;
    end
    //-----------正常中断优先级最低--------------
    else if(csr_mip[`CAUSE_MTI])begin                           //Machine mode timer interrupt
        cause_code = `CAUSE_MTI;
        cause_async= 1;
    end
    else if(csr_mip[`CAUSE_MEI])begin                           //Machine mode external interrupt
        cause_code = `CAUSE_MEI;
        cause_async= 1;
    end
    else if(csr_mip[`CAUSE_MSI])begin                           //Machine mode software interrupt
        cause_code = `CAUSE_MSI;
        cause_async= 1;
    end
    else if(csr_mip[`CAUSE_STI])begin
        cause_code = `CAUSE_STI;
        cause_async= 1;
    end
    else if(csr_mip[`CAUSE_SEI])begin
        cause_code = `CAUSE_SEI;
        cause_async= 1;
    end
    else if(csr_mip[`CAUSE_SSI])begin
        cause_code = `CAUSE_SSI;
        cause_async= 1;
    end
    else begin
        cause_code = 'hx;
        cause_async= 0;
    end
    //---------------产生异常有效信号--------------
    case(priv)
        //-----------------machine模式下只有M模式的中断被使能，S模式中断被遮蔽----------------
        `MACHINE            :
        begin 
            if(trapi_invalid)begin
                cause_valid =   load_acc_flt | load_addr_mis | load_page_flt |
                                store_acc_flt | store_addr_mis | store_page_flt |
                                instr_accflt | instr_pageflt | instr_addrmis |
                                ecall | ebreak | illins;
            end
            else begin
                cause_valid =   csr_mip[`CAUSE_MEI] | csr_mip[`CAUSE_MTI] | csr_mip[`CAUSE_MSI] 
                                |load_acc_flt | load_addr_mis | load_page_flt |
                                store_acc_flt | store_addr_mis | store_page_flt |
                                instr_accflt | instr_pageflt | instr_addrmis |
                                ecall | ebreak | illins;
            end
        end
        //---------------supervisior和user模式下全部中断都是会被接受的------------------------
        `SUPERVISIOR,`USER  :
        begin   
            if(trapi_invalid)begin
                cause_valid =   load_acc_flt | load_addr_mis | load_page_flt |
                                store_acc_flt | store_addr_mis | store_page_flt |
                                instr_accflt | instr_pageflt | instr_addrmis |
                                ecall | ebreak | illins;
            end
            else begin
                cause_valid =   csr_mip[`CAUSE_MEI] | csr_mip[`CAUSE_SEI] | csr_mip[`CAUSE_MTI] | csr_mip[`CAUSE_STI] | csr_mip[`CAUSE_MSI] | csr_mip[`CAUSE_SSI] |
                                load_acc_flt | load_addr_mis | load_page_flt |
                                store_acc_flt | store_addr_mis | store_page_flt |
                                instr_accflt | instr_pageflt | instr_addrmis |
                                ecall | ebreak | illins;
            end
            
        end
        default : cause_valid = 1'hx;
    endcase
end


///////////////////////////////////////////////////////
//                 trap target select                //
///////////////////////////////////////////////////////

always_comb begin
    if(cause_valid)begin
        case(priv)
            `MACHINE    :   target_priv = `MACHINE;         //Machine模式下所有异常的目标权限都在machine模式下
            `SUPERVISIOR, `USER:
            begin
                if(cause_async)begin
                    target_priv = csr_mideleg[cause_code] ? `SUPERVISIOR : `MACHINE;     //中断cause对应位在mideleg中置1，则委托到SUPERVISIOR级
                end
                else begin
                    target_priv = csr_medeleg[cause_code] ? `SUPERVISIOR : `MACHINE;
                end
            end
            default : target_priv = 'hx;
        endcase
    end
    else begin
        target_priv = `MACHINE;
    end
end

///////////////////////////////////////////////////////
//                 trap target mask                  //
///////////////////////////////////////////////////////

always_comb begin
    if(cause_valid & !trap_d)begin      //如果处理器要trap进入debug模式，则不会trap进m或者s模式
        case(target_priv)
            `MACHINE : 
            begin
                if(cause_async)begin
                    trap_m = csr_mstatus[`STATUS_BIT_MIE] & csr_mie[cause_code];
                    trap_s = 1'b0;
                end
                else begin
                    trap_m = 1'b1;
                    trap_s = 1'b0;
                end
            end
            `SUPERVISIOR :
            begin
                if(cause_async)begin
                    trap_m = 1'b0;
                    trap_s = csr_sstatus[`STATUS_BIT_SIE] & csr_sie[cause_code];
                end
                else begin
                    trap_m = 1'b0;
                    trap_s = 1'b1;
                end
            end
            default : 
            begin
                trap_m = 1'b0;
                trap_s = 1'b0;
            end
        endcase
    end
    else begin
        trap_m = 1'b0;
        trap_s = 1'b0;
    end
end

///////////////////////////////////////////////////////
//                 trap pc generate                  //
///////////////////////////////////////////////////////

always_comb begin
    trap_cause  =   cause_code;
    trap_async  =   cause_async;
end

//////////////////////////////////////////////////////
//            debug subsystem signals               //
//////////////////////////////////////////////////////

`ifdef DEBUG_EN
always_comb begin
    if(!trapd_invalid)begin
        if(haltreq | csr_dstatus[`DCSR_BIT_STEP])begin
            trap_d = 1'b1;
            trap_dcause = csr_dstatus[`DCSR_BIT_STEP] ? `DCAUSE_STEP : `DCAUSE_HALTREQ;
        end
        else begin
            case(priv)
                `MACHINE :
                            if(ebreak & csr_dstatus[`DCSR_BIT_EBREAKM])begin
                                trap_d = 1'b1;
                                trap_dcause = `DCAUSE_EBREAK;
                            end
                            else begin
                                trap_d = 1'b0;
                                trap_dcause = 4'dx;
                            end
                `SUPERVISIOR:
                            if(ebreak & csr_dstatus[`DCSR_BIT_EBREAKS])begin
                                trap_d = 1'b1;
                                trap_dcause = `DCAUSE_EBREAK;
                            end
                            else begin
                                trap_d = 1'b0;
                                trap_dcause = 4'dx;
                            end
                `USER :
                            if(ebreak & csr_dstatus[`DCSR_BIT_EBREAKU])begin
                                trap_d = 1'b1;
                                trap_dcause = `DCAUSE_EBREAK;
                            end
                            else begin
                                trap_d = 1'b0;
                                trap_dcause = 4'dx;
                            end
                default:    begin
                                trap_d = 1'b0;
                                trap_dcause = 4'dx;
                            end
            endcase
        end
    end
    else begin
        trap_d = 1'b0;
        trap_dcause = 4'dx;
    end
end
`else
always_comb begin    
    trap_d = 1'b0;
    trap_dcause = 4'dx;
end
`endif

endmodule