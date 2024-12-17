`include"prv664_config.svh"
`include"prv664_define.svh"
interface csr_access_interface();

    logic [`XLEN-1:0]       csrdata;
    logic [11:0]            csrindex;

    modport master(
        output csrindex,
        input  csrdata
    );

    modport slave(
        output csrdata,
        input csrindex
    );

endinterface
