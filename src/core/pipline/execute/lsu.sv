`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
/*********************************************************************************

    Date    : 2022.10.18                                                                          
    Author  : Jack.Pan                                                                          
    Desc    : lsu for prv664                                            
    Version : 1.0 增加了itag表，用于cache查询每个访问id对应的itag值

********************************************************************************/
module lsu#(
    parameter IDLEN = 8
)(

    input wire                      clk_i,
    input wire                      arst_i,
    pip_flush_interface.slave       flush_slave,
    pip_exu_interface.lsu_sif       lsu_sif,                //从dispatch派遣到lsu
    pip_wb_interface.master         lsu_mif,                //从lsu写回到rob TODO: 从lsu写回到rob无握手，从lsu写回rob具备最高的优先级
    //--------------------to memory subsystem---------------------
    mmu_interface.master            mmu_access_mif,         //访问mmu
    output wire                     burnaccess,
    cache_return_interface.slave    cacheinterface_result   //从cache返回的值
);
    localparam  RUN = 1'b0,
                FLUSH=1'b1;

//------------------------from uop buffer--------------------
    logic [4:0]         opcode;
    logic [2:0]         funct3;          
    logic [6:0]         funct7;
    logic [19:0]        imm20;
    logic [`XLEN-1:0]   data1,  data2;          //operation data1 and data2
    logic [7:0]         itag;
    logic               ren;
    logic               empty;

//----------------------lsu state----------------------------
    //reg                 state;          //描述lsu当前状态，处于刷新周期还是正常运行

fifo1r1w#(
    .DWID           (`XLEN+`XLEN+20+5+7+3+8),
    .DDEPTH         (`LSU_UOP_BUFFER_DEEPTH)
)lsu_uop_buffer(
    .clk            (clk_i),
    .rst            (arst_i | flush_slave.flush),
    .ren            (ren),
    .wen            (lsu_sif.valid),
    .wdata          ({
                        lsu_sif.data1,
                        lsu_sif.data2,
                        lsu_sif.imm20,
                        lsu_sif.opcode,
                        lsu_sif.funct,
                        lsu_sif.itag
                    }),
    .rdata          ({
                        data1,
                        data2,
                        imm20,
                        opcode,
                        funct7,
                        funct3,
                        itag
                    }),
    .full           (lsu_sif.full),
    .empty          (empty)
);

//---------------------------------------------------access generate-----------------------------------------

always_comb begin
    //-----------------产生访问控制信号----------------------
    if(!empty & !flush_slave.flush)begin
        if( !mmu_access_mif.full & !empty)begin //FIXME: 
            mmu_access_mif.valid        = 1'b1;
            ren                         = 1'b1;
        end
        else begin                                  //当前访问队列已经满了，停止向arob中写项
            mmu_access_mif.valid        = 1'b0;
            ren                         = 1'b0;
        end
    end
    else begin
        mmu_access_mif.valid        = 1'b0;
        ren                         = 1'b0;
    end
    //----------------access port------------------
        mmu_access_mif.id           = itag;     //直接将指令itag传递到存储子系统中
    case(opcode)
        `OPCODE_LOAD, `OPCODE_LOADFP, `OPCODE_STORE, `OPCODE_STOREFP: mmu_access_mif.addr = data1 + {{44{imm20[19]}},imm20};
        `OPCODE_AMO: mmu_access_mif.addr = data1;
        default    : mmu_access_mif.addr = 'hx;
    endcase
        mmu_access_mif.data         = data2;
    case(opcode)
        `OPCODE_LOADFP: mmu_access_mif.opcode       = `OPCODE_LOAD;
        `OPCODE_STOREFP:mmu_access_mif.opcode       = `OPCODE_STORE;
        default :       mmu_access_mif.opcode       = opcode;
    endcase
        
        mmu_access_mif.funct        = {funct7, 1'b0, funct3[1:0]};
        mmu_access_mif.user         = {funct3, mmu_access_mif.addr};    //将这条指令包含的访存VA和funct3作为用户信号交给存储子系统一起传递
    
end

//-----------------------------存储子系统（storebuffer部分）刷新请求------------------------------
assign burnaccess = flush_slave.flush;
//----------------------------data buffer store address and opcode before dispatch----------------

//---------------------------pipline output----------------------------
always_ff@(posedge clk_i or posedge arst_i) begin
    if(arst_i)begin
        lsu_mif.valid <= 1'b0;
    end else if(flush_slave.flush)begin
        lsu_mif.valid <= 1'b0;
    end else begin
        lsu_mif.valid <= cacheinterface_result.valid;
    end
end
always_ff@(posedge clk_i)begin
    lsu_mif.itag  <= cacheinterface_result.id;
    case(cacheinterface_result.user[`CACHE_USER_W-1:`CACHE_USER_W-3])   //访问内存的funct3段被填充入user段，因此根据user段进行值裁剪
        `FUNCT3_8bit  : lsu_mif.data <= {{56{cacheinterface_result.rdata[7]}}, cacheinterface_result.rdata[7:0]};
        `FUNCT3_8bitU : lsu_mif.data <= {56'b0, cacheinterface_result.rdata[7:0]};
        `FUNCT3_16bit : lsu_mif.data <= {{48{cacheinterface_result.rdata[15]}}, cacheinterface_result.rdata[15:0]};
        `FUNCT3_16bitU: lsu_mif.data <= {48'b0, cacheinterface_result.rdata[15:0]};
        `FUNCT3_32bit : lsu_mif.data <= {{32{cacheinterface_result.rdata[31]}}, cacheinterface_result.rdata[31:0]};
        `FUNCT3_32bitU: lsu_mif.data <= {32'b0, cacheinterface_result.rdata[31:0]};
        `FUNCT3_64bit : lsu_mif.data <= cacheinterface_result.rdata;
        default       : lsu_mif.data <= 'hx;
    endcase

    lsu_mif.load_acc_flt  <= cacheinterface_result.error[`ERRORTYPE_BIT_LOADACCFLT];
    lsu_mif.load_addr_mis <= cacheinterface_result.error[`ERRORTYPE_BIT_LOADADDRMIS];
    lsu_mif.load_page_flt <= cacheinterface_result.error[`ERRORTYPE_BIT_LOADPAGEFLT];
    lsu_mif.store_acc_flt <= cacheinterface_result.error[`ERRORTYPE_BIT_STOREACCFLT];
    lsu_mif.store_addr_mis<= cacheinterface_result.error[`ERRORTYPE_BIT_STOREADDRMIS];
    lsu_mif.store_page_flt<= cacheinterface_result.error[`ERRORTYPE_BIT_STOREPAGEFLT];

    lsu_mif.mmio           <= cacheinterface_result.mmio;

end

endmodule