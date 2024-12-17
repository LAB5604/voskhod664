`include"prv664_config.svh"
`include"prv664_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) 系统信息接口，包含关键csr的值
    Author  : Jack.Pan
    Date    : 2022/10/10
    Version : 0.0 (file initial)

***********************************************************************************************/
interface sysinfo_interface();

    logic [`XLEN-1:0]   mstatus, sstatus, dstatus, mie, sie, mip, sip, mideleg, medeleg, satp;
    logic [`XLEN-1:0]   fcsr;
    logic               trapd_invalid;  //不进入debug模式，debug单元通过这个信号控制N步运行模式
    logic [1:0]         priv;

    modport slave(
        input mstatus, sstatus, dstatus, mie, sie, mip, sip, mideleg, medeleg, satp,
        input fcsr,
        input trapd_invalid,
        input priv
    );

    modport master(
        output mstatus, sstatus, dstatus, mie, sie, mip, sip, mideleg, medeleg, satp,
        output fcsr,
        output trapd_invalid,
        output priv
    );

endinterface