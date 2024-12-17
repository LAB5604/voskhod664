module hp_int_div #(
    parameter DIV_WIDTH = 65                     //除法器位宽
)(
    input  wire clk,
    input  wire rst,
//输入
    input  wire [DIV_WIDTH-1:0] su_dived_i,     //有符号、无符号被除数
    input  wire [DIV_WIDTH-1:0] su_divor_i,     //有符号、无符号除数
    input  wire signed_en,                      //有符号除法标志
    input  wire div_in_valid,                   //输入数据有效，除法期间需持续拉高
    output reg  div_in_ready,                   //准备好接收
//输出
    output wire [DIV_WIDTH-1:0] div_res_data,   //商，符号位由输入决定
    output wire [DIV_WIDTH-1:0] div_rem_data,   //余数，符号位由输入决定
    output reg  div_out_valid,                  //输出数据有效
    input  wire div_out_ready                   //准备好接收
);

wire div_in_hsk  = div_in_ready  & div_in_valid ;//除法器输入握手
wire div_out_hsk = div_out_ready & div_out_valid;//除法器输出握手

wire [DIV_WIDTH-1:0] su_dived_neg = {1'b0, (~su_dived_i[DIV_WIDTH-2:0])} + 1 ;//有符号负被除数取模
wire [DIV_WIDTH-1:0] su_dived_orm = (su_dived_i[DIV_WIDTH-1]==1'b1 && signed_en) ? su_dived_neg : su_dived_i;//被除数取模，原码
wire [DIV_WIDTH-1:0] su_divor_neg = {1'b0, (~su_divor_i[DIV_WIDTH-2:0])} + 1 ;//有符号负被除数取模
wire [DIV_WIDTH-1:0] su_divor_orm = (su_divor_i[DIV_WIDTH-1]==1'b1 && signed_en) ? su_divor_neg : su_divor_i;//被除数取模，原码

wire div_in_equ;//输入值与上一次相同，加速
wire divor_in_zero;//除数为0

localparam ITER_MAX = DIV_WIDTH-1;//除法器最大迭代次数
localparam CNT_WIDTH = clogb2(ITER_MAX);//迭代计数器位宽
reg [CNT_WIDTH-1:0] iter_cnt;//迭代值计数器
wire [CNT_WIDTH:0] iter_cnt_nx;//下一次的迭代值

reg [DIV_WIDTH-1:0] dived_r;//被除数寄存器
reg [DIV_WIDTH-1:0] last_dived_r;//上一次被除数寄存器
reg [DIV_WIDTH-1:0] divor_r;//除数寄存器
reg [DIV_WIDTH-1:0] last_divor_r;//上一次被除数寄存器
reg [1:0]sign_ed_or;//被、除数符号位寄存
reg [1:0]last_sign_ed_or;//被、除数符号位寄存r
//reg [1:0]last_sign_ed_or;//上一次被、除数符号位寄存
reg signed_r;//有符号除法标志寄存器
reg last_signed_r;//上一次有符号除法标志寄存器
reg [DIV_WIDTH-1:0] div_res_r;//商寄存器
reg [DIV_WIDTH-1:0] div_rem_r;//余数寄存器
wire [DIV_WIDTH-1:0] div_res_negs;//负数有符号商结果
wire [DIV_WIDTH-1:0] div_rem_negs;//负数有符号余数结果


wire [DIV_WIDTH-1:0] dived_shift_res;//被除数移位结果
wire [DIV_WIDTH-1:0] divor_shift_res;//除数移位结果
wire [DIV_WIDTH-1:0] dived_sub_res;//被除数 减 除数移位结果 的结果

reg [CNT_WIDTH:0] dived_lz;//被除数前导0计数
reg [CNT_WIDTH:0] divor_lz;//除数前导0计数


wire divored_cmp_res;//迭代比较结果，1:被除数移位结果 大于 除数，减后迭代，0:被除数移位结果 小于等于 除数，迭代

assign div_in_equ = (dived_r==last_dived_r && divor_r==last_divor_r && signed_r==last_signed_r && sign_ed_or==last_sign_ed_or) ? 1'b1 : 1'b0;//输入值与上一次相同，加速
assign divor_in_zero = divor_r == 0;

assign dived_shift_res = dived_r >> iter_cnt;//被除数移位结果
assign divor_shift_res = divor_r << iter_cnt;//除数移位结果，用于减计算
assign dived_sub_res   = dived_r - divor_shift_res;//被除数 减 除数移位结果 的结果
wire [DIV_WIDTH-1:0] dived_wb_res;

assign div_res_negs = {1'b1, (~div_res_r[DIV_WIDTH-2:0])}+1;//负数有符号商结果
assign div_rem_negs = {1'b1, (~div_rem_r[DIV_WIDTH-2:0])}+1;//负数有符号余数结果
assign div_res_data = (signed_r && (^last_sign_ed_or)) ? div_res_negs : div_res_r;
assign div_rem_data = (signed_r && last_sign_ed_or[1]) ? div_rem_negs : div_rem_r;

reg [CNT_WIDTH:0]i;
always @(*) begin //计算 待写回被除数 的前导0，每次迭代都进行
    dived_lz = DIV_WIDTH;
    for (i=0 ; i <=DIV_WIDTH-1 ; i=i+1 ) begin
        if(dived_wb_res[DIV_WIDTH-1-i] && dived_lz==DIV_WIDTH)
            dived_lz = i;
        else
            dived_lz = dived_lz;
    end
end
always @(*) begin //计算 除数 的前导0，仅开始状态计算
    divor_lz = DIV_WIDTH;
    for (i=0 ; i <=DIV_WIDTH-1 ; i=i+1 ) begin
        if(divor_r[DIV_WIDTH-1-i] && divor_lz==DIV_WIDTH)
            divor_lz = i;
        else
            divor_lz = divor_lz;
    end
end
assign iter_cnt_nx = divored_cmp_res ? ((divor_lz > dived_lz) ? (divor_lz - dived_lz) : {(1+CNT_WIDTH){1'b0}}) : {1'b0, iter_cnt} - {{(CNT_WIDTH){1'b0}}, 1'b1};//生成下一次迭代值

assign divored_cmp_res = dived_shift_res >= divor_r;//迭代比较结果，1:被除数移位结果 大于等于 除数，减后迭代，0:被除数移位结果 小于 除数，迭代
assign dived_wb_res = divored_cmp_res?dived_sub_res:dived_r;

//除法器FSM
localparam ST_IDLE = 4'b0001;//初始状态，等待除法器启动
localparam ST_ACSN = 4'b0010;//迭代预加速，符号位转换
localparam ST_ITER = 4'b0100;//除法迭代
localparam ST_SNED = 4'b1000;//符号位转换，输出结果

reg [3:0] cu_st,nx_st;//当前状态，下一状态

//状态迭代
always @(posedge clk) begin
    if(rst) begin
        cu_st <= ST_IDLE;
    end
    else begin
        cu_st <= nx_st;
    end
end

//状态转移
always @(*) begin
    case (cu_st)
        ST_IDLE: begin
            if(div_in_hsk)//输入握手
                nx_st = ST_ACSN;
            else
                nx_st = ST_IDLE;
        end
        ST_ACSN: begin
            if(div_in_equ || divor_r==0)//输入与上次相同，或被除数=0
                nx_st = ST_SNED;
            else//不同
                nx_st = ST_ITER;
        end
        ST_ITER: begin
            if(iter_cnt != 0)//迭代中
                nx_st = ST_ITER;
            else
                nx_st = ST_SNED;
        end
        ST_SNED: begin
            if (div_out_hsk)//输出握手
                nx_st = ST_IDLE;
            else
                nx_st = ST_SNED;
        end
        default: nx_st = ST_IDLE;
    endcase
end

//状态输出
always @(*) begin
    div_in_ready  = 1'b0;
    div_out_valid = 1'b0;

    case (cu_st)
        ST_IDLE: begin
            div_in_ready  = 1'b1;
            div_out_valid = 1'b0;
        end
        ST_ACSN: begin
            div_in_ready  = 1'b0;
            div_out_valid = 1'b0;
        end
        ST_ITER: begin
            div_in_ready  = 1'b0;
            div_out_valid = 1'b0;
        end
        ST_SNED: begin
            div_in_ready  = 1'b0;
            div_out_valid = 1'b1;
        end
        default: ;
    endcase
end

//状态-写寄存器
always @(posedge clk) begin
    case (cu_st)
        ST_IDLE: begin
            iter_cnt <= ITER_MAX;
            dived_r <= su_dived_orm;//锁存到迭代寄存器
            divor_r <= su_divor_orm;
            signed_r <= signed_en;
            sign_ed_or <= {su_dived_i[DIV_WIDTH-1], su_divor_i[DIV_WIDTH-1]};
        end
        ST_ACSN: begin
            case ({div_in_equ, divor_in_zero})
                2'b00 : begin//计算
                    div_rem_r <= dived_r;
                    div_res_r <= 0;
                    last_divor_r <= divor_r;//记录上一次的除数
                end
                2'b01 : begin//0除
                    div_rem_r <= dived_r;
                    div_res_r <= signed_r ? (sign_ed_or[1]?1:-1) : -1;//生成商
                    last_divor_r <= divor_r;//记录上一次的除数
                end
                2'b10 : begin//跳
                    //div_rem_r <= dived_r;//覆盖上一次余数
                    //div_res_r <= signed_r ? 1 : -1;//生成商
                    //last_divor_r <= 0;//记录上一次的除数
                end
                2'b11 : begin//跳
                    //div_rem_r <= dived_r;//覆盖上一次余数
                    //div_res_r <= signed_r ? 1 : -1;//生成商
                    //last_divor_r <= 0;//记录上一次的除数
                end
            endcase
            last_sign_ed_or <= sign_ed_or;
            last_dived_r <= dived_r;
            last_signed_r <= signed_r;
            //iter_cnt <= iter_cnt_nx[CNT_WIDTH-1:0];
        end
        ST_ITER: begin
            div_res_r[iter_cnt] <= divored_cmp_res;//写商
            iter_cnt <= (iter_cnt != iter_cnt_nx[CNT_WIDTH-1:0])?iter_cnt_nx[CNT_WIDTH-1:0]:iter_cnt_nx[CNT_WIDTH-1:0]-{{(CNT_WIDTH-1){1'b0}}, 1'b1};//迭代
            if(divored_cmp_res) begin//写回
                dived_r <= dived_sub_res;
                div_rem_r <= dived_sub_res;
            end
        end
        ST_SNED: begin
            iter_cnt <= 0;
            

        end
        default: ;
    endcase
end


initial begin
    last_dived_r <= 0;
    last_divor_r <= 0;
    last_signed_r <= 0;
    last_sign_ed_or <= 0;
    div_res_r <= 0;
    div_rem_r <= 0;
    signed_r  <= 0;
end


function integer clogb2;//计算log2
    input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
endfunction

endmodule