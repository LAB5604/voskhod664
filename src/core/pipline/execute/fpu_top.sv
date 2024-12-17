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
                                                                             
    Desc    : PRV664(voskhod664) float point unit top file
    Author  : JackPan
    Date    : 2023/7/20
    Version : 0.0 initial version

***********************************************************************************************/
module fpu_top(
    input                           clk_i,
    input                           arst_i,
    pip_flush_interface.slave       flush_slave,
    //系统信息，包含fcsr信息
    sysinfo_interface.slave         sysinfo_slave,
    //access fgpr 
    fgpr_access_interface.slave     fgpr_access_slave,
    //from dpu to fpu
    pip_exu_interface.fpu_sif       fpu_sif,          //connect to decode interface

    pip_wb_interface.master   fpu_mif           //connect to wrtie back interface
);
endmodule