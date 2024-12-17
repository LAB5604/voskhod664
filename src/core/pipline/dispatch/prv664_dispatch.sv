`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022                                                                              //
//  Author  : Jack.Pan                                                                          //
//  Desc    : Dispatch unit for prv664 processor, it dispatch instructions into different       //
//            function unit, and check data realtive                                            //
//  Version : 1.0(scoreboard现在已支持全面暴露的寄存器busy接口)                                    //
//////////////////////////////////////////////////////////////////////////////////////////////////
module prv664_dispatch(

    input wire          clk_i,
    input wire          arst_i,
    pip_flush_interface.slave                       pip_flush_sif,              //flush signal

    pip_decode_interface.slave                      pip_decode_sif0,
    pip_decode_interface.slave                      pip_decode_sif1,

//--------------------read gpr, read csr, read scoreboard port-----------

    igpr_access_interface.master                    igpr_access_master0,        //for instruction0 access igpr
    igpr_access_interface.master                    igpr_access_master1,        //for instruction1 access igpr
    fgpr_access_interface.master                    fgpr_access_master,
    csr_access_interface.master                     csr_access_mster,
    scoreboard_update_interface.master              iscoreboard_update_master0,
    scoreboard_update_interface.master              iscoreboard_update_master1,
    scoreboard_update_interface.master              fscoreboard_update_master,
    cscoreboard_access_interface.master             cscoreboard_access_master,  //csr scoreboard access

    input wire [7:0] igpr_id_flag [31:0],           //目前来说没用
    input wire [7:0] fgpr_id_flag [31:0],           //目前来说没用
    input wire [31:0]igpr_busy_flag, fgpr_busy_flag,

//--------------------dispatch port to next stage------------------

    pip_exu_interface.bru_mif                       pip_dispbru_mif,
    pip_exu_interface.alu_mif                       pip_dispalu0_mif,       //fine, now we have two alu!
    pip_exu_interface.alu_mif                       pip_dispalu1_mif,
    pip_exu_interface.mdiv_mif                      pip_dispmdiv_mif,
    pip_exu_interface.fpu_mif                       pip_dispfpu_mif,
    pip_exu_interface.lsu_mif                       pip_displsu_mif,
    pip_exu_interface.bypass_mif                    pip_dispbypass_mif,
    pip_exu_interface.sysmanage_mif                 pip_dispsysman_mif

);

    logic instr_disp_ready_0, instr_disp_ready_1;               //instruction dispatch destenation is ready
    logic instr_reg_ready_0, instr_reg_ready_1;                //instr register is ready to use

    pip_decode_interface    instr0();           //instr0 is the oldest one in decode_queue
    pip_decode_interface    instr1();     
    
dispatch_input_manage               dispatch_input_manage(

    .clk_i                      (clk_i),
    .arst_i                     (arst_i),
    .flush_i                    (pip_flush_sif.flush),
    .pip_decode_sif0            (pip_decode_sif0),
    .pip_decode_sif1            (pip_decode_sif1),
    .instr0                     (instr0),
    .instr1                     (instr1)

);


//-------------------------------------------将源寄存器送往scoreboard进行判断--------------------------
always_comb begin    
    igpr_access_master0.rs1index        = instr0.rs1index;
    igpr_access_master0.rs2index        = instr0.rs2index;
    csr_access_mster.csrindex           = instr0.csrindex;

    igpr_access_master1.rs1index        = instr1.rs1index;
    igpr_access_master1.rs2index        = instr1.rs2index;

    fgpr_access_master.valid            = instr0.frs2en;
    fgpr_access_master.rs1index         = instr0.frs2index;         //fgpr only have 1 access port, so only index1 is avilible 
end
//---------------------------------------------将指令的必要信息写入scoreboard--------------------------------
always_comb begin
    iscoreboard_update_master0.write    = instr0.ready & instr0.rden & !(instr0.disp_dest==`DECODE_DISP_NONE);
    iscoreboard_update_master0.rdindex  = instr0.rdindex;
    iscoreboard_update_master0.itag     = instr0.itag;

    iscoreboard_update_master1.write    = instr1.ready & instr1.rden;
    iscoreboard_update_master1.rdindex  = instr1.rdindex;
    iscoreboard_update_master1.itag     = instr1.itag;

    fscoreboard_update_master.write     = instr0.ready & instr0.frden & !(instr0.disp_dest==`DECODE_DISP_NONE);
    fscoreboard_update_master.rdindex   = instr0.frdindex;
    fscoreboard_update_master.itag      = instr0.itag;

    cscoreboard_access_master.csren     = instr0.csren;
    cscoreboard_access_master.fflagen   = instr0.fflagen;
    cscoreboard_access_master.write     = instr0.ready & instr0.csren & !(instr0.disp_dest==`DECODE_DISP_NONE);
