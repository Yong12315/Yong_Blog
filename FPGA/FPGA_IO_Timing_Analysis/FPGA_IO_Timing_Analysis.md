**简体中文** | [English](./FPGA_IO_Timing_Analysis_EN.md)

# FPGA端口静态时序分析

在 FPGA 设计中，常需与其他芯片通讯。为确保通讯的可靠性，避免产生亚稳态，端口的静态时序分析尤为重要。

## 1 FPGA 输入端口

输入端口的静态时序分析是指验证外部信号在输入至 FPGA 内部第一级寄存器时，其建立时间和保持时间是否满足时序要求。

### 1.1 原理

#### 1.1.1 建立时间

![Input Setup Timing](./Images/Input_Setup_Timing.png)

如图所示，DATA\_IN 为 FPGA 的数据输入端口，CLK\_IN 为相应的时钟输入端口。由于连接 FPGA 与其他芯片的数据线与时钟线长度不同，以及其他芯片输出的时钟与数据时间存在延迟，因此输入到 FPGA 的 DATA\_IN 需要比 CLK\_IN 延迟 *Tdelay* 时间。例如，如果其他芯片的引脚输出数据相对于时钟延迟*Tchip\_delay*，且连接FPGA与其他芯片的走线导致数据线相对于时钟线延迟*Troute\_delay*，则*Tdelay* = *Tchip\_delay* +*Troute\_delay*。

![Setup Timing Analysis](./Images/Setup_Timing_Analysis.png)

如果时钟到达CLK\_IN端口的时间设定为0，则数据到达DATA\_IN端口的时间为*Tdelay*。数据到达FPGA内部的捕获寄存器REG1/D的时间为*Tdelay* + *Tdata内*，而捕获时钟到达捕获寄存器REG1/CK的时间为*Tclk内* + *Tcycle*。要求数据到达REG1的时间比时钟到达REG1的时间至少早*Tsetup*，以确保数据的正确捕获。因此，对于FPGA的建立时间检查，需满足以下公式：

![Setup Timing Formula](./Images/Setup_Timing_Formula.png)

对于像Vivado这样的FPGA设计软件，上述公式中只有*Tdelay*是未知的因此，需要通过时序约束来指定*Tdelay*。为了保证在最差时序条件下也能满足建立时间，当*Tdelay*为其最大值*Tmax\_delay*时，上述公式也应成立。因此，应如下设定输入端口的建立时间约束，以便软件能够分析输入端口的建立时间：

1. create\_clock -period *Tcycle* -name CLK\_IN -waveform {0 *Tcycle* / 2} [get\_ports CLK\_IN]

2. set\_input\_delay -clock CLK\_IN -max *Tmax\_delay* [get\_ports DATA\_IN]

#### 1.1.2 保持时间

![Input Hold Timing](./Images/Input_Hold_Timing.png)

![Hold Timing Analysis](./Images/Hold_Timing_Analysis.png)

如果时钟到达CLK\_IN端口的时间设定为0，则DATA\_IN端口的数据在*Tdelay*时刻发生变化。FPGA内部的捕获寄存器REG1/D的数据在*Tdelay* + *Tdata内*时刻发生变化，而捕获寄存器REG1/CK的时钟将在*Tclk内*时刻捕获REG1/D的数据。为确保数据正确捕获，要求数据在被REG1的时钟捕获时至少保持*Thold*时间稳定不变。因此，对于FPGA的保持时间检查，需满足以下公式：

![Hold Timing Formula](./Images/Hold_Timing_Formula.png)

对于像Vivado这样的FPGA设计软件，上述公式中只有*Tdelay*是未知的。因此，需要通过时序约束来指定*Tdelay*。为了保证在最差时序条件下也能满足保持时间，当*Tdelay*为其最小值*Tmin\_delay*时，上述公式也应成立。因此，应如下设定输入端口的保持时间约束，以便软件能够分析输入端口的保持时间：

1. create\_clock -period *Tcycle* -name CLK\_IN -waveform {0 *Tcycle* / 2} [get\_ports CLK\_IN]

2. set\_input\_delay -clock CLK\_IN -min *Tmin\_delay* [get\_ports DATA\_IN]

### 1.2 示例

以 AM5728 芯片与 FPGA 通过 GPMC 接口通信中的片选信号 gpmc\_cs 为例：

![Example of gpmc_cs](./Images/gpmc_cs_Example.png)

查阅AM5728的芯片手册可以得到芯片片选信号gpmc\_cs与时钟gpmc\_clk的时序关系。

