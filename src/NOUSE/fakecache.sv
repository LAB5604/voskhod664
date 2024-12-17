`include "prv664_bus_define.svh"
`include "riscv_define.svh"
`include "prv664_define.svh"
`include "prv664_config.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) fake cache module(NO CACHE)
    Author  : Jack.Pan
    Date    : 2023/2/14
    Version : 0.0 file initial

                            NOTE
    This module just convert cpu internal access to axi access, NO cache inside at all
    读访问：固定在AXI上产生2拍，共128bit访问，读取对齐的128位数据。
    写访问：最大写64位。

***********************************************************************************************/
module fakecache(
    input wire                      clk,
    input wire                      rst,
    //------------cpu manage interface-----------
    input wire                      cache_flush_req,
    output wire                     cache_flush_ack,
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
    localparam STATE_IDLE       = 4'h0,
               STATE_READ_ADDR  = 4'h1,     //read address 
               STATE_READ_PEND0 = 4'h2,     //read data pending first data
               STATE_READ_PEND1 = 4'h3,     //read data pending second data
               STATE_WRITE_ADDR = 4'h4,
               STATE_WRITE_DATA = 4'h5,
               STATE_WRITE_PEND = 4'h6,
               STATE_READY      = 4'h7;
    //------------access from command buffer--------------
    logic [7:0]       access_id;
    logic [`XLEN-1:0] access_addr, access_wdata;    //注意，这里的数据是右对齐的
    logic             access_ci, access_wt;
    logic [4:0]       access_opcode;
    logic [6:0]       access_funct7;
    logic [2:0]       access_funct3;
    logic [5:0]       access_error;
    logic             empty,    ren;
    //---------------state machine----------------------
    logic [3:0]         state, state_next;
    //---------------to axi interface-------------------
    logic [7:0]         toaxi_bsel;
    logic [`XLEN-1:0]   toaxi_wdata;
    //---------------from axi---------------------------
    logic [`XLEN-1:0]   frmaxi_rdata_l64, frmaxi_rdata_h64;

fifo1r1w#(
    .DWID       (8+64+64+1+1+5+10+6),
    .DDEPTH     (2)
)command_buffer(
    .clk(clk),
    .rst(rst),
    .ren(ren),
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
assign ren = (state==STATE_READY);
//--------------------------state machine----------------------
always_ff @( posedge clk or posedge rst ) begin
    if(rst)begin
        state <= STATE_IDLE;
    end
    else begin
        state <= state_next;
    end
end
always_comb begin
    case(state)
        STATE_IDLE:begin
            if(!empty)begin
                if(|access_error)begin
                    state_next=STATE_READY; //如果传递过来的访问带有错误，则不进行总线访问
                end
                else begin
                    case(access_opcode)
                        `OPCODE_LOAD: state_next = STATE_READ_ADDR;
                        `OPCODE_STORE:begin
                            case(access_funct3)
                                `FUNCT3_8bit,`FUNCT3_16bit,`FUNCT3_32bit,`FUNCT3_64bit:state_next=STATE_WRITE_ADDR;
                                default:begin
                                    state_next = STATE_IDLE;
                                    $display("ERR: unsupported write command");
                                    $stop();
                                end 
                            endcase
                        end
                        //`OPCODE_AMO:
                        default :begin
                            state_next=STATE_IDLE;
                            $display("ERR: unsupported command");
                            $stop();
                        end 
                    endcase
                end
            end
            else begin
                state_next = state;
            end
        end
        STATE_READ_ADDR: state_next=(cache_axi_ar.arready)?STATE_READ_PEND0 :state;
        STATE_READ_PEND0:state_next=(cache_axi_r.rvalid)?STATE_READ_PEND1   :state;
        STATE_READ_PEND1:state_next=(cache_axi_r.rvalid)?STATE_READY        :state; 
        STATE_WRITE_ADDR:state_next=(cache_axi_aw.awready)?STATE_WRITE_DATA :state; 
        STATE_WRITE_DATA:state_next=(cache_axi_w.wready)?STATE_WRITE_PEND   :state;
        STATE_WRITE_PEND:state_next=(cache_axi_b.bvalid)?STATE_READY        :state; 
        STATE_READY: state_next = STATE_IDLE;
        default: state_next = STATE_IDLE;
    endcase
end
//---------------从axi总线接数据--------------------
always_ff @( posedge clk ) begin
    if(state==STATE_READ_PEND0) frmaxi_rdata_l64 <= cache_axi_r.rdata;
    if(state==STATE_READ_PEND1) frmaxi_rdata_h64 <= cache_axi_r.rdata;
end
//---------------数据左移-------------------
//因为access的数据均为右对齐的，在送到总线上之前需要做一次对齐
data_shift_l            data_shift_l(
    .Offset_ADDR        ({1'b0,access_addr[2:0]}),  //因为目标总线为64位，故这里偏移值只取3位
    .DATAi              (access_wdata),
    .SIZEi              (access_funct3[1:0]),
    .MisAligned         (),           //No error dection
    .BSELo              (toaxi_bsel),
    .DATAo              (toaxi_wdata)
);
//-------------数据右移------------------------
//返回值数据是右对齐的
data_shift_r            data_shift_r(
    .DATAi              ({frmaxi_rdata_h64,frmaxi_rdata_l64}),
    .Offset_ADDR        (access_addr[3:0]),
    .DATAo              (cache_return_if.rdata)
);
//-----------------------cache return result interface-------------------
always_comb begin
    cache_return_if.id      = access_id;
    cache_return_if.valid   = (state==STATE_READY);
    cache_return_if.error   = access_error;
    cache_return_if.mmio    = 0;
end
//-----------------------axi interface-------------------
always_comb begin
    cache_axi_ar.arid   = 0;
    cache_axi_ar.araddr = (state==STATE_READ_ADDR)?{access_addr[63:4],4'b0}:'hx;
    cache_axi_ar.arlen  = 4'b0001;      //read burst constant=2 beat
    cache_axi_ar.arsize = 3'b011;
    cache_axi_ar.arburst= `AXI_BURST_INCR;
    cache_axi_ar.arlock = 0;
    cache_axi_ar.arcache= 0;
    cache_axi_ar.arprot = 0;
    cache_axi_ar.arqos  = 0;
    cache_axi_ar.arregion=0;
    cache_axi_ar.arvalid= (state==STATE_READ_ADDR);
    //--------------rchannel---------------------
    cache_axi_r.rready  = (state==STATE_READ_PEND0)|(state==STATE_READ_PEND1);
    //--------------awchannel--------------------
    cache_axi_aw.awid   = 0;
    cache_axi_aw.awaddr = (state==STATE_WRITE_ADDR)?access_addr:'hx;
    cache_axi_aw.awlen  = 4'b0000;      //write burst fix = 1 beat
    cache_axi_aw.awsize = {1'b0,access_funct3[1:0]};//riscv中存取指令funct3编码数据大小，编码规则和axi一致
    cache_axi_aw.awburst= `AXI_BURST_INCR;
    cache_axi_aw.awlock = 0;
    cache_axi_aw.awcache= 0;
    cache_axi_aw.awprot = 0;
    cache_axi_aw.awqos  = 0;
    cache_axi_aw.awregion=0;
    cache_axi_aw.awvalid = (state==STATE_WRITE_ADDR);
    //--------------wchannel-----------------------
    cache_axi_w.wdata   = toaxi_wdata;
    cache_axi_w.wstrb   = toaxi_bsel;
    cache_axi_w.wlast   = (state==STATE_WRITE_DATA);
    cache_axi_w.wvalid  = (state==STATE_WRITE_DATA);
    //-------------bchannel----------------------
    cache_axi_b.bready  = (state==STATE_WRITE_PEND);
end
assign cache_flush_ack = cache_flush_req;
endmodule