`include"prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
/**********************************************************************************************

   Copyright (c) [2022] [JackPan, XiaoyuHong, KuiSun]
   [Software Name] is licensed under Mulan PSL v2.
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
                                                                             
    Desc    : PRV664(voskhod664) system manage unit for prv664
    Author  : Jack.Pan
    Date    : 2023/3/18
    Version : 1.0 (latch bug fix)

***********************************************************************************************/
module sysmanage(
    input wire                      clk_i, arst_i,
    pip_flush_interface.slave       flush_slave,
    pip_exu_interface.sysmanage_sif sysmag_sif,
    pip_wb_interface.master         sysmag_mif,
    //----------to sys manage bus--------
    output logic                    icache_flush_req, dcache_flush_req, immu_flush_req, dmmu_flush_req,
    input  wire                     icache_flush_ack, dcache_flush_ack, immu_flush_ack, dmmu_flush_ack
);
localparam  STD     = 'h0,      //stand by状态，等待新的访问
            STAGE1  ='h1,       //运行fence、fencei、fencevma指令第一阶段
            STAGE2  ='h2,       //运行第二阶段
            WFACK   ='h4,       //等待发出的指令收到回执
            WWB     ='h5;       //等待指令写回
/***************************************************************************************************


****************************************************************************************************/
//------------------------from uop buffer--------------------
    logic [4:0]         opcode;
    logic [2:0]         funct3;          
    logic [6:0]         funct7;
    logic [7:0]         itag;
    logic               ren;
    logic               empty;
//------------------------ack signal--------------------------
    logic               ack;
//-----------------------uop buffer---------------------
fifo1r1w#(
    .DWID           (5+7+3+8),
    .DDEPTH         (4)
)lsu_uop_buffer(
    .clk            (clk_i),
    .rst            (arst_i | flush_slave.flush),
    .ren            (ren),
    .wen            (sysmag_sif.valid),
    .wdata          ({
                        sysmag_sif.opcode,
                        sysmag_sif.funct,
                        sysmag_sif.itag
                    }),
    .rdata          ({
                        opcode,
                        funct7,
                        funct3,
                        itag
                    }),
    .full           (sysmag_sif.full),
    .empty          (empty)
);

reg [3:0] state;

always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        state <= STD;
    end
    else begin
        case(state)
            STD :
            begin
                if(!empty)begin
                    case(opcode)
                        `OPCODE_SYSTEM, `OPCODE_MISCMEM: state <= STAGE1;
                        default : state <= WWB;
                    endcase
                end
            end
            STAGE1 : state <= ack ? STAGE2 : state;
            STAGE2 : state <= ack ? WWB    : state;
            WWB : state <= sysmag_mif.ready ? STD : state;
            default : state <= STD;
        endcase
    end
end
//----------------------------------存储子系统刷新请求------------------------------
always_comb begin
    case(state)
        STAGE1:
        begin
            case(opcode)
                `OPCODE_MISCMEM: 
                begin
                    case(funct3)
                        `FUNCT3_FENCE,`FUNCT3_FENCEI:
                        begin
                            icache_flush_req= 1'b0;
                            dcache_flush_req= 1'b1;     //刷新dcache
                            immu_flush_req  = 1'b0;
                            dmmu_flush_req  = 1'b0;
                            ack             = dcache_flush_ack;
                        end
                        default :
                        begin
                            icache_flush_req= 1'b0;
                            dcache_flush_req= 1'b0;
                            immu_flush_req  = 1'b0;
                            dmmu_flush_req  = 1'b0;
                            ack             = 1'b1;
                        end
                    endcase
                end
                `OPCODE_SYSTEM:
                begin
                    if((funct3==`FUNCT3_PRIV)&(funct7==7'b0001001))begin
                        icache_flush_req= 1'b0;
                        dcache_flush_req= 1'b1;
                        immu_flush_req  = 1'b0;
                        dmmu_flush_req  = 1'b0;
                        ack             = dcache_flush_ack;
                    end
                    else begin
                        icache_flush_req= 1'b0;
                        dcache_flush_req= 1'b0;
                        immu_flush_req  = 1'b0;
                        dmmu_flush_req  = 1'b0;
                        ack             = 1'b1;
                    end
                end
            default:
            begin
                icache_flush_req= 1'b0;
                dcache_flush_req= 1'b0;
                immu_flush_req  = 1'b0;
                dmmu_flush_req  = 1'b0;
                ack             = 1'b1;
            end
            endcase
        end
        STAGE2:
        begin
            case(opcode)
                `OPCODE_MISCMEM: 
                begin
                    case(funct3)
                        `FUNCT3_FENCEI:
                        begin
                            icache_flush_req= 1'b1;
                            dcache_flush_req= 1'b0;     //刷新dcache，第二阶段刷新icache
                            immu_flush_req  = 1'b0;
                            dmmu_flush_req  = 1'b0;
                            ack             = icache_flush_ack;
                        end
                        default :
                        begin
                            icache_flush_req= 1'b0;
                            dcache_flush_req= 1'b0;
                            immu_flush_req  = 1'b0;
                            dmmu_flush_req  = 1'b0;
                            ack             = 1'b1;
                        end
                    endcase
                end
                `OPCODE_SYSTEM:
                begin
                    if((funct3==`FUNCT3_PRIV)&(funct7==7'b0001001))begin
                        icache_flush_req= 1'b0;
                        dcache_flush_req= 1'b0;
                        immu_flush_req  = 1'b1;
                        dmmu_flush_req  = 1'b1;
                        ack             = immu_flush_ack | dmmu_flush_ack;
                    end
                    else begin
                        icache_flush_req= 1'b0;
                        dcache_flush_req= 1'b0;
                        immu_flush_req  = 1'b0;
                        dmmu_flush_req  = 1'b0;
                        ack             = 1'b1;
                    end
                end
            default:
            begin
                icache_flush_req= 1'b0;
                dcache_flush_req= 1'b0;
                immu_flush_req  = 1'b0;
                dmmu_flush_req  = 1'b0;
                ack             = 1'b1;
            end
            endcase
        end
        default:
        begin
            icache_flush_req= 1'b0;
            dcache_flush_req= 1'b0;
            immu_flush_req  = 1'b0;
            dmmu_flush_req  = 1'b0;
            ack             = 1'b1;
        end
    endcase
end
//-------------------产生写回的信号&uop fifo读使能信号---------------------
always_comb begin
    sysmag_mif.valid = (state==WWB);
    sysmag_mif.itag  = itag;
    ren              = (state==WWB) & sysmag_mif.ready;
end
endmodule