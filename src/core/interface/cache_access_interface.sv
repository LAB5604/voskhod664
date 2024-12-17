`include"prv664_config.svh"
`include"prv664_define.svh"
`include"prv664_bus_define.svh"
interface cache_access_interface();
    logic [7:0]           id;               //access id
    logic [`XLEN-1:0]     addr;             //access address output
    logic [`XLEN-1:0]     wdata;            //accesss write data
    logic                 ci;               //access cache inhibit
    logic                 wt;               //access write through
    logic [4:0]           opcode;           //access opcode output
    logic [9:0]           funct;            //access function output
    logic [`CACHE_USER_W-1:0] user;
    logic [5:0]           error;            //access error bit
    logic                 valid;            //access valid
    logic                 full;             //access full

    modport master (

        output              id,             
        output              addr,
        output              wdata,
        output              ci,
        output              wt,
        output              opcode,
        output              funct,
        output              user,
        output              error,
        output              valid,          
        input               full            

    );

    modport slave (

        input               id,             
        input               addr,
        input               wdata,
        input               ci,
        input               wt,
        input               opcode,
        input               funct,
        input               user,
        input               error,
        input               valid,          
        output              full            

    );

endinterface