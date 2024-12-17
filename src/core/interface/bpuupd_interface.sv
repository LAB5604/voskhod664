`include "prv664_config.svh"
`include "prv664_define.svh"
interface bpuupd_interface();

    logic                   valid;
    logic                   wr_req;				    //写请求信号
    logic [`XLEN-1:0]       wr_pc;					//要写入的分支PC
    logic [`XLEN-1:0]       wr_predictedpc;		    //要写入的预测PC
    logic [2:0]             wr_branchtype;          //要写入的分支类型
    logic                   wr_predictbit;          //要写入的预测位

    modport slave (

        input               valid,
        input               wr_req,
        input               wr_pc,
        input               wr_predictedpc,
        input               wr_branchtype,
        input               wr_predictbit

    );

    modport master(

        output              valid,
        output              wr_req,
        output              wr_pc,
        output              wr_predictedpc,
        output              wr_branchtype,
        output              wr_predictbit

    );

endinterface