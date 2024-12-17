`include"prv664_config.svh"
`include"prv664_define.svh"
interface decoder_interface();
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
    //       instruction information decode
    logic [2:0]             branchtype;          //bit0：直接跳转，bit1：call bit2：return
    logic                   ecall;
    logic                   ebreak;
    logic                   mret;
    logic                   sret;
    logic                   illins;
    logic                   instrpageflt;
    logic                   instraccflt;
    logic                   instraddrmis;
    logic                   irrevo;             //这条指令不能被撤销

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
        output                   branchtype,
        output                   ecall,
        output                   ebreak,
        output                   mret,
        output                   sret,
        output                   illins,
        output                   instrpageflt,
        output                   instraccflt,
        output                   instraddrmis,
        output                   irrevo
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
        input                    branchtype,
        input                    ecall,
        input                    ebreak,
        input                    mret,
        input                    sret,
        input                    illins,
        input                    instrpageflt,
        input                    instraccflt,
        input                    instraddrmis,
        input                    irrevo
    );

endinterface