`include "prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
/******************************************************************************************

   Copyright (c) [2024] [JackPan]
   [prv664] is licensed under Mulan PSL v2.
   You can use this software according to the terms and conditions of the Mulan PSL v2. 
   You may obtain a copy of Mulan PSL v2 at:
            http://license.coscl.org.cn/MulanPSL2 
   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.  
   See the Mulan PSL v2 for more details.  

____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 

    DESC： prv664 branch unit module
    Author: Jack Pan
    Date: 20240301
    Version:2.0       Fixed blt bug 

    Change log:
        Version1.0 20220830 : File initial
        Version2.0 20240301 : Bug ib blt fixed, blt: less bot NOT equal!

******************************************************************************************/
module bru(

    input clk_i,
    input arst_i,

    pip_flush_interface.slave flush_slave,

    pip_exu_interface.bru_sif bru_sif,          //branch unit slave interface
    
    pip_wb_interface.master   bru_mif

);
    logic [`XLEN-1:0]   offset;                 //offset address
//--------------------uop buffer output---------------
    logic               empty;
    logic               ren;
    logic [`XLEN-1:0]   data1, data2, pc;
    logic [19:0]        imm20;
    logic [4:0]         opcode;
    logic [9:0]         funct;
    logic [7:0]         itag;
//--------------------to output FF---------------------
    logic               jump;
    logic               valid;
    logic [`XLEN-1:0]   branchaddr;
    logic [`XLEN-1:0]   data;
//-------------------------------uop buffer------------------------------
fifo1r1w#(
    .DWID           (`XLEN+`XLEN+`XLEN+20+5+10+8),
    .DDEPTH         (`BRU_UOP_BUFFER_DEEPTH)
)bru_uop_buffer(
    .clk            (clk_i),
    .rst            (arst_i | flush_slave.flush),
    .ren            (ren),
    .wen            (bru_sif.valid),
    .wdata          ({
                        bru_sif.data1,
                        bru_sif.data2,
                        bru_sif.pc,
                        bru_sif.imm20,
                        bru_sif.opcode,
                        bru_sif.funct,
                        bru_sif.itag
                    }),
    .rdata          ({
                        data1,
                        data2,
                        pc,
                        imm20,
                        opcode,
                        funct,
                        itag
                    }),
    .full           (bru_sif.full),
    .empty          (empty)
);



always_comb begin
    
    case(opcode)
        `OPCODE_AUIPC: offset = {{32{imm20[19]}},imm20,12'b0};
        `OPCODE_JALR: offset = {{44{imm20[19]}},imm20[19:1],1'b0};
        default: offset = {{43{imm20[19]}},imm20,1'b0};     //符号位拓展到64, 并且左移一位
    endcase

    valid      = !empty;
    case(opcode)
        `OPCODE_AUIPC   :
        begin
            jump       = 0;
            branchaddr = 'hx;
            data       = pc + offset;
        end
        `OPCODE_BRANCH  :
        begin
            case(funct[2:0])
                `FUNCT3_BEQ : jump = (data1 == data2);
                `FUNCT3_BNE : jump = (data1 != data2);
                `FUNCT3_BGE : jump = $signed(data1) >= $signed(data2);
                `FUNCT3_BGEU: jump = (data1 >= data2);
                `FUNCT3_BLT : jump = $signed(data1) < $signed(data2);
                `FUNCT3_BLTU: jump = (data1 < data2);
                default     : jump = 1'b0;
            endcase

            branchaddr = pc + offset;
            data       = 'hx;
        end
        `OPCODE_JAL     :
        begin
            jump       = 1;
            branchaddr = pc + offset;
            data       = pc + 'h4;
        end
        `OPCODE_JALR    :
        begin
            jump       = 1;
            branchaddr = offset + data1;
            data       = pc + 'h4;
        end
        default         :
        begin
            jump       = 0;
            branchaddr = 'hx;
            data       = 'hx;
        end
    endcase
end
//------------------------buffer read enable------------------
assign ren = !(bru_mif.valid & !bru_mif.ready);
//-------------------------output FF--------------------------
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        bru_mif.valid <= 1'b0;      //reset to 0
    end
    else if(flush_slave.flush)begin
        bru_mif.valid <= 1'b0;
    end
    else begin
        case(bru_mif.valid)
            1: bru_mif.valid <= bru_mif.ready ? valid : bru_mif.valid;
            0: bru_mif.valid <= valid;
        default: bru_mif.valid <= 'bx;
        endcase
    end
end

always_ff @( posedge clk_i ) begin
    if(!(bru_mif.valid & !bru_mif.ready))begin      //if next stage is NOT need to hold 
        bru_mif.data        <= data;
        bru_mif.branchaddr  <= branchaddr;
        bru_mif.jump        <= jump;
        bru_mif.itag        <= itag;
    end
end

endmodule