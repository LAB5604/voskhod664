////////////////////////////////////////////////////////////////////////////////////////////
//                                   RISC-V opcode                                        //
////////////////////////////////////////////////////////////////////////////////////////////
`define OPCODE_LOAD                 5'b00000        //Load/Store/LoadFP/StoreFP share the same funct3
`define OPCODE_LOADFP               5'b00001
    `define FUNCT3_8bit             3'b000
    `define FUNCT3_8bitU            3'b100  
    `define FUNCT3_16bit            3'b001  
    `define FUNCT3_16bitU           3'b101  
    `define FUNCT3_32bit            3'b010 
    `define FUNCT3_32bitU           3'b110 
    `define FUNCT3_64bit            3'b011 
`define OPCODE_MISCMEM              5'b00011
    `define FUNCT3_FENCE            3'b000
    `define FUNCT3_FENCEI           3'b001 
`define OPCODE_OPIMM                5'b00100
`define OPCODE_AUIPC                5'b00101 
`define OPCODE_OPIMM32              5'b00110 
`define OPCODE_STORE                5'b01000 
`define OPCODE_STOREFP              5'b01001 
`define OPCODE_AMO                  5'b01011        //AMO instruction use the same funct3 code as load
`define OPCODE_OP                   5'b01100 
    /////////////////////////////////////////
    //         RV64I funct3 define         //
    /////////////////////////////////////////
    `define FUNCT3_ADD              3'b000
    `define FUNCT3_SUB              3'b000
    `define FUNCT3_SLL              3'b001 
    `define FUNCT3_SLT              3'b010 
    `define FUNCT3_SLTU             3'b011  
    `define FUNCT3_XOR              3'b100 
    `define FUNCT3_SRLA             3'b101          //SRL and SRA share the same funct3, funct7 is different
    `define FUNCT3_OR               3'b110 
    `define FUNCT3_AND              3'b111 
    /////////////////////////////////////////
    //         RV64M funct3 define         //
    /////////////////////////////////////////
    `define FUNCT3_MUL              3'b000  
    `define FUNCT3_MULH             3'b001 
    `define FUNCT3_MULHSU           3'b010 
    `define FUNCT3_MULHU            3'b011 
    `define FUNCT3_DIV              3'b100 
    `define FUNCT3_DIVU             3'b101 
    `define FUNCT3_REM              3'b110 
    `define FUNCT3_REMU             3'b111 
`define OPCODE_LUI                  5'b01101 
`define OPCODE_OP32                 5'b01110 
`define OPCODE_MADD                 5'b10000 
`define OPCODE_MSUB                 5'b10001 
`define OPCODE_NMSUB                5'b10010 
`define OPCODE_NMADD                5'b10011 
`define OPCODE_OPFP                 5'b10100 
    `define FUNCT5_FADD             5'b00000
    `define FUNCT5_FSUB             5'b00001
    `define FUNCT5_FMUL             5'b00010
    `define FUNCT5_FDIV             5'b00011
    `define FUNCT5_FSQRT            5'b01011  
    `define FUNCT5_FMINMAX          5'b00101
    `define FUNCT5_FCVT_int_fmt     5'b11000
    `define FUNCT5_FCVT_fmt_int     5'b11010
    `define FUNCT5_FCVT_fmt_fmt     5'b01000
    `define FUNCT5_FMV_fmt_int      5'b11110
    `define FUNCT5_FMV_int_fmt      5'b11100
    `define FUNCT5_FSGNJ            5'b00100
    `define FUNCT5_FCMP             5'b10100
    `define FUNCT5_FCLASS           5'b11100
`define OPCODE_BRANCH               5'b11000 
    `define FUNCT3_BEQ              3'b000
    `define FUNCT3_BNE              3'b001
    `define FUNCT3_BLT              3'b100
    `define FUNCT3_BGE              3'b101
    `define FUNCT3_BLTU             3'b110
    `define FUNCT3_BGEU             3'b111
