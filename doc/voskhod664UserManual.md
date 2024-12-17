# voskhod664 User Manual
本篇用户使用手册将介绍voskhod664 cpu的集成方法，以及采用voskhod664的demo soc：salyut1的集成方法。

使用时需要的前置知识：
1. systemverilog的interface用法需要熟练掌握。

## voskhod664 CPU
本节将介绍voskhod664的连线方式和集成注意事项。
### top接口
|信号名称|方向|描述|
|--|--|--|
|clk_i|input|时钟信号输入|
|arst_i|input|异步复位信号输入，提供这个信号时候需要做好异步复位同步释放|
|clint_sif|sv interface接口|平台中断控制器信号输入|
|cpu_jtag_rstn|input|jtag|
|cpu_jtag_tms|input|jtag|
|cpu_jtag_tck|input|jtag|
|cpu_jtag_tdi|input|jtag|
|cpu_jtag_tdo|output|jtag|
|cpu_dbus_axi_ar|sv interace接口|cpu数据总线ar通道|
|cpu_dbus_axi_r|sv interace接口|cpu数据总线r通道|
|cpu_dbus_axi_aw|sv interace接口|cpu数据总线aw通道|
|cpu_dbus_axi_w|sv interace接口|cpu数据总线w通道|
|cpu_dbus_axi_b|sv interace接口|cpu数据总线b通道|
|cpu_ibus_axi_ar|sv interace接口|cpu数据总线ar通道|
|cpu_ibus_axi_r|sv interace接口|cpu数据总线r通道|

### 总线
voskhod664对外有两条axi协议的总线，1条指令总线（ibus）和1条数据总线（dbus）。其中指令总线只有ar和r通道，工作在只读模式；数据总线是全功能axi，具备ar，r，aw，w，b五个通道。在集成时，两条总线都需要连接到系统中。

当运行的程序访问mmio区段时（mmio区段定义需要在prv664_config.svh文件里配置），voskhod664只会使用单拍axi访问（可以简单桥接到axi-lite总线），此时可以使用salyut1 soc参考实现中的axi-axilite桥以节约资源。

⚠注意！voskhod664处理器不能在mmio区段中运行程序，这会直接引起指令总线访问错误，任何情况下都不要把程序放置在mmio区段中然后直接运行。请使用loader程序将待运行的程序load到内存中然后运行。
### 时钟
voskhod664只有一条时钟输入接口，cpu逻辑均于此时钟同步运行。
### jtag接口
暂缺
### 充话费送的xbar
voskhod664集成了一个4x4的xbar，代码文件位于/src/cpu/xbar/中。
### 配置文件
在集成voskhod664内核时，请参考/src/board中的config文件修改prv664_config.svh文件。*_define.svh、 *_define.vh文件不可以修改。
## salyut1 SoC
salyut1 soc是基于voskhod664 cpu的soc的一个最小系统集成参考实现，作为一款轻量化的soc，其大部分模块均复用了voskhod664中的内容。salyut1 soc具备运行操作系统的最小系统，同时也提供了voskhod664 cpu的指令测试用最小系统。
### 外设
salyut1 soc集成了非常有限的外设，除了ocram和外置dram控制器直接连接到xbar上的axi总线以外，其他低速外设均连接到32位或64位axi-lite总线上。
|总线|外设|描述|
|--|--|--|
|axi master|voskhod664 cpu|占用两条axi master位置|
|axi master|crtc控制器|crtc控制器，字符显卡，可选配置|
|axi slave|sram控制器|sram控制器|
|axi slave|外部dram控制器||
|axi slave|axi转32bit axi-lite桥|总线桥|
|axi slave|axi转64bit axi-lite桥|总线桥|
|32bit axi-lite slave|axi-lite uart 16550||
|64bit axi-lite slave|中断、定时器、gpio组||

## 在windows环境下
### 运行modelsim仿真salyut1 soc
1. 在仓库根目录下打开命令行窗口，输入命令：`synsrc_copy.bat sim`，脚本文件会自动建立仿真用的build相关文件夹。
2. 在./build文件夹下建立工程文件夹，文件名需要全英文，此文件夹作为之后modelsim仿真时的工程目录。
3. 将根目录下的soc_sim.do和add_waves.do文件复制到刚才建立的工程文件夹中。
4. 将内存初始化所需的txt文本形式文件复制到建立的工程文件夹中。
5. 打开modelsim，切换目录至刚才建立的工程文件夹。
6. 在modelsim cli窗口中输入`do soc_sim.do`
7. 开始仿真