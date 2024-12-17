`include "riscv_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 

    Name    : virtual riscv core 
    Author  : Jack.Pan
    Date    : 2023/7/4
    Version : 1.0
    Desc    : This is a full verilog riscv model for voskhood project.
                remember: ONLY VERILOG!

***********************************************************************************************/
module virtual_rv#(
    parameter PROG_FILE = "hex.txt",
              XLEN = 64,
              PC_RESET='h8000_0000,
    // memory space config
              RAM_ADDR_BASE = 'h8000_0000,
              MMIO_ADDR_BASE = 'h0000_0000
)(
//-----------------control port-----------------------
    input wire              clk_i,
    input wire              arst_i,
    input wire              valid_i,
    input wire [7:0]        step_num_i,
    input wire              trap,
    input wire              async,          //表示当前trap是一个异步trap
    input wire [XLEN-1:0]  trap_cause,
//-----------------register out-----------------------
    output reg  [XLEN-1:0]  pc, pc_commited,    //pc指向下一条指令的地址，pc-commit指向当前已提交指令的地址
    output wire [XLEN-1:0]  r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,
    output wire [XLEN-1:0]  r16,r17,r18,r19,r20,r21,r22,r23,r24,r25,r26,r27,r28,r29,r30,r31,
//------------------csr out------------------------------
    output      [XLEN-1:0] csr_mstatus, csr_mtval, csr_mtvec, csr_mcause, csr_mepc, csr_mie
);
///////////////////////////////////////////////////////
//                program ram                        //
///////////////////////////////////////////////////////
    reg [7:0] ram [2147483647:0];       //total 2G ram space
    reg [7:0] mmio[2147483647:0];       //total 2G mmio space
///////////////////////////////////////////////////////
//                 CPU core reg                      //
///////////////////////////////////////////////////////

    reg [XLEN-1:0] ireg [31:0];
    //csr regs
    reg [1:0]       status_priv;    //当前运行的权限
    reg             status_tsr,     status_tw,      status_tvm, status_mxr, status_sum, status_mpriv, status_spp;
    reg             status_mpie,    status_spie,    status_mie, status_sie, status_sd;
    reg [1:0]       status_mpp,     status_fs,      status_uxl, status_sxl; 
    reg [XLEN-1:0] mtval, mtvec, mcause, mepc, mie, mscratch;
    integer i;

initial begin
    pc = PC_RESET;
    for(i=0;i<32;i=i+1)begin
        ireg[i] = 0;            //所有寄存器清零
    end
    status_priv = 2'b11;        //复位后为机器模式
    $readmemh(PROG_FILE, ram);
end
    
always @(posedge clk_i or posedge arst_i) begin
    if(arst_i)begin
        pc = PC_RESET;
    end
    else if(valid_i)begin
        for(i=0; i<step_num_i; i=i+1)begin
            instr_exec();                     //跑N条指令
        end
    end
end

assign r0 = ireg[0];
assign r1 = ireg[1];
assign r2 = ireg[2];
assign r3 = ireg[3];
assign r4 = ireg[4];
assign r5 = ireg[5];
assign r6 = ireg[6];
assign r7 = ireg[7];
assign r8 = ireg[8];
assign r9 = ireg[9];
assign r10= ireg[10];
assign r11= ireg[11];
assign r12= ireg[12];
assign r13= ireg[13];
assign r14= ireg[14];
assign r15= ireg[15];
assign r16= ireg[16];
assign r17= ireg[17];
assign r18= ireg[18];
assign r19= ireg[19];
assign r20= ireg[20];
assign r21= ireg[21];
assign r22= ireg[22];
assign r23= ireg[23];
assign r24= ireg[24];
assign r25= ireg[25];
assign r26= ireg[26];
assign r27= ireg[27];
assign r28= ireg[28];
assign r29= ireg[29];
assign r30= ireg[30];
assign r31= ireg[31];

assign csr_mstatus = {status_sd,25'b0,1'b0,1'b0,status_sxl,status_uxl,9'b0,status_tsr,status_tw,status_tvm,status_mxr,status_sum,status_mpriv,2'b0,status_fs,status_mpp,2'b00,status_spp,status_mpie,1'b0,status_spie,1'b0,status_mie,1'b0,status_sie,1'b0};
assign csr_mtval   = mtval;
assign csr_mtvec   = mtvec;
assign csr_mcause  = mcause;
assign csr_mepc    = mepc;
assign csr_mie     = mie;
//////////////////////////////////////////////////////
//                 cpu core varb                    //
//////////////////////////////////////////////////////
    reg [31:0] instr;
    reg [4:0]  opcode;
    reg [2:0]  funct3;
    reg [4:0]  funct5;
    reg [6:0]  funct7;
    reg [4:0]  rs1index, rs2index, rdindex;
    reg [11:0] csr_index;
    reg [19:0] imm20, imm20j;
    reg [11:0] imm12i,  imm12s;             //imm and store instruction use
    reg [12:0] imm12b;
//////////////////////////////////////////////////////
//                 execute an instruction           //
//////////////////////////////////////////////////////
task instr_exec();
begin
    read_word(pc, instr);       //read an instruction word
    pc_commited = pc;
    //---------------decode-----------------------
    opcode =    instr[6:2];
    rs1index=   instr[19:15];
    rs2index=   instr[24:20];
    rdindex =   instr[11:7];
    csr_index=  instr[31:20];
    funct3 =    instr[14:12];
    funct5 =    instr[31:27];
    funct7 =    instr[31:25];
    imm20  =    instr[31:12];
    imm20j =    {instr[31],instr[19:12],instr[20],instr[30:21]}; //jalr指令使用的20位立即数
    imm12i =    instr[31:20];
    imm12s =    {instr[31:25],instr[11:7]};
    imm12b =    {instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
    //-------------根据opcode选择指令怎么执行----------
    if(trap&async&status_mie & mie[trap_cause])begin  //virtual rv收到一条trap，判定是否进入trap
        trap_capture();
    end else begin
        case(opcode)
            `OPCODE_OPIMM,`OPCODE_OPIMM32,`OPCODE_LUI,`OPCODE_OP,`OPCODE_OP32:
            begin
                int_calculate();
                pc = pc+4;      //move to the next instruction
            end
            `OPCODE_AUIPC, `OPCODE_BRANCH, `OPCODE_JAL, `OPCODE_JALR:
            begin
                branch_calculate(); //branch calculate will automatic move pc to the next instruction
            end
            `OPCODE_LOAD:
            begin
                load_task();
                pc = pc + 4;
            end
            `OPCODE_STORE:
            begin
                store_task();
                pc = pc+4;
            end
            `OPCODE_SYSTEM:
            begin
                system_task();
            end
            5'h1a:begin
                $display("a0(r10)=0x%h",ireg[10]);
                $display("INFO: 0x6b opcode detected, escape simulation.");
                $stop();
            end
            default:
            begin
                $display("ERR:unknown opcode=0x%h at pc=0x%h",opcode, pc);
                $finish(1);
            end
        endcase
    end
    ireg[0] = 0;    //clear reg 0
end
endtask
//////////////////////////////////////////////////////
//                int calculate task                //
//////////////////////////////////////////////////////
task int_calculate();
    reg[XLEN-1:0] opdata1, opdata2, opfin;
begin
    case(opcode)
        `OPCODE_LUI:
        begin
            opdata1 = {{32{imm20[19]}},imm20,12'b0};
        end
        `OPCODE_OP,`OPCODE_OP32:            //TODO: 可能32位处理有问题，之后要弄
        begin
            opdata1 = ireg[rs1index];       //0寄存器始终保持0
            opdata2 = ireg[rs2index];
        end
        `OPCODE_OPIMM,`OPCODE_OPIMM32:
        begin
            opdata1 = ireg[rs1index];
            opdata2 = {{52{imm12i[11]}},imm12i};
        end
    endcase
    case(opcode)
        `OPCODE_LUI: opfin = opdata1;
        `OPCODE_OPIMM, `OPCODE_OPIMM32:begin
            case(funct3)
                `FUNCT3_ADD: begin opfin = opdata1 + opdata2;end
                `FUNCT3_SLL: begin opfin = opdata1 << opdata2[5:0];end
                `FUNCT3_SRLA:begin opfin = opdata1 >> opdata2[5:0];end
                `FUNCT3_SLT: begin opfin = ($signed(opdata1) < $signed(opdata2)); end
                `FUNCT3_SLTU:begin opfin = (opdata1 < opdata2);                   end
                `FUNCT3_XOR: begin opfin = opdata1 ^ opdata2;                     end
                `FUNCT3_OR:  begin opfin = opdata1 | opdata2;                     end
                `FUNCT3_AND: begin opfin = opdata1 & opdata2;                     end
                default:begin $display("ERR:unknow funct3=0x%h at pc=0x%h",funct3 ,pc); $finish(); end
            endcase
        end
        `OPCODE_OP, `OPCODE_OP32:begin
            case(funct3)
                `FUNCT3_ADD:
                begin
                    if(funct7==7'b0100000)begin
                        opfin = opdata1 - opdata2;
                    end
                    else begin
                        opfin = opdata1 + opdata2;
                    end
                end
                `FUNCT3_SLL:
                begin
                    opfin = opdata1 << opdata2[5:0];
                end
                `FUNCT3_SRLA:
                begin
                    if(funct7[5])begin
                        opfin = opdata1 >>> opdata2[5:0];
                    end
                    else begin
                        opfin = opdata1 >> opdata2[5:0];
                    end
                end
                `FUNCT3_SLT: begin opfin = ($signed(opdata1) < $signed(opdata2)); end
                `FUNCT3_SLTU:begin opfin = (opdata1 < opdata2);                   end
                `FUNCT3_XOR: begin opfin = opdata1 ^ opdata2;                     end
                `FUNCT3_OR:  begin opfin = opdata1 | opdata2;                     end
                `FUNCT3_AND: begin opfin = opdata1 & opdata2;                     end
                default:begin $display("ERR:unknow funct3=0x%h at pc=0x%h",funct3 ,pc); $finish(); end
            endcase
        end 
        default:begin $display("ERR:unknow opcode=0x%h at pc=0x%h",opcode ,pc); $finish(); end
    endcase
    case(opcode)
        `OPCODE_OP32, `OPCODE_OPIMM32 : ireg[rdindex] = {{32{opfin[31]}},opfin[31:0]};
        default : ireg[rdindex] = opfin;
    endcase
end
endtask
//////////////////////////////////////////////////////
//                 branch instruction               //
//////////////////////////////////////////////////////
task branch_calculate();
    reg [XLEN-1:0] opdata1, opdata2;
    reg [XLEN-1:0] temp;
begin
    opdata1 = ireg[rs1index];
    opdata2 = ireg[rs2index];
    case(opcode)
        `OPCODE_AUIPC:
        begin
            ireg[rdindex] = pc + {{32{imm20[19]}},imm20,12'b0};
            pc = pc+4;
        end
        `OPCODE_BRANCH:
        begin
            case(funct3)
                `FUNCT3_BEQ : pc = (opdata1 == opdata2) ? (pc+{{51{imm12b[12]}},imm12b})                :(pc+4);
                `FUNCT3_BNE : pc = (opdata1 != opdata2) ? (pc+{{51{imm12b[12]}},imm12b})                :(pc+4);
                `FUNCT3_BGE : pc = $signed(opdata1) >= $signed(opdata2) ? (pc+{{51{imm12b[12]}},imm12b}):(pc+4);
                `FUNCT3_BGEU: pc = (opdata1 >= opdata2) ? (pc+{{51{imm12b[12]}},imm12b})                :(pc+4);
                `FUNCT3_BLT : pc = $signed(opdata1) <= $signed(opdata2) ? (pc+{{51{imm12b[12]}},imm12b}):(pc+4);
                `FUNCT3_BLTU: pc = (opdata1 <= opdata2) ? (pc+{{51{imm12b[12]}},imm12b})                :(pc+4);
                default:begin $display("ERR:unknown funct3 in branch instruction at pc=0x%h",pc); $finish(1); end
            endcase
        end
        `OPCODE_JAL:
        begin
            ireg[rdindex] = pc+4;
            pc            = pc + {{43{imm20j[19]}},imm20j,1'b0};
        end
        `OPCODE_JALR:
        begin
            temp = pc+4;
            pc            = {{52{imm12i[11]}},imm12i}+ireg[rs1index];   //当rs1=rdindex时，如果没有temp寄存器，会引起值错误
            ireg[rdindex] = temp;
        end
    endcase
end
endtask
//////////////////////////////////////////////////////
//                system instruction task           //
//////////////////////////////////////////////////////
task system_task();
    reg [XLEN-1:0] write, read;
begin
    case(funct3)
        `FUNCT3_CSRRW :begin 
            write = ireg[rs1index];
            csr_operation(2'b00, csr_index, write, read);
            ireg[rdindex]= read;
            pc=pc+4;
        end
        `FUNCT3_CSRRS :begin
            write = ireg[rs1index];
            csr_operation(2'b01, csr_index, write, read);
            ireg[rdindex]= read;
            pc=pc+4;
        end
        `FUNCT3_CSRRC :begin
            write = ireg[rs1index];
            csr_operation(2'b10, csr_index, write, read);
            ireg[rdindex]= read;
            pc=pc+4;
        end
        `FUNCT3_CSRRWI:begin
            write = {59'b0,rs1index};
            csr_operation(2'b00, csr_index, write, read);
            ireg[rdindex]= read;
            pc=pc+4;
        end
        `FUNCT3_CSRRSI:begin
            write = {59'b0,rs1index};
            csr_operation(2'b01, csr_index, write, read);
            ireg[rdindex]= read;
            pc=pc+4;
        end
        `FUNCT3_CSRRCI:begin
            write = {59'b0,rs1index};
            csr_operation(2'b10, csr_index, write, read);
            ireg[rdindex]= read;
            pc=pc+4;
        end
        `FUNCT3_PRIV:begin
            if(csr_index==12'b001100000010)begin    //MRET instruction
                status_mie = status_mpie;
                status_mpie= 0;
                status_priv= status_mpp;
                status_mpp = 0;
                pc = mepc;
                mepc=0;
            end else begin
                $display("ERR: unsupport funct12 in system instruction.");//TODO: ECALL EBREAK指令
                $finish();
            end
        end
        default:begin
            $display("ERR: unsupport funct3 in system instruction.");
            $finish();
        end
    endcase
end
endtask
//////////////////////////////////////////////////////
//                csr operation                     //
//////////////////////////////////////////////////////
task csr_operation(
    input [1:0]      operation, //00=write 01=set 10=clear
    input [11:0]     index,
    input [XLEN-1:0] data,      //data write
    output[XLEN-1:0] rdata      //data read
);
begin
    case(index)
        `MRW_MSTATUS_INDEX:begin
            rdata = {status_sd,25'b0,1'b0,1'b0,status_sxl,status_uxl,9'b0,status_tsr,status_tw,status_tvm,status_mxr,status_sum,status_mpriv,2'b0,status_fs,status_mpp,2'b00,status_spp,status_mpie,1'b0,status_spie,1'b0,status_mie,1'b0,status_sie,1'b0};
            status_sxl  = (operation==2'b00)?data[35:34]:          (operation==2'b01)?(status_sxl|data[35:34])          :(operation==2'b10)?(status_sxl&(!data[35:34])):status_sxl;
            status_uxl  = (operation==2'b00)?data[33:32]:          (operation==2'b01)?(status_uxl|data[33:32])          :(operation==2'b10)?(status_uxl&(!data[33:32])):status_uxl;
            status_tsr  = (operation==2'b00)?data[`STATUS_BIT_TSR]:(operation==2'b01)?(status_tsr|data[`STATUS_BIT_TSR]):(operation==2'b10)?(status_tsr&(!data[`STATUS_BIT_TSR])):status_tsr;
            status_tw   = (operation==2'b00)?data[`STATUS_BIT_TW] :(operation==2'b01)?(status_tw|data[`STATUS_BIT_TW])  :(operation==2'b10)?(status_tw&(!data[`STATUS_BIT_TW])):status_tw;
            status_tvm  = (operation==2'b00)?data[`STATUS_BIT_TVM]:(operation==2'b01)?(status_tvm|data[`STATUS_BIT_TVM]):(operation==2'b10)?(status_tvm&(!data[`STATUS_BIT_TVM])):status_tvm;
            status_mxr  = (operation==2'b00)?data[`STATUS_BIT_MXR]:(operation==2'b01)?(status_mxr|data[`STATUS_BIT_MXR]):(operation==2'b10)?(status_mxr&(!data[`STATUS_BIT_MXR])):status_mxr;
            status_sum  = (operation==2'b00)?data[`STATUS_BIT_SUM]:(operation==2'b01)?(status_sum|data[`STATUS_BIT_SUM]):(operation==2'b10)?(status_sum&(!data[`STATUS_BIT_SUM])):status_sum;
            status_mpriv= (operation==2'b00)?data[17]             :(operation==2'b01)?(status_mpriv|data[17])           :(operation==2'b10)?(status_mpriv&(!data[17])):status_mpriv;
            status_mpp  = (operation==2'b00)?data[`STATUS_BIT_MPP_HI:`STATUS_BIT_MPP_LO]:(operation==2'b01)?(status_mpp|data[`STATUS_BIT_MPP_HI:`STATUS_BIT_MPP_LO]):(operation==2'b10)?(status_mpp&(!data[`STATUS_BIT_MPP_HI:`STATUS_BIT_MPP_LO])):status_mpp;
            status_spp  = (operation==2'b00)?data[`STATUS_BIT_SPP] :(operation==2'b01)?(status_spp|data[`STATUS_BIT_SPP]):(operation==2'b10)?(status_mpp&(!data[`STATUS_BIT_SPP])):status_mpp;
            status_mpie = (operation==2'b00)?data[`STATUS_BIT_MPIE]:(operation==2'b01)?(status_mpie|data[`STATUS_BIT_MPIE]):(operation==2'b10)?(status_mpie&(!data[`STATUS_BIT_MPIE])):status_mpie;
            status_spie = (operation==2'b00)?data[`STATUS_BIT_SPIE]:(operation==2'b01)?(status_spie|data[`STATUS_BIT_SPIE]):(operation==2'b10)?(status_spie&(!data[`STATUS_BIT_SPIE])):status_spie;
            status_mie  = (operation==2'b00)?data[`STATUS_BIT_MIE] :(operation==2'b01)?(status_mie|data[`STATUS_BIT_MIE]):(operation==2'b10)?(status_mie&(!data[`STATUS_BIT_MIE])):status_mie;
            status_sie  = (operation==2'b00)?data[`STATUS_BIT_SIE] :(operation==2'b01)?(status_sie|data[`STATUS_BIT_SIE]):(operation==2'b10)?(status_sie&(!data[`STATUS_BIT_SIE])):status_sie;
        end
        `MRW_MIE_INDEX:begin
            rdata = mie;
            mie = (operation==2'b00)?data:(operation==2'b01)?(mie|data):(operation==2'b10)?(mie&(!data)):mie;
        end
        `MRW_MTVEC_INDEX:begin
            rdata = mtvec;
            mtvec = (operation==2'b00)?data:(operation==2'b01)?(mtvec|data):(operation==2'b10)?(mtvec&(!data)):mtvec;
        end
        `MRW_MTVAL_INDEX:begin
            rdata = mtval;
            mtval = (operation==2'b00)?data:(operation==2'b01)?(mtval|data):(operation==2'b10)?(mtval&(!data)):mtval;
        end
        `MRW_MCAUSE_INDEX:begin
            rdata = mcause;
            mcause = (operation==2'b00)?data:(operation==2'b01)?(mcause|data):(operation==2'b10)?(mcause&(!data)):mcause;
        end
        `MRW_MEPC_INDEX:begin
            rdata = mepc;
            mepc = (operation==2'b00)?data:(operation==2'b01)?(mepc|data):(operation==2'b10)?(mepc&(!data)):mepc;
        end
        `MRW_MSCRATCH_INDEX:begin
            rdata = mscratch;
            mscratch = (operation==2'b00)?data:(operation==2'b01)?(mscratch|data):(operation==2'b10)?(mscratch&(!data)):mscratch;
        end
        default:begin
            $display("ERR: Unsupport csr is been read/write!");
            $finish();
        end
    endcase
end
endtask
//////////////////////////////////////////////////////
//                store instruction                 //
//////////////////////////////////////////////////////
task store_task();
    reg [XLEN-1:0] store_addr, store_data;
begin
    store_addr = ireg[rs1index] + {{52{imm12s[11]}},imm12s};
    store_data = ireg[rs2index];
    case(funct3)
        `FUNCT3_8bit:
        begin
            store_byte(store_addr+0, store_data[7:0]);
        end
        `FUNCT3_16bit:
        begin
            store_byte(store_addr+0, store_data[7:0]);
            store_byte(store_addr+1, store_data[15:8]);
        end
        `FUNCT3_32bit:
        begin
            store_byte(store_addr+0, store_data[7:0]);
            store_byte(store_addr+1, store_data[15:8]);
            store_byte(store_addr+2, store_data[23:16]);
            store_byte(store_addr+3, store_data[31:24]);
        end
        `FUNCT3_64bit:
        begin
            store_byte(store_addr+0, store_data[7:0]);
            store_byte(store_addr+1, store_data[15:8]);
            store_byte(store_addr+2, store_data[23:16]);
            store_byte(store_addr+3, store_data[31:24]);
            store_byte(store_addr+4, store_data[39:32]);
            store_byte(store_addr+5, store_data[47:40]);
            store_byte(store_addr+6, store_data[55:48]);
            store_byte(store_addr+7, store_data[63:56]);
        end
    endcase
end
endtask
//////////////////////////////////////////////////////
//                load instruction                  //
//////////////////////////////////////////////////////
task load_task();
    reg [XLEN-1:0] load_data, load_addr;
begin
    load_addr = ireg[rs1index] + {{52{imm12i[11]}},imm12i};
    read_dword(load_addr, load_data);                       //LOAD指令先读64位值，之后进行处理
    case(funct3)
        `FUNCT3_8bit:     ireg[rdindex] = {{56{load_data[7]}},  load_data[7:0]};
        `FUNCT3_8bitU:    ireg[rdindex] = {56'b0,               load_data[7:0]};
        `FUNCT3_16bit:    ireg[rdindex] = {{48{load_data[15]}}, load_data[15:0]};
        `FUNCT3_16bitU:   ireg[rdindex] = {48'b0,               load_data[15:0]};
        `FUNCT3_32bit:    ireg[rdindex] = {{32{load_data[31]}}, load_data[31:0]};
        `FUNCT3_32bitU:   ireg[rdindex] = {32'b0,               load_data[31:0]};
        `FUNCT3_64bit:    ireg[rdindex] = load_data;
        default:begin $display("ERR:unknown funct3 in load instruction at pc=0x%h",pc); $finish(1); end
    endcase
end
endtask
//////////////////////////////////////////////////////
//                 read d-word from memory          //
//////////////////////////////////////////////////////
task read_dword(
    input [XLEN-1:0] addr,
    output[63:0]     data
);

begin
    read_byte(addr, data[7:0]);
    read_byte(addr+1, data[15:8]);
    read_byte(addr+2, data[23:16]);
    read_byte(addr+3, data[31:24]);
    read_byte(addr+4, data[39:32]);
    read_byte(addr+5, data[47:40]);
    read_byte(addr+6, data[55:48]);
    read_byte(addr+7, data[63:56]);
end
endtask
//////////////////////////////////////////////////////
//                 read word from memory            //
//////////////////////////////////////////////////////
task read_word(
    input [XLEN-1:0] addr,
    output[31:0]     data
);
begin    
    read_byte(addr, data[7:0]);
    read_byte(addr+1, data[15:8]);
    read_byte(addr+2, data[23:16]);
    read_byte(addr+3, data[31:24]);
end
endtask
/////////////////////////////////////////////////////
//                read byte from memory            //
/////////////////////////////////////////////////////
task automatic read_byte(
    input [XLEN-1:0] addr,
    output[7:0]      data
);
begin
    if(addr>=RAM_ADDR_BASE)begin
        data[7:0] = ram[addr-RAM_ADDR_BASE];
    end
    else begin
        $display("virtual rv INFO:MMIO space read");
        $display("                access address = 0x%h",addr);
        data[7:0] = mmio[addr];
    end
end
endtask
////////////////////////////////////////////////////
//             store byte to memory               //
////////////////////////////////////////////////////
task automatic store_byte(
    input [XLEN-1:0] addr,
    input [7:0]      data
);
begin
    if(addr>=RAM_ADDR_BASE)begin
        ram[addr-RAM_ADDR_BASE] = data;
    end
    else begin
        $display("virtual rv INFO:MMIO space write");
        $display("                access address = 0x%h, data=0x%h",addr, data);
        mmio[addr] = data;
    end
end
endtask
/////////////////////////////////////////////////////
//               trap处理task                       //
/////////////////////////////////////////////////////
task trap_capture();
begin
    mepc = pc;
    status_mpie=status_mie;
    status_mie=0;
    status_mpp=status_priv;
    pc = (mtvec[1:0]==0) ? {mtvec[XLEN-1:2],2'b00} : {{mtvec[XLEN-1:2],2'b00}+(trap_cause*4)};    //向量模式跳转 or 非向量模式跳转
    if(async)begin
        case(trap_cause)
            `CAUSE_MSI: mtval = 0;
            `CAUSE_MTI: mtval = 0;
            `CAUSE_MEI: mtval = 0;
        endcase
    end
    else begin
        case(trap_cause)
            `CAUSE_MSI: mtval = 0;
            `CAUSE_MTI: mtval = 0;
            `CAUSE_MEI: mtval = 0;
        endcase
    end
end
endtask














endmodule