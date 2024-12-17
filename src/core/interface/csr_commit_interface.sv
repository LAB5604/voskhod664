`include "prv664_config.svh"
`include "prv664_define.svh"
interface csr_commit_interface();

    logic               valid;
    logic [`XLEN-1:0]   csrdata;   //write back data
    logic [11:0]        csrindex;
    logic               csren;
    logic               mret,       sret;
    logic [4:0]         fflag;
    logic               fflagen;
    
    modport master(
        output valid,
        output csrdata,
		output csrindex,
		output csren,
        output mret,       sret,
        output fflag,
        output fflagen
    );

    modport slave(
        input  valid,
        input  csrdata,
		input  csrindex,
		input  csren,
        input  mret,       sret,
        input  fflag,
        input  fflagen
    );
    
endinterface