`include "prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2023/3/12                                                                         //
//  Author  : Jack.Pan                                                                          //
//  Desc    : Virtual trans registers for PRV664 processor                                      //
//  Version : 1.0(change satp_mode domain)                                                      //
//////////////////////////////////////////////////////////////////////////////////////////////////
module virtual_trans(
    input wire              clk_i,
    input wire              arst_i,
    //--------------csr commit----------------
    input wire              valid,
    input wire [11:0]       csrindex,
    input wire [`XLEN-1:0]  csrdata,
    input wire              csren,
    output reg [`XLEN-1:0]  satp
);
    reg  [43:0]      satp_ppn;
    reg  [3:0]       satp_mode;

always_ff@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        satp_ppn <= 'h0;
        satp_mode<= `SV39_MODE_BARE;
    end
    else if(valid&csren)begin
        if(csrindex == `SRW_SATP_INDEX)begin
            satp_ppn <= csrdata[`SATP_BIT_PPN_HI:`SATP_BIT_PPN_LO];
            case(csrdata[`SATP_BIT_MODE_HI:`SATP_BIT_MODE_LO])
                `SV39_MODE_BARE: satp_mode <= `SV39_MODE_BARE;
                `SV39_MODE_SV39: satp_mode <= `SV39_MODE_SV39;
                default:satp_mode <= `SV39_MODE_BARE;   //if write illeagal value, mode change to bare mode
            endcase
        end
    end
end
assign satp = {satp_mode,16'b0,satp_ppn};


endmodule