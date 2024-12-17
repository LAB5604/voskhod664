`include"prv664_define.svh"
`include"prv664_config.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : 32 registers' floatpoint scoreboard, with 1-read port 1-commit port
    Author  : Jack.Pan
    Date    : 2022/10/14
    Version : 1.0 将busy接口全面暴露

***********************************************************************************************/
module prv664_fscoreboard#(
    parameter IDLEN = 8,
              RNM   = "ENABLE"
)(

    input wire clk_i,
    input wire srst_i,

    scoreboard_update_interface.slave  fscoreboard_update_slave,   //2 instruction can access scoreboard once
    output wire [31:0]  busy_flag,
    output wire [7:0]   id_flag     [31:0],

    input wire          commit0_valid,
    input wire          commit0_wren,
    input wire [4:0]    commit0_rdindex,
    input wire [7:0]    commit0_itag

);

    wire [31:0] wen0,      cen0;                    //write enable commit enable

    reg  [31:0]         reg_busy;                   //register file is busy
    reg  [IDLEN-1:0]    reg_pitag   [31:0];         //pending write back itag

///////////////////////////////////////////////////////////////////////
//                     generate write enable and commit enable       //
///////////////////////////////////////////////////////////////////////
genvar j;
generate
    for(j=0; j<32; j=j+1)begin: writeenable_sel
        assign wen0[j] = fscoreboard_update_slave.write & (fscoreboard_update_slave.rdindex==j);
        assign cen0[j] = commit0_valid & (commit0_rdindex==j) & commit0_wren;
    end
endgenerate
///////////////////////////////////////////////////////////////////////
//              scoreboard cell generate                             //
///////////////////////////////////////////////////////////////////////
genvar i;
generate
    for(i=0; i<32; i=i+1)begin:busy_flag_gen
        always_ff @( posedge clk_i ) begin
            if(RNM=="ENABLE")begin
                if(srst_i)begin
                    reg_busy[i] <= 'h0;
                end
                else if(wen0[i])begin
                    reg_busy[i] <= 1'b1;
                    reg_pitag[i]<= fscoreboard_update_slave.itag;
                end
                else if(cen0[i] & (commit0_itag==reg_pitag[i]))begin
                    reg_busy[i] <= 1'b0;
                    reg_pitag[i]<= 'hx;
                end
            end 
            else begin
                if(srst_i)begin
                    reg_busy[i] <= 'h0;
                end
                else if(wen0[i])begin
                    reg_busy[i] <= 1'b1;
                end
                else if(cen0[i])begin
                    reg_busy[i] <= 1'b0;
                end
            end
        end
    end
endgenerate
/////////////////////////////////////////////////////////
//                output mux                           //
/////////////////////////////////////////////////////////
generate
    for(j=0;j<32;j=j+1)begin:itag_gen
        if(j==0)begin
            assign busy_flag[j]=0;
            assign id_flag[j]=reg_pitag[j];
        end
        else begin
            assign busy_flag[j]=reg_busy[j];
            assign id_flag[j]=reg_pitag[j];
        end
    end
endgenerate

endmodule