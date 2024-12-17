`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
/*********************************************************************************

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
                                                                             
    Date    : 2022.11.23                                                                        
    Author  : Jack.Pan                                                                          
    Desc    : tlb_top for prv664, include MEGA GIGA  KILO page tlb and mux logic
    Version : 1.0(added multiple hit)   

********************************************************************************/
module tlb_top(
    input wire          clk_i,
    input wire          arst_i,
    input wire          flush_i,
    input wire          access_valid_i,             //access valid input
    input wire [26:0]   access_vpn_i,               //access virtual page number input, NOT VPN!
    output logic        access_valid_o,             //access valid output
    output logic        access_miss_o,
    output logic        access_multihit_o,          //存在multiple hit情况
    output logic        access_error_o,
    output logic [7:0]  access_pte_o,
    output logic [25:0] access_ppn2_o,
    output logic [8:0]  access_ppn1_o,
    output logic [8:0]  access_ppn0_o,
    //--------------tlb update port----------------
    input wire          update_valid_i,
    input wire          update_we_i,                //为1时更新普通tlb
    input wire          update_errpage_i,           //为1时更新error tlb
    input wire [1:0]    update_pagesize_i,
    input wire [26:0]   update_vpn_i,
    input wire [25:0]   update_ppn2_i,
    input wire [8:0]    update_ppn1_i,
    input wire [8:0]    update_ppn0_i,
    input wire [7:0]    update_pte_i
);
//----------------------tlb ram output---------------------------
    wire        ktlb_valid_o, mtlb_valid_o, gtlb_valid_o, errtlb_valid_o;
    wire        ktlb_miss_o,  mtlb_miss_o,  gtlb_miss_o,  errtlb_miss_o;
    wire [7:0]  ktlb_pte_o,   mtlb_pte_o,   gtlb_pte_o;
    wire [25:0] ktlb_ppn2_o,  mtlb_ppn2_o,  gtlb_ppn2_o;
    wire [8:0]  ktlb_ppn1_o,  mtlb_ppn1_o;
    wire [8:0]  ktlb_ppn0_o;

    logic       tlb_flush;

always_comb begin
    tlb_flush = flush_i;
    //------------output mux---------------------
    case({(gtlb_valid_o&!gtlb_miss_o), (mtlb_valid_o&!mtlb_miss_o), (ktlb_valid_o&!ktlb_miss_o), (errtlb_valid_o&!errtlb_miss_o)})
        4'b0000:
        begin
            access_miss_o  = 1'b1;
            access_multihit_o=1'b0;
            access_error_o = 1'b0;
            access_pte_o   = 'hx;
            access_ppn2_o  = 'hx;
            access_ppn1_o  = 'hx;
            access_ppn0_o  = 'hx;
        end
        4'b0001:                    //当前hit的是error tlb，里面的表项是错误的
        begin
            access_miss_o  = 1'b0;
            access_multihit_o=1'b0;
            access_error_o = 1'b1;
            access_pte_o   = 'hx;
            access_ppn2_o  = 'hx;
            access_ppn1_o  = 'hx;
            access_ppn0_o  = 'hx;
        end
        4'b0010:
        begin
            access_miss_o  = 1'b0;
            access_multihit_o=1'b0;
            access_error_o = 1'b0;
            access_pte_o   = ktlb_pte_o;
            access_ppn2_o  = ktlb_ppn2_o;
            access_ppn1_o  = ktlb_ppn1_o;
            access_ppn0_o  = ktlb_ppn0_o;
        end
        4'b0100: 
        begin
            access_miss_o  = 1'b0;
            access_multihit_o=1'b0;
            access_error_o = 1'b0;
            access_pte_o   = mtlb_pte_o;
            access_ppn2_o  = mtlb_ppn2_o;
            access_ppn1_o  = mtlb_ppn1_o;
            access_ppn0_o  = access_vpn_i[8:0];
        end
        4'b1000:
        begin
            access_miss_o  = 1'b0;
            access_multihit_o=1'b0;
            access_error_o = 1'b0;
            access_pte_o   = gtlb_pte_o;
            access_ppn2_o  = gtlb_ppn2_o;
            access_ppn1_o  = access_vpn_i[17:9];
            access_ppn0_o  = access_vpn_i[8:0];
        end
        default:
        begin
            access_miss_o  = 1'b0;              //当前是multiple hit，或者没有hit
            access_multihit_o=1'b1;
            access_error_o = 1'b0;
            access_pte_o   = 'hx;
            access_ppn2_o  = 'hx;
            access_ppn1_o  = 'hx;
            access_ppn0_o  = 'hx;
        end
    endcase
    access_valid_o = tlb_flush ? 1'b0 : (gtlb_valid_o | mtlb_valid_o | ktlb_valid_o | errtlb_valid_o);
end
tlb#(
    .PAGE_TYPE                  ("KILO_PAGE"), // "KILO_PAGE" "GIGA_PAGE"
    .TLB_SIZE                   (`L1ITLB_ERRPAGE_SIZE)
)error_tlb(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    //--------------manage port--------------------
    .tlb_flush                  (tlb_flush),
    //--------------access port--------------------
    .access_valid_i             (access_valid_i),
    .access_vpn_i               (access_vpn_i),
    .access_valid_o             (errtlb_valid_o),
    .access_miss_o              (errtlb_miss_o),
    .access_pte_o               (),
    .access_ppn2_o              (),
    .access_ppn1_o              (),
    .access_ppn0_o              (),
    //--------------tlb update port----------------
    .update_valid_i             (update_valid_i),
    .update_we_i                (update_errpage_i),
    .update_vpn_i               (update_vpn_i),
    .update_ppn2_i              (0),                //NO USE
    .update_ppn1_i              (0),
    .update_ppn0_i              (0),
    .update_pte_i               (0)
);
tlb#(
    .PAGE_TYPE                  ("KILO_PAGE"), // "KILO_PAGE" "GIGA_PAGE"
    .TLB_SIZE                   (`L1ITLB_KPAGE_SIZE)
)kilo_tlb(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    //--------------manage port--------------------
    .tlb_flush                  (tlb_flush),
    //--------------access port--------------------
    .access_valid_i             (access_valid_i),
    .access_vpn_i               (access_vpn_i),
    .access_valid_o             (ktlb_valid_o),
    .access_miss_o              (ktlb_miss_o),
    .access_pte_o               (ktlb_pte_o),
    .access_ppn2_o              (ktlb_ppn2_o),
    .access_ppn1_o              (ktlb_ppn1_o),
    .access_ppn0_o              (ktlb_ppn0_o),
    //--------------tlb update port----------------
    .update_valid_i             (update_valid_i),
    .update_we_i                (update_we_i&(update_pagesize_i==`SV39_PAGESIZE_KILO)),
    .update_vpn_i               (update_vpn_i),
    .update_ppn2_i              (update_ppn2_i),
    .update_ppn1_i              (update_ppn1_i),
    .update_ppn0_i              (update_ppn0_i),
    .update_pte_i               (update_pte_i)
);
tlb#(
    .PAGE_TYPE                  ("MEGA_PAGE"), // "KILO_PAGE" "GIGA_PAGE"
    .TLB_SIZE                   (`L1ITLB_MPAGE_SIZE)
)mega_tlb(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    //--------------manage port--------------------
    .tlb_flush                  (tlb_flush),
    //--------------access port--------------------
    .access_valid_i             (access_valid_i),
    .access_vpn_i               (access_vpn_i),
    .access_valid_o             (mtlb_valid_o),
    .access_miss_o              (mtlb_miss_o),
    .access_pte_o               (mtlb_pte_o),
    .access_ppn2_o              (mtlb_ppn2_o),
    .access_ppn1_o              (mtlb_ppn1_o),
    .access_ppn0_o              (),                 //mega page don't trans ppn0
    //--------------tlb update port----------------
    .update_valid_i             (update_valid_i),
    .update_we_i                (update_we_i&(update_pagesize_i==`SV39_PAGESIZE_MEGA)),
    .update_vpn_i               (update_vpn_i),
    .update_ppn2_i              (update_ppn2_i),
    .update_ppn1_i              (update_ppn1_i),
    .update_ppn0_i              ('h0),              
    .update_pte_i               (update_pte_i)
);
tlb#(
    .PAGE_TYPE                  ("GIGA_PAGE"), // "KILO_PAGE" "GIGA_PAGE"
    .TLB_SIZE                   (`L1ITLB_GPAGE_SIZE)
)giga_tlb(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    //--------------manage port--------------------
    .tlb_flush                  (tlb_flush),
    //--------------access port--------------------
    .access_valid_i             (access_valid_i),
    .access_vpn_i               (access_vpn_i),
    .access_valid_o             (gtlb_valid_o),
    .access_miss_o              (gtlb_miss_o),
    .access_pte_o               (gtlb_pte_o),
    .access_ppn2_o              (gtlb_ppn2_o),
    .access_ppn1_o              (),             //giga page only trans vpn2 to ppn2
    .access_ppn0_o              (),
    //--------------tlb update port----------------
    .update_valid_i             (update_valid_i),
    .update_we_i                (update_we_i&(update_pagesize_i==`SV39_PAGESIZE_GIGA)),
    .update_vpn_i               (update_vpn_i),
    .update_ppn2_i              (update_ppn2_i),
    .update_ppn1_i              ('h0),
    .update_ppn0_i              ('h0),
    .update_pte_i               (update_pte_i)
);
endmodule