end
always_comb begin
//-------------------------------------------判断指令的寄存器是否就绪--------------------------------------------    
    if(instr0.valid)begin
        if(instr0.csren & cscoreboard_access_master.fcsr_busy | cscoreboard_access_master.csr_busy)begin   //如果csr正在被占用
            instr_reg_ready_0 = 1'b0;
        end
        else if(instr0.disp_dest==`DECODE_DISP_NONE) begin          //如果指令直接派遣到bypass，则不检查寄存器
            instr_reg_ready_0 = 1'b1;
        end
        else begin
            if(`RNM=="ENABLE")begin                 //重命名开，不需要判定目的寄存器是否被占用
            instr_reg_ready_0 = ! ((instr0.rs1en & igpr_busy_flag[instr0.rs1index]) |
                                    (instr0.rs2en & igpr_busy_flag[instr0.rs2index]) |
                                    (instr0.frs1en & fgpr_busy_flag[instr0.frs1index])|
                                    (instr0.frs2en & fgpr_busy_flag[instr0.frs2index])|
                                    (instr0.frs3en & fgpr_busy_flag[instr0.frs3index]));      //如果寄存器正在被使用，则等待
            end
            else begin      //重命名关，需要考虑目的寄存器是否被占用
            instr_reg_ready_0 = ! ((instr0.rs1en & igpr_busy_flag[instr0.rs1index]) |
                                    (instr0.rs2en & igpr_busy_flag[instr0.rs2index]) |
                                    (instr0.rden  & igpr_busy_flag[instr0.rdindex]) |
                                    (instr0.frs1en & fgpr_busy_flag[instr0.frs1index])|
                                    (instr0.frs2en & fgpr_busy_flag[instr0.frs2index])|
                                    (instr0.frs3en & fgpr_busy_flag[instr0.frs3index])|
                                    (instr0.frden  & fgpr_busy_flag[instr0.frdindex]));
            end
        end
        
        case(instr0.disp_dest)
            `DECODE_DISP_NONE   :   instr_disp_ready_0 = !pip_dispbypass_mif.full;
            `DECODE_DISP_SYSMAG :   instr_disp_ready_0 = !pip_dispsysman_mif.full;
            `DECODE_DISP_BRANCH :   instr_disp_ready_0 = !pip_dispbru_mif.full;
            `DECODE_DISP_SHORTINT:  instr_disp_ready_0 = !pip_dispalu0_mif.full;
            `DECODE_DISP_MULDIV :   instr_disp_ready_0 = !pip_dispmdiv_mif.full;
            `DECODE_DISP_LOADSTORE: instr_disp_ready_0 = !pip_displsu_mif.full;
            `DECODE_DISP_FPU :      instr_disp_ready_0 = !pip_dispfpu_mif.full;
            default :               instr_disp_ready_0 = 1'b0;
        endcase

    end
    else begin
        instr_reg_ready_0 = 1'b0;
        instr_disp_ready_0  = 1'b0;
    end
end

always_comb begin
    if(instr1.valid)begin
        if(instr1.csren | (instr1.disp_dest==`DECODE_DISP_FPU) | (instr1.disp_dest==`DECODE_DISP_LOADSTORE))begin      //指令1需要使用csr，或者请求使用FPU，不派遣
            instr_reg_ready_1 = 1'b0;
        end
        else if(!instr0.ready)begin       //指令0不能被派遣，则指令1也不能被派遣，避免乱序
            instr_reg_ready_1 = 1'b0;
        end
        else if(instr1.rs1en & instr0.rden & (instr1.rs1index==instr0.rdindex) |
                instr1.rs2en & instr0.rden & (instr1.rs2index==instr0.rdindex) |
                instr1.rden & instr0.rden & (instr1.rs2index==instr0.rdindex))begin   //指令1和0有寄存器相关性
            instr_reg_ready_1 = 1'b0;
        end
        else begin
            if(`RNM=="ENABLE")begin
            instr_reg_ready_1 = ! ((instr1.rs1en & igpr_busy_flag[instr1.rs1index]) |
                                    (instr1.rs2en & igpr_busy_flag[instr1.rs2index]));   //指令1不能被派遣给FPU，所以在这里不检查FGPR
            end
            else begin
            instr_reg_ready_1 = ! ((instr1.rs1en & igpr_busy_flag[instr1.rs1index]) |
                                    (instr1.rs2en & igpr_busy_flag[instr1.rs2index]) |
                                    (instr1.rden  & igpr_busy_flag[instr1.rdindex]));   //指令1不能被派遣给FPU，所以在这里不检查FGPR
            end
        end

        case(instr1.disp_dest)
            `DECODE_DISP_NONE   :   instr_disp_ready_1 = 1'b0;
            //`DECODE_DISP_BRANCH :   instr_disp_ready_1 = !pip_dispbru_mif.full;
            `DECODE_DISP_SHORTINT:  instr_disp_ready_1 = !pip_dispalu1_mif.full;     //因为机器除了ALU 其他所有部件只有1份，因此指令1只能用短alu
            //`DECODE_DISP_MULDIV :   instr_disp_ready_1 = !pip_dispmdiv_mif.full;
            //`DECODE_DISP_LOADSTORE: instr_disp_ready_1 = !pip_displsu_mif.full;
            //`DECODE_DISP_FPU :      instr_disp_ready_1 = !pip_dispfpu_mif.full;
            default :               instr_disp_ready_1 = 1'b0;
        endcase

    end
    else begin
        instr_reg_ready_1 = 1'b0;
        instr_disp_ready_1  = 1'b0;
    end
