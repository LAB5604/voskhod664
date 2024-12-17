`include "prv664_define.svh"
`include "riscv_define.svh"
`include"prv664_config.svh"
/**********************************************************************************************

   Copyright (c) [2024] [JackPan, XiaoyuHong, KuiSun]
   [Software Name] is licensed under Mulan PSL v2.
   You can use this software according to the terms and conditions of the Mulan PSL v2. 
   You may obtain a copy of Mulan PSL v2 at:
            http://license.coscl.org.cn/MulanPSL2 
   THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.  
   See the Mulan PSL v2 for more details.  

____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
                                                                             
    Desc    : PRV664(voskhod664) pht 
    Author  : JackPan
    Date    : 2024/02/07
    Version : 0.0(file initialize)
              0.1(pht update bug fix)

    change log:
            2024/02/07: version 0.1  解决了pht更新分支信息时会更新错误位置的bug 

***********************************************************************************************/
module pht
#(
    parameter   PHT_SIZE    =   64
)(
    input   wire                    clk_i,
    input   wire                    rst_i,
    input   wire    [`XLEN-1:00]    pht_rd_pc_i,
    output  wire    [03     :00]    pht_rd_predicted_o,
    //
    input   wire                    pht_wr_req_i,
    input   wire    [`XLEN-1:00]    pht_wr_pc_i,
    input   wire                    pht_wr_predictbit_i
);

    localparam      GHR_WIDTH           =   $clog2(PHT_SIZE)                    ,
                    CHANEL_ID_WIDTH     =   2                                   ,
                    PREDICT_PC_WIDTH    =   GHR_WIDTH + CHANEL_ID_WIDTH         ,
                    READ_PC_WIDTH       =   PREDICT_PC_WIDTH - CHANEL_ID_WIDTH  ,
                    WRITE_BACK_PC_WIDTH =   PREDICT_PC_WIDTH                    ,
                    WRITE_PC_WIDTH      =   READ_PC_WIDTH                       ;

    localparam      StronglyNotTaken    =   2'b00,
                    WeaklyNotTaken      =   2'b01,
                    WeaklyTaken         =   2'b11,
                    StronglyTaken       =   2'b10;

    
    /*
        Addr
    */
    wire    [PREDICT_PC_WIDTH-1:00]     Predict_PC1     =   pht_rd_pc_i[PREDICT_PC_WIDTH+1:02];
    wire    [PREDICT_PC_WIDTH-1:00]     Predict_PC2     =   pht_rd_pc_i[PREDICT_PC_WIDTH+1:02];/*Predict_PC1 + { {PREDICT_PC_WIDTH-1{1'b0}}, 1'b1 };*/
    wire    [PREDICT_PC_WIDTH-1:00]     Predict_PC3     =   pht_rd_pc_i[PREDICT_PC_WIDTH+1:02];/*Predict_PC1 + { {PREDICT_PC_WIDTH-2{1'b0}}, 2'd2 };*/
    wire    [PREDICT_PC_WIDTH-1:00]     Predict_PC4     =   pht_rd_pc_i[PREDICT_PC_WIDTH+1:02];/*Predict_PC1 + { {PREDICT_PC_WIDTH-2{1'b0}}, 2'd3 };*/
    //  Chanel
    wire    [CHANEL_ID_WIDTH-1:00]      Read_Chanel_Id1 =   Predict_PC1[CHANEL_ID_WIDTH-1:00];
    //wire    [CHANEL_ID_WIDTH-1:00]      Read_Chanel_Id2 =   Predict_PC2[CHANEL_ID_WIDTH-1:00];
    //wire    [CHANEL_ID_WIDTH-1:00]      Read_Chanel_Id3 =   Predict_PC3[CHANEL_ID_WIDTH-1:00];
    //wire    [CHANEL_ID_WIDTH-1:00]      Read_Chanel_Id4 =   Predict_PC4[CHANEL_ID_WIDTH-1:00];
    //
    wire    [READ_PC_WIDTH-1:00]        Read_PC1        =   Predict_PC1[PREDICT_PC_WIDTH-1:02] ;
    wire    [READ_PC_WIDTH-1:00]        Read_PC2        =   Predict_PC2[PREDICT_PC_WIDTH-1:02] ;
    wire    [READ_PC_WIDTH-1:00]        Read_PC3        =   Predict_PC3[PREDICT_PC_WIDTH-1:02] ;
    wire    [READ_PC_WIDTH-1:00]        Read_PC4        =   Predict_PC4[PREDICT_PC_WIDTH-1:02] ;
    //  
    wire    [WRITE_BACK_PC_WIDTH-1:00]  WriteBack_PC    =   pht_wr_pc_i[WRITE_BACK_PC_WIDTH+1:02] ;
    //
    wire    [CHANEL_ID_WIDTH-1:00]      Write_Chanel_Id =   WriteBack_PC[CHANEL_ID_WIDTH-1:00] ;
    //
    wire    [WRITE_PC_WIDTH-1:00]       Write_PC        =   WriteBack_PC[WRITE_BACK_PC_WIDTH-1:02] ;
    /*
        GHRs
    */
    reg     [GHR_WIDTH-1:00]            GHR1;
    reg     [GHR_WIDTH-1:00]            GHR2;
    reg     [GHR_WIDTH-1:00]            GHR3;
    reg     [GHR_WIDTH-1:00]            GHR4;
    always @( posedge clk_i ) begin
        if ( rst_i ) begin
            GHR1    <=  {GHR_WIDTH{1'b0}};
            GHR2    <=  {GHR_WIDTH{1'b0}};
            GHR3    <=  {GHR_WIDTH{1'b0}};
            GHR4    <=  {GHR_WIDTH{1'b0}};
        end
        else begin
            if ( pht_wr_req_i ) begin
                case( Write_Chanel_Id )
                    2'b00 : GHR1    <=  {GHR1[GHR_WIDTH-2:00], pht_wr_predictbit_i};
                    2'b01 : GHR2    <=  {GHR2[GHR_WIDTH-2:00], pht_wr_predictbit_i};
                    2'b10 : GHR3    <=  {GHR3[GHR_WIDTH-2:00], pht_wr_predictbit_i};
                    2'b11 : GHR4    <=  {GHR4[GHR_WIDTH-2:00], pht_wr_predictbit_i};
                endcase
            end
        end
    end
    /*
        PHT
    */
    logic    [READ_PC_WIDTH-1:00]    Pht_RdAddr1 ;
    logic    [READ_PC_WIDTH-1:00]    Pht_RdAddr2 ;
    logic    [READ_PC_WIDTH-1:00]    Pht_RdAddr3 ;
    logic    [READ_PC_WIDTH-1:00]    Pht_RdAddr4 ;
    logic    [WRITE_PC_WIDTH-1:00]   Pht_WrAddr  ;  
    
    /*
        PHT Item Valid Bit
    */
    reg     Pht_ItemValid1  [PHT_SIZE-1:00];
    reg     Pht_ItemValid2  [PHT_SIZE-1:00];
    reg     Pht_ItemValid3  [PHT_SIZE-1:00];
    reg     Pht_ItemValid4  [PHT_SIZE-1:00];

    genvar i;
    generate
        for (i = 0; i < PHT_SIZE; ++i) begin:Pht_ItemValid1_wire
            always @( posedge clk_i ) begin
                if( rst_i ) 
                    Pht_ItemValid1[i]   <=  1'b0;
                else 
                    if( pht_wr_req_i && Write_Chanel_Id == 2'b00 && Pht_WrAddr == i)
                        Pht_ItemValid1[i]   <=  1'b1;
            end
        end
    endgenerate
    generate
        for (i = 0; i < PHT_SIZE; ++i) begin:Pht_ItemValid2_wire
            always @( posedge clk_i ) begin
                if( rst_i ) 
                    Pht_ItemValid2[i]   <=  1'b0;
                else 
                    if( pht_wr_req_i && Write_Chanel_Id == 2'b01 && Pht_WrAddr == i)
                        Pht_ItemValid2[i]   <=  1'b1;
            end
        end
    endgenerate
    generate
        for (i = 0; i < PHT_SIZE; ++i) begin:Pht_ItemValid3_wire
            always @( posedge clk_i ) begin
                if( rst_i ) 
                    Pht_ItemValid3[i]   <=  1'b0;
                else 
                    if( pht_wr_req_i && Write_Chanel_Id == 2'b10 && Pht_WrAddr == i)
                        Pht_ItemValid3[i]   <=  1'b1;
            end
        end
    endgenerate
    generate
        for (i = 0; i < PHT_SIZE; ++i) begin:Pht_ItemValid4_wire
            always @( posedge clk_i ) begin
                if( rst_i ) 
                    Pht_ItemValid4[i]   <=  1'b0;
                else 
                    if( pht_wr_req_i && Write_Chanel_Id == 2'b11 && Pht_WrAddr == i)
                        Pht_ItemValid4[i]   <=  1'b1;
            end
        end
    endgenerate


    /*
        Read Item Valid
    */
    wire            ItemValid1 ;
    wire            ItemValid2 ;
    wire            ItemValid3 ;
    wire            ItemValid4 ;
    assign ItemValid1  =   Pht_ItemValid1[Pht_RdAddr1];
    assign ItemValid2  =   Pht_ItemValid2[Pht_RdAddr2];
    assign ItemValid3  =   Pht_ItemValid3[Pht_RdAddr3];
    assign ItemValid4  =   Pht_ItemValid4[Pht_RdAddr4];
    always_comb begin
        Pht_RdAddr1 = Write_PC ^ GHR1 ;
        Pht_RdAddr2 = Write_PC ^ GHR2 ;
        Pht_RdAddr3 = Write_PC ^ GHR3 ;
        Pht_RdAddr4 = Write_PC ^ GHR4 ;
        
        Pht_WrAddr  = Pht_RdAddr1 ;
        if( pht_wr_req_i ) begin
            case ( Write_Chanel_Id )
                2'b00 : begin
                    Pht_RdAddr1 = Write_PC ^ GHR1 ;
                    Pht_WrAddr  = Write_PC ^ {GHR1[GHR_WIDTH-2:00], pht_wr_predictbit_i} ;
                end
                2'b01 : begin
                    Pht_RdAddr2 = Write_PC ^ GHR2;
                    Pht_WrAddr  = Write_PC ^ {GHR2[GHR_WIDTH-2:00], pht_wr_predictbit_i} ;
                end
                2'b10 : begin
                    Pht_RdAddr3 = Write_PC ^ GHR3;
                    Pht_WrAddr  = Write_PC ^ {GHR3[GHR_WIDTH-2:00], pht_wr_predictbit_i} ;
                end
                2'b11 : begin
                    Pht_RdAddr4 = Write_PC ^ GHR4;
                    Pht_WrAddr  = Write_PC ^ {GHR4[GHR_WIDTH-2:00], pht_wr_predictbit_i} ;
                end
            endcase
        end
        else begin
            Pht_RdAddr1 = Read_PC1 ^ GHR1;
            Pht_RdAddr2 = Read_PC2 ^ GHR2;
            Pht_RdAddr3 = Read_PC3 ^ GHR3;
            Pht_RdAddr4 = Read_PC4 ^ GHR4;
        end
    end
    //

    wire    [01:00]             Pht_RdData1_temp;
    wire    [01:00]             Pht_RdData2_temp;
    wire    [01:00]             Pht_RdData3_temp;
    wire    [01:00]             Pht_RdData4_temp;
    wire                        Pht_WrEn1   =   pht_wr_req_i & ( Write_Chanel_Id == 2'b00 );
    wire                        Pht_WrEn2   =   pht_wr_req_i & ( Write_Chanel_Id == 2'b01 );
    wire                        Pht_WrEn3   =   pht_wr_req_i & ( Write_Chanel_Id == 2'b10 );
    wire                        Pht_WrEn4   =   pht_wr_req_i & ( Write_Chanel_Id == 2'b11 );
    reg     [01:00]             Pht_WrData  ;
    /*
        PHT Chanel 1
    */
    sram_1r1w_async_read
    #(
        .DATA_WIDTH     (2          ),
        .DATA_DEPTH     (PHT_SIZE   )
    )
    Pht_Ch1
    (
        .clkw           (clk_i              ),
        .addrr          (Pht_RdAddr1        ),
        .addrw          (Pht_WrAddr         ),
        .ce             (1'b1               ),
        .we             (Pht_WrEn1          ),
        .datar          (Pht_RdData1_temp   ),
        .dataw          (Pht_WrData         )
    );
    /*
        PHT Chanel 2
    */
    sram_1r1w_async_read
    #(
        .DATA_WIDTH     (2          ),
        .DATA_DEPTH     (PHT_SIZE   )
    )
    Pht_Ch2
    (
        .clkw           (clk_i              ),
        .addrr          (Pht_RdAddr2        ),
        .addrw          (Pht_WrAddr         ),
        .ce             (1'b1               ),
        .we             (Pht_WrEn2          ),
        .datar          (Pht_RdData2_temp   ),
        .dataw          (Pht_WrData         )
    );
    /*
        PHT Chanel 3
    */
    sram_1r1w_async_read
    #(
        .DATA_WIDTH     (2          ),
        .DATA_DEPTH     (PHT_SIZE   )
    )
    Pht_Ch3
    (
        .clkw           (clk_i              ),
        .addrr          (Pht_RdAddr3        ),
        .addrw          (Pht_WrAddr         ),
        .ce             (1'b1               ),
        .we             (Pht_WrEn3          ),
        .datar          (Pht_RdData3_temp   ),
        .dataw          (Pht_WrData         )
    );
    /*
        PHT Chanel 3
    */
    sram_1r1w_async_read
    #(
        .DATA_WIDTH     (2          ),
        .DATA_DEPTH     (PHT_SIZE   )
    )
    Pht_Ch4
    (
        .clkw           (clk_i              ),
        .addrr          (Pht_RdAddr4        ),
        .addrw          (Pht_WrAddr         ),
        .ce             (1'b1               ),
        .we             (Pht_WrEn4          ),
        .datar          (Pht_RdData4_temp   ),
        .dataw          (Pht_WrData         )
    );


    wire    [01:00] Pht_RdData1 =   ItemValid1  ?   Pht_RdData1_temp : 2'b0;
    wire    [01:00] Pht_RdData2 =   ItemValid2  ?   Pht_RdData2_temp : 2'b0;
    wire    [01:00] Pht_RdData3 =   ItemValid3  ?   Pht_RdData3_temp : 2'b0;
    wire    [01:00] Pht_RdData4 =   ItemValid4  ?   Pht_RdData4_temp : 2'b0;

    /*
        PHT Item Update logic
    */
    reg    [01:00] DataForUpdate;
    always @ ( * ) begin
        case ( Write_Chanel_Id )
            2'b00 : DataForUpdate = ItemValid1 ? Pht_RdData1_temp : (pht_wr_predictbit_i ? WeaklyNotTaken : WeaklyTaken);
            2'b01 : DataForUpdate = ItemValid2 ? Pht_RdData2_temp : (pht_wr_predictbit_i ? WeaklyNotTaken : WeaklyTaken);
            2'b10 : DataForUpdate = ItemValid3 ? Pht_RdData3_temp : (pht_wr_predictbit_i ? WeaklyNotTaken : WeaklyTaken);
            2'b11 : DataForUpdate = ItemValid4 ? Pht_RdData4_temp : (pht_wr_predictbit_i ? WeaklyNotTaken : WeaklyTaken);
        endcase
    end

    always_comb begin
        Pht_WrData = DataForUpdate;
        case ( DataForUpdate)
            StronglyNotTaken : begin
                if( pht_wr_predictbit_i )
                    Pht_WrData = WeaklyNotTaken;
            end
            WeaklyNotTaken : begin
                if( pht_wr_predictbit_i )
                    Pht_WrData = WeaklyTaken;
                else
                    Pht_WrData = StronglyNotTaken;
            end
            WeaklyTaken : begin
                if( pht_wr_predictbit_i )
                    Pht_WrData = StronglyTaken;
                else
                    Pht_WrData = WeaklyNotTaken;
            end
            StronglyTaken : begin
                if( !pht_wr_predictbit_i )
                    Pht_WrData = WeaklyTaken;
            end
        endcase
    end


    assign  pht_rd_predicted_o[0]   =   Pht_RdData1[1] ;

    assign  pht_rd_predicted_o[1]   =   Pht_RdData2[1] ;

    assign  pht_rd_predicted_o[2]   =   Pht_RdData3[1] ;

    assign  pht_rd_predicted_o[3]   =   Pht_RdData4[1] ;



endmodule