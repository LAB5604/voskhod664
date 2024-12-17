/**********************************************************************************************

   Copyright (c) [2022] [JackPan, XiaoyuHong, KuiSun]
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
                                                                             
    Desc    : simple apb bus mux
    Author  : JackPan
    Date    : 2023/3/17
    Version : 0.0 (file initialize)


***********************************************************************************************/
module apb_busmux#(
    parameter DWID = 8,     //databus width
              AWID = 32,    //addressbus width
              SLV0_START_ADDR= 'h0000,
              SLV0_END_ADDR =  'h0FFF,
              SLV1_START_ADDR= 'h1000,
              SLV1_END_ADDR =  'h1FFF,
              SLV2_START_ADDR= 'h2000,
              SLV2_END_ADDR =  'h2FFF,
              SLV3_START_ADDR= 'h3000,
              SLV3_END_ADDR =  'h3FFF,
              SLV4_START_ADDR= 'h4000,
              SLV4_END_ADDR =  'h4FFF,
              SLV5_START_ADDR= 'h5000,
              SLV5_END_ADDR =  'h5FFF,
              SLV6_START_ADDR= 'h6000,
              SLV6_END_ADDR =  'h6FFF,
              SLV7_START_ADDR= 'h8000,
              SLV7_END_ADDR =  'hAFFF,
              NULL_START_ADDR = 'hB000,          //from slave7 end to 32bit end always is null device, ack ready with no error
              NULL_END_ADDR   = 'hFFFFFFFF
)(
    input wire              slv_psel, slv_penable, slv_pwrite,
    input wire [DWID-1:0]   slv_pwdata,
    input wire [AWID-1:0]   slv_paddr,
    output wire             slv_pready, slv_pslverr,
    output wire[DWID-1:0]   slv_prdata,
    //---------slave0--------------
    output wire             mst0_psel, mst0_penable, mst0_pwrite,
    output wire [DWID-1:0]  mst0_pwdata,
    output wire [AWID-1:0]  mst0_paddr,
    input wire              mst0_pready, mst0_pslverr,
    input wire [DWID-1:0]   mst0_prdata,
    //---------slave1--------------
    output wire             mst1_psel, mst1_penable, mst1_pwrite,
    output wire [DWID-1:0]  mst1_pwdata,
    output wire [AWID-1:0]  mst1_paddr,
    input wire              mst1_pready, mst1_pslverr,
    input wire [DWID-1:0]   mst1_prdata,
    //---------slave2--------------
    output wire             mst2_psel, mst2_penable, mst2_pwrite,
    output wire [DWID-1:0]  mst2_pwdata,
    output wire [AWID-1:0]  mst2_paddr,
    input wire              mst2_pready, mst2_pslverr,
    input wire [DWID-1:0]   mst2_prdata,
    //---------slave3--------------
    output wire             mst3_psel, mst3_penable, mst3_pwrite,
    output wire [DWID-1:0]  mst3_pwdata,
    output wire [AWID-1:0]  mst3_paddr,
    input wire              mst3_pready, mst3_pslverr,
    input wire [DWID-1:0]   mst3_prdata,
    //---------slave4--------------
    output wire             mst4_psel, mst4_penable, mst4_pwrite,
    output wire [DWID-1:0]  mst4_pwdata,
    output wire [AWID-1:0]  mst4_paddr,
    input wire              mst4_pready, mst4_pslverr,
    input wire [DWID-1:0]   mst4_prdata,
    //---------slave5--------------
    output wire             mst5_psel, mst5_penable, mst5_pwrite,
    output wire [DWID-1:0]  mst5_pwdata,
    output wire [AWID-1:0]  mst5_paddr,
    input wire              mst5_pready, mst5_pslverr,
    input wire [DWID-1:0]   mst5_prdata,
    //---------slave6--------------
    output wire             mst6_psel, mst6_penable, mst6_pwrite,
    output wire [DWID-1:0]  mst6_pwdata,
    output wire [AWID-1:0]  mst6_paddr,
    input wire              mst6_pready, mst6_pslverr,
    input wire [DWID-1:0]   mst6_prdata,
    //---------slave7--------------
    output wire             mst7_psel, mst7_penable, mst7_pwrite,
    output wire [DWID-1:0]  mst7_pwdata,
    output wire [AWID-1:0]  mst7_paddr,
    input wire              mst7_pready, mst7_pslverr,
    input wire [DWID-1:0]   mst7_prdata
);

