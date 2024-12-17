`include"prv664_config.svh"
`include"prv664_define.svh"
`include"prv664_bus_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) system manage interface, 当前版本暂时未使用此接口
    Author  : Jack.Pan
    Date    : 2022/10/10
    Version : 0.0 (file initial)

***********************************************************************************************/
interface sysmanage_interface();

    logic           valid;
    logic           ready;
    logic [7:0]     command;

    modport master(

        output valid,
        input  ready,
        output command

    );

    modport slave(

        input  valid,
        output ready,
        input  command

    );

endinterface