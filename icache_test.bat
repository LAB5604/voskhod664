set /p var=Select mode 1=init project file 2=copy src
if %var%==1 (
    md icache_test_proj\work
    md icache_test_proj\src
    copy .\icache_test.do .\icache_test_proj
)
if %var%==2 (
    @echo on
    del .\icache_test_proj\src\*.*
    copy .\src\misc\*.v .\icache_test_proj\src
    copy .\src\misc\bsc_lib\*.* .\icache_test_proj\src
    copy .\src\core\interface\prv664_bus_interface.sv .\icache_test_proj\src
    copy .\src\core\interface\prv664_commit_interface.sv .\icache_test_proj\src
    copy .\src\core\interface\prv664_debug_interface.sv .\icache_test_proj\src
    copy .\src\core\interface\prv664_decode_interface.sv .\icache_test_proj\src
    copy .\src\core\interface\prv664_execute_interface.sv .\icache_test_proj\src
    copy .\src\core\interface\prv664_interface.sv .\icache_test_proj\src
    copy .\src\core\interface\prv664_test_interface.sv .\icache_test_proj\src
    copy .\src\core\prv664_define.sv .\icache_test_proj\src
    copy .\src\core\prv664_config.sv .\icache_test_proj\src
    copy .\src\core\prv664_bus_define.sv .\icache_test_proj\src
    copy .\src\core\riscv_define.sv .\icache_test_proj\src
    copy .\src\sim\icache_difftest\icache_difftest.sv .\icache_test_proj\src 
    copy .\src\sim\icache_difftest\axi_ram.v .\icache_test_proj\src
    ::your own cache design files
    copy .\src\core\cache\*.sv .\icache_test_proj\src
    copy .\src\core\cache\*.v .\icache_test_proj\src
)
pause