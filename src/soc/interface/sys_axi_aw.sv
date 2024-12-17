`include"salyut1_soc_config.svh"

interface sys_axi_aw();
    logic [`AXI_ID_WIDTH-1:0]   awid;
    logic [`AXI_ADDR_WIDTH-1:0] awaddr;
    logic [7:0]               	awlen;
    logic [2:0]               	awsize;
    logic [1:0]               	awburst;
    logic                     	awlock;
    logic [3:0]               	awcache;
    logic [2:0]               	awprot;
    logic [3:0]               	awqos;
    logic [3:0]               	awregion;
    logic                     	awvalid;
    logic                       awready;
    modport master(
        output awid,
        output awaddr,
        output awlen,
        output awsize,
        output awburst,
        output awlock,
        output awcache,
        output awprot,
        output awqos,
        output awregion,
        output awvalid,
        input  awready
    );
    modport slave(
        input  awid,
        input  awaddr,
        input  awlen,
        input  awsize,
        input  awburst,
        input  awlock,
        input  awcache,
        input  awprot,
        input  awqos,
        input  awregion,
        input  awvalid,
        output awready
    );
endinterface