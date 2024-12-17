`timescale 1ps/1ps
`include "prv664_define.svh"
`include "prv664_config.svh"
`include "riscv_define.svh"
module icache_difftest();
//              simulation parameter
parameter   ADDR_WIDTH = 20,
            ADDR_RANGE = 1<<ADDR_WIDTH,
            TEST_PATTRN='h7766554433221100,//内存中的初始化序列
            TEST_NUMBER= 512;           //每个访问类型产生多少种访问
//             NO TOUCH parameter
parameter   STATE_128BIT_ACCESS = 4'b0000;
//----------------globak signal-------------------
    reg             clk, rst;
//----------------ram------------------------------
    reg [7:0]       ref_sram     [ADDR_RANGE-1:0];
//----------------access generate---------------------
    reg             generate_state;         //0:write access 1:read access
    reg [31:0]      generate_counter;       //记录一共产生多少次访问
    reg [31:0]      generate_loop_counter;
    reg [31:0]      generate_cycle_counter; //记录每次loop一共用了多少cycle
    reg [3:0]       generate_size_state;//产生访问的大小 000：8bit 001：16bit 010：32bit 011：64bit 100：128bit
    reg [7:0]       generate_id;
    reg [`XLEN-1:0] generate_addr;
    reg [`XLEN-1:0] generate_wdata;
    reg             generate_ci, generate_wt;
    reg [4:0]       generate_opcode;
    reg [9:0]       generate_funct;
    reg [5:0]       generate_error;
