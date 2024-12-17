`include"prv664_config.svh"
`include"prv664_define.svh"
interface pip_decode_interface();

    logic [4:0]             opcode;
    logic [9:0]             funct;
    logic [4:0]             rs1index;
    logic                   rs1en;
    logic [4:0]             rs2index;
    logic                   rs2en;
    logic [4:0]             rdindex;
    logic                   rden;
    logic [`XLEN-1:0]       pc;
    logic [19:0]            imm;               //RV最多只有20位立即数，为了节约DFF资源在这里也只放20位
    //        float-point register decode
    logic [4:0]             frs1index;
    logic                   frs1en;
    logic [4:0]             frs2index;
    logic                   frs2en;
    logic [4:0]             frs3index;
    logic                   frs3en;
    logic [4:0]             frdindex;
    logic                   frden;
    //        csr register decode
    logic [11:0]            csrindex;
    logic                   csren;
    logic                   fflagen;            //fflag will be affect
    //       dispatch dest and control
    logic [7:0]             itag;
    logic [3:0]             disp_dest;
    logic                   valid;
    logic                   ready;

    modport master(

        output                   opcode,
        output                   funct,
        output                   rs1index,
        output                   rs1en,
        output                   rs2index,
        output                   rs2en,
        output                   rdindex,
        output                   rden,
        output                   pc,
        output                   imm,
        output                   frs1index,
        output                   frs1en,
        output                   frs2index,
        output                   frs2en,
        output                   frs3index,
        output                   frs3en,
        output                   frdindex,
        output                   frden,
        output                   csrindex,
        output                   csren,
        output                   fflagen,
        output                   itag,
        output                   disp_dest,
        output                   valid,
        input                    ready

    );

    modport slave(

        input                    opcode,
        input                    funct,
        input                    rs1index,
        input                    rs1en,
        input                    rs2index,
        input                    rs2en,
        input                    rdindex,
        input                    rden,
        input                    pc,
        input                    imm,
        input                    frs1index,
        input                    frs1en,
        input                    frs2index,
        input                    frs2en,
        input                    frs3index,
        input                    frs3en,
        input                    frdindex,
        input                    frden,
        input                    csrindex,
        input                    csren,
        input                    fflagen,
        input                    itag,
        input                    disp_dest,
        input                    valid,
        output                   ready

    );

endinterface