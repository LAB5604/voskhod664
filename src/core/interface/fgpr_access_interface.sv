`include"prv664_config.svh"
`include"prv664_define.svh"
interface fgpr_access_interface();

    logic                   valid;
    logic [`XLEN-1:0]       rs1data;
    logic [4:0]             rs1index;

    modport master(

        output valid,
        output rs1index,
        input  rs1data
        
    );

    modport slave(
        input   valid,
        input   rs1index,
        output  rs1data
    );

    
endinterface