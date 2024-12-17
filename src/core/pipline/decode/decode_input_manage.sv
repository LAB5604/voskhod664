`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022                                                                              //
//  Author  : Jack.Pan                                                                          //
//  Desc    : Decode unit input manage, generate hand-shake and validwork manage for this unit  //
//                                                                                              //
//  Version : 0.0(file initialize)                                                              //
//////////////////////////////////////////////////////////////////////////////////////////////////
module decode_input_manage(
    input  wire                 clk_i,
    input  wire                 arst_i,

    pip_ifu_interface.slave     decode_input,

    pip_flush_interface.slave   pip_flush_sif,

    output logic [31:0]         instr0_o,       instr1_o,
    output logic [`XLEN-1:0]    instr0_pc_o,    instr1_pc_o,
    output logic                instr0_valid_o, instr1_valid_o,
    input logic                 instr0_ready_i, instr1_ready_i

);

    reg         next_flag;          //current fetch group need 2-cycle to decode, rather than 1
    logic [3:0] instr0_sel, instr1_sel, instr0_sel_final, instr1_sel_final;
    logic [3:0] validword_cnt;      //fetchgroup中有多少有效指令
    reg   [3:0] step_count;         //指令计数

//------------------------------------ERROR display-------------------------------
`ifdef DECODE_ERROR_REPORT
    always@(posedge clk_i)begin
        if(decode_input.valid)begin
            case(decode_input.validword)
                4'b0001, 4'b0011, 4'b0111, 4'b1111, 4'b0010, 4'b0110, 4'b1110, 4'b0100, 4'b1100, 4'b1000:
                begin

                end
                default :
                begin
                    $display("DECODE ERROR : invalid validword in fetch group, validwork=%b", decode_input.validword);
                end
            endcase
        end
    end
`endif

always_comb begin
    //--------------------计算fetchgroup中有多少有效指令----------------------
    case(decode_input.validword)
        4'b0001, 4'b0010, 4'b0100, 4'b1000: validword_cnt = 1;
        4'b0011, 4'b0110, 4'b1100:          validword_cnt = 2;
        4'b0111, 4'b1110:                   validword_cnt = 3;
        4'b1111:                            validword_cnt = 4;
        default :                           validword_cnt = 0;
    endcase
    //--------------------generate instruction0/1 select--------------------
    if(decode_input.valid)begin
        case(decode_input.validword)
            4'b0001, 4'b0011, 4'b0111, 4'b1111:
            begin
                case(step_count)
                    4'h0:
                    begin
                        instr0_sel = 4'b0001;
                        instr1_sel = 4'b0010;
                    end
                    4'h1:
                    begin
                        instr0_sel = 4'b0010;
                        instr1_sel = 4'b0100;
                    end
                    4'h2:
                    begin
                        instr0_sel = 4'b0100;
                        instr1_sel = 4'b1000;
                    end
                    4'h3:
                    begin
                        instr0_sel = 4'b1000;
                        instr1_sel = 4'b0000;
                    end
                    default:
                    begin
                        instr0_sel = 4'b0000;
                        instr1_sel = 4'b0000;
                    end
                endcase
            end
            4'b0010, 4'b0110, 4'b1110:
            begin
                case(step_count)
                    4'h0:
                    begin
                        instr0_sel = 4'b0010;
                        instr1_sel = 4'b0100;
                    end
                    4'h1:
                    begin
                        instr0_sel = 4'b0100;
                        instr1_sel = 4'b1000;
                    end
                    4'h2:
                    begin
                        instr0_sel = 4'b1000;
                        instr1_sel = 4'b0000;
                    end
                    default:
                    begin
                        instr0_sel = 4'b0000;
                        instr1_sel = 4'b0000;
                    end
                endcase
            end
            4'b0100, 4'b1100:
            begin
                case(step_count)
                    4'h0:
                    begin
                        instr0_sel = 4'b0100;
                        instr1_sel = 4'b1000;
                    end
                    4'h1:
                    begin
                        instr0_sel = 4'b1000;
                        instr1_sel = 4'b0000;
                    end
                    default:
                    begin
                        instr0_sel = 4'b0100;
                        instr1_sel = 4'b1000;
                    end
                endcase
            end
            4'b1000:
            begin
                case(step_count)
                    4'h0:
                    begin
                        instr0_sel = 4'b1000;
                        instr1_sel = 4'b0000;
                    end
                    default:
                    begin
                        instr0_sel = 4'b0000;
                        instr1_sel = 4'b0000;
                    end
                endcase
            end
            default :
            begin
                instr0_sel = 4'b0000;
                instr1_sel = 4'b0000;
            end
        endcase
    end
    else begin          //current input is not valid, select nothing
        instr0_sel = 4'b0000;
        instr1_sel = 4'b0000;
    end
