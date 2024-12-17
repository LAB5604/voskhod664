`include "prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) pipline simulation virtual bus module.
    Author  : Jack.Pan
    Date    : 2023/3/17
    Version : 1.0  change bus function

                            NOTE
    This file is ONLY for SIMULATION USE, NOT FOR implications use.
    Address space define in this virtual ram:
    0x00000000~0x7FFFFFFF : mmio space
    0x80000000~0xFFFFFFFF : ram space

***********************************************************************************************/
module virtual_bus#(
    parameter INIT_FILE = "hex.txt"
)(

    input wire                      clk_i,
    input wire                      arst_i,
    cache_access_interface.slave    icache_access,
    cache_return_interface.master   icache_return,
    cache_access_interface.slave    dcache_access,
    cache_return_interface.master   dcache_return

);
    logic [`XLEN-1:0] ibus_access_address ;
    logic [`XLEN-1:0] dbus_access_address ;
    
assign ibus_access_address = icache_access.addr - 64'h8000_0000;
assign dbus_access_address = dcache_access.addr - 64'h8000_0000;

    reg [7:0]  virtual_ram [65535:0];
    integer i = 0;

initial begin
    $readmemh(INIT_FILE, virtual_ram);
end
//------------------I-bus access logic----------------
always@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        icache_return.valid <= 1'b0;
    end
    else begin
        icache_return.valid <= icache_access.valid;
    end
    if(icache_access.valid)begin
        if($isunknown({icache_access.ci,icache_access.wt}))begin
            $display("ERR: unknow value wt/ci in icache access");
            $stop();
        end
    end
    icache_return.id    <= icache_access.id;
    icache_return.error <= 'h0;
    icache_return.mmio  <= 'b0;
    icache_return.rdata <= {virtual_ram[{ibus_access_address+'hf}],
                            virtual_ram[{ibus_access_address+'he}],
                            virtual_ram[{ibus_access_address+'hd}],
                            virtual_ram[{ibus_access_address+'hc}],
                            virtual_ram[{ibus_access_address+'hb}],
                            virtual_ram[{ibus_access_address+'ha}],
                            virtual_ram[{ibus_access_address+'h9}],
                            virtual_ram[{ibus_access_address+'h8}],
                            virtual_ram[{ibus_access_address+'h7}],
                            virtual_ram[{ibus_access_address+'h6}],
                            virtual_ram[{ibus_access_address+'h5}],
                            virtual_ram[{ibus_access_address+'h4}],
                            virtual_ram[{ibus_access_address+'h3}],
                            virtual_ram[{ibus_access_address+'h2}],
                            virtual_ram[{ibus_access_address+'h1}],
                            virtual_ram[{ibus_access_address+'h0}]};
end
assign icache_access.full = 0;
//-----------------D-bus access logic--------------------
always@(posedge clk_i or posedge arst_i)begin
    if(arst_i)begin
        dcache_return.valid <= 1'b0;
    end
    else begin
        dcache_return.valid <= dcache_access.valid;
    end
    dcache_return.id    <= dcache_access.id;
    dcache_return.error <= 'h0;
    dcache_return.mmio  <= 'b0;
    dcache_return.rdata <= {virtual_ram[{dbus_access_address+'hf}],
                            virtual_ram[{dbus_access_address+'he}],
                            virtual_ram[{dbus_access_address+'hd}],
                            virtual_ram[{dbus_access_address+'hc}],
                            virtual_ram[{dbus_access_address+'hb}],
                            virtual_ram[{dbus_access_address+'ha}],
                            virtual_ram[{dbus_access_address+'h9}],
                            virtual_ram[{dbus_access_address+'h8}],
                            virtual_ram[{dbus_access_address+'h7}],
                            virtual_ram[{dbus_access_address+'h6}],
                            virtual_ram[{dbus_access_address+'h5}],
                            virtual_ram[{dbus_access_address+'h4}],
                            virtual_ram[{dbus_access_address+'h3}],
                            virtual_ram[{dbus_access_address+'h2}],
                            virtual_ram[{dbus_access_address+'h1}],
                            virtual_ram[{dbus_access_address+'h0}]};
    if(dcache_access.valid)begin
        if($isunknown({dcache_access.ci,dcache_access.wt}))begin
            $display("ERR: unknow value wt/ci in dcache access");
            $stop();
        end
        if(|dcache_access.error)begin
            $display("INFO:some errors in dcache access."); //when has error, dcache behave no operating
        end
        else begin
            case(dcache_access.opcode)
                `OPCODE_STORE:
                begin
                    case(dcache_access.funct[2:0])
                        `FUNCT3_8bit:
                        begin
                            virtual_ram[{dbus_access_address+'h0}] <= dcache_access.wdata[7:0];
                        end
                        `FUNCT3_16bit:
                        begin
                            virtual_ram[{dbus_access_address+'h1}] <= dcache_access.wdata[15:8];
                            virtual_ram[{dbus_access_address+'h0}] <= dcache_access.wdata[7:0];
                        end
                        `FUNCT3_32bit:
                        begin
                            virtual_ram[{dbus_access_address+'h3}] <= dcache_access.wdata[31:24];
                            virtual_ram[{dbus_access_address+'h2}] <= dcache_access.wdata[23:16];
                            virtual_ram[{dbus_access_address+'h1}] <= dcache_access.wdata[15:8];
                            virtual_ram[{dbus_access_address+'h0}] <= dcache_access.wdata[7:0];
                        end
                        `FUNCT3_64bit:
                        begin
                            virtual_ram[{dbus_access_address+'h7}] <= dcache_access.wdata[63:56];
                            virtual_ram[{dbus_access_address+'h6}] <= dcache_access.wdata[55:48];
                            virtual_ram[{dbus_access_address+'h5}] <= dcache_access.wdata[47:40];
                            virtual_ram[{dbus_access_address+'h4}] <= dcache_access.wdata[39:32];
                            virtual_ram[{dbus_access_address+'h3}] <= dcache_access.wdata[31:24];
                            virtual_ram[{dbus_access_address+'h2}] <= dcache_access.wdata[23:16];
                            virtual_ram[{dbus_access_address+'h1}] <= dcache_access.wdata[15:8];
                            virtual_ram[{dbus_access_address+'h0}] <= dcache_access.wdata[7:0];
                        end
                    endcase    
                end
            endcase
        end
    end
end
assign dcache_access.full = 0;
endmodule