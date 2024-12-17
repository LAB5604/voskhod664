`include "prv664_config.svh"
`include "prv664_define.svh"
`include "riscv_define.svh"
/*************************************************************************************
____    ____  ______        _______. __  ___  __    __    ______    _______  
\   \  /   / /  __  \      /       ||  |/  / |  |  |  |  /  __  \  |       \ 
 \   \/   / |  |  |  |    |   (----`|  '  /  |  |__|  | |  |  |  | |  .--.  |
  \      /  |  |  |  |     \   \    |    <   |   __   | |  |  |  | |  |  |  |
   \    /   |  `--'  | .----)   |   |  .  \  |  |  |  | |  `--'  | |  '--'  |
    \__/     \______/  |_______/    |__|\__\ |__|  |__|  \______/  |_______/ 
    
    Date    : 2024.1.24                                                                          
    Author  : Jack.Pan                                                                          
    Desc    : write back select unit for prv664                                            
    Version :1.2(timing bug fix) 
    change log:
            1.1: bypass and sysmanage module writeback added   
            1.2: fix timing bug
********************************************************************************/
module prv664_writeback(

    pip_wb_interface.slave          bru_wb_sif,
    pip_wb_interface.slave          alu0_wb_sif,
    pip_wb_interface.slave          alu1_wb_sif,
    pip_wb_interface.slave          mdiv_wb_sif,
    pip_wb_interface.slave          fpu_wb_sif,
    pip_wb_interface.slave          lsu_wb_sif,
    pip_wb_interface.slave          bypass_wb_sif,
    pip_wb_interface.slave          sysmag_wb_sif,

    pip_wb_interface.master         wbu_mif0,
    pip_wb_interface.master         wbu_mif1

);
localparam WB_SEL_NONE= 4'h0,
           WB_SEL_BRU = 4'h1,
           WB_SEL_ALU0= 4'h2,
           WB_SEL_ALU1= 4'h3,
           WB_SEL_MDIV= 4'h4,
           WB_SEL_FPU = 4'h5,
           WB_SEL_LSU = 4'h6,
           WB_SEL_BYPASS=4'h7,
           WB_SEL_SYSMAG=4'h8;

logic [1:0] bru_wb_ready, alu0_wb_ready, alu1_wb_ready, mdiv_wb_ready, fpu_wb_ready, lsu_wb_ready, bypass_wb_ready, sysmag_wb_ready;
logic [3:0] wbu_mif0_sel, wbu_mif1_sel;

