`include"prv664_config.svh"
`include"prv664_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) 32个寄存器的scoreboard更新接口
    Author  : Jack.Pan
    Date    : 2022/10/10
    Version : 0.0 (file initial)

***********************************************************************************************/
interface scoreboard_update_interface();

    logic [4:0]             rdindex;
    logic [7:0]             itag;
    logic                   write;
    
    modport master(
        output rdindex,   
        output itag,
        output write
    );
    modport slave(
        input  rdindex,
        input  itag,
        input  write
    );
endinterface