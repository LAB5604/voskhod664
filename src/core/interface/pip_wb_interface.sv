`include "prv664_config.svh"
`include "prv664_define.svh"
interface pip_wb_interface(

);

    logic [`XLEN-1:0]   data;
    logic [`XLEN-1:0]   csrdata;
    logic [`XLEN-1:0]   branchaddr;

    logic               jump;
    logic [4:0]         fflag;

    logic               mmio;

    logic               load_acc_flt, load_addr_mis, load_page_flt;
    logic               store_acc_flt, store_addr_mis, store_page_flt;

    logic [7:0]         itag;

    logic               valid;
    logic               ready;

    modport master(
        output data,
        output csrdata,
        output branchaddr,
        output jump,
        output fflag,
        output mmio,
        output load_acc_flt, load_addr_mis, load_page_flt,store_acc_flt, store_addr_mis, store_page_flt,
        output itag,
        output valid,
        input  ready
    );

    modport slave(
        input  data,
        input  csrdata,
        input  branchaddr,
        input  jump,
        input  fflag,
        input  mmio,
        input  load_acc_flt, load_addr_mis, load_page_flt,store_acc_flt, store_addr_mis, store_page_flt,
        input  itag,
        input  valid,
        output ready
    );

endinterface