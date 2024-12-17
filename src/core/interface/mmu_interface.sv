`include"prv664_config.svh"
`include"prv664_define.svh"
`include"prv664_bus_define.svh"
////////////////////////////////////////////////////////////////////////////////
//                          TLB access interface                              //
////////////////////////////////////////////////////////////////////////////////
interface mmu_interface();

    logic [7:0]           id;               //access id
    logic [`XLEN-1:0]     addr;             //access address output
    logic [`XLEN-1:0]     data;
    logic [4:0]           opcode;           //access opcode output
    logic [9:0]           funct   ;         //access function output
    logic [`MMU_USER_W-1:0]   user;
    logic                 valid;            //access valid
    logic                 full;             //access full

    modport master (
        output            id,      
        output            addr,    
        output            data,
        output            opcode,  
        output            funct,
        output            user,
        output            valid,   
        input             full     
    );
    modport slave (
        input             id,      
        input             addr,
        input             data, 
        input             opcode,  
        input             funct,
        input             user,
        input             valid,   
        output            full     
    );

endinterface //interfacename