`include "prv664_define.svh"
`include "riscv_define.svh"
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
                                                                             
    Desc    : PRV664(voskhod664) mmu top file
    Author  : JackPan
    Date    : 2024/01/09
    Version : 2022/11/22 0.0 file initialize
              2024/01/09 1.0 added user channel for passthrough more infomation 
                             added mmu_burnaccess signal, and make access wait for itself tobe the last one in pipline

                                            NOTE
    MMU中包含了TLB和PTW（Page Table Walker），Sv39分页方案中TLB的装填是自动的，但是页面更新是可选软件处理or硬件处理，
    在这里我选择页表项中A、D位的更新是硬件更新。
    MMU有三个状态：
        RUN：运行状态，在这个状态下可以正常进行虚拟地址转换。
        RELOAD：重装填，当TLB中表项缺失、TLB发生multiple hit后由RUN状态跳转而来。
        FLUSH：刷新TLB，清空所有TLB项。

***********************************************************************************************/
module prv664_mmu#(
    parameter INST = 0
)(
    input wire                      clk_i, arst_i,
    sysinfo_interface.slave         sysinfo_slave,
    input wire                      mmuflush_req,
    output logic                    mmuflush_ack,
    input wire                      mmu_burnaccess,     //命令mmu将当前正在进行的所有访问都清空
    input wire [7:0]                last_inst_itag,
    input wire                      last_inst_valid,
//------------------pipline access stream------------------------
    mmu_interface.slave             mmu_access_sif,
    cache_access_interface.master   cache_access_mif,
//-------------------ptw access memory--------------------------
    axi_ar.master                   ptw_axi_ar,
    axi_r.slave                     ptw_axi_r
);
    localparam  ITAGLEN = 8;
    localparam  RUN     = 4'h0,         //running mode
                RELOAD  = 4'h1,         //reload tlb
                FLUSH   = 4'h2;         //tlb refersh cycle

    wire                empty;
    wire [ITAGLEN-1:0]  access_id;
    wire [`XLEN-1:0]    access_addr,    access_data;
    wire [4:0]          access_opcode;
    wire [9:0]          access_funct;
    wire [`MMU_USER_W-1:0] access_user;
    logic               ren;
//-----------------------tlb output------------------------
    wire                tlb_valid;
    wire                tlb_miss;       //描述访问miss
    wire                tlb_multihit;   //当前tlb中存在multiple hit
    wire                tlb_error;      //描述当前存储的项是一个错误页面
    wire [8:0]          tlb_pte;
    wire [8:0]          tlb_ppn0,   tlb_ppn1;
    wire [25:0]         tlb_ppn2;
//------------------------page check logic-----------------
    wire                sv39_on;                                                //sv39分页模式开
    wire                va_check_err;                                           //虚拟地址检查有错误
    wire                load_page_fault,    store_page_fault;                   //页面检查有错误
//-----------------------ptw io----------------------------
    wire                ptw_ready;
    wire                ptw_error;
//-----------------------update logic----------------------
    logic               update_valid;
    logic               update_tlb,     update_errtlb;
    logic [43:0]        update_ppn;
    logic [9:0]         update_pte;
    logic [1:0]         update_pagesize;
    logic [3:0]         state,  state_next;
