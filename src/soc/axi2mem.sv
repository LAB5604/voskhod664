// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// ----------------------------
// AXI to SRAM Adapter
// ----------------------------
// Author: Florian Zaruba (zarubaf@iis.ee.ethz.ch)
// Change by Jack.pan (2320025806@qq.com) 20231108
//
// Description: Manages AXI transactions
//              Supports all burst accesses but only on aligned addresses and with full data width.
//              Assertions should guide you if there is something unsupported happening.
//Change log: modify axi interface
//
module axi2mem #(
    parameter int unsigned AXI_ID_WIDTH      = 10,
    parameter int unsigned AXI_ADDR_WIDTH    = 64,
    parameter int unsigned AXI_DATA_WIDTH    = 64,
    parameter int unsigned AXI_USER_WIDTH    = 10
)(
    input logic                         clk_i,    // Clock
    input logic                         rst_ni,  // Asynchronous reset active low
    //--------------- axi4 bus(interface)-----------
    sys_axi_ar.slave                    s_axi_ar,
    sys_axi_r.master                    s_axi_r,
    sys_axi_aw.slave                    s_axi_aw,
    sys_axi_w.slave                     s_axi_w,
    sys_axi_b.master                    s_axi_b,

    output logic                        req_o,
    output logic                        we_o,
    output logic [AXI_ADDR_WIDTH-1:0]   addr_o,
    output logic [AXI_DATA_WIDTH/8-1:0] be_o,
    output logic [AXI_USER_WIDTH-1:0]   user_o,
    output logic [AXI_DATA_WIDTH-1:0]   data_o,
    input  logic [AXI_USER_WIDTH-1:0]   user_i,
    input  logic [AXI_DATA_WIDTH-1:0]   data_i
);

    // AXI has the following rules governing the use of bursts:
    // - for wrapping bursts, the burst length must be 2, 4, 8, or 16
    // - a burst must not cross a 4KB address boundary
    // - early termination of bursts is not supported.
    typedef enum logic [1:0] { FIXED = 2'b00, INCR = 2'b01, WRAP = 2'b10} axi_burst_t;

    localparam LOG_NR_BYTES = $clog2(AXI_DATA_WIDTH/8);

    typedef struct packed {
        logic [AXI_ID_WIDTH-1:0]   id;
        logic [AXI_ADDR_WIDTH-1:0] addr;
        logic [7:0]                len;
        logic [2:0]                size;
        axi_burst_t                burst;
    } ax_req_t;

    // Registers
    enum logic [2:0] { IDLE, READ, WRITE, SEND_B, WAIT_WVALID }  state_d, state_q;
    ax_req_t                   ax_req_d, ax_req_q;
    logic [AXI_ADDR_WIDTH-1:0] req_addr_d, req_addr_q;
    logic [7:0]                cnt_d, cnt_q;

    function automatic logic [AXI_ADDR_WIDTH-1:0] get_wrap_boundary (input logic [AXI_ADDR_WIDTH-1:0] unaligned_address, input logic [7:0] len);
        logic [AXI_ADDR_WIDTH-1:0] warp_address = '0;
        //  for wrapping transfers ax_len can only be of size 1, 3, 7 or 15
        if (len == 4'b1)
            warp_address[AXI_ADDR_WIDTH-1:1+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-1:1+LOG_NR_BYTES];
        else if (len == 4'b11)
            warp_address[AXI_ADDR_WIDTH-1:2+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-1:2+LOG_NR_BYTES];
        else if (len == 4'b111)
            warp_address[AXI_ADDR_WIDTH-1:3+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-3:2+LOG_NR_BYTES];
        else if (len == 4'b1111)
            warp_address[AXI_ADDR_WIDTH-1:4+LOG_NR_BYTES] = unaligned_address[AXI_ADDR_WIDTH-3:4+LOG_NR_BYTES];

        return warp_address;
    endfunction

    logic [AXI_ADDR_WIDTH-1:0] aligned_address;
    logic [AXI_ADDR_WIDTH-1:0] wrap_boundary;
    logic [AXI_ADDR_WIDTH-1:0] upper_wrap_boundary;
    logic [AXI_ADDR_WIDTH-1:0] cons_addr;

    always_comb begin
        // address generation
        aligned_address = {ax_req_q.addr[AXI_ADDR_WIDTH-1:LOG_NR_BYTES], {{LOG_NR_BYTES}{1'b0}}};
        wrap_boundary = get_wrap_boundary(ax_req_q.addr, ax_req_q.len);
        // this will overflow
        upper_wrap_boundary = wrap_boundary + ((ax_req_q.len + 1) << LOG_NR_BYTES);
        // calculate consecutive address
        cons_addr = aligned_address + (cnt_q << LOG_NR_BYTES);

        // Transaction attributes
        // default assignments
        state_d    = state_q;
        ax_req_d   = ax_req_q;
        req_addr_d = req_addr_q;
        cnt_d      = cnt_q;
        // Memory default assignments
        data_o = s_axi_w.wdata;
        user_o = 0;//slave.w_user;      //TODO: NO wuser signal use
        be_o   = s_axi_w.wstrb;
        we_o   = 1'b0;
        req_o  = 1'b0;
        addr_o = '0;
        // AXI assignments
        // request
        s_axi_aw.awready = 1'b0;
        s_axi_ar.arready = 1'b0;
        // read response channel
        s_axi_r.rvalid  = 1'b0;
        s_axi_r.rdata   = data_i;
        s_axi_r.rresp   = '0;
        s_axi_r.rlast   = '0;
        s_axi_r.rid     = ax_req_q.id;
        //slave.r_user   = user_i;    //TODO: NO  ruser signal use
        // slave write data channel
        s_axi_w.wready  = 1'b0;
        // write response channel
        s_axi_b.bvalid  = 1'b0;
        s_axi_b.bresp   = 1'b0;
        s_axi_b.bid     = 1'b0;
        //slave.b_user   = 1'b0;      //TODO: No buser signal use

        case (state_q)

            IDLE: begin
                // Wait for a read or write
                // ------------
                // Read
                // ------------
                if (s_axi_ar.arvalid) begin
                    s_axi_ar.arready = 1'b1;
                    // sample ax
                    ax_req_d       = {s_axi_ar.arid, s_axi_ar.araddr, s_axi_ar.arlen, s_axi_ar.arsize, s_axi_ar.arburst};
                    state_d        = READ;
                    //  we can request the first address, this saves us time
                    req_o          = 1'b1;
                    addr_o         = s_axi_ar.araddr;
                    // save the address
                    req_addr_d     = s_axi_ar.araddr;
                    // save the ar_len
                    cnt_d          = 1;
                // ------------
                // Write
                // ------------
                end else if (s_axi_aw.awvalid) begin
                    s_axi_aw.awready = 1'b1;
                    s_axi_w.wready  = 1'b1;
                    addr_o         = s_axi_aw.awaddr;
                    // sample ax
                    ax_req_d       = {s_axi_aw.awid, s_axi_aw.awaddr, s_axi_aw.awlen, s_axi_aw.awsize, s_axi_aw.awburst};
                    // we've got our first w_valid so start the write process
                    if (s_axi_w.wvalid) begin
                        req_o          = 1'b1;
                        we_o           = 1'b1;
                        state_d        = (s_axi_w.wlast) ? SEND_B : WRITE;
                        cnt_d          = 1;
                    // we still have to wait for the first w_valid to arrive
                    end else
                        state_d = WAIT_WVALID;
                end
            end

            // ~> we are still missing a w_valid
            WAIT_WVALID: begin
                s_axi_w.wready = 1'b1;
                addr_o = ax_req_q.addr;
                // we can now make our first request
                if (s_axi_w.wvalid) begin
                    req_o          = 1'b1;
                    we_o           = 1'b1;
                    state_d        = (s_axi_w.wlast) ? SEND_B : WRITE;
                    cnt_d          = 1;
                end
            end

            READ: begin
                // keep request to memory high
                req_o  = 1'b1;
                addr_o = req_addr_q;
                // send the response
                s_axi_r.rvalid = 1'b1;
                s_axi_r.rdata  = data_i;
                //slave.r_user  = user_i;   //TODO: NO user signal 
                s_axi_r.rid    = ax_req_q.id;
                s_axi_r.rlast  = (cnt_q == ax_req_q.len + 1);

                // check that the master is ready, the slave must not wait on this
                if (s_axi_r.rready) begin
                    // ----------------------------
                    // Next address generation
                    // ----------------------------
                    // handle the correct burst type
                    case (ax_req_q.burst)
                        FIXED, INCR: addr_o = cons_addr;
                        WRAP:  begin
                            // check if the address reached warp boundary
                            if (cons_addr == upper_wrap_boundary) begin
                                addr_o = wrap_boundary;
                            // address warped beyond boundary
                            end else if (cons_addr > upper_wrap_boundary) begin
                                addr_o = ax_req_q.addr + ((cnt_q - ax_req_q.len) << LOG_NR_BYTES);
                            // we are still in the incremental regime
                            end else begin
                                addr_o = cons_addr;
                            end
                        end
                    endcase
                    // we need to change the address here for the upcoming request
                    // we sent the last byte -> go back to idle
                    if (s_axi_r.rlast) begin
                        state_d = IDLE;
                        // we already got everything
                        req_o = 1'b0;
                    end
                    // save the request address for the next cycle
                    req_addr_d = addr_o;
                    // we can decrease the counter as the master has consumed the read data
                    cnt_d = cnt_q + 1;
                    // TODO: configure correct byte-lane
                end
            end
            // ~> we already wrote the first word here
            WRITE: begin

                s_axi_w.wready = 1'b1;

                // consume a word here
                if (s_axi_w.wvalid) begin
                    req_o         = 1'b1;
                    we_o          = 1'b1;
                    // ----------------------------
                    // Next address generation
                    // ----------------------------
                    // handle the correct burst type
                    case (ax_req_q.burst)

                        FIXED, INCR: addr_o = cons_addr;
                        WRAP:  begin
                            // check if the address reached warp boundary
                            if (cons_addr == upper_wrap_boundary) begin
                                addr_o = wrap_boundary;
                            // address warped beyond boundary
                            end else if (cons_addr > upper_wrap_boundary) begin
                                addr_o = ax_req_q.addr + ((cnt_q - ax_req_q.len) << LOG_NR_BYTES);
                            // we are still in the incremental regime
                            end else begin
                                addr_o = cons_addr;
                            end
                        end
                    endcase
                    // save the request address for the next cycle
                    req_addr_d = addr_o;
                    // we can decrease the counter as the master has consumed the read data
                    cnt_d = cnt_q + 1;

                    if (s_axi_w.wlast)
                        state_d = SEND_B;
                end
            end
            // ~> send a write acknowledge back
            SEND_B: begin
                s_axi_b.bvalid = 1'b1;
                s_axi_b.bid    = ax_req_q.id;
                if (s_axi_b.bready)
                    state_d = IDLE;
            end

        endcase
    end

    `ifndef SYNTHESIS
    `ifndef VERILATOR
    // assert that only full data lane transfers allowed
    // assert property (
    //   @(posedge clk_i) axi_aw.awvalid |-> (axi_aw.awsize == LOG_NR_BYTES)) else $fatal ("Only full data lane transfers allowed");
    //   assert property (
    //   @(posedge clk_i) axi_ar.arvalid |-> (axi_ar.arsize == LOG_NR_BYTES)) else $fatal ("Only full data lane transfers allowed");
    // assert property (
    //   @(posedge clk_i) axi_aw.awvalid |-> (axi_ar.araddr[LOG_NR_BYTES-1:0] == '0)) else $fatal ("Unaligned accesses are not allowed at the moment");
    // assert property (
    //   @(posedge clk_i) axi_ar.arvalid |-> (axi_aw.awaddr[LOG_NR_BYTES-1:0] == '0)) else $fatal ("Unaligned accesses are not allowed at the moment");
    `endif
    `endif
    // --------------
    // Registers
    // --------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            state_q    <= IDLE;
            ax_req_q  <= '0;
            req_addr_q <= '0;
            cnt_q      <= '0;
        end else begin
            state_q    <= state_d;
            ax_req_q   <= ax_req_d;
            req_addr_q <= req_addr_d;
            cnt_q      <= cnt_d;
        end
    end
endmodule


