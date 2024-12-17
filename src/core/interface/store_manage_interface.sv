`include "prv664_config.svh"
`include "prv664_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) 存储子系统管理接口，当前版本已经未使用
    Author  : Jack.Pan
    Date    : 2022/10/10
    Version : 0.0 (file initial)

***********************************************************************************************/
interface store_manage_interface();

    logic       valid;
    logic       ready;
    logic       fence;
    logic       fencevma;
    logic       fencei;
    logic       commit;
    logic [7:0] itag;

    modport master(

        output valid,
        input ready,
        output fence, fencevma, fencei, commit, itag

    );

    modport slave(

        input  valid,
        output ready,
        input  fence, fencevma, fencei, commit, itag

    );

endinterface