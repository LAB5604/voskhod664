`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
/*********************************************************************************

    Date    : 2022.11.15                                                                        
    Author  : Jack.Pan                                                                          
    Desc    : tlb for prv664
    Version : 1.0(change 1r1w sram to 1rw sram)   

********************************************************************************/
module tlb#(

    parameter   PAGE_TYPE = "MEGA_PAGE", // "KILO_PAGE" "GIGA_PAGE"
                TLB_SIZE  = 16

)(
    input wire          clk_i,
    input wire          arst_i,
    //--------------manage port--------------------
    input wire          tlb_flush,
    //--------------access port--------------------
    input wire          access_valid_i,             //access valid input
    input wire [26:0]   access_vpn_i,               //access virtual page number input, NOT VPN!
    output wire         access_valid_o,             //access valid output
    output logic        access_miss_o,
    output logic [7:0]  access_pte_o,
    output logic [25:0] access_ppn2_o,
    output logic [8:0]  access_ppn1_o,
    output logic [8:0]  access_ppn0_o,
    //--------------tlb update port----------------
    input wire          update_valid_i,
    input wire          update_we_i,
    input wire [26:0]   update_vpn_i,
    input wire [25:0]   update_ppn2_i,
    input wire [8:0]    update_ppn1_i,
    input wire [8:0]    update_ppn0_i,
    input wire [7:0]    update_pte_i
);

    localparam  INDEX_ADDR_SIZE = $clog2(TLB_SIZE),
                TAG_ADDR_SIZE = (PAGE_TYPE=="KILO_PAGE") ? (27-INDEX_ADDR_SIZE) : 
                                (PAGE_TYPE=="MEGA_PAGE") ? (18-INDEX_ADDR_SIZE) :
                                (PAGE_TYPE=="GIGA_PAGE") ? (9-INDEX_ADDR_SIZE) : (27-INDEX_ADDR_SIZE);

    logic [INDEX_ADDR_SIZE-1:0]   index_r,   index_w;
    logic [TAG_ADDR_SIZE-1:0]     tag_r,     tag_w,      tag_a;  //tag read, tag write, tag access
// generate tag&index in different type tlb
generate
    case(PAGE_TYPE)
        "KILO_PAGE":
        begin: KPAGE
            assign index_r = access_vpn_i[INDEX_ADDR_SIZE-1:0];
            assign index_w = update_vpn_i[INDEX_ADDR_SIZE-1:0];
            assign tag_a   = access_vpn_i[26:INDEX_ADDR_SIZE];
            assign tag_w   = update_vpn_i[26:INDEX_ADDR_SIZE];
        end
        "MEGA_PAGE":
        begin: MPAGE
            assign index_r = access_vpn_i[INDEX_ADDR_SIZE-1+9:9];
            assign index_w = update_vpn_i[INDEX_ADDR_SIZE-1+9:9];
            assign tag_a   = access_vpn_i[26:INDEX_ADDR_SIZE+9];
            assign tag_w   = update_vpn_i[26:INDEX_ADDR_SIZE+9];
        end
        "GIGA_PAGE":
        begin: GPAGE
            assign index_r = access_vpn_i[INDEX_ADDR_SIZE-1+18:18];
            assign index_w = update_vpn_i[INDEX_ADDR_SIZE-1+18:18];
            assign tag_a   = access_vpn_i[26:INDEX_ADDR_SIZE+18];
            assign tag_w   = update_vpn_i[26:INDEX_ADDR_SIZE+18];
        end
        default    : 
        begin: BUGPAGE
            assign index_r = access_vpn_i[INDEX_ADDR_SIZE-1:0];
            assign index_w = update_vpn_i[INDEX_ADDR_SIZE-1:0];
            assign tag_a   = access_vpn_i[26:INDEX_ADDR_SIZE];
            assign tag_w   = update_vpn_i[26:INDEX_ADDR_SIZE];
        end
    endcase
endgenerate
    reg [TLB_SIZE-1:0] entry_valid;

always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        entry_valid <= 'b0;
    end
    else if(tlb_flush)begin
        entry_valid <= 'b0;
    end
    else if(update_valid_i & update_we_i)begin
        entry_valid[index_w] <= 'b1;
    end
end

//                  tag ram
sram_1rw_async_read#(
    .DATA_WIDTH                 (TAG_ADDR_SIZE),
    .DATA_DEPTH                 (TLB_SIZE)
)tag_ram(   
    .clk                        (clk_i),
    .addr                       (update_valid_i ? index_w : index_r),
    .ce                         (1'b1),
    .we                         (update_valid_i & update_we_i),
    .datar                      (tag_r),
    .dataw                      (tag_w)
);

//                      pte ram
sram_1rw_async_read#(
    .DATA_WIDTH                 (8),
    .DATA_DEPTH                 (TLB_SIZE)
)pte_ram(   
    .clk                        (clk_i),
    .addr                       (update_valid_i ? index_w : index_r),
    .ce                         (1'b1),
    .we                         (update_valid_i & update_we_i),
    .datar                      (access_pte_o),
    .dataw                      (update_pte_i)
);
//                      ppn ram
sram_1rw_async_read#(
    .DATA_WIDTH                 (44),
    .DATA_DEPTH                 (TLB_SIZE)
)ppn_ram(   
    .clk                        (clk_i),
    .addr                       (update_valid_i ? index_w : index_r),
    .ce                         (1'b1),
    .we                         (update_valid_i & update_we_i),
    .datar                      ({access_ppn2_o, access_ppn1_o, access_ppn0_o}),
    .dataw                      ({update_ppn2_i, update_ppn1_i, update_ppn0_i})
);

assign access_valid_o   = update_valid_i ? 1'b0 : access_valid_i;
assign access_miss_o    = entry_valid[index_r]? (tag_r != tag_a) : 1'b1;

endmodule