`timescale 1ns/1ps
///////////////////////////////////////////////////////////////////////////////
//                      simulation config                                    //
///////////////////////////////////////////////////////////////////////////////
`define SIMULATION
//`define YSYX_DIFFTEST
`define IFU_ERROR_REPORT
`define IFU_INFO_REPORT
`define DECODE_ERROR_REPORT
`define DECODE_INFO_REPORT
`define COMMIT_INFO_REPORT      0               //to display commit information in command line
`define INT_COMMIT_REPORT       0               //to display int commit data in command line(must enable COMMIT_INFO_REPORT first)
`define AUTO_STOP               1               //auto stop cpu when processor hit any trap, eg: useing ebreak instruction to stop simulation
///////////////////////////////////////////////////////////////////////////////
//                 core config                                               //
///////////////////////////////////////////////////////////////////////////////
`ifdef YSYX_DIFFTEST
    `define PC_RESET                64'h80000000    //when using this core in ysyx test env, reset to 0x80000000
`else
    `define PC_RESET                64'h60000000    //when useing this core in other env, reset to your soc bootrom address
`endif
//determing address range can be cacheable: bootrom,sram,dram address range
//the PC_RESET must be in cacheable range
`define CACHEABLE_ADDR_HI       64'hffff_ffff_ffff_ffff
`define CACHEABLE_ADDR_LO       64'h0000_0000_6000_0000
`define SAFE_EXECUTE                            //safe execute mode, when have this defines noo need to have storebuffer
                                                //del this define will make store instruction unsafe
`define FGROUP_BUFFER_SIZE      32              //instruction fetch group buffer size value from 1~256
`define BPU_ON                                  //I suggest you turn on BPU, deleeat this define to close BPU     关掉BPU后这车就像没有驾驶舱的泥头车
//`define FPU_ON                                  //deleat this define to close FPU
`define AMO_ON                                  //AMO unit
`define RAS_SIZE                32
`define BTB_SIZE                32
`define PHT_SIZE                64
`define L1ITLB_ERRPAGE_SIZE     4
`define L1ITLB_KPAGE_SIZE       32              //4K page TLB entry number
`define L1ITLB_MPAGE_SIZE       8               //2M page TLB entry number
`define L1ITLB_GPAGE_SIZE       2               //1G page TLB entry number
`define L1I_LINE_NUM            128             //Line size=128Byte
`define L1D_LINE_NUM            128
`define LS_ROB_SIZE             2               //ROB size of LSU, recommend  value is 8
`define BRU_UOP_BUFFER_DEEPTH   4               //recommend value is 4
`define ALU_UOP_BUFFER_DEEPTH   4               //short int uop buffer size, recommend size is 4 for general purpose
`define MDIV_UOP_BUFFER_DEEPTH  4
`define LSU_UOP_BUFFER_DEEPTH   4
`define ROB_SIZE                8
`define RNM                     "DISABLE"         //re-name function enable
`define PADDR                   32               //physical address width
//////////////////////////////////////////////////////////////////////////////
//                  L1 cache config                                         //
//////////////////////////////////////////////////////////////////////////////
//`define NONE_CACHE                              //define none cache install
`define PIP_ICACHE
`define PIP_DCACHE
//////////////////////////////////////////////////////////////////////////////
//                  debug subsystem config                                  //
//////////////////////////////////////////////////////////////////////////////
//`define DEBUG_EN                                //enable debug subsystem
`define DCSR_EBREAM_INIT        1'b0            //ebreak initial value 
`define DCSR_EBREAS_INIT        1'b0 
`define DCSR_EBREAU_INIT        1'b0 