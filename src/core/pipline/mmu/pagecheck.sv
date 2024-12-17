`include "prv664_config.svh"
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
                                                                             
    Desc    : PRV664(voskhod664) page check unit
    Author  : JackPan
    Date    : 2022/11/22
    Version : 0.0 file initialize

***********************************************************************************************/
module pagecheck#(
    parameter INST = 0              //1:指令用 0=数据用
)(
    //-------------csr input--------------
    input wire          mxr, sum, 
    //-------------op input---------------
    input wire          valid,
    input wire [4:0]    opcode,
    input wire [1:0]    priv,
    input wire [9:0]    pte,
    input wire          va_check_err,   //虚拟地址范围越界，直接产生异常
    input wire          tlb_err,        //tlb异常
    //-------------error output-----------
    output logic        load_page_fault, store_page_fault, inst_page_fault
);

    logic load_check_err, store_check_err;  //操作检查
    logic priv_check_err;                                   //操作权限检查

always_comb begin
    //--------------------load和store检查--------------------------
    case(opcode)
        `OPCODE_LOAD:
        begin
            if((pte[`SV39_PTE_BIT_R] | pte[`SV39_PTE_BIT_X]&mxr)&pte[`SV39_PTE_BIT_A])begin
                load_check_err = 0;
            end
            else begin
                load_check_err = 1;
            end
        end
        default: load_check_err = 0;
    endcase
    case(opcode)
        `OPCODE_STORE, `OPCODE_AMO:
        begin
            if(pte[`SV39_PTE_BIT_W] & pte[`SV39_PTE_BIT_A] & !pte[`SV39_PTE_BIT_D])begin
                store_check_err = 0;
            end
            else begin
                store_check_err = 1;
            end
        end
        default: store_check_err = 0;
    endcase
    //-----------------------权限检查----------------------------------
    case(priv)
        `MACHINE : priv_check_err = 0;  //Machine模式下默认可以访问所有页面
        `SUPERVISIOR: 
        begin
            if(pte[`SV39_PTE_BIT_U]&sum | !pte[`SV39_PTE_BIT_U])begin
                priv_check_err = 0;     //User页面但是打开sum、或者不是user页面，访问可以进行
            end    
            else begin
                priv_check_err = 1;
            end
        end
        `USER :
        begin
            if(pte[`SV39_PTE_BIT_U])begin
                priv_check_err = 0;
            end
            else begin
                priv_check_err = 1;
            end
        end
        default: priv_check_err = 1;
    endcase
    //--------------------最终的检查信号------------------
    load_page_fault = valid & (opcode==`OPCODE_LOAD) & (tlb_err | va_check_err | priv_check_err | load_check_err);
    store_page_fault= valid & ((opcode==`OPCODE_STORE)|(opcode==`OPCODE_AMO)) & (tlb_err | va_check_err | priv_check_err | store_check_err);
end

endmodule