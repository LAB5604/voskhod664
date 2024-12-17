/*
    Return Address Stack
*/ 
`include"timescale.v"
module ras
#(
    parameter WIDTH     = 64,
              DEEPTH    = 8
)
(
    input   wire                    clk_i,
    input   wire                    rst_i,

    input   wire                    ras_pop_i,
    input   wire                    ras_push_i,
    /*
	input   wire                    ras_jalr_flag_i,
    input   wire    [04:00]         ras_rs1_id_i,
    input   wire    [04:00]         ras_rd_id_i,
    */
    input   wire    [WIDTH-1:00]    ras_addr_i,
    output  wire                    ras_empty_o,
    output  wire                    ras_full_o,
	output  wire    [WIDTH-1:00]    ras_addr_o
);
    localparam      PTR_WIDTH = $clog2(DEEPTH);
    /*
    //
    wire                jalr            =   ras_jalr_flag_i;
    wire    [03:00]     rs1_id          =   {ras_rs1_id_i[04:03],ras_rs1_id_i[01:00]};
    wire    [03:00]     rd_id           =   {ras_rd_id_i[04:03],ras_rd_id_i[01:00]};
    //
    wire                rs1_eq_rd       =   ~(ras_rs1_id_i[2]  ^  ras_rd_id_i[2]);
    wire                rs1_link        =   rs1_id  ==  4'b1;
    wire                rd_link         =   rd_id   ==  4'b1;
    //
    wire                push_only       =   jalr &   (   rd_link  &   ((~rs1_link) | (rs1_link & rs1_eq_rd))  );
    wire                pop_only        =   jalr &   ( (~rd_link) &   rs1_link                              );
    */

    wire                push_only       =   ras_push_i;
    wire                pop_only        =   ras_pop_i;

    //  ras
    reg     [WIDTH-1:00]    ras[DEEPTH-1:00];

//-------------------------------------------------------------pointers----------------------------------------------------------------------
    //  ras sp adder
    //  the ras is a recycle struct,if overflow,the new item will replace the oldest item
    reg     [PTR_WIDTH-1:00]     sp;     
    wire    [PTR_WIDTH-1:00]     sp_adder_operand;                         
    wire    [PTR_WIDTH-1:00]     sp_adder_res;
    
    assign  sp_adder_operand    =   (push_only | pop_only) ? {{PTR_WIDTH-1{pop_only}},1'b1} : 'd0; 
    assign  sp_adder_res        =   sp + sp_adder_operand;

    always @( posedge clk_i or negedge rst_i) begin
        if( !rst_i ) begin
            sp      <=  'd0;
        end
        else    begin
			if	(push_only | pop_only)	begin
				sp  <=  sp_adder_res;
			end
        end
    end

    //  rd & wr pointer
    wire    [PTR_WIDTH-1:00]     wr_ptr  =   sp + 'd1;     //  push            :   write pointer
    wire    [PTR_WIDTH-1:00]     rd_ptr  =   sp;     //  pop             :   read pointer

//------------------------------------------------------------------ras push & ras pop--------------------------------------------------------
    wire    [WIDTH-1:00]    temp_out_data =  ras[rd_ptr];

    always @(posedge clk_i ) begin
        if ( push_only ) begin
            ras[wr_ptr] <=  ras_addr_i + {{WIDTH-3{1'b0}},3'b100};
        end
    end
    
//-------------------------------------------------------------------ras empty & ras full-------------------------------------------------------------
    reg     [PTR_WIDTH:00]  ras_cnt;
    wire    [PTR_WIDTH:00]  ras_cnt_adder_operand2 = {{PTR_WIDTH{pop_only}},1'b1};
    wire    [PTR_WIDTH:00]  ras_cnt_adder_res = ras_cnt + ras_cnt_adder_operand2;
    //
    always @(posedge clk_i or negedge rst_i ) begin
        if( !rst_i ) begin
            ras_cnt <= 'd0;
        end
        else begin
            if ( push_only ) begin
                if( ras_cnt == {1'b1,{PTR_WIDTH{1'b0}}} )
                    ras_cnt <=  ras_cnt;
                else
                    ras_cnt <=  ras_cnt_adder_res;
            end
            else if( pop_only ) begin
                if( ras_cnt == 'd0 )
                    ras_cnt <= ras_cnt;
                else
                    ras_cnt <=  ras_cnt_adder_res;
            end
            else
                ras_cnt <= ras_cnt;
        end
    end

    assign  ras_empty_o =   ~ ( |ras_cnt );
    assign  ras_full_o  =   ras_cnt == {1'b1,{PTR_WIDTH{1'b0}}};
//--------------------------------------------------------------------------Output--------------------------------------------------------------
    assign  ras_addr_o      =   temp_out_data; //pop_only ? temp_out_data : 'd0;    //TODO: 确认这个能这样改

endmodule