`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
/*************************************************************************************

    Date    : 2023.3.10                                                                          
    Author  : Jack.Pan                                                                          
    Desc    : rob for prv664                                            
    Version : 1.0(irrevo signal added)   

********************************************************************************/
module prv664_rob#(
    parameter ROB_NUM   = 1'b0              //ROB number, 1'b0 or 1'b1
)(

    input wire clk_i,
    input wire arst_i,

    pip_flush_interface.slave       flush_slave,

    pip_rob_interface.slave         pip_rob_interface,         //from decode unit, wirte to rob
    pip_wb_interface.slave          rob_writeback_port,       //from execute engine, write to rob
    pip_robread_interface.master    pip_robread_interface

);
    logic [7:0] wentrynum,  rentrynum;
    logic       rcomplete,  empty; 
//----------------------------------access re-order buffer------------------------------
rob_core#(
    .DWIDTH             (1),                            //
    .IDWIDTH            (8),                            //tag width
    .DEEPTH             (`ROB_SIZE)                     //deepth
)rob_core(
//---------------------------clock and reset-----------------------
    .clk_i              (clk_i),
    .srst_i             (flush_slave.flush | arst_i),   //notice that here is a sync reset
//---------------------------flush port----------------------------
    .flush_i            (0),
//---------------------------write port-----------------------------
    .wren_i             (pip_rob_interface.valid),
    .wcomplete_i        (pip_rob_interface.complete),
    .wtag_i             ('h0),                          //no use
    .wentrynum_o        (wentrynum),
    .wdata_i            ('h0),                          //no use
    .full_o             (pip_rob_interface.full),
//---------------------------write port (CAM)-----------------------
//               only tag is matched can be write in rob
    .cam_wren_i         (rob_writeback_port.valid),
    .cam_wtag_i         ({1'b0, rob_writeback_port.itag[6:0]}),
//---------------------------read port------------------------------
    .rden_i             (pip_robread_interface.valid & pip_robread_interface.ready),
    .rtag_o             (),                             //no use
    .rentrynum_o        (rentrynum),     
    .rcomplete_o        (rcomplete),
    .rcancel_o          (),                             //no use
    .rdata_o            (),                             //no use
    .empty_o            (empty)
);
//---------------------------decode buffer ram---------------------
sram_1r1w_async_read#(

    .DATA_DEPTH         (`ROB_SIZE),
    .DATA_WIDTH         (`XLEN+5+11+5+1+5+1+12+1+1+3)

)decode_buffer(

    .clkw           (clk_i),
    .ce             (1),
    .we             (pip_rob_interface.valid & !pip_rob_interface.full),
    .addrr          (rentrynum),    
    .addrw          (pip_rob_interface.entrynum),
    .dataw          ({
                        pip_rob_interface.pc,
                        pip_rob_interface.opcode,
                        pip_rob_interface.instr_accflt,
                        pip_rob_interface.instr_pageflt,
                        pip_rob_interface.instr_addrmis,
                        pip_rob_interface.mret,
                        pip_rob_interface.sret,
                        pip_rob_interface.illins,
                        pip_rob_interface.ecall,
                        pip_rob_interface.ebreak,
                        pip_rob_interface.irrevo,
                        pip_rob_interface.rdindex,
                        pip_rob_interface.rden,
                        pip_rob_interface.frdindex,
                        pip_rob_interface.frden,
                        pip_rob_interface.csrindex,
                        pip_rob_interface.csren,
                        pip_rob_interface.fflagen,
                        pip_rob_interface.branchtype
                    }),
    .datar          ({
                        pip_robread_interface.pc,
                        pip_robread_interface.opcode,
                        pip_robread_interface.instr_accflt,
                        pip_robread_interface.instr_pageflt,
                        pip_robread_interface.instr_addrmis,
                        pip_robread_interface.mret,
                        pip_robread_interface.sret,
                        pip_robread_interface.illins,
                        pip_robread_interface.ecall,
                        pip_robread_interface.ebreak,
                        pip_robread_interface.irrevo,
                        pip_robread_interface.rdindex,
                        pip_robread_interface.rden,
                        pip_robread_interface.frdindex,
                        pip_robread_interface.frden,
                        pip_robread_interface.csrindex,
                        pip_robread_interface.csren,
                        pip_robread_interface.fflagen,
                        pip_robread_interface.branchtype
                        
                    })

);
//---------------------------decode buffer ram---------------------
sram_1r1w_async_read#(

    .DATA_DEPTH         (`ROB_SIZE),
    .DATA_WIDTH         (`XLEN+`XLEN+`XLEN+1+5+7)

)execute_data_buffer(

    .clkw           (clk_i),
    .ce             (1),
    .we             (rob_writeback_port.valid),
    .addrr          (rentrynum),
    .addrw          (rob_writeback_port.itag[6:0]),
    .dataw          ({
                        rob_writeback_port.data,
                        rob_writeback_port.csrdata,
                        rob_writeback_port.branchaddr,
                        rob_writeback_port.jump,
                        rob_writeback_port.fflag,
                        rob_writeback_port.mmio,
                        rob_writeback_port.load_acc_flt, 
                        rob_writeback_port.load_addr_mis, 
                        rob_writeback_port.load_page_flt,
                        rob_writeback_port.store_acc_flt, 
                        rob_writeback_port.store_addr_mis, 
                        rob_writeback_port.store_page_flt
                    }),
    .datar          ({
                        pip_robread_interface.data,
                        pip_robread_interface.csrdata,
                        pip_robread_interface.branchaddr,
                        pip_robread_interface.jump,
                        pip_robread_interface.fflag,
                        pip_robread_interface.mmio,
                        pip_robread_interface.load_acc_flt, 
                        pip_robread_interface.load_addr_mis, 
                        pip_robread_interface.load_page_flt,
                        pip_robread_interface.store_acc_flt, 
                        pip_robread_interface.store_addr_mis, 
                        pip_robread_interface.store_page_flt
                    })

);

assign pip_rob_interface.entrynum   = {ROB_NUM, wentrynum[6:0]};
assign pip_rob_interface.empty      = empty;
assign pip_robread_interface.itag   = {ROB_NUM, rentrynum[6:0]};
assign rob_writeback_port.ready     = 1'b1;
assign pip_robread_interface.valid  = !empty;
assign pip_robread_interface.complete=rcomplete;
`ifdef SIMULATION
//---------------------assert------------------------------------
always@(posedge clk_i or posedge arst_i)begin
    if(!arst_i & pip_robread_interface.valid)begin
       if($isunknown({
                        pip_robread_interface.jump,
                        pip_robread_interface.fflag,
                        pip_robread_interface.mmio,
                        pip_robread_interface.load_acc_flt, 
                        pip_robread_interface.load_addr_mis, 
                        pip_robread_interface.load_page_flt,
                        pip_robread_interface.store_acc_flt, 
                        pip_robread_interface.store_addr_mis, 
                        pip_robread_interface.store_page_flt,
                        pip_robread_interface.pc,
                        pip_robread_interface.opcode,
                        pip_robread_interface.instr_accflt,
                        pip_robread_interface.instr_pageflt,
                        pip_robread_interface.instr_addrmis,
                        pip_robread_interface.mret,
                        pip_robread_interface.sret,
                        pip_robread_interface.illins,
                        pip_robread_interface.ecall,
                        pip_robread_interface.ebreak,
                        pip_robread_interface.irrevo,
                        pip_robread_interface.rden,
                        pip_robread_interface.frden,
                        pip_robread_interface.csren,
                        pip_robread_interface.fflagen,
                        pip_robread_interface.branchtype
                    }==1))begin
                        $display("ERR: x or z is detected in rob readport signal");
                    end
    end
end
`endif
endmodule