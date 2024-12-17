`include "riscv_define.svh"
`include "prv664_config.svh"
`include "prv664_define.svh"
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
                                                                             
    Desc    : PRV664(voskhod664) simple icache top file
    Author  : JackPan
    Date    : 2023/5/28
    Version : 0.0(file initialize)

    NOTE： 适用于664处理器的icache单元，支持在可缓存区域内的128位访问


***********************************************************************************************/
module icache_top#(
    parameter CACHE_INDEXADDR_SIZE = 7,
              CACHE_LINEADDR_SIZE  = 6      //DO NOT touch this parameter
)(
    input wire                      clk_i,
    input wire                      srst_i,
    //------------cpu manage interface-----------
    input wire                      cache_flush_req,
    output logic                    cache_flush_ack,
    //------------cpu pipline interface-----------
    cache_access_interface.slave    cache_access_if,
    cache_return_interface.master   cache_return_if,
    //------------axi interface-----------
    axi_ar.master                   cache_axi_ar,
    axi_r.slave                     cache_axi_r,
    axi_aw.master                   cache_axi_aw,
    axi_w.master                    cache_axi_w,
    axi_b.slave                     cache_axi_b
);
localparam CACHE_PADDR_SIZE = `PADDR,
           TAGADDR_SIZE = CACHE_PADDR_SIZE - CACHE_INDEXADDR_SIZE - CACHE_LINEADDR_SIZE,
           CACHE_LINE_NUM = 1<<CACHE_INDEXADDR_SIZE,   //Cache行数
           CACHERAM_DEEPTH = (1<<(CACHE_INDEXADDR_SIZE+CACHE_LINEADDR_SIZE)) / 16;//cacheram为16字节宽的sram，因此深度需要除以16
           
localparam STATE_STD = 'h0,         //wait for an access
           STATE_TAG = 'h1,         //read tag from memory / read data from memory
           STATE_WEN = 'h3,         //write data enable
           STATE_RELOAD = 'h4,      //reload cache
           STATE_REFERSH= 'h5,      //refersh cache
           STATE_AGAIN  = 'h6,
           STATE_SINGLE = 'h7;      //single cache access

    //-----------FSM-------------------------------------
    reg [3:0]   state;
    logic[3:0]  state_next;
    logic       valid_next;
    //------------access from command buffer--------------
    logic [7:0]       access_id;
    logic [`XLEN-1:0] access_addr, access_wdata;    //注意，这里的数据是右对齐的
    logic             access_ci, access_wt;
    logic [4:0]       access_opcode;
    logic [6:0]       access_funct7;
    logic [2:0]       access_funct3;
    logic [5:0]       access_error;
    logic             empty;
    wire              access_misalign;              //当前访问有错误
    assign access_misalign=(access_addr[3:0]!=4'b0000);
    //----------------read data from ram-------------------
    wire [127:0]        data_toshift;
    //------------地址分割为index tag offset---------------
    wire [TAGADDR_SIZE-1:0]             tag_addr;   //物理地址的tag部分
    wire [CACHE_INDEXADDR_SIZE-1:0]     index_addr; //物理地址的index部分
    wire [CACHE_LINEADDR_SIZE-1:0]      offset_addr;//物理地址在cacheline的部分
    assign tag_addr   = access_addr[CACHE_PADDR_SIZE-1: CACHE_PADDR_SIZE-TAGADDR_SIZE]; 
    assign index_addr = access_addr[CACHE_PADDR_SIZE-TAGADDR_SIZE-1 : CACHE_LINEADDR_SIZE];
    assign offset_addr= access_addr[CACHE_LINEADDR_SIZE-1:0];
    //--------------cacheline valid/dirty 标识--------------------
    reg [CACHE_LINE_NUM-1:0] line_valid;
    //--------------cache ram control signal---------------------
    logic [127:0]               cacheram_dataw, cacheram_datar;
    logic [15:0]                cacheram_bsel;
    logic                       cacheram_ce, cacheram_we;
    logic [CACHE_INDEXADDR_SIZE+CACHE_LINEADDR_SIZE-1-4:0] cacheram_addr;   //cacheram is 16Byte width sram, 地址的低四位是字节选择，在这里需要-4
    //--------------tagram---------------------------------------
    logic [TAGADDR_SIZE-1:0]    tagram_dataw, tagram_dataq;
    logic                       tagram_ce, tagram_we;
    logic [CACHE_INDEXADDR_SIZE-1:0] tagram_addr;
    //----------------refersh/reaload ctrl signal--------------------
    // 在刷新状态、reload状态下所有sram的控制信号交给控制器
    wire                         reload_done, refersh_done, reload_fault, refersh_fault;
    wire [127:0]                 ctrl2cacheram_dataw;
    wire [15:0]                  ctrl2cacheram_bsel;
    wire                         ctrl2cacheram_ce, ctrl2cacheram_we;
    wire [CACHE_INDEXADDR_SIZE+CACHE_LINEADDR_SIZE-1-4:0] ctrl2cacheram_addr;
    wire [TAGADDR_SIZE-1:0]      ctrl2tagram_dataw;
    wire                         ctrl2tagram_ce, ctrl2tagram_we;
    wire [CACHE_INDEXADDR_SIZE-1:0] ctrl2tagram_addr;
    //----------------biu signal---------------------
    //-----------------stream access port-----------------
    wire                         biu_stream_error;
    wire                         biu_stream_write_done;
    reg                          biu_stream_rvalid;
    reg                          biu_stream_rlast;       //标识当前读取流到最后一个数据
    wire                         biu_stream_wready;      //写数据准备好，此信号直接连接在请求方FIFO的ren上
    wire                         biu_stream_wvalid;      //写数据有效，此信号直接为FIFO信号empty取反，此模块不判定此信号
    wire                         biu_stream_readline_req;
    wire                         biu_stream_writeline_req;//请求读一行，行大小为beat_num * 128bit
    wire [`PADDR-1:0]            biu_stream_addr;
    wire [127:0]                 biu_stream_wdata;
    wire [127:0]                 biu_stream_rdata;

