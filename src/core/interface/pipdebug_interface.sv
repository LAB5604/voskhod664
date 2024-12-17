`include "prv664_config.svh"
`include "prv664_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) debug单元与核心的接口
    Author  : Jack.Pan
    Date    : 2022/10/10
    Version : 0.0 (file initial)

***********************************************************************************************/
interface pipdebug_interface();
    logic [11:0]          csrindex;
    logic                 csrwr;
    logic [`XLEN-1:0]     csrwdata;
    logic [`XLEN-1:0]     csrrdata;
    logic [4:0]           igprindex,    fgprindex;
    logic                 igprwr,       fgprwr;
    logic [`XLEN-1:0]     igprwdata,    fgprwdata;
    logic [`XLEN-1:0]     igprrdata,    fgprrdata;
    logic                 haltreq;                  //request core to halt, when core is halted, this signal is ignored
    logic                 halted;                   //core is halted
    logic                 resumereq;                //request core to resume, when core halted signal is not active, this signal is ignored
    logic                 run;                      //core is resume now
    modport master (
        output csrindex,
        output csrwr,
        output csrwdata,
        output csrrdata,
        output igprindex,    fgprindex,
        output igprwr,       fgprwr,
        output igprwdata,    fgprwdata,
        input  igprrdata,    fgprrdata,
        output haltreq,
        input  halted,
        output resumereq,
        input  run
    );
    modport slave(
        input  csrindex,
        input  csrwr,
        input  csrwdata,
        output csrrdata,
        input  igprindex,    fgprindex,
        input  igprwr,       fgprwr,
        input  igprwdata,    fgprwdata,
        output igprrdata,    fgprrdata,
        input  haltreq,
        output halted,
        input  resumereq,
        output run
    );

endinterface