![gpmc_cs Timing](./Images/gpmc_cs_Timing.png)

gpmc\_clk为100MHz。gpmc\_cs信号相对于时钟 gpmc\_clk延后的时间为-1.48ns ~ 3.84ns。在假设 PCB 走线等长、两者之间的板级时延差可以忽略的前提下，可认为gpmc\_cs信号相对于时钟gpmc\_clk延后-1.48ns ~ 3.84ns到达FPGA。

因此，在 Vivado 的 XDC 中可按如下方式对 gpmc\_cs 设置输入延迟约束：

![Vivado Setup Setting](./Images/Vivado_Setup_Setting.png)

## 2 FPGA输出端口

FPGA 输出端口的静态时序分析是指验证信号从 FPGA 内部最后一级寄存器传输到输出端口时，能否在规定时间内稳定输出到 FPGA 端口，从而满足外部器件的建立时间和保持时间的时序要求。

### 2.1 原理

#### 2.1.1 建立时间

![Output Setup Timing](./Images/Output_Setup_Timing.png)

如图所示，DATA\_OUT为FPGA的数据输出端口，CLK\_OUT为相应的时钟输出端口。假设FPGA输出的数据比时钟提前*TFPGA*，PCB上时钟和数据线做了等长处理（*Troute* = 0），那么输入其他芯片的数据要比时钟提前*TFPGA*。为了满足其他芯片的建立时间，输入的数据通常需要比时钟提前至少（*Tdata内* ＋ *Tsetup* – *Tclk\_内*）的时间稳定，这个时间芯片手册一般会标出。因此，当*TFPGA* ≥ （*Tdata内* ＋ *Tsetup* – *Tclk\_内*）时，能够满足其他芯片的建立时间。

对于像Vivado这样的FPGA设计软件，需要明确指出*TFPGA*，软件才会分析输出端口的数据能否比时钟提前*TFPGA*的时间稳定下来。需要通过时序约束“set\_output\_delay”来指定*Tdelay*。因此，应如下设定输出端口的建立时间约束，以便软件能够分析输出端口的时序：

1、set\_output\_delay -clock CLKM -max *TFPGA* [get\_ports DATA\_OUT]

2.1.2 保持时间

![Output Hold Timing](./Images/Output_Hold_Timing.png)

如图所示，DATA\_OUT为FPGA的数据输出端口，CLK\_OUT为相应的时钟输出端口。假设FPGA输出的数据比时钟提前*TFPGA*，PCB上时钟和数据线做了等长处理（*Troute* = 0），那么输入其他芯片的数据要比时钟延后-*TFPGA*。为了满足其他芯片的保持时间，输入的数据通常需要比时钟延后至少（*Tclk* ＋ *Thold* – *Tdata内*）的时间变化，这个时间芯片手册一般会标出。因此，当*TFPGA* ≤ -（*Tclk* ＋ *Thold* – *Tdata内*）时，能够满足其他芯片的建立时间。

对于像Vivado这样的FPGA设计软件，需要明确指出*TFPGA*，软件才会分析输出端口的数据能否比时钟延后*TFPGA*的时间变化。因此，应如下设定输出端口的保持时间约束，以便软件能够分析输出端口的时序：

1.set\_output\_delay -clock CLKM -min *TFPGA* [get\_ports DATA\_OUT]

### 2.1 示例

以 AM5728 芯片与 FPGA 通过 GPMC 接口通信中的数据信号 gpmc\_ad为例：

![Example of gpmc_ad](./Images/gpmc_ad_Example.png)

查阅AM5728的芯片手册可以得到芯片数据信号 gpmc\_ad与时钟gpmc\_clk的时序关系。

![gpmc_ad Timing](./Images/gpmc_ad_Timing.png)

gpmc\_clk为100MHz。gpmc\_ad信号相对于时钟 gpmc\_clk上升沿要提前2.69ns稳定，并且gpmc\_ad信号在时钟 gpmc\_clk上升沿之后1.53ns才能变化。

因此，在 Vivado 的 XDC 中可按如下方式对 gpmc\_ad 设置输出延迟约束：

![Vivado Hold Setting](./Images/Vivado_Hold_Setting.png)

## 3 REFERENCE

1. https://blog.csdn.net/aaaaaaaa585/article/details/118862049
2. https://blog.csdn.net/aaaaaaaa585/article/details/118859268
3. Rakesh Chadha, J. Bhasker (auth.) - Static Timing Analysis for Nanometer Designs\_ A Practical Approach (2009, Springer) [10.1007\_978-0-387-93820-2]
