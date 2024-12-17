`include"salyut1_soc_config.svh"

interface sys_axi_ar();
    logic [`AXI_ID_WIDTH-1:0]   arid;
    logic [`AXI_ADDR_WIDTH-1:0] araddr;
    logic [7:0]               	arlen;
    logic [2:0]               	arsize;
    logic [1:0]               	arburst;
    logic                     	arlock;
    logic [3:0]               	arcache;
    logic [2:0]               	arprot;
    logic [3:0]               	arqos;
    logic [3:0]               	arregion;
    logic                     	arvalid;
    logic                       arready;
    modport master(
        output arid,
        output araddr,
        output arlen,
        output arsize,
        output arburst,
        output arlock,
        output arcache,
        output arprot,
        output arqos,
        output arregion,
        output arvalid,
        input  arready
    );
    modport slave(
        input  arid,
        input  araddr,
        input  arlen,
        input  arsize,
        input  arburst,
        input  arlock,
        input  arcache,
        input  arprot,
        input  arqos,
        input  arregion,
        input  arvalid,
        output arready
    );
endinterface