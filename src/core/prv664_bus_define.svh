/***********************************************************
            bus configuration of prv664 cpu core
    NO TOUCH ANY THING IN THIS FILE
************************************************************/
`define BUS_ID_W            8   
`define AXI_BURST_FIXED     'b00
`define AXI_BURST_INCR      'b01
`define AXI_BURST_WRAP      'b10 
`define AXI_RESP_OKAY       'b00
`define AXI_RESP_EXOKAY     'b01
`define AXI_RESP_SLVERR     'b10
`define AXI_RESP_DECERR     'b11