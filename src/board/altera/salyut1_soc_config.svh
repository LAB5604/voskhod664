//`define SIMULATION             //default set simulation
`define OCRAM_SIZE 131072       //65536=64KByte 131072=128KByte 262144=256KByte 
//`define EXT_MEMORY              //enable external memory(axi interface)

//              SoC system bus configuration 
`define AXI_ADDR_WIDTH      32
`define AXI_ID_WIDTH        12  //prv664 core need 8bit axi id width, bus bridge need 4bit tag width
`define AXI_DATA_WIDTH      64