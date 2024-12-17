`include "prv664_config.svh"
`include "prv664_define.svh"
interface instr_commit_interface();

    logic               valid;
    logic [`XLEN-1:0]   pc;
    logic [7:0]         itag;
    logic [4:0]         opcode;
    logic               mmio;
    logic [`XLEN-1:0]   trap_value, trap_cause, trap_pc;
    logic [3:0]         trap_dcause;
    logic               trap_s,     trap_m,     trap_async; //处理器trap进入s模式、进入m模式、async trap
    logic               trap_d;                             //处理器trap进入debug模式
    
    modport master(
        output valid,
        output pc,
        output itag,
        output mmio,
        output opcode,
        output trap_value, trap_cause, trap_pc,
        output trap_s,     trap_m,     trap_async,
        output trap_d,     trap_dcause
    );

    modport slave(
        input  valid,
        input  pc,
        input  itag,
        input  mmio,
        input  opcode,
        input  trap_value, trap_cause, trap_pc,
        input  trap_s,     trap_m,     trap_async,
        input  trap_d,     trap_dcause
    );

endinterface