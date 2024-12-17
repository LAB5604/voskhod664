`include "prv664_define.svh"
`include "prv664_config.svh"
/********************************************************************
    4r2w regfile for DRAM optimize
    this regfile is suitable for FPGA imp
***********************************************************************/
module prv664_regfile#(
    parameter DATA_WIDTH = 64
)(
    input wire                  clk_i,
    input wire                  arst_i,
    //--------------------------test port---------------------
`ifdef SIMULATION
    output wire [DATA_WIDTH-1:0]test_reg_out[31:0],
`endif
    //--------------------------2 read port-------------------
    // each read port have 2 register read port
    input wire [4:0]            port0_rs1index, port0_rs2index, port1_rs1index, port1_rs2index,
    output logic [DATA_WIDTH-1:0]port0_rs1data,  port0_rs2data,  port1_rs1data,  port1_rs2data,
    //-------------------------2 commit port--------------------
    input wire [4:0]            port0_rdindex,  port1_rdindex,
    input wire [DATA_WIDTH-1:0] port0_rddata,   port1_rddata,
    input wire                  port0_valid,    port1_valid,
    //-------------------------debug port-----------------------
    input wire                  halted,         //pipline is halted
    input wire [4:0]            debug_rsindex,
    output wire[DATA_WIDTH-1:0] debug_rsdata

);
    reg [31:0]      data_pointer;
    wire[DATA_WIDTH-1:0] bank0_read_data [3:0];
    wire[DATA_WIDTH-1:0] bank1_read_data [3:0];

genvar i;
generate
    for(i=0; i<32; i=i+1)begin : data_pointer_generate
        always_ff @( posedge clk_i or posedge arst_i ) begin 
            if(arst_i)begin
                data_pointer[i] <= 1'b0;
            end
            else begin
                case({port0_valid & (port0_rdindex==i), port1_valid & (port1_rdindex==i)})
                    2'b00 : data_pointer[i] <= data_pointer[i];
                    2'b01 : data_pointer[i] <= 1'b1;
                    2'b10 : data_pointer[i] <= 1'b0;
                    2'b11 : data_pointer[i] <= 1'b1;
                endcase
            end
        end
    end
    
endgenerate

