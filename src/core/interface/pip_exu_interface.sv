`include "prv664_config.svh"
`include "prv664_define.svh"
interface pip_exu_interface();

    logic [`XLEN-1:0]       data1;          //1st data
    logic [`XLEN-1:0]       data2;          //2st data
    logic [4:0]             frs1index,   frs2index,  frs3index;
    logic                   frs1en,      frs2en,     frs3en;
    logic [`XLEN-1:0]       pc;             //
    logic [19:0]            imm20;
    logic [4:0]             imm5;           //5bit imm for FPU use
    logic [4:0]             opcode;
    logic [9:0]             funct;
    logic [7:0]             itag;
    logic                   valid;
    logic                   full;

    modport bypass_mif(
        output                  itag,
        output                  valid,
        input                   full
    );

    modport bypass_sif(
        input                   itag,
        input                   valid,
        output                  full
    );

    modport sysmanage_mif(
        output                  valid,
        output                  itag,
        output                  opcode,
        output                  funct,
        input                   full
    );

    modport sysmanage_sif (
        input                   valid,
        input                   itag,
        input                   opcode,
        input                   funct,
        output                  full
    );

    modport bru_mif (
        output                  data1,
        output                  data2,
        output                  pc,
        output                  imm20,
        output                  opcode,
        output                  funct,
        output                  itag,
        output                  valid,
        input                   full
    );

    modport bru_sif (

        input                   data1,
        input                   data2,
        input                   pc,
        input                   imm20,
        input                   opcode,
        input                   funct,
        input                   itag,
        input                   valid,
        output                  full

    );

    modport alu_mif (

        output                  data1,
        output                  data2,
        output                  imm20,
        output                  opcode,
        output                  funct,
        output                  itag,
        output                  valid,
        input                   full

    );

    modport alu_sif (

        input                   data1,
        input                   data2,
        input                   imm20,
        input                   opcode,
        input                   funct,
        input                   itag,
        input                   valid,
        output                  full

    );

    modport mdiv_mif (

        output                  data1,
        output                  data2,
        output                  opcode,
        output                  funct,
        output                  itag,
        output                  valid,
        input                   full

    );

    modport mdiv_sif (

        input                   data1,
        input                   data2,
        input                   opcode,
        input                   funct,
        input                   itag,
        input                   valid,
        output                  full

    );

    modport fpu_mif (

        output                  data1,
        output                  frs1index,
        output                  frs1en,
        output                  frs2index,
        output                  frs2en,
        output                  frs3index,
        output                  frs3en,
        output                  imm5,
        output                  opcode,
        output                  funct,
        output                  itag,
        output                  valid,
        input                   full

    );

    modport fpu_sif (

        input                   data1,
        input                   frs1index,
        input                   frs1en,
        input                   frs2index,
        input                   frs2en,
        input                   frs3index,
        input                   frs3en,
        input                   imm5,
        input                   opcode,
        input                   funct,
        input                   itag,
        input                   valid,
        output                  full

    );

    modport lsu_mif(

        output                  data1,
        output                  data2,
        output                  imm20,
        output                  opcode,
        output                  funct,
        output                  itag,
        output                  valid,
        input                   full

    );

    modport lsu_sif(

        input                   data1,
        input                   data2,
        input                   imm20,
        input                   opcode,
        input                   funct,
        input                   itag,
        input                   valid,
        output                  full

    );

endinterface