//----------------------write back port handshake----------------------------
assign bru_wb_sif.ready = |bru_wb_ready;
assign alu0_wb_sif.ready= |alu0_wb_ready;
assign alu1_wb_sif.ready= |alu1_wb_ready;
assign mdiv_wb_sif.ready= |mdiv_wb_ready;
assign fpu_wb_sif.ready = |fpu_wb_ready;
assign lsu_wb_sif.ready = |lsu_wb_ready;
assign bypass_wb_sif.ready=|bypass_wb_ready;
assign sysmag_wb_sif.ready=|sysmag_wb_ready;
//---------------------- write back port-0, to rob0 select---------------------
always_comb begin
    if(lsu_wb_sif.valid & !lsu_wb_sif.itag[7])begin
        wbu_mif0_sel    = WB_SEL_LSU;
        wbu_mif0.valid  = 1'b1;
    end
    else if(alu0_wb_sif.valid & !alu0_wb_sif.itag[7])begin
        wbu_mif0_sel    = WB_SEL_ALU0;
        wbu_mif0.valid  = 1'b1;
    end
    else if(alu1_wb_sif.valid & !alu1_wb_sif.itag[7])begin
        wbu_mif0_sel    = WB_SEL_ALU1;
        wbu_mif0.valid  = 1'b1;
    end
    else if(mdiv_wb_sif.valid & !mdiv_wb_sif.itag[7])begin
        wbu_mif0_sel    = WB_SEL_MDIV;
        wbu_mif0.valid  = 1'b1;
    end
    else if(fpu_wb_sif.valid & !fpu_wb_sif.itag[7])begin
        wbu_mif0_sel    = WB_SEL_FPU;
        wbu_mif0.valid  = 1'b1;
    end
    else if(bru_wb_sif.valid & !bru_wb_sif.itag[7])begin
        wbu_mif0_sel    = WB_SEL_BRU;
        wbu_mif0.valid  = 1'b1;
    end
    else if(bypass_wb_sif.valid & !bypass_wb_sif.itag[7])begin
        wbu_mif0_sel    = WB_SEL_BYPASS;
        wbu_mif0.valid  = 1'b1;
    end
    else if(sysmag_wb_sif.valid & !sysmag_wb_sif.itag[7])begin
        wbu_mif0_sel    = WB_SEL_SYSMAG;
        wbu_mif0.valid  = 1'b1;
    end
    else begin
        wbu_mif0_sel    = WB_SEL_NONE;
        wbu_mif0.valid  = 1'b0;
    end
    bru_wb_ready[0] = (wbu_mif0_sel==WB_SEL_BRU) & wbu_mif0.ready;
    alu0_wb_ready[0]= (wbu_mif0_sel==WB_SEL_ALU0)& wbu_mif0.ready;
    alu1_wb_ready[0]= (wbu_mif0_sel==WB_SEL_ALU1)& wbu_mif0.ready;
    mdiv_wb_ready[0]= (wbu_mif0_sel==WB_SEL_MDIV)& wbu_mif0.ready;
    fpu_wb_ready[0] = (wbu_mif0_sel==WB_SEL_FPU) & wbu_mif0.ready;
    lsu_wb_ready[0] = (wbu_mif0_sel==WB_SEL_LSU) & wbu_mif0.ready;
    bypass_wb_ready[0]=(wbu_mif0_sel==WB_SEL_BYPASS) & wbu_mif0.ready;
    sysmag_wb_ready[0]=(wbu_mif0_sel==WB_SEL_SYSMAG) & wbu_mif0.ready;
    //---------------------------select write back data-----------------------------
    case(wbu_mif0_sel)
        WB_SEL_BRU :
        begin 
            wbu_mif0.data = bru_wb_sif.data;
            wbu_mif0.itag = bru_wb_sif.itag;
        end
        WB_SEL_ALU0:
        begin 
            wbu_mif0.data = alu0_wb_sif.data;
            wbu_mif0.itag = alu0_wb_sif.itag;
        end
        WB_SEL_ALU1:
        begin 
            wbu_mif0.data = alu1_wb_sif.data;
            wbu_mif0.itag = alu1_wb_sif.itag;
        end
        WB_SEL_MDIV:
        begin 
            wbu_mif0.data = mdiv_wb_sif.data;
            wbu_mif0.itag = mdiv_wb_sif.itag;
        end
        WB_SEL_FPU :
        begin 
            wbu_mif0.data = fpu_wb_sif.data;
            wbu_mif0.itag = fpu_wb_sif.itag;
        end
        WB_SEL_LSU :
        begin 
            wbu_mif0.data = lsu_wb_sif.data;
            wbu_mif0.itag = lsu_wb_sif.itag;
        end
        WB_SEL_BYPASS :
        begin
            wbu_mif0.data = 'hx;                //bypass unit dont write back any data
            wbu_mif0.itag = bypass_wb_sif.itag;
        end
        WB_SEL_SYSMAG :
        begin
            wbu_mif0.data = 'hx;
            wbu_mif0.itag = sysmag_wb_sif.itag;
        end
        default    :
        begin
            wbu_mif0.data = 'hx;
            wbu_mif0.itag = 'hx;
        end
    endcase

    case(wbu_mif0_sel)
        WB_SEL_ALU0: wbu_mif0.csrdata        =   alu0_wb_sif.csrdata;
        WB_SEL_ALU1: wbu_mif0.csrdata        =   alu1_wb_sif.csrdata;
        WB_SEL_LSU : wbu_mif0.csrdata        =   lsu_wb_sif.csrdata;
        default    : wbu_mif0.csrdata        =   'hx;
    endcase

    wbu_mif0.branchaddr     = (wbu_mif0_sel==WB_SEL_BRU) ? bru_wb_sif.branchaddr : 'h0;
    wbu_mif0.jump           = (wbu_mif0_sel==WB_SEL_BRU) ? bru_wb_sif.jump : 'h0;
    wbu_mif0.fflag          = (wbu_mif0_sel==WB_SEL_FPU) ? fpu_wb_sif.fflag : 'h0;
    wbu_mif0.mmio           = (wbu_mif0_sel==WB_SEL_LSU) ? lsu_wb_sif.mmio : 'h0;
    wbu_mif0.load_acc_flt   = (wbu_mif0_sel==WB_SEL_LSU) ? lsu_wb_sif.load_acc_flt : 'h0;
    wbu_mif0.load_addr_mis  = (wbu_mif0_sel==WB_SEL_LSU) ? lsu_wb_sif.load_addr_mis : 'h0;
    wbu_mif0.load_page_flt  = (wbu_mif0_sel==WB_SEL_LSU) ? lsu_wb_sif.load_page_flt : 'h0;
    wbu_mif0.store_acc_flt  = (wbu_mif0_sel==WB_SEL_LSU) ? lsu_wb_sif.store_acc_flt : 'h0;
    wbu_mif0.store_addr_mis = (wbu_mif0_sel==WB_SEL_LSU) ? lsu_wb_sif.store_addr_mis : 'h0;
    wbu_mif0.store_page_flt = (wbu_mif0_sel==WB_SEL_LSU) ? lsu_wb_sif.store_page_flt : 'h0;