end
    assign instr0_sel_final = instr0_sel;
    assign instr1_sel_final = instr1_sel;
always_comb begin
    //------------------------instruction0 select-----------------------
    case(instr0_sel_final)
        4'b0001:
        begin
            instr0_o        = decode_input.instr[31:0];
            instr0_pc_o     = decode_input.grouppc;
            instr0_valid_o  = decode_input.validword[0];
        end
        4'b0010:
        begin
            instr0_o        = decode_input.instr[63:32];
            instr0_pc_o     = decode_input.grouppc + 4;
            instr0_valid_o  = decode_input.validword[1];
        end
        4'b0100:
        begin
            instr0_o        = decode_input.instr[95:64];
            instr0_pc_o     = decode_input.grouppc + 8;
            instr0_valid_o  = decode_input.validword[2];
        end
        4'b1000:
        begin
            instr0_o        = decode_input.instr[127:96];
            instr0_pc_o     = decode_input.grouppc + 12;
            instr0_valid_o  = decode_input.validword[3];
        end
        default :
        begin
            instr0_o        = 'hx;
            instr0_pc_o     = 'hx;
            instr0_valid_o  = 1'b0;
        end
    endcase
end
always_comb begin
    //------------------------instruction0 select-----------------------
    case(instr1_sel_final)
        4'b0001:
        begin
            instr1_o        = decode_input.instr[31:0];
            instr1_pc_o     = decode_input.grouppc;
            instr1_valid_o  = decode_input.validword[0];
        end
        4'b0010:
        begin
            instr1_o        = decode_input.instr[63:32];
            instr1_pc_o     = decode_input.grouppc + 4;
            instr1_valid_o  = decode_input.validword[1];
        end
        4'b0100:
        begin
            instr1_o        = decode_input.instr[95:64];
            instr1_pc_o     = decode_input.grouppc + 8;
            instr1_valid_o  = decode_input.validword[2];
        end
        4'b1000:
        begin
            instr1_o        = decode_input.instr[127:96];
            instr1_pc_o     = decode_input.grouppc + 12;
            instr1_valid_o  = decode_input.validword[3];
        end
        default :
        begin
            instr1_o        = 'hx;
            instr1_pc_o     = 'hx;
            instr1_valid_o  = 1'b0;
        end
    endcase
end
always_comb begin
    //------------------------generate hand shake------------------------
    if(decode_input.valid)begin    
        if(decode_input.validword==4'b0000)begin
            decode_input.ready = 1'b1;
        end
        else if((step_count + (instr0_valid_o&instr0_ready_i) + (instr1_valid_o&instr1_ready_i))>=validword_cnt)begin
            decode_input.ready = 1'b1;
        end
        else begin
            decode_input.ready = 1'b0;
        end
    end
    else begin
        decode_input.ready = 1'b0;
    end
end

always_ff @ (posedge clk_i or posedge arst_i)begin
//------------------step counter记录当前fetchgroup中已经成功送到下一级的指令数量-------------
    if(arst_i)begin
        step_count <= 0;
    end
    else if((decode_input.valid & decode_input.ready) | pip_flush_sif.flush)begin
        step_count <= 0;
    end
    else begin
        step_count <= step_count + (instr0_valid_o&instr0_ready_i) + (instr1_valid_o&instr1_ready_i);
    end
end

endmodule