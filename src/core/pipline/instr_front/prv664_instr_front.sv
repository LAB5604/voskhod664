`include "prv664_define.svh"
`include "riscv_define.svh"
`include"prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 20211226                                                                          //
//  Author  : Jack.Pan                                                                          //
//  Desc    : Instruction front for prv664(voskhod) processor, include PHT,BTB,RAS              //
//  Version : 3.3(增加了hold信号，避免流水线空转)                                                 //
//////////////////////////////////////////////////////////////////////////////////////////////////
module prv664_instr_front(

    input logic                 clk_i,
    input logic                 arst_i,

    pip_flush_interface.slave   flush_slave,
    sysinfo_interface.slave     sysinfo_slave,

//---------------------bpu update interface----------------

    bpuupd_interface.slave      bpuupd_slave,

//---------------------access port------------------------

    mmu_interface.master        mmuinterface_mif,               //mmu access port
    cache_return_interface.slave cacheinterface_result,          //cache return value in

//-------------------to next stage------------------------

    pip_ifu_interface.master    pip_ifu_mif

);

//----------------------access rob----------------------

    logic               arob_wren_i,        arob_rden_i,        arob_full_o,        arob_empty_o;
    logic [7:0]         arob_wentrynum_o,   arob_rentrynum_o;                //which entry will the result fill
    logic [3:0]         arob_validword_i,   arob_validword_o;
    logic               arob_complete_o;
    logic               arob_cancel_o;

//------------------------generate pc and bpu busy--------------------

    logic               pcgen_ready;            //1:generate pcnext 0:hold pc 
    logic               bpu_busy;               //1:bpu is busy in current cycle 0:bpu is not busy

//---------------------next pc group------------------
    logic [`XLEN-1:0]   pc,     pc_next;

always_ff @( posedge clk_i or posedge arst_i) begin
    if(arst_i)begin
        pc <= `PC_RESET;
    end
    else begin
        pc <= pc_next;
    end
end

//---------------------------------------------------access generate-----------------------------------------

always_comb begin
    //-----------------产生访问控制信号----------------------
    if(!arob_full_o & !mmuinterface_mif.full &!bpu_busy & !flush_slave.hold)begin   //若arob还有空间、mmu队列没满、bpu不忙、没有要求hold
        pcgen_ready                 = 1'b1;                     //generate new pc is ready
        arob_wren_i                 = !flush_slave.flush;       //如果当前周期是刷新周期，则不向arob中记录值
        mmuinterface_mif.valid      = !flush_slave.flush;
    end
    else begin                                                  //当前访问队列已经满了，停止产生pc
        pcgen_ready                 = 1'b0;
        arob_wren_i                 = 1'b0;
        mmuinterface_mif.valid      = 1'b0;
    end
    //----------------access port------------------
        mmuinterface_mif.opcode     = `OPCODE_LOAD;             //opcode = load
        mmuinterface_mif.id         = arob_wentrynum_o;
        mmuinterface_mif.addr       = {pc[`XLEN-1:4], 4'b0};
        mmuinterface_mif.data       = 'h0;
        mmuinterface_mif.funct      = {7'b0, 3'b100};           //size = 128bit
end
//-------------------------------------BPU------------------------------------------
// BPU generate pc_next and valid word of a whole fetch group according to current pc
//
bpu                     bpu(
    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
//---------------------flush interface--------------------
    .flush_slave                (flush_slave),
//---------------------btb update interface----------------
    .bpuupd_slave               (bpuupd_slave),
//-------------------
    .pc                         (pc),
    .pcgen_ready                (pcgen_ready),
    .bpu_busy                   (bpu_busy),
    .pc_next                    (pc_next),
    .validword                  (arob_validword_i)
);

//----------------------------------access re-order buffer------------------------------
rob_core#(
    .DWIDTH             (2+4),                          //data width = privilege + valid word
    .IDWIDTH            (8),                            //tag width
    .DEEPTH             (`FGROUP_BUFFER_SIZE)           //deepth
)arob(
//---------------------------clock and reset-----------------------
    .clk_i              (clk_i),
    .srst_i             (arst_i),                       //notice that here is a sync reset
//---------------------------flush port-----------------------------
    .flush_i            (flush_slave.flush),
//---------------------------write port-----------------------------
    .wren_i             (arob_wren_i),
    .wcomplete_i        (1'b0),                         //enery new entry is uncomplete
    .wtag_i             ('h0),                          //no use
    .wentrynum_o        (arob_wentrynum_o),     
    .wdata_i            ('h0),                          //no use
    .full_o             (arob_full_o),
//---------------------------write port (CAM)-----------------------
//               only tag is matched can be write in rob
    .cam_wren_i         (cacheinterface_result.valid),
    .cam_wtag_i         (cacheinterface_result.id),
//---------------------------read port------------------------------
    .rden_i             (arob_rden_i),
    .rtag_o             (),                             //no use
    .rentrynum_o        (arob_rentrynum_o),     
    .rcomplete_o        (arob_complete_o),
    .rcancel_o          (arob_cancel_o),
    .rdata_o            (),                             //no use
    .empty_o            (arob_empty_o)
);

always_comb begin
    if(flush_slave.flush)begin
        arob_rden_i = 1'b0;         //刷新周期什么也不做
    end
    else begin
        arob_rden_i = (pip_ifu_mif.valid & pip_ifu_mif.ready) | (!arob_empty_o & arob_complete_o & arob_cancel_o);
    end
end

//----------------------------adddress store the address of an access-------------------------
sram_1r1w_async_read#(

    .DATA_WIDTH         (4+`XLEN),                //2bit privilege, 4bit validword, and 64bit address
    .DATA_DEPTH         (`FGROUP_BUFFER_SIZE)

)address_buffer(

    .clkw               (clk_i),
    .addrr              (arob_rentrynum_o),
    .addrw              (arob_wentrynum_o),
    .ce                 (1'b1),
    .we                 (arob_wren_i),
    .datar              ({pip_ifu_mif.validword, pip_ifu_mif.grouppc}),
    .dataw              ({arob_validword_i, mmuinterface_mif.addr})

);
//----------------------------data buffer store the data back from cache-----------------------
sram_1r1w_async_read#(

    .DATA_WIDTH         (6+128),                //6bit error code, 128bit cache data
    .DATA_DEPTH         (`FGROUP_BUFFER_SIZE)

)data_buffer(

    .clkw               (clk_i),
    .addrr              (arob_rentrynum_o),
    .addrw              (cacheinterface_result.id),
    .ce                 (1'b1),
    .we                 (cacheinterface_result.valid),
    .datar              ({pip_ifu_mif.errtype, pip_ifu_mif.instr}),
    .dataw              ({cacheinterface_result.error, cacheinterface_result.rdata})

);

//----------------------------to next stage-----------------------

assign pip_ifu_mif.valid = !arob_empty_o & arob_complete_o & !arob_cancel_o; //当前读出项已经被回填且arob不为空，则传递到下一级

endmodule