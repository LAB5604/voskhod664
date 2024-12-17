/*
    写回内存：将要写回内存的行先全部存储在fifo中，然后再从fifo中写到内存中，这样可以避免cacheram和总线的握手过程，错误通常是在握手过程中引起的。
*/
`include"timescale.v"
module refersh_reload_ctrl#(
    parameter CACHE_PADDR_SIZE     = 32,    //整体物理地址宽度
              CACHE_INDEXADDR_SIZE = 5,     //索引地址宽度
              CACHE_LINEADDR_SIZE = 7,      //cache行地址宽度（以字节计）NO TOUCH THIS
              CACHE_BYTEADDR_SIZE = 4       //no touch this parameter
)(
    clk_i,
    srst_i,
    //----------------nocheck dirty line-------------------
    nocheck_dirty,              //不检查脏行，icache不需要检查脏行，这一位需要置1以提高刷新速度
    //----------------cacheram interface----------------
    cacheram_addr,
    cacheram_ce,
    cacheram_we,
    cacheram_bsel,
    cacheram_wdata,
    cacheram_qdata,
    //----------------tagram interface-------------------
    tagram_addr,
    tagram_ce,
    tagram_we,
    tagram_wdata,
    tagram_qdata,
    //----------------cacheline state---------------------
    linestate_valid,
    linestate_dirty,
    //----------------command interface-------------------
    refersh_req, reload_req,
    reload_addr,
    refersh_done, reload_done,
    refersh_fault, reload_fault,
    //----------------biu interface------------------------
    biu_error,
    biu_write_done,
    biu_rvalid,
    biu_wready,
    biu_wvalid,
    biu_readline_req,
    biu_writeline_req,
    biu_addr,
    biu_wdata,
    biu_rdata
);
localparam TAGADDR_SIZE = CACHE_PADDR_SIZE - CACHE_INDEXADDR_SIZE - CACHE_LINEADDR_SIZE,
           BYTE_NUM     = 1<<CACHE_BYTEADDR_SIZE,           //
           CACHE_LINE_NUM= 1<<CACHE_INDEXADDR_SIZE,         //cache行数，
           DATA_WIDTH   = BYTE_NUM * 8;
localparam BEAT_NUM = 1<<(CACHE_LINEADDR_SIZE-CACHE_BYTEADDR_SIZE);//重装cache行所需拍数
localparam STATE_STD = 'h00,                //等待命令
           STATE_READLINE = 'h01,           //从cacheram中读取一个行的所有数据到FIFO中，从tagram中读取当前line的tag
           STATE_WRITEBACK= 'h02,           //将FIFO中的数据写入到内存中，写入地址为对齐的{tag, index, 0000000}
           STATE_INCRINDEX= 'h03,           //增加index计数器
           STATE_RELOAD   = 'h04,           //写cache line
           STATE_READY    = 'h0E,
           STATE_FAULT    = 'h0F;
    input wire clk_i, srst_i;
    //---------------nocheck dirty-------------------------
    input wire  nocheck_dirty;
    //---------------cacheram interface--------------------
    output logic [CACHE_INDEXADDR_SIZE+CACHE_LINEADDR_SIZE-4-1:0] cacheram_addr;
    output logic  cacheram_ce;
    output logic  cacheram_we;
    output logic [BYTE_NUM-1:0] cacheram_bsel;
    output logic [DATA_WIDTH-1:0]cacheram_wdata;
    input        [DATA_WIDTH-1:0]cacheram_qdata;
    //----------------command interface--------------------
    input wire                          refersh_req, reload_req;
    input wire [CACHE_PADDR_SIZE-1:0]   reload_addr;
    output logic                        refersh_done, reload_done;
    output logic                        refersh_fault, reload_fault;
    //----------------tagram interface-------------------
    output logic [CACHE_INDEXADDR_SIZE-1:0] tagram_addr;
    output logic  tagram_ce;
    output logic  tagram_we;
    output logic  [TAGADDR_SIZE-1:0] tagram_wdata;
    input         [TAGADDR_SIZE-1:0] tagram_qdata;

    input [CACHE_LINE_NUM-1:0] linestate_dirty, linestate_valid;
//---------------------biu interface------------------------
    input wire                          biu_error;
    input wire                          biu_write_done;
    input wire                          biu_rvalid;
    input wire                          biu_wready;
    output wire                         biu_wvalid;
    output wire                         biu_readline_req;
    output wire                         biu_writeline_req;
    output wire [CACHE_PADDR_SIZE-1:0]  biu_addr;
    output wire [DATA_WIDTH-1:0]        biu_wdata;
    input wire [DATA_WIDTH-1:0]         biu_rdata;
//--------------------reload address seprate-----------
    wire [TAGADDR_SIZE-1:0]         reload_tag;
    wire [CACHE_INDEXADDR_SIZE-1:0] reload_index;
assign reload_tag = reload_addr[CACHE_PADDR_SIZE-1: CACHE_PADDR_SIZE-TAGADDR_SIZE];
assign reload_index=reload_addr[CACHE_PADDR_SIZE-TAGADDR_SIZE-1 : CACHE_LINEADDR_SIZE];
//--------------------counter--------------------
    reg [CACHE_LINEADDR_SIZE-CACHE_BYTEADDR_SIZE-1:0] r_beat_counter, w_beat_counter;   //w_beat_counter:计算写入cacheram拍数的计数器。r_beat_counter:计算从cacheram中读出数据拍数的计数器
    wire [CACHE_BYTEADDR_SIZE-1:0]  byte_offset;
    assign byte_offset = 0;
    reg [CACHE_INDEXADDR_SIZE-1:0]  index_counter;                      //计算索引值计数器
    reg [TAGADDR_SIZE-1:0] tag;
//--------------------state----------------------
    logic [3:0] state, state_next;
//--------------------wfifo ctrl signal--------------
    logic       wfifo_empty, wfifo_wen;
    logic       wfifo_rst;
always_ff @( posedge clk_i ) begin
    if(srst_i)begin
        state <= STATE_STD;
    end
    else begin
        state <= state_next;
    end
end
always_comb begin
    case(state)
        STATE_STD:begin
            if(refersh_req)begin
                state_next = nocheck_dirty?STATE_READY:STATE_READLINE; //如果不需要检查脏行，直接进入就绪状态
            end else if(reload_req)begin
                state_next = nocheck_dirty?STATE_RELOAD:STATE_READLINE;
            end
            else begin
                state_next = state;
            end
        end
        STATE_READLINE:begin
            if(linestate_valid[index_counter]&linestate_dirty[index_counter])begin
                state_next = (r_beat_counter==(BEAT_NUM-1))?STATE_WRITEBACK:state;  //行内偏移量计数器计到顶后，进入写行模式
            end else begin
                state_next = reload_req ?STATE_RELOAD: STATE_INCRINDEX;     //当前行不需要写回内存，直接进入reload模式
            end
        end
        STATE_WRITEBACK:begin
            if(biu_error)begin
                state_next = STATE_FAULT;
            end else if(biu_write_done)begin        //biu写内存完成
                if(reload_req)begin
                    state_next = STATE_RELOAD;    //如果是reaload请求，写回当前脏行之后进入装填模式
                end else begin
                    state_next = STATE_INCRINDEX;
                end
            end else begin
                state_next = state;
            end
        end
        STATE_INCRINDEX:begin
            state_next = (index_counter==(CACHE_LINE_NUM-1))?STATE_READY:STATE_READLINE;    //如果已经把所有line写进内存中，则进入ready状态，否则继续读下一行
        end
        STATE_RELOAD:begin
            state_next = biu_error ? STATE_FAULT : (w_beat_counter==(BEAT_NUM-1)&biu_rvalid)?STATE_READY:state;
        end
        STATE_READY: state_next = STATE_STD;
        STATE_FAULT: state_next = STATE_STD;
    endcase
end
//---------------------计数器-----------------------
always_ff @( posedge clk_i ) begin
    if(srst_i)begin
        r_beat_counter <= 0;
    end else begin
        case(state)
            STATE_READLINE: r_beat_counter <= r_beat_counter + 1;
            default: r_beat_counter <= 0;
        endcase
    end
    if(srst_i)begin
        w_beat_counter <= 0;
    end else begin
        case(state)
            STATE_RELOAD: w_beat_counter <= biu_rvalid ? (w_beat_counter+1) : w_beat_counter;
            default: w_beat_counter <= 0;
        endcase
    end
    if(srst_i)begin
        index_counter <= 0;
    end else begin
        case(state)
            STATE_STD: index_counter <= reload_req ? reload_index : 0;
            STATE_INCRINDEX: index_counter <= index_counter + 1;
        endcase
    end
end
always_ff @( posedge clk_i ) begin
    if(wfifo_wen)begin
        tag <= tagram_qdata;
    end
end
always_ff @( posedge clk_i ) begin
    if(srst_i)begin
        wfifo_wen <= 0;
    end
    else begin
        wfifo_wen <= (state==STATE_READLINE);   //因为cacheram数据要比地址延后一拍，因此wen也延后一拍
    end
end
assign wfifo_rst = (state==STATE_STD) | (state==STATE_INCRINDEX);   //在每次写FIFO前将FIFO清空避免出现错误数据
//------------------cacheline fifo------------------
fifo1r1w#(
    .DWID           (DATA_WIDTH),
    .DDEPTH         (BEAT_NUM)
)wfifo(
    .clk            (clk_i),
    .rst            (srst_i|wfifo_rst),
    .ren            (biu_wready),
    .wen            (wfifo_wen),
    .wdata          (cacheram_qdata),
    .rdata          (biu_wdata),
    .full           (),                 //因为FIFO大小是cache行大小，因此不需要判断满
    .empty          (wfifo_empty)
);
//------------------cacheram signal----------------------
assign cacheram_addr = {index_counter,((state==STATE_RELOAD)?w_beat_counter:r_beat_counter)};
assign cacheram_ce   = 1'b1;
assign cacheram_we   = (state==STATE_RELOAD) & biu_rvalid;
assign cacheram_bsel = 'hffff;
assign cacheram_wdata= biu_rdata;
//------------------tagram signal--------------------------
assign tagram_addr = index_counter;
assign tagram_ce   = 1'b1;
assign tagram_wdata= reload_tag;
assign tagram_we   = (state==STATE_RELOAD);
//-------------------biu interface--------------------------
assign biu_readline_req = (state==STATE_RELOAD);
assign biu_writeline_req= (state==STATE_WRITEBACK);
assign biu_addr = (state==STATE_WRITEBACK)?{tag,index_counter,6'b0}:{reload_tag,reload_index,6'b0}; //TODO:这里把line大小写死为64字节，之后改
assign biu_wvalid=!wfifo_empty & (state==STATE_WRITEBACK);
//-----------------command interface------------------------
assign reload_done = (state==STATE_READY) & reload_req;
assign refersh_done= (state==STATE_READY) & refersh_req;
assign reload_fault= (state==STATE_FAULT) & reload_req;
assign refersh_fault=(state==STATE_FAULT) & refersh_req;
endmodule