module ram_sim#(
    parameter 
    NEED_INIT  = 0,             //0: no init file ,1:init with INIT_FILE
    INIT_FILE  = "FILE.bin",    //can direct init binary file
    DATA_WIDTH = 64,
    DATA_DEPTH = 1024
)(
    clk,
    addr,
    ce,
    we,
    datar,
    dataw,
    be
);
localparam ADDR_WIDTH=$clog2(DATA_DEPTH);

input                   clk;
input [ADDR_WIDTH-1:0]  addr;
input [DATA_WIDTH-1:0]  dataw;
input                   ce;
input                   we;
input [DATA_WIDTH/8-1:0]be;
output reg [DATA_WIDTH-1:0]  datar;

integer fd, err, code;
reg [320:0] str;

// (* RAM_STYLE="BLOCK" *)
reg [8-1:0] mem[0 : DATA_DEPTH*(DATA_WIDTH/8)-1];

integer i=0;
integer j = 0;

always@(posedge clk)begin
    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
        if (ce & we & be[i]) begin
            mem[addr*8 +i] <= dataw[8*i +: 8];
        end
    end
end

always @(posedge clk ) begin
    if(ce & !we)begin
        for(j=0; j<DATA_WIDTH/8; j=j+1)begin
            datar[(j*8)+:8] <= mem[(addr*8)+j];
        end
    end
end

//           init memory direct with binary file
if(NEED_INIT>0)begin:INIT_RAM
initial begin
    fd = $fopen(INIT_FILE, "rb");
    err = $ferror(fd, str);
    if (!err) begin
       code = $fread(mem, fd); //数组型读取，读取4次
    end else begin
        $display("ERR: init memory failed : %s", str);
        $stop();
    end
    $fclose(fd) ;
end
end

endmodule