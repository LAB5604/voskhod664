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
                                                                             
    Desc    : PRV664(voskhod664) simple cache top file
    Author  : JackPan
    Date    : 2024/01/09
    Version : 0.0(file initialize)
              1.0(added more function)

    change log:
            2024/01/09: version 1.0, 添加了"burnaccess"信号用于流水线取消当前正在运行的访问；
                        添加了等待指令成为最后一条指令的功能，即：在这条指令成为最老的那条指令前，cache不会进行任何总线操作和修改操作。

    NOTE： 处于不可缓存区间的访问仅支持不大于总线宽度的访问，处于可缓存区间的访问能支持128位


***********************************************************************************************/
module cache_top#(
    parameter CACHE_INDEXADDR_SIZE = 7,
              CACHE_LINEADDR_SIZE  = 6      //DO NOT touch this parameter
)(
    input wire clk_i,
    input wire srst_i,
    //------------cpu manage interface-----------
    input wire                      cache_flush_req,
    output logic                    cache_flush_ack,
    input wire                      cache_burnaccess,
    input wire [7:0]                last_inst_itag,
    input wire                      last_inst_valid,
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
           STATE_AMO = 'h2,         //run AMO operation
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
    logic [`CACHE_USER_W-1:0]access_user;
    logic             empty;
    wire  [`XLEN-1:0] access_wdata_shift2bus;       //将数据移位到和总线宽度对齐
    wire  [127:0]     access_wdata_shift2cache;     //将数据移位到128位（给cacheram用）
    wire [7:0]        tobus_bsel;                  
    wire [15:0]       tocache_bsel;
    wire              access_misalign;              //当前访问有错误
    wire              access_thelast;               //当前访问已经是等待提交的最后一条指令了
    assign access_thelast = last_inst_valid & (access_id==last_inst_itag);
    //----------------read data from ram-------------------
    wire [127:0]        data_toshift;
    wire [127:0]        data_frmshift;
    //------------地址分割为index tag offset---------------
    wire [TAGADDR_SIZE-1:0]             tag_addr;   //物理地址的tag部分
    wire [CACHE_INDEXADDR_SIZE-1:0]     index_addr; //物理地址的index部分
    wire [CACHE_LINEADDR_SIZE-1:0]      offset_addr;//物理地址在cacheline的部分
    assign tag_addr   = access_addr[CACHE_PADDR_SIZE-1: CACHE_PADDR_SIZE-TAGADDR_SIZE]; 
    assign index_addr = access_addr[CACHE_PADDR_SIZE-TAGADDR_SIZE-1 : CACHE_LINEADDR_SIZE];
    assign offset_addr= access_addr[CACHE_LINEADDR_SIZE-1:0];
    //--------------cacheline valid/dirty 标识--------------------
    reg [CACHE_LINE_NUM-1:0] line_valid, line_dirty;
    //--------------cache ram control signal---------------------
    logic [127:0]               cacheram_dataw, cacheram_datar;
    logic [15:0]                cacheram_bsel;
    logic                       cacheram_ce, cacheram_we;
    logic [CACHE_INDEXADDR_SIZE+CACHE_LINEADDR_SIZE-1-4:0] cacheram_addr;   //cacheram is 16Byte width sram, 地址的低四位是字节选择，在这里需要-4
    //--------------tagram---------------------------------------
    logic [TAGADDR_SIZE-1:0]    tagram_dataw, tagram_dataq;
    logic                       tagram_ce, tagram_we;
    logic [CACHE_INDEXADDR_SIZE-1:0] tagram_addr;
    //-------------------AMO指令信号----------------------------------
    wire                         amo_run;
    wire [`XLEN-1:0]             amo_data2mem, amo_data2rf;
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
    wire                         biu_single_read_req;
    wire                         biu_single_write_req;
    wire [`PADDR-1:0]            biu_single_addr;
    wire [2:0]                   biu_single_size;
    wire [7:0]                   biu_single_bsel;
    wire [`XLEN-1:0]             biu_single_wdata;
    wire [`XLEN-1:0]             biu_single_rdata;
    wire                         biu_single_ack;
    wire                         biu_single_error;       
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
    .DWID       (8+64+64+1+1+5+10+6+`CACHE_USER_W),
    .DDEPTH     (2)
)command_buffer(
    .clk(clk_i),
    .rst(srst_i | cache_burnaccess),
    .ren(valid_next),
    .wen(cache_access_if.valid),
    .wdata({cache_access_if.id,
            cache_access_if.addr,
            cache_access_if.wdata,
            cache_access_if.ci,
            cache_access_if.wt,
            cache_access_if.opcode,
            cache_access_if.funct,
            cache_access_if.error,
            cache_access_if.user}),
    .rdata({access_id,
            access_addr,
            access_wdata,
            access_ci,
            access_wt,
            access_opcode,
            access_funct7,
            access_funct3,
            access_error,
            access_user}),
    .full   (cache_access_if.full),
    .empty  (empty)
);
//---------------------datashift-------------------------
//              shift data to bus
data_shift_l            data_shift_tobus(
    .Offset_ADDR        ({1'b0,offset_addr[2:0]}),  //因为目标总线为64位，故这里偏移值只取3位
    .DATAi              (access_wdata),
    .SIZEi              (access_funct3[1:0]),
    .MisAligned         (access_misalign),
    .BSELo              (tobus_bsel),
    .DATAo              (access_wdata_shift2bus)
);
data_shift_l            data_shift_tocache(
    .Offset_ADDR        (offset_addr[3:0]),         //cache为128位，故在这里取全部地址
    .DATAi              (amo_run?amo_data2mem:access_wdata),//当运行AMO指令时，写入内存的数据是AMO运算单元出来的数据
    .SIZEi              (access_funct3[1:0]),
    .MisAligned         (),
    .BSELo              (tocache_bsel),
    .DATAo              (access_wdata_shift2cache)
);
//--------------------amo operation unit------------------------
`ifdef AMO_ON
    amo_unit#(
        .XLEN(64)     //64 for rv64, 32 for rv32
    )amo_unit(
        .clk_i          (clk_i),
        .rst_i          (srst_i),
        .en             (state==STATE_TAG),
        .funct3         (access_funct3),
        .funct5         (access_funct7[6:2]),      //the lower two bit of funct7 is aq/rl bit
        .data1          (access_wdata),
        .data2          (data_frmshift[63:0]),  //data1 is the value from instruction, data2 is the value from memory
        .data2rf        (amo_data2rf),       //value write back to register
        .data2mem       (amo_data2mem)       //value write back to memory
    );
    assign amo_run = (access_opcode==`OPCODE_AMO) & (state!=STATE_STD);
`else           //NO AMO support
    assign amo_run = 0;
    assign amo_data2mem = 0;
    assign amo_data2rf = 0;
`endif
always_ff @( posedge clk_i ) begin
    if(srst_i)begin
        state <= STATE_STD;
    end else begin
        state <= state_next;
    end
end
always_comb begin
    if(cache_burnaccess)begin
        state_next = STATE_STD;
        valid_next = 1'b0;
    end else begin
        case(state)
            STATE_STD:begin
                if(cache_flush_req)begin
                    state_next = STATE_REFERSH;
                    valid_next = 1'b0;
                end else if(!empty)begin
                    if(access_misalign | (|access_error))begin
                        state_next = STATE_STD;
                        valid_next = 1'b1;
                    end else if(access_ci)begin
                        state_next = access_thelast ? STATE_SINGLE : state;      //当前访问是ci 或者是物理地址为mmio区段
                        valid_next = 1'b0;
                    end else begin
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
                    state_next = access_thelast ? STATE_RELOAD : state;
                    valid_next = 1'b0;
                end else begin
                    case(access_opcode)
                        `OPCODE_LOAD:begin
                            state_next = STATE_STD;  //读数据在这个周期就可以拿到了
                            valid_next = 1'b1;
                        end  
                        `OPCODE_STORE:begin 
                            state_next = access_thelast ? STATE_WEN : state;  //写数据需要再等到下个周期拉高wen信号，需要等待指令成为最老的那条
                            valid_next = 1'b0;
                        end
                        `ifdef AMO_ON
                        `OPCODE_AMO:begin
                            state_next = access_thelast ? STATE_AMO : state;
                            valid_next = 1'b0;
                        end
                        `endif
                        default:begin 
                            state_next = STATE_STD;
                            valid_next = 1'b0;
                        end
                    endcase
                end
            end
            `ifdef AMO_ON
            STATE_AMO:begin
                state_next = STATE_WEN;
                valid_next = 1'b0;
            end
            `endif
            STATE_WEN:begin 
                state_next = STATE_STD;
                valid_next = 1'b1; 
            end
            STATE_SINGLE:begin 
                state_next = biu_single_ack ? STATE_STD : state; 
                valid_next = biu_single_ack ? 1'b1 : 1'b0;
            end
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
            cacheram_we   = (state==STATE_WEN);
            cacheram_bsel = (access_funct3==3'b100)?16'hffff:tocache_bsel;
            cacheram_dataw= access_wdata_shift2cache;
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
    if(srst_i)begin
        line_dirty <= 0;
    end else begin
        case(state)
            STATE_WEN:   line_dirty[index_addr] <= 1'b1;
            STATE_RELOAD:begin
                if(reload_done)begin
                    line_dirty[index_addr] <= 1'b0;
                end
            end
            STATE_REFERSH:begin
                if(refersh_done)begin
                    line_dirty <= 0;
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
    .nocheck_dirty              (1'b0),
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
    .linestate_dirty            (line_dirty),
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
//-------------------------single access-------------------------
assign biu_single_read_req = (state==STATE_SINGLE) & (access_opcode==`OPCODE_LOAD);
assign biu_single_write_req= (state==STATE_SINGLE) & (access_opcode==`OPCODE_STORE);
assign biu_single_addr     = access_addr;
assign biu_single_size     = access_funct3[1:0];
assign biu_single_bsel     = tobus_bsel;
assign biu_single_wdata    = access_wdata_shift2bus;
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
    .single_read_req        (biu_single_read_req),
    .single_write_req       (biu_single_write_req),
    .single_addr            (biu_single_addr),
    .single_size            (biu_single_size),
    .single_bsel            (biu_single_bsel),
    .single_wdata           (biu_single_wdata),
    .single_rdata           (biu_single_rdata),
    .single_ack             (biu_single_ack),
    .single_error           (biu_single_error),
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
assign data_toshift = (state==STATE_SINGLE) ? {biu_single_rdata,biu_single_rdata} : cacheram_datar;  //因为总线上读取的值只能读128位，因此在这里把总线上的值复制成128位
data_shift_r            data_shift_r(
    .DATAi                  (data_toshift),
    .Offset_ADDR            (access_addr[3:0]),
    .DATAo                  (data_frmshift)
);
always_comb begin
    cache_return_if.valid= valid_next;      //因为cache输出直接接到内部逻辑的DFF中，因此在这里直接使用组合逻辑输出valid
    cache_return_if.rdata= amo_run?amo_data2rf:data_frmshift;
    cache_return_if.id   = access_id;
    cache_return_if.error= access_error;    //FIXME: 在这里忽略总线错误，因为总线错误通常是严重错误，会导致系统完全卡死
    cache_return_if.user = access_user;
    cache_return_if.mmio = (|cache_return_if.error)?1'b0 : (access_ci);   //如果当前访问有error，则mmio信号为0
    cache_flush_ack = (state==STATE_REFERSH) & refersh_done;
end
//////////////////////////////////////////////////////////////////////////////////////////
//                     assert                                                           //
//////////////////////////////////////////////////////////////////////////////////////////
//always@(posedge clk_i)begin
//    if(srst_i)begin
//        reset_info: assert(1==1) $info("INFO:cache reset");
//    end
//    else begin
//        sread_chk: assert(biu_single_read_req & cache_burnaccess) $error("ERR:cache burnaccess but bus is in access");
//        swrite_chk: assert(biu_single_write_req & cache_burnaccess) $error("ERR:cache burnaccess but bus is in access");
//        bread_chk: assert(biu_stream_readline_req & cache_burnaccess) $error("ERR:cache burnaccess but bus is in access");
//        bwrite_chk: assert(biu_stream_writeline_req & cache_burnaccess) $error("ERR:cache burnaccess but bus is in access");
//    end
//end
`ifdef SIMULATION
    always@(posedge clk_i)begin
        if(access_misalign & !empty)begin
            $finish();
            $display("dcache has misalign access!");
        end
    end
`endif
endmodule