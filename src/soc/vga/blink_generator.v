module blink_generator#(

    parameter BLINK_CYCLE_MS = 500          //in ms

)(
    input wire vgaclk_i,
    input wire vgarst_i,
    output reg blink
);

    reg [31:0] blink_counter;

always@( posedge vgaclk_i or posedge vgarst_i)begin
    if(vgarst_i)begin
        blink_counter <= 'h0;
    end
    else if(blink_counter==(25000*BLINK_CYCLE_MS))begin
        blink_counter <= 'h0;
        blink <= !blink;
    end
    else begin
        blink_counter <= blink_counter + 1;
    end
end

endmodule