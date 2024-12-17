set /p var=Select mode 1=init project file 2=copy src
if %var%==1 (
    md cache_test_proj\work
    md cache_test_proj\src
    copy .\cache_test.do .\cache_test_proj
)
if %var%==2 (
    @echo on
    del .\cache_test_proj\src\*.*
    copy .\src\misc\*.v .\cache_test_proj\src
    copy .\src\misc\bsc_lib\*.* .\cache_test_proj\src
    copy .\src\core\interface\prv664_bus_interface.sv .\cache_test_proj\src
    copy .\src\core\interface\prv664_commit_interface.sv .\cache_test_proj\src
    copy .\src\core\interface\prv664_debug_interface.sv .\cache_test_proj\src
    copy .\src\core\interface\prv664_decode_interface.sv .\cache_test_proj\src
    copy .\src\core\interface\prv664_execute_interface.sv .\cache_test_proj\src
    copy .\src\core\interface\prv664_interface.sv .\cache_test_proj\src
    copy .\src\core\interface\prv664_test_interface.sv .\cache_test_proj\src
    copy .\src\core\prv664_define.sv .\cache_test_proj\src
    copy .\src\core\prv664_config.sv .\cache_test_proj\src
    copy .\src\core\prv664_bus_define.sv .\cache_test_proj\src
    copy .\src\core\riscv_define.sv .\cache_test_proj\src
    copy .\src\sim\cache_difftest\cache_difftest.sv .\cache_test_proj\src 
    copy .\src\sim\cache_difftest\axi_ram.v .\cache_test_proj\src
    ::your own cache design files
    copy .\src\core\cache\*.sv .\cache_test_proj\src
    copy .\src\core\cache\*.v .\cache_test_proj\src
)
pause