`include"prv664_define.svh"
`include"prv664_config.svh"
/**********************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : 32 registers' integer scoreboard, with 2-read port 2-commit port
    Author  : Jack.Pan
    Date    : 2022/10/14
    Version : 1.0 将reg busy接口全面暴露

***********************************************************************************************/
module prv664_iscoreboard#(
    parameter IDLEN = 8,
              RNM   = "ENABLE"
)(

    input wire clk_i,
    input wire srst_i,

    scoreboard_update_interface.slave  iscoreboard_update_slave0, //2 instruction can access scoreboard once
    scoreboard_update_interface.slave  iscoreboard_update_slave1,

    output wire [31:0]  busy_flag,
    output wire [7:0]   id_flag     [31:0],

    input wire          commit0_valid,      commit1_valid,
    input wire          commit0_wren,       commit1_wren,
    input wire [4:0]    commit0_rdindex,    commit1_rdindex,
    input wire [7:0]    commit0_itag,       commit1_itag

);

    wire [31:0] wen0,   wen1,   cen0,   cen1;       //write enable 1/2 commit enable 1/2

    reg  [31:0]         reg_busy;                   //register file is busy
    reg  [IDLEN-1:0]    reg_pitag   [31:0];         //pending write back itag

///////////////////////////////////////////////////////////////////////
//                     generate write enable and commit enable       //
///////////////////////////////////////////////////////////////////////
genvar j;
generate
    for(j=0; j<32; j=j+1)begin: writeenable_sel
        assign wen0[j] = iscoreboard_update_slave0.write & (iscoreboard_update_slave0.rdindex==j);
        assign wen1[j] = iscoreboard_update_slave1.write & (iscoreboard_update_slave1.rdindex==j);
        assign cen0[j] = commit0_valid & (commit0_rdindex==j) & commit0_wren;
        assign cen1[j] = commit1_valid & (commit1_rdindex==j) & commit1_wren;
    end
endgenerate
///////////////////////////////////////////////////////////////////////
//              scoreboard cell generate                             //
///////////////////////////////////////////////////////////////////////
genvar i;
generate
    for(i=0; i<32; i=i+1)begin:busy_flag_gen
        always_ff @( posedge clk_i ) begin
            if(RNM=="ENABLE")begin              //重命名开，提交时要对比itag
                if(srst_i)begin
                    reg_busy[i] <= 'h0;
                end
                else if(wen1[i])begin
                    reg_busy[i] <= 1'b1;
                    reg_pitag[i]<= iscoreboard_update_slave1.itag;
                end
                else if(wen0[i])begin
                    reg_busy[i] <= 1'b1;
                    reg_pitag[i]<= iscoreboard_update_slave0.itag;
                end
                else if((cen0[i] & (commit0_itag==reg_pitag[i])) | (cen1[i] & (commit1_itag==reg_pitag[i])))begin
                    reg_busy[i] <= 1'b0;
                    reg_pitag[i]<= 'hx;
                end
            end
            else begin
                if(srst_i)begin
                    reg_busy[i] <= 'h0;
                end
                else if(wen1[i])begin
                    reg_busy[i] <= 1'b1;
                end
                else if(wen0[i])begin
                    reg_busy[i] <= 1'b1;
                end
                else if(cen0[i] | cen1[i])begin
                    reg_busy[i] <= 1'b0;
                end
            end
        end
    end
endgenerate

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