module ras_tb();

    reg                 clk_i;
    reg                 rst_i;
    reg                 ras_pop_i;
    reg                 ras_push_i;
    reg     [63:00]     ras_addr_i;
    wire                ras_empty_o;
    wire                ras_full_o;
    wire    [63:00]     ras_addr_o;


    ras                                     ras
    (   
        .clk_i                              (clk_i      ),
        .rst_i                              (rst_i      ),
	    .ras_pop_i                          (ras_pop_i  ),
        .ras_push_i                         (ras_push_i ),
        .ras_addr_i                         (ras_addr_i ),
        .ras_empty_o                        (ras_empty_o),
        .ras_full_o                         (ras_full_o ),
	    .ras_addr_o                         (ras_addr_o )
    );

    task push (input [63:00] addr); begin
        @(posedge clk_i)
            ras_push_i = 1;
            ras_addr_i = addr;
        @(posedge clk_i)
            ras_push_i = 0;
            ras_addr_i = 0;
    end
    endtask
    
    task pop (); begin
        @(posedge clk_i)
            ras_pop_i = 1;
        @(posedge clk_i)
            ras_pop_i = 0;
    end
    endtask


    always begin
        #10 clk_i = ~clk_i;
    end
    initial begin
        clk_i = 1'b0;
        rst_i = 1'b0;
        ras_push_i = 'd0;
        ras_pop_i = 'd0;
        ras_addr_i = 'd0;
        #40
            rst_i = 1'b1;
        #20
            push('h100);
            push('h200);
            push('h300);
            push('h400);

            push(100);
            pop();
            push(200);
            pop();
            pop();
            pop();
            pop();
            pop();
            push('h100);
            push('h200);
            pop();
            pop();
            pop();
    end

endmodule