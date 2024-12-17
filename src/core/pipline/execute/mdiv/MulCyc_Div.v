`include "timescale.v"
module MulCyc_Div
	#(
		parameter DIV_WIDTH=32,
		UNROLL_COEFF=0
	)
	(
	input 					clk,
	input 					rst,
	input 					flush,
	input 					start,
	input 					stall,
	input wire 				sign,		//1:输入值都当作有符号数，0：输入值都当作无符号数
	input [DIV_WIDTH-1:0]	DIVIDEND,	//被除数
	input [DIV_WIDTH-1:0]	DIVISOR,	//除数
	
	output wire[DIV_WIDTH-1:0]DIV,		//商
	output wire[DIV_WIDTH-1:0]MOD,		//余数
	output 					div_idle, 	//Calculate done
	output reg 				calc_done
	);
	localparam IDLE = 2'd0;
	localparam CALC = 2'd1;
	localparam FINISH = 2'd2;
	localparam DONE = 2'd3;
	localparam UNROLL_STAGE=(UNROLL_COEFF==0)?1:(2**UNROLL_COEFF);
	localparam STEP_NUM=DIV_WIDTH/UNROLL_STAGE;
	localparam STEP_WID=$clog2(STEP_NUM);
	reg [1:0]			state,state_next;
	reg [STEP_WID:0]	step_cnt;
	reg [2*DIV_WIDTH-1:0]middle;
	reg [DIV_WIDTH-1:0]	diver_hold;
	reg [1:0]			sign_hold;		//被除数符号、除数符号寄存
	reg                 sign_flag;		//有符号运算标志位
	wire [DIV_WIDTH-1:0]try_remain;
	reg [DIV_WIDTH-1:0] rem, res;

	wire [DIV_WIDTH-1:0] dived_neg;
	wire [DIV_WIDTH-1:0] dived_orm;

	assign dived_neg = {1'b0, (~DIVIDEND[DIV_WIDTH-2:0])} + 1 ;//有符号负被除数取模
	assign dived_orm = (DIVIDEND[DIV_WIDTH-1]==1'b1 && sign) ? dived_neg : DIVIDEND;//被除数取模，原码
	wire [DIV_WIDTH-1:0] divor_orm;
	wire [DIV_WIDTH-1:0] divor_neg;
	assign divor_neg = {1'b0, (~DIVISOR[DIV_WIDTH-2:0])} + 1 ;//有符号负被除数取模
	assign divor_orm = (DIVISOR[DIV_WIDTH-1]==1'b1 && sign) ? divor_neg : DIVISOR;//被除数取模，原码

	wire [DIV_WIDTH-1:0] res_negs;
	wire [DIV_WIDTH-1:0] rem_negs;
	assign res_negs = {1'b1, (~res[DIV_WIDTH-2:0])}+1;//负数有符号商结果
	assign rem_negs = {1'b1, (~rem[DIV_WIDTH-2:0])}+1;//负数有符号余数结果
	assign DIV 	 = (sign_flag && (^sign_hold)) ? res_negs : res;
	assign MOD 	 = (sign_flag && sign_hold[1]) ? rem_negs : rem;

	wire can_minus;
	always@(posedge clk or posedge rst)
		if(rst)
			state<=IDLE;
		else 
			state<=state_next;
	always@(*)
	begin
	  	case(state)
			IDLE:
				if(start)
					state_next=CALC;
				else 
					state_next=IDLE;
			CALC:
				if(flush)
					state_next=IDLE;
				else if(step_cnt==STEP_NUM-1)
					state_next=DONE;
				else 
					state_next=CALC;
			DONE:
				if(flush)
					state_next=IDLE;
				else
					state_next=FINISH;
			FINISH:
				if(stall)state_next=FINISH;
				else state_next=IDLE;
			default:
				state_next=IDLE;
		endcase
	end

	always@(posedge clk or posedge rst)//SCNT
	if(rst) 
		step_cnt<=0;
	else if(state==CALC)
		step_cnt<=step_cnt+1;
	else 
		step_cnt<=0;

	assign div_idle=(state==IDLE || state==FINISH);
	
	assign can_minus=(middle[2*DIV_WIDTH-1:DIV_WIDTH] >= diver_hold);
	assign try_remain=(can_minus)? (middle[2*DIV_WIDTH-1:DIV_WIDTH] - diver_hold) : middle[2*DIV_WIDTH-1:DIV_WIDTH];

	always@(posedge clk)
	if(state==CALC)
	begin
		middle<={{try_remain[DIV_WIDTH-2:0],middle[DIV_WIDTH-1:0]},can_minus};//(  )+
		diver_hold<=diver_hold;
	end
	else
	if(state==DONE)
	begin
		middle<=middle;
	  	diver_hold<=diver_hold;
	end
	else
	begin 
		middle<={{DIV_WIDTH{1'b0}},dived_orm};
		sign_hold <= {DIVIDEND[DIV_WIDTH-1], DIVISOR[DIV_WIDTH-1]};		//保存符号位
		sign_flag <= sign;
		diver_hold<=divor_orm;
	end

	always@(posedge clk)
	if(state_next==FINISH)
	begin
		calc_done<=1'b1;
		rem<=try_remain;
		res<={ middle[DIV_WIDTH-2:0],can_minus };
	end
	else 
	begin
		calc_done<=1'b0;
		rem <= rem;
		res <= res;
	end

endmodule

