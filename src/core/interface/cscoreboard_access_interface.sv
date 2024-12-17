`include"prv664_config.svh"
`include"prv664_define.svh"
interface cscoreboard_access_interface();

    logic                   write,      csren,      fflagen;
    logic                   csr_busy;
    logic                   fcsr_busy;

    modport master(

        output write,   csren,  fflagen,
        input  csr_busy,    fcsr_busy

    );
endinterface