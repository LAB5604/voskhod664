`include"prv664_config.svh"
`include"prv664_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) interface for simulation and test use
    Author  : Jack.Pan
    Date    : 2022/10/10
    Version : 0.0 (file initial)

***********************************************************************************************/
interface test_commit_interface;
    logic [`XLEN-1:0] pc;
    logic             trap;
    logic             valid;
    logic             wen;
    logic [4:0]       windex;   //写回int寄存器的索引
    logic [`XLEN-1:0] wdata;    //写回int寄存器的值
    modport master (
        output pc,
        output trap,
        output valid,
        output windex,   //写回int寄存器的索引
        output wdata     //写回int寄存器的值
    );
    modport slave(
        input pc,
        input trap,
        input valid
    );
endinterface
///////////////////////////////////////////////////////////////////
//            csr interface for difftest check                   //
///////////////////////////////////////////////////////////////////
interface test_csr_interface;
    logic [`XLEN-1:0] mepc;
    modport master(
        output mepc
    );
    modport slave(
        input mepc
    );
endinterface