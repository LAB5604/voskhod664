`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
`timescale 1ns/100ps
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) pipline simulation top file, MMU and Cache are NOT include
              full-v difftest now avilible!
    Author  : Jack.Pan
    Date    : 2022/10/10
    Version : 1.0 full-v difftest avilible

***********************************************************************************************/
module voskhod664_simtop#(
    parameter INIT_FILE = "add_test.txt",
              XLEN      = 64
)(

);
    logic                       clk_i,  arst_i;
//----------------pipline interfaces---------------------
    test_commit_interface       test_commit0();         //cpu core commit info
    test_commit_interface       test_commit1();         //
    cache_access_interface      icache_access();
    cache_access_interface      dcache_access();
    cache_return_interface      icache_return();        //pipline icache return data
    cache_return_interface      dcache_return();
    clint_interface             clint_if();
    pipdebug_interface          pip_dbg_if();
    sysmanage_interface         stbmanage_if();         //给storebuffer的信号流
    axi_ar                      immu_axi_ar();
    axi_r                       immu_axi_r();
    axi_ar                      dmmu_axi_ar();
    axi_r                       dmmu_axi_r();
    wire                        icache_flush_req, dcache_flush_req;
//--------------wires-----------------------------
    wire [XLEN-1:0]    dut_ireg    [31:0];

prv664_pipline_top              dut(

    .clk_i                  (clk_i),              //clock input, all the logic inside this module is posedge active
    .arst_i                 (arst_i),             //async reset input, high active, ples make sure this signal is sync with clock
`ifdef SIMULATION
    .test_commit_m0         (test_commit0),
    .test_commit_m1         (test_commit1),
    .test_reg_out           (dut_ireg),
`endif
//---------------------------clint-----------------------------------------
    .clint_slave            (clint_if),
//--------------------------debug interface--------------------------------
    .pipdebug_slave         (pip_dbg_if),
//-----------------------------to store buffer--------------------------
    .stb_manage_master      (stbmanage_if),
//-------------------------axi bus for ptw use-------------------------
    .immu_axi_ar            (immu_axi_ar),
    .immu_axi_r             (immu_axi_r),
    .dmmu_axi_ar            (dmmu_axi_ar),
    .dmmu_axi_r             (dmmu_axi_r),
//-------------------------to system manage bus-----------------------
    .icache_flush_req       (icache_flush_req),
    .dcache_flush_req       (dcache_flush_req),
    .icache_flush_ack       (icache_flush_req),
    .dcache_flush_ack       (dcache_flush_req),
//-------------------instruction mmu and cache access port------------------
    .icache_mif             (icache_access),
    .icache_sif             (icache_return),
//--------------------data mmu and cache access port------------------------
    .dcache_mif             (dcache_access),
    .dcache_sif             (dcache_return)
);
//TODO: 下面的信号目前还不用，先接为固定信号
always_comb begin
    clint_if.mei = 0;
    clint_if.sei = 0;
    clint_if.msi = 0;
    clint_if.mti = 0;
    clint_if.mtime=114514;
    pip_dbg_if.haltreq  =0;
    pip_dbg_if.resumereq=0;
    dmmu_axi_ar.arready=0;
    dmmu_axi_r.rvalid=0;
    immu_axi_ar.arready=0;
    immu_axi_r.rvalid=0;
end

fullv_difftest#(
    .XLEN                   (64),
    .PROG_FILE              (INIT_FILE)
)fullv_difftest(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
//--------------dut 寄存器值输入-------------
    .dut_ireg               (dut_ireg),
//--------------dut 指令提交端口-------------
    .test_commit0           (test_commit0),
    .test_commit1           (test_commit1)
);

virtual_bus#(
    .INIT_FILE              (INIT_FILE)
)virtual_bus(
    .clk_i                  (clk_i),
    .arst_i                 (arst_i),
    .icache_access          (icache_access),
    .icache_return          (icache_return),
    .dcache_access          (dcache_access),
    .dcache_return          (dcache_return)
);

initial begin

    clk_i = 1'b0;
    arst_i= 1'b1;
#15 arst_i= 1'b0;
    $display("Ignition emission!");

end

always begin
    #10 clk_i = ~clk_i;
end

endmodule