end

//---------------------- write back port-1, to rob1 select---------------------
always_comb begin
    if(lsu_wb_sif.valid & lsu_wb_sif.itag[7])begin
        wbu_mif1_sel    = WB_SEL_LSU;
        wbu_mif1.valid  = 1'b1;
    end
    else if(alu0_wb_sif.valid & alu0_wb_sif.itag[7])begin
        wbu_mif1_sel    = WB_SEL_ALU0;
        wbu_mif1.valid  = 1'b1;
    end
    else if(alu1_wb_sif.valid & alu1_wb_sif.itag[7])begin
        wbu_mif1_sel    = WB_SEL_ALU1;
        wbu_mif1.valid  = 1'b1;
    end
    else if(mdiv_wb_sif.valid & mdiv_wb_sif.itag[7])begin
        wbu_mif1_sel    = WB_SEL_MDIV;
        wbu_mif1.valid  = 1'b1;
    end
    else if(fpu_wb_sif.valid & fpu_wb_sif.itag[7])begin
        wbu_mif1_sel    = WB_SEL_FPU;
        wbu_mif1.valid  = 1'b1;
    end
    else if(bru_wb_sif.valid & bru_wb_sif.itag[7])begin
        wbu_mif1_sel    = WB_SEL_BRU;
        wbu_mif1.valid  = 1'b1;
    end
    else if(bypass_wb_sif.valid & bypass_wb_sif.itag[7])begin
        wbu_mif1_sel    = WB_SEL_BYPASS;
        wbu_mif1.valid  = 1'b1;
    end
    else if(sysmag_wb_sif.valid & sysmag_wb_sif.itag[7])begin
        wbu_mif1_sel    = WB_SEL_SYSMAG;
        wbu_mif1.valid  = 1'b1;
    end
    else begin
        wbu_mif1_sel    = WB_SEL_NONE;
        wbu_mif1.valid  = 1'b0;
    end
    bru_wb_ready [1]= (wbu_mif1_sel==WB_SEL_BRU) & wbu_mif1.ready;
    alu0_wb_ready[1]= (wbu_mif1_sel==WB_SEL_ALU0)& wbu_mif1.ready;
    alu1_wb_ready[1]= (wbu_mif1_sel==WB_SEL_ALU1)& wbu_mif1.ready;
    mdiv_wb_ready[1]= (wbu_mif1_sel==WB_SEL_MDIV)& wbu_mif1.ready;
    fpu_wb_ready [1]= (wbu_mif1_sel==WB_SEL_FPU) & wbu_mif1.ready;
    lsu_wb_ready [1]= (wbu_mif1_sel==WB_SEL_LSU) & wbu_mif1.ready;
    bypass_wb_ready[1]=(wbu_mif1_sel==WB_SEL_BYPASS) & wbu_mif1.ready;
    sysmag_wb_ready[1]=(wbu_mif1_sel==WB_SEL_SYSMAG) & wbu_mif1.ready;
    //---------------------------select write back data-----------------------------
    case(wbu_mif1_sel)
        WB_SEL_BRU :
        begin 
            wbu_mif1.data = bru_wb_sif.data;
            wbu_mif1.itag = bru_wb_sif.itag;
        end
        WB_SEL_ALU0:
        begin 
            wbu_mif1.data = alu0_wb_sif.data;
            wbu_mif1.itag = alu0_wb_sif.itag;
        end
        WB_SEL_ALU1:
        begin 
            wbu_mif1.data = alu1_wb_sif.data;
            wbu_mif1.itag = alu1_wb_sif.itag;
        end
        WB_SEL_MDIV:
        begin 
            wbu_mif1.data = mdiv_wb_sif.data;
            wbu_mif1.itag = mdiv_wb_sif.itag;
        end
        WB_SEL_FPU :
        begin 
            wbu_mif1.data = fpu_wb_sif.data;
            wbu_mif1.itag = fpu_wb_sif.itag;
        end
        WB_SEL_LSU :
        begin 
            wbu_mif1.data = lsu_wb_sif.data;
            wbu_mif1.itag = lsu_wb_sif.itag;
        end
        WB_SEL_BYPASS :
        begin
            wbu_mif1.data = 'hx;                //bypass unit dont write back any data
            wbu_mif1.itag = bypass_wb_sif.itag;
        end
        WB_SEL_SYSMAG :
        begin
            wbu_mif1.data = 'hx;
            wbu_mif1.itag = sysmag_wb_sif.itag;
        end
        default    :
        begin
            wbu_mif1.data = 'hx;
            wbu_mif1.itag = 'hx;
        end
    endcase

    case(wbu_mif1_sel)
        WB_SEL_ALU0: wbu_mif1.csrdata        =   alu0_wb_sif.csrdata;
        WB_SEL_ALU1: wbu_mif1.csrdata        =   alu1_wb_sif.csrdata;
        WB_SEL_LSU : wbu_mif1.csrdata        =   lsu_wb_sif.csrdata;
        default    : wbu_mif1.csrdata        =   'hx;
    endcase

    wbu_mif1.branchaddr     = (wbu_mif1_sel==WB_SEL_BRU) ? bru_wb_sif.branchaddr : 'h0;
    wbu_mif1.jump           = (wbu_mif1_sel==WB_SEL_BRU) ? bru_wb_sif.jump : 'h0;
    wbu_mif1.fflag          = (wbu_mif1_sel==WB_SEL_FPU) ? fpu_wb_sif.fflag : 'h0;
    wbu_mif1.mmio           = (wbu_mif1_sel==WB_SEL_LSU) ? lsu_wb_sif.mmio : 'h0;
    wbu_mif1.load_acc_flt   = (wbu_mif1_sel==WB_SEL_LSU) ? lsu_wb_sif.load_acc_flt : 'h0;
    wbu_mif1.load_addr_mis  = (wbu_mif1_sel==WB_SEL_LSU) ? lsu_wb_sif.load_addr_mis : 'h0;
    wbu_mif1.load_page_flt  = (wbu_mif1_sel==WB_SEL_LSU) ? lsu_wb_sif.load_page_flt : 'h0;
    wbu_mif1.store_acc_flt  = (wbu_mif1_sel==WB_SEL_LSU) ? lsu_wb_sif.store_acc_flt : 'h0;
    wbu_mif1.store_addr_mis = (wbu_mif1_sel==WB_SEL_LSU) ? lsu_wb_sif.store_addr_mis : 'h0;
    wbu_mif1.store_page_flt = (wbu_mif1_sel==WB_SEL_LSU) ? lsu_wb_sif.store_page_flt : 'h0;

end
//------------------------------assert-----------------------------
`ifdef SIMULATION
    
`endif


endmodule