end

assign instr0.ready = instr_disp_ready_0 & instr_reg_ready_0;
assign instr1.ready = instr_disp_ready_1 & instr_reg_ready_1;

//---------------------------------------指令是否可以被正常派遣-----------------------------------------
always_comb begin
    
//--------------------------------------派遣端口选择----------------------------------------------------
    //-------BRU------------
    pip_dispbru_mif.data1   = igpr_access_master0.rs1data;
    pip_dispbru_mif.data2   = igpr_access_master0.rs2data;
    pip_dispbru_mif.pc      = instr0.pc;
    pip_dispbru_mif.imm20   = instr0.imm;
    pip_dispbru_mif.opcode  = instr0.opcode;
    pip_dispbru_mif.funct   = instr0.funct;
    pip_dispbru_mif.itag    = instr0.itag;
    pip_dispbru_mif.valid   = instr_reg_ready_0 & (instr0.disp_dest==`DECODE_DISP_BRANCH);
    //------------------ALU0------------------
    pip_dispalu0_mif.data1  =igpr_access_master0.rs1data;
    pip_dispalu0_mif.data2  =instr0.csren ? csr_access_mster.csrdata : igpr_access_master0.rs2data;
    pip_dispalu0_mif.imm20  =instr0.imm;
    pip_dispalu0_mif.opcode =instr0.opcode;
    pip_dispalu0_mif.funct  =instr0.funct;
    pip_dispalu0_mif.itag   =instr0.itag;
    pip_dispalu0_mif.valid  =instr_reg_ready_0 & (instr0.disp_dest==`DECODE_DISP_SHORTINT);
    //-----------------ALU1------------------
    pip_dispalu1_mif.data1  =igpr_access_master1.rs1data;
    pip_dispalu1_mif.data2  =igpr_access_master1.rs2data;
    pip_dispalu1_mif.imm20  =instr1.imm;
    pip_dispalu1_mif.opcode =instr1.opcode;
    pip_dispalu1_mif.funct  =instr1.funct;
    pip_dispalu1_mif.itag   =instr1.itag;
    pip_dispalu1_mif.valid  =instr_reg_ready_1 & (instr1.disp_dest==`DECODE_DISP_SHORTINT);
    //------MULDIV-------------
    pip_dispmdiv_mif.data1  = igpr_access_master0.rs1data;
    pip_dispmdiv_mif.data2  = igpr_access_master0.rs2data;
    pip_dispmdiv_mif.opcode = instr0.opcode;
    pip_dispmdiv_mif.funct  = instr0.funct;
    pip_dispmdiv_mif.itag   = instr0.itag;
    pip_dispmdiv_mif.valid  = instr_reg_ready_0 & (instr0.disp_dest==`DECODE_DISP_MULDIV);
    //----------------LSU-------------------
    pip_displsu_mif.data1  = igpr_access_master0.rs1data;
    pip_displsu_mif.data2  = instr0.frs2en ? fgpr_access_master.rs1data : igpr_access_master0.rs2data;
    pip_displsu_mif.imm20  = instr0.imm;
    pip_displsu_mif.opcode = instr0.opcode;
    pip_displsu_mif.funct  = instr0.funct;
    pip_displsu_mif.itag   = instr0.itag;
    pip_displsu_mif.valid  = instr_reg_ready_0 & (instr0.disp_dest==`DECODE_DISP_LOADSTORE);
    //---------------BYPASS----------------------
    pip_dispbypass_mif.itag= instr0.itag;
    pip_dispbypass_mif.valid=instr_reg_ready_0 & (instr0.disp_dest==`DECODE_DISP_NONE);
    //---------------SYSMANAGE-------------------
    pip_dispsysman_mif.itag = instr0.itag;
    pip_dispsysman_mif.valid= instr_reg_ready_0 & (instr0.disp_dest==`DECODE_DISP_SYSMAG);
    pip_dispsysman_mif.opcode=instr0.opcode;
    pip_dispsysman_mif.funct= instr0.funct;
    //----------------FPU-----------------
    pip_dispfpu_mif.data1       = igpr_access_master0.rs1data;
    pip_dispfpu_mif.frs1index   = instr0.frs1index;
    pip_dispfpu_mif.frs1en      = instr0.frs1en;
    pip_dispfpu_mif.frs2index   = instr0.frs2index;
    pip_dispfpu_mif.frs2en      = instr0.frs2en;
    pip_dispfpu_mif.frs3index   = instr0.frs3index;
    pip_dispfpu_mif.frs3en      = instr0.frs3en;
    pip_dispfpu_mif.imm5        = instr0.imm;
    pip_dispfpu_mif.opcode      = instr0.opcode;
    pip_dispfpu_mif.funct       = instr0.funct;
    pip_dispfpu_mif.itag        = instr0.itag;
    pip_dispfpu_mif.valid       = instr_reg_ready_0 & (instr0.disp_dest==`DECODE_DISP_FPU);

end


endmodule