`include "prv664_define.svh"
`include "riscv_define.svh"
`include "prv664_config.svh"
//////////////////////////////////////////////////////////////////////////////////////////////////
//  Date    : 2022/9/3                                                                          //
//  Author  : Jack.Pan                                                                          //
//  Desc    : fp csrs for PRV664 processor                                                      //
//  Version : 0.0(Orignal)                                                                      //
//////////////////////////////////////////////////////////////////////////////////////////////////
module fpcsr(
    input wire      clk_i, arst_i,
    //-------------fp commit--------------------
    input wire              valid,
    input wire              csren,
    input wire [11:0]       csrindex,
    input wire [`XLEN-1:0]  csrdata,
    input wire              fflagen,
    input wire [4:0]        fflag,
    //-------------csr out-------------------
    output logic [`XLEN-1:0]   fcsr
);
    reg [2:0] frm;
    reg       nv, dz, of, uf, nx;

always_ff @( posedge clk_i or posedge arst_i ) begin
    if(arst_i)begin
        nv <= 1'b0;
        dz <= 1'b0;
        of <= 1'b0;
        uf <= 1'b0;
        nx <= 1'b0;
        frm<= `FRM_MODE_RNE;
    end
    else if(valid)begin
        if(csren&(csrindex==`URW_FCSR_INDEX))begin          //csr寄存器读写应当是最高的优先级
            nv <= csrdata[`FCSR_BIT_NV];
            dz <= csrdata[`FCSR_BIT_DZ];
            of <= csrdata[`FCSR_BIT_OF];
            uf <= csrdata[`FCSR_BIT_UF];
            nx <= csrdata[`FCSR_BIT_NX];
            frm<= csrdata[`FCSR_BIT_FRM_HI : `FCSR_BIT_FRM_LO];
        end
        else if(fflagen)begin   //浮点标志位更新
            nv <= nv | fflag[`FCSR_BIT_NV];
            dz <= dz | fflag[`FCSR_BIT_DZ];
            of <= of | fflag[`FCSR_BIT_OF];
            uf <= uf | fflag[`FCSR_BIT_UF];
            nx <= nx | fflag[`FCSR_BIT_NX];
        end
    end
end

assign fcsr = {56'b0, frm, nv, dz, of, uf, nx};

endmodule