//---------------------------read port 0-------------------------
sram_1r1w_async_read#(
    .DATA_WIDTH     (DATA_WIDTH),
    .DATA_DEPTH     (32)
)readport0_bank0_sram(
    .clkw           (clk_i),
    .addrr          (halted ? debug_rsindex : port0_rs1index),
    .addrw          (port0_rdindex),
    .ce             (1'b1),
    .we             (port0_valid),
    .datar          (bank0_read_data[0]),
    .dataw          (port0_rddata)
); 
sram_1r1w_async_read#(
    .DATA_WIDTH     (DATA_WIDTH),
    .DATA_DEPTH     (32)
)readport0_bank1_sram(
    .clkw           (clk_i),
    .addrr          (halted ? debug_rsindex : port0_rs1index),
    .addrw          (port1_rdindex),
    .ce             (1'b1),
    .we             (port1_valid),
    .datar          (bank1_read_data[0]),
    .dataw          (port1_rddata)
); 
//---------------------------read port 1---------------------------
sram_1r1w_async_read#(
    .DATA_WIDTH     (DATA_WIDTH),
    .DATA_DEPTH     (32)
)readport1_bank0_sram(
    .clkw           (clk_i),
    .addrr          (port0_rs2index),
    .addrw          (port0_rdindex),
    .ce             (1'b1),
    .we             (port0_valid),
    .datar          (bank0_read_data[1]),
    .dataw          (port0_rddata)
); 
sram_1r1w_async_read#(
    .DATA_WIDTH     (DATA_WIDTH),
    .DATA_DEPTH     (32)
)readport1_bank1_sram(
    .clkw           (clk_i),
    .addrr          (port0_rs2index),
    .addrw          (port1_rdindex),
    .ce             (1'b1),
    .we             (port1_valid),
    .datar          (bank1_read_data[1]),
    .dataw          (port1_rddata)
); 
//---------------------------read port 2---------------------------
sram_1r1w_async_read#(
    .DATA_WIDTH     (DATA_WIDTH),
    .DATA_DEPTH     (32)
)readport2_bank0_sram(
    .clkw           (clk_i),
    .addrr          (port1_rs1index),
    .addrw          (port0_rdindex),
    .ce             (1'b1),
    .we             (port0_valid),
    .datar          (bank0_read_data[2]),
    .dataw          (port0_rddata)
); 
sram_1r1w_async_read#(
    .DATA_WIDTH     (DATA_WIDTH),
    .DATA_DEPTH     (32)
)readport2_bank1_sram(
    .clkw           (clk_i),
    .addrr          (port1_rs1index),
    .addrw          (port1_rdindex),
    .ce             (1'b1),
    .we             (port1_valid),
    .datar          (bank1_read_data[2]),
    .dataw          (port1_rddata)
); 
//---------------------------read port 3---------------------------
sram_1r1w_async_read#(
    .DATA_WIDTH     (DATA_WIDTH),
    .DATA_DEPTH     (32)
)readport3_bank0_sram(
    .clkw           (clk_i),
    .addrr          (port1_rs2index),
    .addrw          (port0_rdindex),
    .ce             (1'b1),
    .we             (port0_valid),
    .datar          (bank0_read_data[3]),
    .dataw          (port0_rddata)
); 
sram_1r1w_async_read#(
    .DATA_WIDTH     (DATA_WIDTH),
    .DATA_DEPTH     (32)
)readport3_bank1_sram(
    .clkw           (clk_i),
    .addrr          (port1_rs2index),
    .addrw          (port1_rdindex),
    .ce             (1'b1),
    .we             (port1_valid),
    .datar          (bank1_read_data[3]),
    .dataw          (port1_rddata)
); 
//-----------------------------output mux--------------------------------
assign port0_rs1data = (port0_rs1index==0) ? 'h0 : data_pointer[port0_rs1index] ? bank1_read_data[0] : bank0_read_data[0];
assign port0_rs2data = (port0_rs2index==0) ? 'h0 : data_pointer[port0_rs2index] ? bank1_read_data[1] : bank0_read_data[1];
assign port1_rs1data = (port1_rs1index==0) ? 'h0 : data_pointer[port1_rs1index] ? bank1_read_data[2] : bank0_read_data[2];
assign port1_rs2data = (port1_rs2index==0) ? 'h0 : data_pointer[port1_rs2index] ? bank1_read_data[3] : bank0_read_data[3];
assign debug_rsdata  = (debug_rsindex==0)  ? 'h0 : data_pointer[debug_rsindex]  ? bank1_read_data[0] : bank0_read_data[0];
////////////////////////////////////////////////////////////////////////
//      仿真时使用的测试代码，模仿寄存器文件的行为生成一个平面的寄存器     //
//      值输出，测试工具可以通过此平面上的寄存器值进行测试。              //
///////////////////////////////////////////////////////////////////////
`ifdef SIMULATION
    reg [DATA_WIDTH-1:0] bank0_sram [31:0];
    reg [DATA_WIDTH-1:0] bank1_sram [31:0];
integer k=0;
always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        for(k=0;k<32;k=k+1)begin
            bank0_sram[k] <= 0;
            bank1_sram[k] <= 0;
        end
    end
    else begin
        if(port0_valid)begin
            bank0_sram[port0_rdindex]<=port0_rddata;
        end
        if(port1_valid)begin
            bank1_sram[port1_rdindex]<=port1_rddata;
        end
    end
end
genvar j;
generate
    for(j=0;j<32;j=j+1)begin:test_reg_output
        if(j==0)begin
            assign test_reg_out[j] = 0;
        end
        else begin
            assign test_reg_out[j] = data_pointer[j] ? bank1_sram[j] : bank0_sram[j];
        end
    end
endgenerate
`endif
endmodule