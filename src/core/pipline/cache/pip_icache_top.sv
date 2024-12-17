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
                                                                             
    Desc    : PRV664(voskhod664) simple pipline icache top file
    Author  : JackPan
    Date    : 2024/04/24
    Version : 0.0(file initialize)

    change log:


    NOTE： 处于不可缓存区间的访问仅支持不大于总线宽度的访问，处于可缓存区间的访问能支持128位

    Arch:

    -------------------
    |   command fifo  |
    -------------------
           |
           |------------------------|
    ----------------          ---------------                Level-1
    |   cache ram  |          |   tag ram   |         ==============
    ----------------          --------------                 level-2


***********************************************************************************************/
module pip_icache_top#(
    parameter CACHE_INDEXADDR_SIZE = 7,
              CACHE_LINEADDR_SIZE  = 6      //DO NOT touch this parameter
)(
    input wire clk_i,
    input wire srst_i,
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
           
localparam STATE_RUN = 'h0,         //normal access
           STATE_RELOAD = 'h5,      //reload cache
           STATE_REFERSH= 'h6,      //refersh cache
           STATE_AGAIN  = 'h7;      //try again current access

    //-----------FSM-------------------------------------
    reg [3:0]   state;
    logic[3:0]  state_next;
    //-------------pipline handshake----------------------
    reg                 lv2_valid;
    logic               lv2_ready;
    logic               lv1_valid;
    logic               lv1_ready;         //level-1 pipline handshake
    /****************************************************************************
                level-1 pipline signal begin
        流水线第一级的信号只包含从command buffer里读出的值+少量译码后的值
        流水线第一级不进行任何多周期操作
    *****************************************************************************/
    //------------access from command buffer--------------
    logic [7:0]       lv1_id;
    logic [`XLEN-1:0] lv1_addr;
    logic             lv1_ci, lv1_wt;
    logic [4:0]       lv1_opcode;
    logic [6:0]       lv1_funct7;
    logic [2:0]       lv1_funct3;
    logic [5:0]       lv1_error;
    logic [`CACHE_USER_W-1:0]lv1_user;
    logic             empty;
    logic             buffer_read;                  //read buffer
    //-----------将index、tag、offset部分从地址中分离开，送进ram里读取----------------
    wire [TAGADDR_SIZE-1:0]             lv1_tag_addr;   //物理地址的tag部分
    wire [CACHE_INDEXADDR_SIZE-1:0]     lv1_index_addr; //物理地址的index部分
    wire [CACHE_LINEADDR_SIZE-1:0]      lv1_offset_addr;//物理地址在cacheline的部分
    assign lv1_tag_addr   = lv1_addr[CACHE_PADDR_SIZE-1: CACHE_PADDR_SIZE-TAGADDR_SIZE]; 
    assign lv1_index_addr = lv1_addr[CACHE_PADDR_SIZE-TAGADDR_SIZE-1 : CACHE_LINEADDR_SIZE];
    assign lv1_offset_addr= lv1_addr[CACHE_LINEADDR_SIZE-1:0];
    /***************************************************************************
            level-1 pipline signal end
    ****************************************************************************/
    //----------------level-2 pipline signals----------------------
    reg [7:0]           lv2_id;
    reg [`XLEN-1:0]     lv2_addr;                           //注意，这里的数据是右对齐的

    reg [4:0]           lv2_opcode;
    reg [6:0]           lv2_funct7;
    reg [2:0]           lv2_funct3;
    reg [5:0]           lv2_error;
    reg [`CACHE_USER_W-1:0]lv2_user;
    wire                lv2_misalign;              //当前访问有错误
    assign lv2_misalign = (lv2_addr[3:0]!=4'b0000);
    //----------------read data from ram-------------------
    wire [127:0]        data_toshift;
    wire [127:0]        data_frmshift;
    //------------地址分割为index tag offset---------------
    
    reg [TAGADDR_SIZE-1:0]              lv2_tag_addr;   //将地址缓冲一拍以便在流水线第二级使用
    reg [CACHE_INDEXADDR_SIZE-1:0]      lv2_index_addr; 
    reg [CACHE_LINEADDR_SIZE-1:0]       lv2_offset_addr;
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
    //          stream access port
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

/*************************************************************************
                        Level-1 pipline logic begin
**************************************************************************/
fifo1r1w#(
    .DWID       (8+64+1+1+5+10+6+`CACHE_USER_W),
    .DDEPTH     (2)
)command_buffer(
    .clk(clk_i),
    .rst(srst_i),
    .ren(buffer_read),
    .wen(cache_access_if.valid),
    .wdata({cache_access_if.id,
            cache_access_if.addr,
            cache_access_if.ci,
            cache_access_if.wt,
            cache_access_if.opcode,
            cache_access_if.funct,
            cache_access_if.error,
            cache_access_if.user}),
    .rdata({lv1_id,
            lv1_addr,
            lv1_ci,
            lv1_wt,
            lv1_opcode,
            lv1_funct7,
            lv1_funct3,
            lv1_error,
            lv1_user}),
    .full   (cache_access_if.full),
    .empty  (empty)
);
//---------------------------cacheram and tagram control-------------------------------
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
        STATE_AGAIN:begin       //重试周期中，cacheram的控制信号被切换给lv2传递过来的控制信号
            cacheram_addr = {lv2_index_addr,{lv2_offset_addr[CACHE_LINEADDR_SIZE-1:4]}};
            cacheram_ce   = 1'b1;
            cacheram_we   = 1'b0;
            cacheram_bsel = 16'hffff;
            cacheram_dataw= 'hx;
            tagram_addr   = lv2_index_addr;
            tagram_ce     = 1'b1;
            tagram_we     = 1'b0;               //正常运行状态下不需要对tagram写
            tagram_dataw  = 0;
        end
        default:begin                           //在正常运行状态下，cacheram的控制输入是lv1的输入
            cacheram_addr = {lv1_index_addr,{lv1_offset_addr[CACHE_LINEADDR_SIZE-1:4]}};
            cacheram_ce   = 1'b1;
            cacheram_we   = 1'b0;
            cacheram_bsel = 16'hffff;
            cacheram_dataw= 'hx;
            tagram_addr   = lv1_index_addr;
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
//------------------------tag ram-------------------------------------
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
assign buffer_read = lv1_valid & lv1_ready;
assign lv1_valid = !empty;
//          pipline reg
handshake_dff#(
    .DATA_WIDTH     (8+64+5+10+6+TAGADDR_SIZE+CACHE_INDEXADDR_SIZE+CACHE_LINEADDR_SIZE)
)pipline_reg(
    // clock and sync reset
    .clk_i          (clk_i),
    .rst_i          (srst_i),
    .data_i         ({lv1_id,
                      lv1_addr,
                      lv1_opcode,
                      lv1_funct7,
                      lv1_funct3,
                      lv1_error,
                      lv1_tag_addr,
                      lv1_index_addr,
                      lv1_offset_addr}),
    .valid_i        (lv1_valid),
    .ready_o        (lv1_ready),
    .data_o         ({
                      lv2_id,
                      lv2_addr,
                      lv2_opcode,
                      lv2_funct7,
                      lv2_funct3,
                      lv2_error ,
                      lv2_tag_addr,
                      lv2_index_addr,
                      lv2_offset_addr}),    //user信号暂未接入，因为icache并不需要user信号
    .valid_o        (lv2_valid),
    .ready_i        (lv2_ready)
);

/***************************************************************************
                    level-1 pipline logic end
****************************************************************************/

/***************************************************************************
                 level-2 pipline logic begin
 缓存流水线第二级将对比第一级中从tagram读取的tag和这条访存指令的tag是否一致，若不
 一致则进行缓存换行；若一致就可以进行缓存读写了，根据传递的opcode，第二级流水线将
 进行以下操作：
    1、opcode=load
        ci=1： 禁止使用缓存，将等到access_thelast信号拉高后再使用single_access操作总线。
        ci=0： 可以使用缓存，直接返回从缓存中读取到的值
****************************************************************************/
always_ff @( posedge clk_i ) begin
    if(srst_i)begin
        state <= STATE_RUN;
    end else begin
        state <= state_next;
    end
end
always_comb begin
    case(state)
        STATE_RUN:begin
            if(cache_flush_req)begin
                state_next = STATE_REFERSH;
                lv2_ready = 1'b0;
            end else if(lv2_valid)begin
                if(lv2_misalign | (|lv2_error))begin  //有错误的访问直接传递到下一级，不进行处理
                    state_next = STATE_RUN;
                    lv2_ready = 1'b1;
                end else begin
                    if(!line_valid[lv2_index_addr] | line_valid[lv2_index_addr]&(tagram_dataq!=lv2_tag_addr))begin//访问没有命中
                        state_next = STATE_RELOAD;
                        lv2_ready = 1'b0;
                    end else begin
                        case(lv2_opcode)
                            `OPCODE_LOAD:begin
                                state_next = STATE_RUN;  //读数据在这个周期就可以拿到了
                                lv2_ready = 1'b1;
                            end
                            default:begin 
                                state_next = STATE_RUN;
                                lv2_ready = 1'b0;
                            end
                        endcase
                    end
                end
            end else begin          //当前无任何访问，也无任何刷新请求
                state_next = state;
                lv2_ready = 1'b0;
            end
        end
        STATE_RELOAD:begin 
            state_next = reload_done ? STATE_AGAIN : state;   //完成重装填后进入重试
            lv2_ready = 1'b0;
        end
        STATE_AGAIN: begin
            state_next = STATE_RUN;
            lv2_ready = 1'b0;
        end
        STATE_REFERSH:begin 
            state_next = refersh_done ? STATE_RUN : state;
            lv2_ready = 1'b0;
        end
        default:begin 
            state_next = STATE_RUN;
            lv2_ready = 1'b0;
        end
    endcase
end

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
    .reload_addr                (lv2_addr),              //当前正在访问的地址作为请求重装填的地址
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
//          single access port only support 64bit access
    .single_read_req        (1'b0),
    .single_write_req       (1'b0),
    .single_addr            (),
    .single_size            (),
    .single_bsel            (),
    .single_wdata           (),
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
//---------------------datashift-------------------------
//              shift data to bus
assign data_toshift = cacheram_datar;  //icache永远只会读取对齐的128位数据
//---------------------to pipline interface-------------------
always_comb begin
    cache_return_if.valid= lv2_ready;      //因为cache输出直接接到内部逻辑的DFF中，因此在这里直接使用组合逻辑输出valid
    cache_return_if.rdata= data_toshift;    //icache直接使用从cacheram中读取的对齐的128bit数据
    cache_return_if.id   = lv2_id;
    cache_return_if.error= lv2_error;    //FIXME: 在这里忽略总线错误，因为总线错误通常是严重错误，会导致系统完全卡死
    cache_return_if.user = lv2_user;
    cache_return_if.mmio = 1'b0;
    cache_flush_ack = (state==STATE_REFERSH) & refersh_done;
end

endmodule