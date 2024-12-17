`include"prv664_config.svh"
`include"prv664_define.svh"
interface igpr_access_interface();

    logic [`XLEN-1:0]       rs1data,    rs2data;
    logic [4:0]             rs1index,   rs2index;

    modport master(

        output rs1index,    rs2index,
        input  rs1data,     rs2data  
        
    );

    modport slave(
        input   rs1index,    rs2index,
        output  rs1data,     rs2data
    );

    
endinterface