`define OPCODE_JALR                 5'b11001
`define OPCODE_JAL                  5'b11011
`define OPCODE_SYSTEM               5'b11100
    `define FUNCT3_CSRRW            3'b001
    `define FUNCT3_CSRRS            3'b010
    `define FUNCT3_CSRRC            3'b011
    `define FUNCT3_CSRRWI           3'b101
    `define FUNCT3_CSRRSI           3'b110
    `define FUNCT3_CSRRCI           3'b111

//------------------------------------CSRs----------------------------------------
//----------CSR index------------------------
//          user read and write 
`define URW_FCSR_INDEX              12'h003
//          User read only
`define URO_CYCLE_INDEX 			12'hc00	        //User read only, a shadow of Machine mode cycle counter
`define URO_TIME_INDEX  			12'hc01	        //User read only, a shadow of Machine mode time
`define URO_INSTRET_INDEX 		    12'hc02         //User read only, a shadow of instruction retired counter
`define URO_HPMCOUNTER3_INDEX		12'hc03         //User read only, performance counter3
`define URO_HPMCOUNTER4_INDEX 	    12'hc04         //User read only, performance counter4
`define URW_HALT_INDEX               12'hcc0         //halt pulse generate csr, write to this csr will cause a halt (for ysyx difftest use) 
`define URW_PRINT_INDEX              12'hcc1         //print function generate csr, value write to this csr will display on Simulation tool
//   Supervisior mode read and write
`define SRW_SSTATUS_INDEX			12'h100
`define SRW_SIE_INDEX 			    12'h104
`define SRW_STVEC_INDEX 			12'h105
`define SRW_SCOUNTEREN_INDEX 		12'h106
`define SRW_SSCRATCH_INDEX 		    12'h140
`define SRW_SEPC_INDEX 			    12'h141
`define SRW_SCAUSE_INDEX 			12'h142
`define SRW_STVAL_INDEX 			12'h143
`define SRW_SIP_INDEX 			    12'h144
`define SRW_SATP_INDEX 			    12'h180
//    Machine mode read only
`define MRO_MVENDORID_INDEX 		12'hf11
`define MRO_MARCHID_INDEX 		    12'hf12
`define MRO_MIMP_INDEX 			    12'hf13
`define MRO_MHARDID_INDEX 		    12'hf14
`define MRW_MSTATUS_INDEX 		    12'h300
`define MRO_MISA_INDEX 			    12'h301
`define MRW_EVANGELION_INDEX        12'hbc0         //Machine mode read/write, this csr is for sepecial use 
`define MRW_KERNELCFG_INDEX         12'hbc1         //Machine mode read/write, this csr is set to control some modules in kernel
//     Machine mode read and write
`define MRW_MEDELEG_INDEX 		    12'h302
`define MRW_MIDELEG_INDEX 		    12'h303	
`define MRW_MIE_INDEX 			    12'h304
`define MRW_MTVEC_INDEX 			12'h305
`define MRW_MCOUNTEREN_INDEX 		12'h306
`define MRW_MSCRATCH_INDEX 		    12'h340
`define MRW_MEPC_INDEX 			    12'h341
`define MRW_MCAUSE_INDEX 			12'h342
`define MRW_MTVAL_INDEX 			12'h343
`define MRW_MIP_INDEX 			    12'h344
`define MRW_PMPCFG0_INDEX 		    12'h3a0
`define MRW_PMPADDR0_INDEX 		    12'h3b0
`define MRW_PMPADDR1_INDEX 		    12'h3b1
`define MRW_MCYCLE_INDEX 			12'hb00
`define MRW_MINSTRET_INDEX 		    12'hb02
`define MRW_MHPCOUNTER3_INDEX 	    12'hb03
`define MRW_MHPCOUNTER4_INDEX	 	12'hb04
`define MRW_MCOUNTINHIBIT_INDEX     12'h320
`define MRW_MHPMEVENT3_INDEX 		12'h323
//       Debug mode csrs, can be accessed in Machine mode
`define DRW_DCSR_INDEX              12'h7b0
`define DRW_DPC_INDEX               12'h7b1
`define DRW_DSCRATCH0_INDEX         12'h7b2
`define DRW_DSCRATCH1_INDEX         12'h7b3

`define MACHINE                     2'b11 
`define SUPERVISIOR                 2'b01 
`define USER                        2'b00 
////////////////////////////////////////////////////////////////////////////////////////////
//                             csr defines                                                //
////////////////////////////////////////////////////////////////////////////////////////////

`define CAUSE_SSI                   1
`define CAUSE_MSI                   3
`define CAUSE_STI                   5
`define CAUSE_MTI                   7
`define CAUSE_SEI                   9
`define CAUSE_MEI                   11
`define CAUSE_INST_ADDR_MIS         0
`define CAUSE_INST_ACC_FLT          1
`define CAUSE_INST_ILL_INS          2
`define CAUSE_BREAKPOINT            3
`define CAUSE_LOAD_ADDR_MIS         4
`define CAUSE_LOAD_ACC_FLT          5
`define CAUSE_STOR_ADDR_MIS         6
`define CAUSE_STOR_ACC_FLT          7
`define CAUSE_ECALL_U               8
`define CAUSE_ECALL_S               9
`define CAUSE_ECALL_M               11
`define CAUSE_INST_PAGE_FLT         12
`define CAUSE_LOAD_PAGE_FLT         13
`define CAUSE_STOR_PAGE_FLT         15
`define CAUSE_NMI                   16