# 核心emulation板需求
## 组成
应当为核心板+底板的组成。
## 核心板需求
1. 核心板与底板之间通过BTB连接器连接，核心板面积不超过10cm*10cm，层数不超过8层。
2. FPGA应当为28nm+工艺或更高，等效100K LUT4资源以上、有分布式存储器且支持异步读取（目前已知Cyclone V系列、Xilinx 7系列均支持）、（可选的）有serdes，速度不做要求。
3. 核心板从底板上取电。
4. 核心板应板载DDR内存，形式为颗粒或者DIMM插槽、有一些指示灯和按键、（可选的）有板载下载器和UART-USB 
## 底板需求
### 多媒体开发板型（325t 676）
1. 面积不超过24.5*24.5（如果条件允许，可以开ITX or Flex MATX or Standard MATX版型的螺丝孔）
2. 板载有以太网PHY和RJ45网口（RTL8211较为合适）、HDMI接口（IO直推）、PS2接口（Terasic同款连接方式）、USB-Root接口（米联客同款PHY）、音频CODEC（ADAU1761）。
3. 板载FPGA下载器和USB-UART（质量好的，如CP2102）
4. PCIE ROOT接口（x4模式）、SATA 2个、GTX时钟使用CDCM61002+拨码开关。
5. 7段数码管（2个，IO直推）、拨码开关（4个）、按键开关（4个）、LED（8个）。
6. 一个2.54mm 20Px2排针座用于用户连接单端GPIO（高质量插座、采用IO、GND、IO、GND的形式排布）、一个40P FPC用于连接差分IO（FPC排线应该尽可能靠近板边，方便使用FPC排线进行多板互联）
7. 所有的铜柱安装位都应该接入系统地，方便多板互联的统一地。
## 上电时序
1. 19V输入总开关（PMOS）开。
2. 产生3.3V待机电压，EC启动，OLED上显示STAND BY
3. 按下“PSON”按键后，EC将12V电源的EN拉高，整板12V供电启动。
4. 12V电源PG后，EC将核心板电源EN拉高，核心板电源PG后在OLED上显示READY。
5. 若再次按下PSON，则先将核心板EN拉低，再将12V供电拉低，下电后回到步骤2。
## EC OLED显示内容
### 待机时
========================

STAND BY                          



========================

### 启动后
========================

READY

Vcore=***V

Icore=***A

Tcore=***℃

========================

按下“CTRL”按键后翻到下一页

========================

READY

Vbus=***V

Ibus=***V

========================