wire nullslv_sel, nullslv_enable;
assign nullslv_sel = slv_psel & (!(mst0_psel|mst1_psel|mst2_psel|mst3_psel|mst4_psel|mst5_psel|mst6_psel|mst7_psel));   //if none of these slave is selected, null device is selected 
assign nullslv_enable= nullslv_sel & slv_penable;

assign mst0_psel = slv_psel & (slv_paddr >= SLV0_START_ADDR) & (slv_paddr <= SLV0_END_ADDR);
assign mst1_psel = slv_psel & (slv_paddr >= SLV1_START_ADDR) & (slv_paddr <= SLV1_END_ADDR);
assign mst2_psel = slv_psel & (slv_paddr >= SLV2_START_ADDR) & (slv_paddr <= SLV2_END_ADDR);
assign mst3_psel = slv_psel & (slv_paddr >= SLV3_START_ADDR) & (slv_paddr <= SLV3_END_ADDR);
assign mst4_psel = slv_psel & (slv_paddr >= SLV4_START_ADDR) & (slv_paddr <= SLV4_END_ADDR);
assign mst5_psel = slv_psel & (slv_paddr >= SLV5_START_ADDR) & (slv_paddr <= SLV5_END_ADDR);
assign mst6_psel = slv_psel & (slv_paddr >= SLV6_START_ADDR) & (slv_paddr <= SLV6_END_ADDR);
assign mst7_psel = slv_psel & (slv_paddr >= SLV7_START_ADDR) & (slv_paddr <= SLV7_END_ADDR);

assign mst0_penable = mst0_psel & slv_penable;
assign mst1_penable = mst1_psel & slv_penable;
assign mst2_penable = mst2_psel & slv_penable;
assign mst3_penable = mst3_psel & slv_penable;
assign mst4_penable = mst4_psel & slv_penable;
assign mst5_penable = mst5_psel & slv_penable;
assign mst6_penable = mst6_psel & slv_penable;
assign mst7_penable = mst7_psel & slv_penable;

assign mst0_pwrite = mst0_psel & slv_pwrite;
assign mst1_pwrite = mst1_psel & slv_pwrite;
assign mst2_pwrite = mst2_psel & slv_pwrite;
assign mst3_pwrite = mst3_psel & slv_pwrite;
assign mst4_pwrite = mst4_psel & slv_pwrite;
assign mst5_pwrite = mst5_psel & slv_pwrite;
assign mst6_pwrite = mst6_psel & slv_pwrite;
assign mst7_pwrite = mst7_psel & slv_pwrite;

assign mst0_pwdata = slv_pwdata;
assign mst1_pwdata = slv_pwdata;
assign mst2_pwdata = slv_pwdata;
assign mst3_pwdata = slv_pwdata;
assign mst4_pwdata = slv_pwdata;
assign mst5_pwdata = slv_pwdata;
assign mst6_pwdata = slv_pwdata;
assign mst7_pwdata = slv_pwdata;

assign mst0_paddr = slv_paddr;
assign mst1_paddr = slv_paddr;
assign mst2_paddr = slv_paddr;
assign mst3_paddr = slv_paddr;
assign mst4_paddr = slv_paddr;
assign mst5_paddr = slv_paddr;
assign mst6_paddr = slv_paddr;
assign mst7_paddr = slv_paddr;

assign slv_pready = (mst0_psel&mst0_pready)|(mst1_psel&mst1_pready)|(mst2_psel&mst2_pready)|(mst3_psel&mst3_pready)|
                    (mst4_psel&mst4_pready)|(mst5_psel&mst5_pready)|(mst6_psel&mst6_pready)|(mst7_psel&mst7_pready)|nullslv_enable;
assign slv_pslverr= (mst0_psel&mst0_pslverr)|(mst1_psel&mst1_pslverr)|(mst2_psel&mst2_pslverr)|(mst3_psel&mst3_pslverr)|
                    (mst4_psel&mst4_pslverr)|(mst5_psel&mst5_pslverr)|(mst6_psel&mst6_pslverr)|(mst7_psel&mst7_pslverr);
assign slv_prdata = (mst0_psel?mst0_prdata:0)|
                    (mst1_psel?mst1_prdata:0)|
                    (mst2_psel?mst2_prdata:0)|
                    (mst3_psel?mst3_prdata:0)|
                    (mst4_psel?mst4_prdata:0)|
                    (mst5_psel?mst5_prdata:0)|
                    (mst6_psel?mst6_prdata:0)|
                    (mst7_psel?mst7_prdata:0);

endmodule