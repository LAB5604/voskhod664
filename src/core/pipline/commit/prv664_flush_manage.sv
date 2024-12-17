`include "prv664_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022.8.9                                                                          //
//  Author  : Jack.Pan                                                                          //
//  Desc    : 流水线冲刷管理单元，管理指令提交时的刷新请求和csr的刷新请求                            //
//  Version : 0.0(file initialize)                                                              //
//////////////////////////////////////////////////////////////////////////////////////////////////
module prv664_flush_manage(
    pip_flush_interface.master  flush_master,
    //----------------指令提交的流水线刷新请求------------------
    input wire                  instr_flush_req,
    input wire [`XLEN-1:0]      instr_flush_pc,
    //-----------------csr的流水线刷新请求----------------------
    input wire                  csr_flush_req,
    input wire                  csr_hold_req,
    input wire [`XLEN-1:0]      csr_flush_pc
);

always_comb begin
    if(csr_flush_req)begin
        flush_master.newpc = csr_flush_pc;
    end
    else begin
        flush_master.newpc = instr_flush_pc;
    end

    flush_master.flush  = instr_flush_req | csr_flush_req;
    flush_master.hold   = csr_hold_req;
    flush_master.flushbpu= 1'b0;    //No need to flush bpu
end



endmodule