/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) apb-sramc
    Author  : Jack.Pan
    Date    : 2023/2/16
    Version : 0.0 file initial

***********************************************************************************************/
module apb_sramc#(
    parameter DATA_WIDTH = 8,   //cuurnt only support 8bit access
    parameter ADDR_WIDTH = 32
)(
    input                   clk,
    input                   rstn,
    input                   psel,
    input                   penable,
    input [ADDR_WIDTH-1:0]  paddr,
    input                   pwrite,
    input [DATA_WIDTH-1:0]  pwdata,
    output                  pready,
    output  [DATA_WIDTH-1:0]prdata,
    //----------sram interface---------------
    output wire             sram_cs,
    output wire             sram_we,
    output wire [ADDR_WIDTH-1:0]sram_addr,
    output wire [DATA_WIDTH-1:0]sram_din,
    input  wire [DATA_WIDTH-1:0]sram_dout
);

localparam IDEL = 0;
localparam SETUP = 1;
localparam ENABLE = 2;

reg [1:0] sta;
reg [1:0] nsta;

//fsm;
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        sta = 2'd0;
    end
    else begin
        sta = nsta;
    end
end

//state transition;
always @(*) begin
    nsta = sta;
    case (sta) 
        IDEL: begin
            if (psel) begin
                nsta = SETUP;
            end
            else begin
                nsta = IDEL;
            end
        end
        SETUP: begin
            if (psel&penable) begin
                nsta = ENABLE;
            end
            else begin
                nsta = IDEL;
            end
        end
        ENABLE: begin
            if (psel&penable) begin
                nsta = ENABLE;
            end
            else begin
                nsta = IDEL;
            end
        end
        default: begin
            nsta <= IDEL;
        end
    endcase
end

assign prdata = sram_dout;
assign pready = (sta==ENABLE);                 //apb trans done;
assign sram_cs = (sta==SETUP)|(sta==ENABLE);     //sram cs;
assign sram_we = (sta==ENABLE)&pwrite;                 //sram we;
assign sram_din= pwdata;
assign sram_addr=paddr;


endmodule