fifo1r1w#(
    .DWID       (8+64+64+1+1+5+10+6),
    .DDEPTH     (2)
)command_buffer(
    .clk(clk_i),
    .rst(srst_i),
    .ren(valid_next),
    .wen(cache_access_if.valid),
    .wdata({cache_access_if.id,
            cache_access_if.addr,
            cache_access_if.wdata,
            cache_access_if.ci,
            cache_access_if.wt,
            cache_access_if.opcode,
            cache_access_if.funct,
            cache_access_if.error}),
    .rdata({access_id,
            access_addr,
            access_wdata,
            access_ci,
            access_wt,
            access_opcode,
            access_funct7,
            access_funct3,
            access_error}),
    .full   (cache_access_if.full),
    .empty  (empty)
);
always_ff @( posedge clk_i ) begin
    if(srst_i)begin
        state <= STATE_STD;
    end else begin
        state <= state_next;
    end
end
always_comb begin
    case(state)
        STATE_STD:begin
            if(cache_flush_req)begin
                state_next = STATE_REFERSH;
                valid_next = 1'b0;
            end else if(!empty)begin
                if(access_misalign | (|access_error))begin
                    state_next = STATE_STD;
                    valid_next = 1'b1;
                end 
                //else if(access_ci | access_mmio)begin
                //    state_next = STATE_SINGLE;      //当前访问是ci 或者是物理地址为mmio区段
                //    valid_next = 1'b0;
                //end 
                else begin
                    state_next = STATE_TAG;
                    valid_next = 1'b0;
                end
            end else begin          //当前无任何访问，也无任何刷新请求
                state_next = state;
                valid_next = 1'b0;
            end
        end
        STATE_TAG:begin
            if(!line_valid[index_addr] | line_valid[index_addr]&(tagram_dataq!=tag_addr))begin
                state_next = STATE_RELOAD;
                valid_next = 1'b0;
            end else begin
                case(access_opcode)
                    `OPCODE_LOAD:begin
                        state_next = STATE_STD;  //读数据在这个周期就可以拿到了
                        valid_next = 1'b1;
                    end  
                    default:begin 
                        state_next = STATE_STD;
                        valid_next = 1'b0;
                    end
                endcase
            end
        end
        //STATE_SINGLE:begin 
        //    state_next = biu_single_ack ? STATE_STD : state; 
        //    valid_next = biu_single_ack ? 1'b1 : 1'b0;
        //end
        STATE_RELOAD:begin 
            state_next = reload_done ? STATE_AGAIN : state;   //完成重装填后进入重试
            valid_next = 1'b0;
        end
        STATE_AGAIN: begin
            state_next = STATE_TAG;
            valid_next = 1'b0;
        end
        STATE_REFERSH:begin 
            state_next = refersh_done ? STATE_STD : state;
            valid_next = 1'b0;
        end
        default:begin 
            state_next = STATE_STD;
            valid_next = 1'b0;
        end
    endcase
end
sram_1rw_sync_read#(
    .DATA_WIDTH         (TAGADDR_SIZE),
    .DATA_DEPTH         (CACHE_LINE_NUM)
)tag_ram(
    .clk        (clk_i),
    .addr       (tagram_addr),
    .ce         (tagram_ce),
    .we         (tagram_we),
    .datar      (tagram_dataq),
    .dataw      (tagram_dataw)
);
//---------------------------cacheram-------------------------------
always_comb begin
    case(state)
        STATE_REFERSH, STATE_RELOAD:begin
            cacheram_addr = ctrl2cacheram_addr; 
            cacheram_ce  = ctrl2cacheram_ce;
            cacheram_we = ctrl2cacheram_we;
            cacheram_bsel=ctrl2cacheram_bsel;
            cacheram_dataw=ctrl2cacheram_dataw;
            tagram_addr =ctrl2tagram_addr;
            tagram_ce =ctrl2tagram_ce;
            tagram_we =ctrl2tagram_we;
            tagram_dataw=ctrl2tagram_dataw;
        end
        default:begin
            cacheram_addr = {index_addr,{offset_addr[CACHE_LINEADDR_SIZE-1:4]}};
            cacheram_ce   = 1'b1;
            cacheram_we   = 1'b0;
            cacheram_bsel = 16'hffff;
            cacheram_dataw= 0;
            tagram_addr   = index_addr;
            tagram_ce     = 1'b1;
            tagram_we     = 1'b0;               //正常运行状态下不需要对tagram写
            tagram_dataw  = 0;
        end
    endcase
end
cacheram#(
    .DEEPTH         (CACHERAM_DEEPTH),      //total=deepth * byte_num * 8 bit (in bits)
    .BYTE_NUM       (16)
)cacheram(
    .clk            (clk_i),
    .addr           (cacheram_addr),
    .ce             (cacheram_ce),
    .we             (cacheram_we),
    .bsel           (cacheram_bsel),           //byte select
    .datar          (cacheram_datar),
    .dataw          (cacheram_dataw)
);
//-----------------------line valid/dirty flag-------------------
always_ff @( posedge clk_i ) begin
    if(srst_i)begin
        line_valid <= 0;
    end else begin
        case(state)
            STATE_RELOAD:begin 
                if(reload_done)begin 
                    line_valid[ctrl2tagram_addr] <= 1'b1;
                end
            end
            STATE_REFERSH:begin
                if(refersh_done)begin
                    line_valid <= 0;        //刷新完成后全部清零
                end
            end
        endcase
    end
end
//---------------------------reload/refersh control-------------------------
refersh_reload_ctrl#(
    .CACHE_PADDR_SIZE           (32),    //整体物理地址宽度
    .CACHE_INDEXADDR_SIZE       (CACHE_INDEXADDR_SIZE),     //索引地址宽度
    .CACHE_LINEADDR_SIZE        (CACHE_LINEADDR_SIZE),      //cache行地址宽度（以字节计）NO TOUCH THIS
    .CACHE_BYTEADDR_SIZE        (4)       //NO TOUCH THIS
)refersh_reload_ctrl(
    .clk_i                      (clk_i),
    .srst_i                     (srst_i),
    .nocheck_dirty              (1'b1),
    //----------------cacheram interface----------------
    .cacheram_addr              (ctrl2cacheram_addr),
    .cacheram_ce                (ctrl2cacheram_ce),
    .cacheram_we                (ctrl2cacheram_we),
    .cacheram_bsel              (ctrl2cacheram_bsel),
    .cacheram_wdata             (ctrl2cacheram_dataw),
    .cacheram_qdata             (cacheram_datar),
    //----------------tagram interface-------------------
    .tagram_addr                (ctrl2tagram_addr),
    .tagram_ce                  (ctrl2tagram_ce),
    .tagram_we                  (ctrl2tagram_we),
    .tagram_wdata               (ctrl2tagram_dataw),
    .tagram_qdata               (tagram_dataq),
    //----------------cacheline state---------------------
    .linestate_valid            (line_valid),
    .linestate_dirty            (0),
    //----------------command interface-------------------
    .refersh_req                (state==STATE_REFERSH), 
    .reload_req                 (state==STATE_RELOAD),
    .reload_addr                (access_addr),              //当前正在访问的地址作为请求重装填的地址
    .refersh_done               (refersh_done),
    .reload_done                (reload_done),
    .refersh_fault              (refersh_fault), 
    .reload_fault               (reload_fault),
    //----------------biu interface------------------------
    .biu_error                  (biu_stream_error),
    .biu_write_done             (biu_stream_write_done),
    .biu_rvalid                 (biu_stream_rvalid),
    .biu_wready                 (biu_stream_wready),
    .biu_wvalid                 (biu_stream_wvalid),
    .biu_readline_req           (biu_stream_readline_req),
    .biu_writeline_req          (biu_stream_writeline_req),
    .biu_addr                   (biu_stream_addr),
    .biu_wdata                  (biu_stream_wdata),
    .biu_rdata                  (biu_stream_rdata)
);
//-------------------------bus interface unit-----------------------------
biu#(
    .PADDR_SIZE             (`PADDR)
    //.SINGLE_DATA_WIDTH = 64,
    //.DATA_WIDTH = 128,     //NO TOUCH
    //.BEAT_NUM = 4          //NO TOUCH
)biu(
    .clk_i                  (clk_i), 
    .srst_i                 (srst_i),
//-----------------------single access port-----------------
//          single access port only support 64bit access Icache不需要单次访问信号
    .single_read_req        (0),
    .single_write_req       (1'b0),
    .single_addr            (0),
    .single_size            (0),
    .single_bsel            (0),
    .single_wdata           (0),
    .single_rdata           (),
    .single_ack             (),
    .single_error           (),
//-----------------------stream access port-----------------
    .stream_error           (biu_stream_error),
    .stream_write_done      (biu_stream_write_done),
    .stream_rvalid          (biu_stream_rvalid),
    .stream_rlast           (),                       //标识当前读取流到最后一个数据,在这里不使用
    .stream_wready          (biu_stream_wready),      //写数据准备好，此信号直接连接在请求方FIFO的ren上
    .stream_wvalid          (biu_stream_wvalid),      //写数据有效，此信号直接为FIFO信号empty取反，此模块不判定此信号
    .stream_readline_req    (biu_stream_readline_req),
    .stream_writeline_req   (biu_stream_writeline_req),//请求读一行，行大小为beat_num * 128bit
    .stream_addr            (biu_stream_addr),
    .stream_wdata           (biu_stream_wdata),
    .stream_rdata           (biu_stream_rdata),
//------------------------axi interface--------------------
    .biu_axi_ar             (cache_axi_ar),
    .biu_axi_r              (cache_axi_r),
    .biu_axi_aw             (cache_axi_aw),
    .biu_axi_w              (cache_axi_w),
    .biu_axi_b              (cache_axi_b)
);
//---------------------to pipline interface-------------------
assign data_toshift = cacheram_datar;           //指令cache固定读出对齐的128位数据，因此不需要移位器
assign cache_return_if.rdata = data_toshift;

always_comb begin
    cache_return_if.valid= valid_next;      //因为cache输出直接接到内部逻辑的DFF中，因此在这里直接使用组合逻辑输出valid
    cache_return_if.id   = access_id;
    cache_return_if.error= access_error;    //FIXME: 在这里忽略总线错误，因为总线错误通常是严重错误，会导致系统完全卡死
    cache_return_if.mmio = (|cache_return_if.error)?1'b0 : (access_ci);   //如果当前访问有error，则mmio信号为0
    cache_flush_ack = (state==STATE_REFERSH) & refersh_done;
end
endmodule