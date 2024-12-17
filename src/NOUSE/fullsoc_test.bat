set DEST_FILE=.\fullsoc_test_proj\src
set /p var=Select mode 1=init project file 2=copy src
if %var%==1 (
    md fullsoc_test_proj\work
    md fullsoc_test_proj\src
    copy .\fullsoc_test.do .\fullsoc_test_proj
)
if %var%==2 (
    @echo on
    del %DEST_FILE%\*.*
    ::generic instence module
    copy .\src\misc\fifo1r1w.v %DEST_FILE%
    copy .\src\misc\sram_1r1w_async_read.v %DEST_FILE%
    copy .\src\misc\sram_1rw_async_read.v %DEST_FILE%
    copy .\src\misc\sram_1rw_sync_read.v %DEST_FILE%
    copy .\src\misc\bsc_lib\*.v %DEST_FILE%
    ::cpu core module
    copy .\src\core\interface\*.sv %DEST_FILE%
    copy .\src\core\pipline\commit\*.sv %DEST_FILE%
    copy .\src\core\pipline\csr\*.sv %DEST_FILE%
    copy .\src\core\pipline\decode\decode.sv %DEST_FILE%
    copy .\src\core\pipline\decode\decode_input_manage.sv %DEST_FILE%
    copy .\src\core\pipline\decode\decode_output_manage.sv %DEST_FILE%
    copy .\src\core\pipline\decode\prv664_decode.sv %DEST_FILE%
    copy .\src\core\pipline\dispatch\*.sv %DEST_FILE%
    copy .\src\core\pipline\execute\*.sv %DEST_FILE%
    copy .\src\core\pipline\execute\mdiv\*.v %DEST_FILE%
    copy .\src\core\pipline\execute\mdiv\*.sv %DEST_FILE%
    copy .\src\core\pipline\mmu\*.sv %DEST_FILE%
    copy .\src\core\pipline\instr_front\*.sv %DEST_FILE%
    copy .\src\core\pipline\instr_front\*.v %DEST_FILE%
    copy .\src\core\pipline\rob\prv664_rob.sv %DEST_FILE%
    copy .\src\core\pipline\writeback\prv664_writeback.sv %DEST_FILE%
    copy .\src\core\pipline\prv664_pipline_top.sv %DEST_FILE%
    copy .\src\core\pipline\rob_core.sv %DEST_FILE%
    copy .\src\core\cache\*.v %DEST_FILE%
    copy .\src\core\cache\*.sv %DEST_FILE%
    copy .\src\core\prv664_top.sv %DEST_FILE%
    copy .\src\core\prv664_define.sv %DEST_FILE%
    copy .\src\core\prv664_config.sv %DEST_FILE%
    copy .\src\core\prv664_bus_define.sv %DEST_FILE%
    copy .\src\core\riscv_define.sv %DEST_FILE%
:: SoC file
    copy .\src\soc\*.v %DEST_FILE%
    copy .\src\soc\*.sv %DEST_FILE%
    copy .\src\soc\*.svh %DEST_FILE%
    copy .\src\soc\axi_xbar\*.sv %DEST_FILE%
    copy .\src\soc\apb_cluster\*.v %DEST_FILE%
    copy .\src\soc\apb_cluster\text_vga\*.v %DEST_FILE%
    copy .\src\soc\apb_cluster\text_vga\rom\font.txt %DEST_FILE%
    copy .\src\soc\apb_cluster\uart16550\*.v %DEST_FILE%
    copy .\src\soc\axil_cluster\*.v %DEST_FILE%
    copy .\src\soc\axil_cluster\*.sv %DEST_FILE%
::Simulation file
    copy .\src\sim\ref\*.sv %DEST_FILE%
    copy .\src\sim\ref\*.v %DEST_FILE%
    copy .\src\sim\*.sv %DEST_FILE%
)
pause