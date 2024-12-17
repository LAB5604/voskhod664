//              SImulation config
`define SIMULATION              //default set simulation
`define ENABLE_PHERP            //enable pherp (打开IO设备)
//              SoC config
`define EXT_MEMORY              //enable external memory(axi interface)
`define TXT_CRTC                //enable internal text mode VGA
//`define DEBUG_UART              //enable debug uart module
//              SoC system bus configuration 
`define AXI_ADDR_WIDTH      32
`define AXI_ID_WIDTH        12  //prv664 core need 8bit axi id width, bus bridge need 4bit tag width
`define AXI_DATA_WIDTH      64