//----------------------sv39 on check-------------------------
assign sv39_on = (sysinfo_slave.satp[`SATP_BIT_MODE_HI:`SATP_BIT_MODE_LO]==`SV39_MODE_SV39);
//----------------------mmu state machine----------------------
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        state <= RUN;
    end
    else begin
        state <= state_next;
    end
end
always_comb begin
    if(mmu_burnaccess)begin
        state_next = RUN;
    end else begin
        case(state)
            RUN     :
            begin
                if(sv39_on)begin
                    if(mmuflush_req)begin                   state_next = FLUSH; end
                    else if(tlb_multihit)begin              state_next = FLUSH; end    
                    else if(tlb_miss&!va_check_err)begin
                        state_next = (INST==1)?RELOAD:(last_inst_valid & (access_id==last_inst_itag)) ? RELOAD : state;  //需要等待这条指令成为最老的那条指令
                    end
                    else begin                              state_next = state; end
                end
                else begin                                  state_next = state; end
            end
            RELOAD  : state_next = ptw_ready ? RUN : state;
            FLUSH   : state_next = RUN;
          default   : state_next = RUN;
        endcase
    end
end

fifo1r1w#(
    .DWID           (ITAGLEN+`XLEN+`XLEN+5+10+`MMU_USER_W),
    .DDEPTH         (4)
)mmu_uop_buffer(
    .clk            (clk_i),
    .rst            (arst_i | mmu_burnaccess),
    .ren            (ren),
    .wen            (mmu_access_sif.valid),
    .wdata          ({
                        mmu_access_sif.id,
                        mmu_access_sif.addr,
                        mmu_access_sif.data,
                        mmu_access_sif.opcode,
                        mmu_access_sif.funct,
                        mmu_access_sif.user
                    }),
    .rdata          ({
                        access_id,
                        access_addr,
                        access_data,
                        access_opcode,
                        access_funct,
                        access_user
                    }),
    .full           (mmu_access_sif.full),
    .empty          (empty)
);
//---------------------------virtual address check--------------------------------------
assign va_check_err = 0;    //TODO: 应该检查虚拟地址高位均为符号位拓展
//---------------------------tlb fabric include normal tlb and error page---------------------------------
tlb_top                         tlb(
    .clk_i                          (clk_i),
    .arst_i                         (arst_i),
    .flush_i                        (state==FLUSH),
    .access_valid_i                 (!empty & (state==RUN)),         //access valid input
    .access_vpn_i                   (access_addr[`SV39_VA_BIT_VPN2_HI:`SV39_VA_BIT_VPN0_LO]),
    .access_valid_o                 (tlb_valid),             //access valid output
    .access_miss_o                  (tlb_miss),
    .access_multihit_o              (tlb_multihit),
    .access_error_o                 (tlb_error),
    .access_pte_o                   (tlb_pte),
    .access_ppn2_o                  (tlb_ppn2),
    .access_ppn1_o                  (tlb_ppn1),
    .access_ppn0_o                  (tlb_ppn0),
    //--------------tlb update port----------------
    .update_valid_i                 (update_valid),
    .update_we_i                    (update_tlb),
    .update_errpage_i               (update_errtlb),
    .update_pagesize_i              (update_pagesize),
    .update_vpn_i                   (access_addr[`SV39_VA_BIT_VPN2_HI:`SV39_VA_BIT_VPN0_LO]),
    .update_ppn2_i                  (update_ppn[`SV39_PTE_BIT_PPN2_HI-10:`SV39_PTE_BIT_PPN2_LO-10]),
    .update_ppn1_i                  (update_ppn[`SV39_PTE_BIT_PPN1_HI-10:`SV39_PTE_BIT_PPN1_LO-10]),
    .update_ppn0_i                  (update_ppn[`SV39_PTE_BIT_PPN0_LO-10:`SV39_PTE_BIT_PPN0_LO-10]),
    .update_pte_i                   (update_pte)
);
//------------------------------page check--------------------------------
/*verilator lint_off PINMISSING*/
pagecheck                   pagecheck(
    //-------------csr input--------------
    .mxr                            (sysinfo_slave.mstatus[`STATUS_BIT_MXR]),
    .sum                            (sysinfo_slave.mstatus[`STATUS_BIT_SUM]),
    //-------------op input---------------
    .valid                          (sv39_on),
    .opcode                         (access_opcode),
    .priv                           (sysinfo_slave.priv),
    .pte                            (tlb_pte),
    .va_check_err                   (va_check_err),
    .tlb_err                        (tlb_error),
    //-------------error output-----------
    .load_page_fault                (load_page_fault),
    .store_page_fault               (store_page_fault)
);
/*verilator lint_on PINMISSING*/
//------------------------------output logic----------------------------
always_comb begin
    if((state==RUN)&(state_next==RUN)&(!cache_access_mif.full)&(!mmu_burnaccess))begin
        if(sv39_on)begin
            cache_access_mif.valid  = tlb_valid;
        end
        else begin
            cache_access_mif.valid  = !empty;
        end
    end
    else begin
        cache_access_mif.valid  = 0;
    end
    ren = cache_access_mif.valid;
    if(sv39_on)begin
        cache_access_mif.addr   = {{8{tlb_ppn2[25]}}, tlb_ppn2, tlb_ppn1, tlb_ppn0, access_addr[`SV39_VA_BIT_VPN0_LO-1:0]};
        cache_access_mif.opcode = (load_page_fault|store_page_fault) ? 5'b0 : access_opcode;        //如果虚拟地址检查发现有错误，opcode直接置0
        cache_access_mif.error[`ERRORTYPE_BIT_LOADPAGEFLT] = load_page_fault;
        cache_access_mif.error[`ERRORTYPE_BIT_LOADADDRMIS] = 0;
        cache_access_mif.error[`ERRORTYPE_BIT_LOADACCFLT]  = 0;
        cache_access_mif.error[`ERRORTYPE_BIT_STOREPAGEFLT]= store_page_fault;
        cache_access_mif.error[`ERRORTYPE_BIT_STOREADDRMIS]= 0;
        cache_access_mif.error[`ERRORTYPE_BIT_STOREACCFLT] = 0;
    end
    else begin
        cache_access_mif.addr   = access_addr;
        cache_access_mif.opcode = access_opcode;
        cache_access_mif.error  = 0;
    end
    cache_access_mif.funct  = access_funct;
    cache_access_mif.user   = access_user;      //passthrough user channel to next stage
    /*verilator lint_off CMPCONST*/ 
    cache_access_mif.ci     = !((cache_access_mif.addr<=`CACHEABLE_ADDR_HI)&(cache_access_mif.addr>=`CACHEABLE_ADDR_LO));
    /*verilator lint_on CMPCONST*/
    cache_access_mif.wt     = 1'b0;
    cache_access_mif.wdata  = access_data;
    cache_access_mif.id     = access_id;
end
//------------------------------update logic----------------------------
always_comb begin
    update_valid = (state==RELOAD);
    update_tlb   = ptw_ready & !ptw_error;
    update_errtlb= ptw_ready & ptw_error;
end
assign mmuflush_ack = (state==FLUSH);
ptw                             ptw(
//---------Global Signals-------------
    .ptw_clk_i                      (clk_i),
    .ptw_arst_i                     (arst_i),
    .sysinfo_slave                  (sysinfo_slave),
//---------Command & Data signals------------
    .ptw_valid_i                    (state==RELOAD),
    .ptw_vpn_i                      (access_addr[`SV39_VA_BIT_VPN2_HI:`SV39_VA_BIT_VPN0_LO]),
    .ptw_ready_o                    (ptw_ready),
//---------PTE and PPN Reply-----------------
    .ptw_ppn_o                      (update_ppn),
    .ptw_pte_o                      (update_pte),
    .ptw_pgsize_o                   (update_pagesize),
    .ptw_error_o                    (ptw_error),
//------------FIB bus interface--------------
    .ptw_axi_ar                     (ptw_axi_ar),
    .ptw_axi_r                      (ptw_axi_r)
);

endmodule