//---------------ref command fifo-------------------
//  reg command fifo have a copy of command send to dut
    reg             ref_fifo_wen,   ref_fifo_ren;
    wire            ref_fifo_full,  ref_fifo_empty;
    wire [7:0]      ref_fifo_id;
    wire [`XLEN-1:0]ref_fifo_addr, ref_fifo_wdata;
    wire            ref_fifo_ci, ref_fifo_wt;
    wire [4:0]      ref_fifo_opcode;
    wire [9:0]      ref_fifo_funct;
    wire [5:0]      ref_fifo_error;

    reg [127:0] load_temp, amo_temp;

   // wire [7:0] dut_ram_2d [(1<<ADDR_WIDTH)-1:0];

//---------------sramc control-------------------------
/*    reg  [7:0]      dut_sram    [ADDR_RANGE-1:0];
    wire            sram_cs, sram_we;
    wire [7:0]      sram_din;
    reg [7:0]       sram_dout;
    wire [31:0]     sram_addr;
always @(posedge clk) begin
    if (sram_cs) begin
        if (sram_we) begin
            dut_sram[sram_addr] <= sram_din;
        end
        else begin
            sram_dout <= dut_sram[sram_addr];
        end
    end
end*/
fifo1r1w#(
    .DWID       (8+64+64+1+1+5+10+6),
    .DDEPTH     (8)
)command_buffer(
    .clk(clk),
    .rst(rst),
    .ren(ref_fifo_ren),
    .wen(ref_fifo_wen),
    .wdata({generate_id,
            generate_addr,
            generate_wdata,
            generate_ci,
            generate_wt,
            generate_opcode,
            generate_funct,
            generate_error}),
    .rdata({ref_fifo_id,
            ref_fifo_addr,
            ref_fifo_wdata,
            ref_fifo_ci,
            ref_fifo_wt,
            ref_fifo_opcode,
            ref_fifo_funct,
            ref_fifo_error}),
    .full   (ref_fifo_full),
    .empty  (ref_fifo_empty)
);
//------------------dut i/o--------------------------
    cache_access_interface          dut_access();
    cache_return_interface          dut_return();
    axi_ar                          dut_axi_ar();
    axi_r                           dut_axi_r();
    axi_aw                          dut_axi_aw();
    axi_w                           dut_axi_w();
    axi_b                           dut_axi_b();
//------------------dut module--------------------------
assign dut_access.id = generate_id;
assign dut_access.addr=generate_addr;
assign dut_access.wdata=generate_wdata;
assign dut_access.ci  = generate_ci;
assign dut_access.wt  =generate_wt;
assign dut_access.opcode=generate_opcode;
assign dut_access.funct=generate_funct;
assign dut_access.error=generate_error;
pip_icache_top                           dut(
    .clk_i                      (clk),
    .srst_i                     (rst),
    //------------cpu manage interface-----------
    .cache_flush_req            (0),
    .cache_flush_ack            (),
    //------------cpu pipline interface-----------
    .cache_access_if            (dut_access),
    .cache_return_if            (dut_return),
    //------------axi interface-----------
    .cache_axi_ar               (dut_axi_ar),
    .cache_axi_r                (dut_axi_r),
    .cache_axi_aw               (dut_axi_aw),
    .cache_axi_w                (dut_axi_w),
    .cache_axi_b                (dut_axi_b)
);
/*
axi4_ocram_top        test_ram(
    .clk        (clk),
    .rst        (rst),
    .awid       ({3'b000,dut_axi_aw.awid}),
    .awaddr     (dut_axi_aw.awaddr),
    .awlen      (dut_axi_aw.awlen),
    .awsize     (dut_axi_aw.awsize),
    .awburst    (dut_axi_aw.awburst),
    .awvalid    (dut_axi_aw.awvalid),
    // 	output    	                
    .awready    (dut_axi_aw.awready),
    .wdata      (dut_axi_w.wdata),
    .wstrb      (dut_axi_w.wstrb),
    .wlast      (dut_axi_w.wlast),          
    .wvalid     (dut_axi_w.wvalid),       
    .wready     (dut_axi_w.wready),
    .bid        (dut_axi_b.bid),
    .bresp      (dut_axi_b.bresp),
    .bvalid     (dut_axi_b.bvalid),
    .bready     (dut_axi_b.bready),
    .arid       ({3'b000,dut_axi_ar.arid}),
    .araddr     (dut_axi_ar.araddr),     
    .arlen      (dut_axi_ar.arlen),
    .arsize     (dut_axi_ar.arsize),  
    .arburst    (dut_axi_ar.arburst),    
    .arvalid    (dut_axi_ar.arvalid),    
    .arready    (dut_axi_ar.arready),
    .rid        (dut_axi_r.rid),
    .rdata      (dut_axi_r.rdata),
    .rresp      (dut_axi_r.rresp),
    .rlast      (dut_axi_r.rlast),
    .rvalid     (dut_axi_r.rvalid),        
    .rready     (dut_axi_r.rready),
    //------------sram interface---------------
    .sram_cs    (sram_cs),
    .sram_we    (sram_we),
    .sram_addr  (sram_addr),
    .sram_din   (sram_din),
    .sram_dout  (sram_dout)
);
*/
axi_ram #
(
    .TEST_PATTRN    (TEST_PATTRN),
    // Width of data bus in bits
    .DATA_WIDTH     (64),
    // Width of address bus in bits
    .ADDR_WIDTH     (ADDR_WIDTH),
    // Width of wstrb (width of data bus in words)
    //.STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    .ID_WIDTH       (8)
    // Extra pipeline register on output
    //.PIPELINE_OUTPUT = 0
)test_ram(
    .clk                (clk),
    .rst                (rst),

    .s_axi_awid         ({3'b000,dut_axi_aw.awid}),
    .s_axi_awaddr       (dut_axi_aw.awaddr),
    .s_axi_awlen        (dut_axi_aw.awlen),
    .s_axi_awsize       (dut_axi_aw.awsize),
    .s_axi_awburst      (dut_axi_aw.awburst),
    .s_axi_awlock       (0),
    .s_axi_awcache      (0),
    .s_axi_awprot       (0),
    .s_axi_awvalid      (dut_axi_aw.awvalid),
    .s_axi_awready      (dut_axi_aw.awready),
    .s_axi_wdata        (dut_axi_w.wdata),
    .s_axi_wstrb        (dut_axi_w.wstrb),
    .s_axi_wlast        (dut_axi_w.wlast),
    .s_axi_wvalid       (dut_axi_w.wvalid),
    .s_axi_wready       (dut_axi_w.wready),
    .s_axi_bid          (dut_axi_b.bid),
    .s_axi_bresp        (dut_axi_b.bresp),
    .s_axi_bvalid       (dut_axi_b.bvalid),
    .s_axi_bready       (dut_axi_b.bready),
    .s_axi_arid         ({3'b000,dut_axi_ar.arid}),
    .s_axi_araddr       (dut_axi_ar.araddr),
    .s_axi_arlen        (dut_axi_ar.arlen),
    .s_axi_arsize       (dut_axi_ar.arsize),
    .s_axi_arburst      (dut_axi_ar.arburst),
    .s_axi_arlock       (0),
    .s_axi_arcache      (0),
    .s_axi_arprot       (0),
    .s_axi_arvalid      (dut_axi_ar.arvalid),
    .s_axi_arready      (dut_axi_ar.arready),
    .s_axi_rid          (dut_axi_r.rid),
    .s_axi_rdata        (dut_axi_r.rdata),
    .s_axi_rresp        (dut_axi_r.rresp),
    .s_axi_rlast        (dut_axi_r.rlast),
    .s_axi_rvalid       (dut_axi_r.rvalid),
    .s_axi_rready       (dut_axi_r.rready)
    //.ram                (dut_ram_2d)
);
/******************************************************
initial 
*******************************************************/
integer i;
reg [7:0] generate_data_temp;
initial begin
    clk = 0;
    rst = 1;
    generate_state = 0;                         //initialize reg
    generate_size_state = STATE_128BIT_ACCESS;
    generate_counter   = 0;
    generate_loop_counter = 0;
    generate_cycle_counter=0;
    $display("INFO:start ram initializing.");
    for(i=0;i<ADDR_RANGE;i=i+1)begin
        ref_sram[i] = {1'b0,i[2:0],1'b0,i[2:0]};                   //FIXME:内存测试序列最好不要动
    end
    $display("INFO:initial finish!cache test begin.");
#40
    rst = 0;
end
always begin
    #5 clk=~clk;
end
/******************************************************
    generate access to dut and ref
*******************************************************/
always@(negedge clk)begin
    generate_cycle_counter = generate_cycle_counter + 1;
    if(rst)begin
        ref_fifo_wen = 0;
        dut_access.valid= 0;
    end
    else if(!ref_fifo_full & !dut_access.full)begin
        case(generate_size_state)
        STATE_128BIT_ACCESS:begin
            generate_addr   = {$random}%ADDR_RANGE;//generate address=0~ADDR_RANGE
            generate_addr[3:0]=4'b000;
            generate_ci = 0;
            generate_128bit_read();
            ref_fifo_wen = 1;
            dut_access.valid=1;
            generate_counter = (generate_counter==TEST_NUMBER)?0:(generate_counter+1);
            if(generate_counter==TEST_NUMBER)begin
                generate_loop_counter = generate_loop_counter + 1;
                $display("INFO:loop%d 128bit test PASS",generate_loop_counter);
                $display("     Total access number=%d, use %d cycle.",TEST_NUMBER,generate_cycle_counter);
                generate_cycle_counter=0;
            end
        end
        endcase
    end
    else begin
        ref_fifo_wen = 0;
        dut_access.valid= 0;
    end
end
/*****************************************************
compare result with ref
******************************************************/
always@(negedge clk)begin
    if(dut_return.valid)begin
        if(|dut_return.error)begin
            $display("INFO:an error happen in access");
            $stop();
        end
        else begin
            compare_result();
        end
    end
end
assign ref_fifo_ren = dut_return.valid;
/****************************************************
    task to generate 128bit read/write access
*****************************************************/
task  generate_128bit_read();
begin
    generate_id     = {$random};
    generate_wdata  = $random();
    generate_wt     = $random();
    generate_opcode = `OPCODE_LOAD;
    generate_funct  = {7'b0, 3'b100};
    generate_error  = 0;
end
endtask 
task generate_128bit_write();
begin
    generate_id     = {$random};
    generate_wdata  = $random();
    generate_wt     = $random();
    generate_opcode = `OPCODE_STORE;
    generate_funct  = {7'b0, 3'b100};
    generate_error  = 0;
end
endtask
/*****************************************************
    task to compare result
*****************************************************/
task compare_result();
begin
    case(ref_fifo_opcode)
        `OPCODE_LOAD:
        begin
            load_temp ={ref_sram[{ref_fifo_addr+'hf}],
                        ref_sram[{ref_fifo_addr+'he}],
                        ref_sram[{ref_fifo_addr+'hd}],
                        ref_sram[{ref_fifo_addr+'hc}],
                        ref_sram[{ref_fifo_addr+'hb}],
                        ref_sram[{ref_fifo_addr+'ha}],
                        ref_sram[{ref_fifo_addr+'h9}],
                        ref_sram[{ref_fifo_addr+'h8}],
                        ref_sram[{ref_fifo_addr+'h7}],
                        ref_sram[{ref_fifo_addr+'h6}],
                        ref_sram[{ref_fifo_addr+'h5}],
                        ref_sram[{ref_fifo_addr+'h4}],
                        ref_sram[{ref_fifo_addr+'h3}],
                        ref_sram[{ref_fifo_addr+'h2}],
                        ref_sram[{ref_fifo_addr+'h1}],
                        ref_sram[{ref_fifo_addr+'h0}]};
            case(ref_fifo_funct[2:0])
                `FUNCT3_8bit:
                begin
                    if(dut_return.rdata[7:0] != load_temp[7:0])begin
                        $display("ERR:wrong load result in id=0x%h 8bit access.",dut_return.id);
                        $display("right value=0x%h, wrong=0x%h", load_temp[7:0], dut_return.rdata[7:0]);
                        $stop();
                    end
                end
                `FUNCT3_16bit:
                begin
                    if(dut_return.rdata[15:0] != load_temp[15:0])begin
                        $display("ERR:wrong load result in id=0x%h 16bit access.",dut_return.id);
                        $display("right value=0x%h, wrong=0x%h", load_temp[15:0], dut_return.rdata[15:0]);
                        $stop();
                    end
                end
                `FUNCT3_32bit:
                begin
                    if(dut_return.rdata[31:0] != load_temp[31:0])begin
                        $display("ERR:wrong load result in id=0x%h 32bit access.",dut_return.id);
                        $display("right value=0x%h, wrong=0x%h", load_temp[31:0], dut_return.rdata[31:0]);
                        $stop();
                    end
                end
                `FUNCT3_64bit:
                begin
                    if(dut_return.rdata[63:0] != load_temp[63:0])begin
                        $display("ERR:wrong load result in id=0x%h 64bit access.",dut_return.id);
                        $display("right value=0x%h, wrong=0x%h", load_temp[63:0], dut_return.rdata[63:0]);
                        $stop();
                    end
                end
                3'b100:
                begin
                    if(dut_return.rdata != load_temp)begin
                        $display("ERR:wrong load result in id=0x%h 128bit access.",dut_return.id);
                        $display("right value=0x%h, wrong=0x%h", load_temp, dut_return.rdata);
                        $stop();
                    end
                end
                default :begin
                    $display("ERR: unknown funct in read access.");
                    $stop();
                end
            endcase
        end
        `OPCODE_STORE:
        begin
            case(ref_fifo_funct[2:0])
                `FUNCT3_8bit:
                begin
                    ref_sram[{ref_fifo_addr+'h0}] = ref_fifo_wdata[7:0];
                end
                `FUNCT3_16bit:
                begin
                    ref_sram[{ref_fifo_addr+'h1}] = ref_fifo_wdata[15:8];
                    ref_sram[{ref_fifo_addr+'h0}] = ref_fifo_wdata[7:0];
                end
                `FUNCT3_32bit:
                begin
                    ref_sram[{ref_fifo_addr+'h3}] = ref_fifo_wdata[31:24];
                    ref_sram[{ref_fifo_addr+'h2}] = ref_fifo_wdata[23:16];
                    ref_sram[{ref_fifo_addr+'h1}] = ref_fifo_wdata[15:8];
                    ref_sram[{ref_fifo_addr+'h0}] = ref_fifo_wdata[7:0];
                end
                `FUNCT3_64bit:
                begin
                    ref_sram[{ref_fifo_addr+'h7}] = ref_fifo_wdata[63:56];
                    ref_sram[{ref_fifo_addr+'h6}] = ref_fifo_wdata[55:48];
                    ref_sram[{ref_fifo_addr+'h5}] = ref_fifo_wdata[47:40];
                    ref_sram[{ref_fifo_addr+'h4}] = ref_fifo_wdata[39:32];
                    ref_sram[{ref_fifo_addr+'h3}] = ref_fifo_wdata[31:24];
                    ref_sram[{ref_fifo_addr+'h2}] = ref_fifo_wdata[23:16];
                    ref_sram[{ref_fifo_addr+'h1}] = ref_fifo_wdata[15:8];
                    ref_sram[{ref_fifo_addr+'h0}] = ref_fifo_wdata[7:0];
                end
            endcase    
        end
        `OPCODE_AMO:
        begin
            load_temp ={ref_sram[{ref_fifo_addr+'hf}],      //首先从内存中读取一个值作为临时值
                        ref_sram[{ref_fifo_addr+'he}],
                        ref_sram[{ref_fifo_addr+'hd}],
                        ref_sram[{ref_fifo_addr+'hc}],
                        ref_sram[{ref_fifo_addr+'hb}],
                        ref_sram[{ref_fifo_addr+'ha}],
                        ref_sram[{ref_fifo_addr+'h9}],
                        ref_sram[{ref_fifo_addr+'h8}],
                        ref_sram[{ref_fifo_addr+'h7}],
                        ref_sram[{ref_fifo_addr+'h6}],
                        ref_sram[{ref_fifo_addr+'h5}],
                        ref_sram[{ref_fifo_addr+'h4}],
                        ref_sram[{ref_fifo_addr+'h3}],
                        ref_sram[{ref_fifo_addr+'h2}],
                        ref_sram[{ref_fifo_addr+'h1}],
                        ref_sram[{ref_fifo_addr+'h0}]};
            case(ref_fifo_funct[9:5])
                `FUNCT5_AMOADD:begin amo_temp=load_temp+ref_fifo_wdata; end
                `FUNCT5_AMOAND:begin amo_temp=load_temp&ref_fifo_wdata; end
                default:begin $display("ERR: unsupported AMO function!");$stop();end
            endcase
            case(ref_fifo_funct[2:0])
                3'b010:begin
                    ref_sram[{ref_fifo_addr+'h3}] = amo_temp[31:24];
                    ref_sram[{ref_fifo_addr+'h2}] = amo_temp[23:16];
                    ref_sram[{ref_fifo_addr+'h1}] = amo_temp[15:8];
                    ref_sram[{ref_fifo_addr+'h0}] = amo_temp[7:0];
                    if(dut_return.rdata[31:0] != load_temp[31:0])begin
                        $display("ERR:wrong amo result in id=0x%h AMOADD.W access.",dut_return.id);
                        $display("right value=0x%h, wrong=0x%h", load_temp, dut_return.rdata);
                        $stop();
                    end
                end
                3'b011:begin
                    ref_sram[{ref_fifo_addr+'h7}] = amo_temp[63:56];
                    ref_sram[{ref_fifo_addr+'h6}] = amo_temp[55:48];
                    ref_sram[{ref_fifo_addr+'h5}] = amo_temp[47:40];
                    ref_sram[{ref_fifo_addr+'h4}] = amo_temp[39:32];
                    ref_sram[{ref_fifo_addr+'h3}] = amo_temp[31:24];
                    ref_sram[{ref_fifo_addr+'h2}] = amo_temp[23:16];
                    ref_sram[{ref_fifo_addr+'h1}] = amo_temp[15:8];
                    ref_sram[{ref_fifo_addr+'h0}] = amo_temp[7:0];
                    if(dut_return.rdata[63:0] != load_temp[63:0])begin
                        $display("ERR:wrong amo result in id=0x%h AMOADD.D access.",dut_return.id);
                        $display("right value=0x%h, wrong=0x%h", load_temp, dut_return.rdata);
                        $stop();
                    end
                end
            endcase
        end
    endcase
end
endtask
endmodule