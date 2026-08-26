**简体中文** | [English](./Zynq7000_Resource_Overview_EN.md)

# Zynq-7000 器件架构与资源介绍

Zynq-7000 是 AMD（原 Xilinx）推出的 All Programmable SoC。它把 ARM Cortex-A9 处理器系统与 Xilinx 7 系列可编程逻辑集成在同一颗芯片中，既能运行 Linux、裸机程序和传统嵌入式软件，也能利用 FPGA 逻辑完成高速接口、实时控制与数据流加速。

本文从工程使用角度介绍 Zynq-7000 的 PS、PL、PS–PL 互连以及器件选型方法。文中的资源数量用于帮助理解系列差异；真正选型时仍应以具体器件、封装、速度等级对应的 AMD 数据手册和封装手册为准。

## 1. Zynq-7000 的整体架构

### 1.1 PS、PL 与 AXI

Zynq-7000 主要由两部分组成：

- **PS（Processing System，处理器系统）**：包含 ARM Cortex-A9、缓存、片上存储器、DDR 控制器、DMA、中断控制器以及常用外设；
- **PL（Programmable Logic，可编程逻辑）**：采用 7 系列 FPGA 架构，包含 LUT、触发器、Block RAM、DSP48E1、时钟、I/O 以及部分型号具备的高速收发器和 PCIe 硬核。

PS 与 PL 的主要数据通路采用 AXI 接口。除此之外，两者之间还有中断、时钟、复位、DMA 请求/应答、EMIO、器件配置和 XADC 等连接，因此不能把 PS–PL 关系简单理解为“只有一条 AXI 总线”。

<p align="center"><a href="./Images/Zynq_PS_PL_Overview.png"><img src="./Images/Zynq_PS_PL_Overview.png" alt="Zynq-7000 中 PS、PL 与 AXI 接口的关系" width="520"></a></p>

<p align="center"><em>图 1：Zynq-7000 中 PS、PL 与 AXI 接口的关系</em></p>

Zynq-7000S 器件采用单核 Cortex-A9，其他 Zynq-7000 器件采用双核 Cortex-A9。PL 并不是只能充当 PS 的普通外设：它既可以实现寄存器型控制逻辑，也可以作为高吞吐数据面，直接访问 PS DDR，或通过 ACP 参与缓存一致性访问。

### 1.2 SoC 与板级系统

传统板级系统往往使用多颗芯片分别实现处理、存储、接口和专用逻辑；SoC 则把其中多个功能模块集成到单颗器件内部。集成可以缩短数据传输路径并减少板级互连，但系统性能、功耗和成本最终仍取决于具体架构、软件以及外围器件设计。

<p align="center"><a href="./Images/SoC_vs_Board_System.png"><img src="./Images/SoC_vs_Board_System.png" alt="片上系统与板上系统的结构对比" width="900"></a></p>

<p align="center"><em>图 2：片上系统（左）与板级系统（右）的结构对比</em></p>

Zynq-7000 的核心价值在于把“软件控制面”和“硬件数据面”放进同一颗器件：PS 负责配置、协议、调度和复杂软件，PL 负责确定性时序、并行计算及高速数据搬运。

## 2. Processing System 资源

下图给出了 Zynq-7000 PS 的主要组成。图中灰色的第二个 Cortex-A9 内核仅适用于双核器件。

<p align="center"><a href="./Images/Zynq_PS_Block_Diagram.png"><img src="./Images/Zynq_PS_Block_Diagram.png" alt="Zynq-7000 Processing System 的内部结构和主要接口" width="900"></a></p>

<p align="center"><em>图 3：Zynq-7000 Processing System 架构</em></p>

### 2.1 APU、缓存与片上存储

| 资源 | 作用与要点 |
| --- | --- |
| Cortex-A9 | Zynq-7000S 为单核，其他型号为双核；支持 ARMv7-A，可运行 Linux 或裸机软件 |
| MMU | 提供虚拟内存、地址转换和内存属性管理，是运行完整 Linux 系统的重要基础 |
| NEON/FPU | 支持 SIMD 与单/双精度浮点运算，可加速部分信号处理和多媒体算法 |
| L1 Cache | 每个 CPU 内核具有 32 KB 指令缓存和 32 KB 数据缓存 |
| L2 Cache | 全部处理器内核共享 512 KB L2 Cache |
| OCM | 256 KB 片上 SRAM，延迟低，可用于启动代码、实时数据或关键缓冲区 |
| SCU | 维护处理器核之间的一致性，并连接 ACP 等一致性访问路径 |

OCM 和 PL 端 Block RAM 都属于片上存储，但用途不同：OCM 位于 PS 地址空间并直接服务处理器系统；Block RAM 位于 PL 中，适合构造并行缓存、FIFO、查找表和自定义存储结构。

### 2.2 外部存储、DMA 与外设

PS DDR 控制器支持 DDR3、DDR3L、DDR2 和 LPDDR2，数据宽度可配置为 16 bit 或 32 bit。具体存储器类型、速率和 ECC 使用限制应结合器件数据手册与板级设计确认。

PS 提供用于启动及非易失存储的 Quad-SPI、NAND 接口，SMC 则支持 NOR/SRAM；其中 SRAM 本身不是非易失存储器。PS 还包含一个 8 通道 DMA 控制器，其中部分通道提供与 PL 相连的请求/应答接口，可在外设、存储器和 PL 之间搬运数据，减少 CPU 参与。

常用 PS 外设包括：

- 2 路 USB 2.0 OTG；
- 2 路千兆以太网；
- 2 路 SD/SDIO；
- 2 路 UART、2 路 CAN、2 路 I²C 和 2 路 SPI；
- GPIO、三重定时器计数器、看门狗等。

PS 外设信号可通过 MIO 或 EMIO 路由：

- **MIO**：PS 外设直接复用到专用 PS 引脚；大多数器件最多提供 54 个 MIO，部分小封装只有 32 个；
- **EMIO**：把支持 EMIO 路由的外设信号送入 PL，再由 PL 逻辑处理或通过 PL I/O 引出。

并非所有 PS 外设都支持 EMIO。例如 USB、Quad-SPI 和 SMC 不能简单地改走 EMIO，具体路由能力应查阅 UG585 的 IOP Interface Routing 表。

### 2.3 中断、定时、调试与安全

- **GIC**：管理来自 CPU、PS 外设和 PL 的中断；PL 可向 PS 提供 16 路共享外设中断输入；
- **TTC**：PS 含两个 Triple Timer Counter 模块，每个模块具有三个独立定时器/计数器；
- **Watchdog**：包含 CPU 私有看门狗和 System Watchdog Timer（SWDT）；SWDT 中的 `S` 表示 System，而不是 Software；
- **CoreSight/DAP**：用于 ARM 调试、追踪和系统诊断；
- **安全启动资源**：包括 AES-CBC-256 解密、HMAC-SHA-256 认证以及 RSA-2048 公钥认证支持。

这些安全模块主要服务于启动镜像和 PL 配置保护，不应笼统地当作普通应用程序可随意调用的通用密码加速器。

### 2.4 PS–PL 接口如何选择

| 接口 | 方向（以 PS 为参照） | 位宽 | 典型用途 |
| --- | --- | ---: | --- |
| `M_AXI_GP0/1` | PS 主机访问 PL | 32 bit | AXI-Lite 寄存器、低带宽控制与状态访问 |
| `S_AXI_GP0/1` | PL 主机访问 PS | 32 bit | PL 访问 PS 地址空间或低带宽存储映射通路 |
| `S_AXI_HP0~3` | PL 主机访问 PS | 32/64 bit | PL 通过 PS 内存互连访问 DDR，适合视频、采集和大数据流 |
| `S_AXI_ACP` | PL 主机一致性访问 PS | 64 bit | 加速器通过 SCU 访问可缓存内存，减少显式缓存维护 |
| 中断/时钟/复位 | 双向或固定方向 | — | 事件通知、时钟提供、复位控制和系统协同 |

接口选择不应只看理论位宽。持续带宽还受到 AXI 突发长度、Outstanding 事务、数据宽度转换、DDR 效率、缓存策略和软件驱动方式影响。

## 3. Programmable Logic 资源

PL 采用 Xilinx 7 系列 FPGA 架构。下图用于说明典型资源分布，图中的 PCIe 硬核和 GTP/GTX 高速收发器只存在于部分型号与封装中，并不是每颗 Zynq-7000 都具备。

<p align="center"><a href="./Images/Zynq_PL_Resource_Layout.png"><img src="./Images/Zynq_PL_Resource_Layout.png" alt="Zynq-7000 PL 中的 CLB、DSP、Block RAM、I/O、高速收发器和 PCIe 资源" width="720"></a></p>

<p align="center"><em>图 4：Zynq-7000 PL 端的典型资源分布</em></p>

### 3.1 CLB：通用逻辑资源

CLB（Configurable Logic Block）由 LUT、触发器、进位链及相关互连组成，可实现组合逻辑、状态机、计数器、流水线和控制逻辑。部分 LUT 还可以配置成分布式 RAM 或移位寄存器。

工程上不能只看“Logic Cells”这一折算指标。真正影响设计映射和时序的通常是 LUT、FF、CARRY、分布式 RAM 以及它们在芯片上的布局与布线拥塞。

### 3.2 DSP48E1：乘加与高吞吐计算

DSP48E1 Slice 包含 25 × 18 位乘法器、48 位算术逻辑和累加通路，适合实现乘加、滤波、FFT、数字下变频、相关和矩阵运算等数据通路。

与使用 LUT 拼接乘法器相比，DSP48E1 通常能获得更高性能和更好的功耗效率。但高利用率并不等于高有效吞吐率，设计仍需考虑流水线级数、位宽增长、舍入饱和以及 DSP 列的物理分布。

### 3.3 Block RAM：片上块存储

Block RAM 以 36 Kb 为基本资源，也可拆分成两个 18 Kb 块，支持双口访问和多种宽深比。常见用途包括：

- AXI-Stream FIFO 和跨模块缓存；
- FIR 系数、查找表和波形表；
- 行缓存、帧缓存片段和数据重排；
- MicroBlaze 指令/数据存储器；
- Ping-Pong Buffer 和多端口存储结构。

选择器件时，应同时检查 BRAM 总量、端口模式、目标时钟频率和物理分布。单纯“容量够用”并不保证布局布线一定容易收敛。

### 3.4 时钟管理与分发

7 系列时钟资源主要包括：

- **CMT（Clock Management Tile）**：每个 CMT 包含一个 MMCM 和一个 PLL，可用于倍频、分频、相位调整和抖动滤除；
- **时钟缓冲与网络**：BUFG、BUFH、BUFR、BUFIO 等负责全局、区域或 I/O 时钟分发；
- **PS–PL 时钟**：PS 可向 PL 输出多路可配置时钟，PL 也可以使用外部时钟管脚或收发器参考时钟。

时钟资源既受数量限制，也受区域和走线限制。选型时应明确异步时钟域数量、GT 参考时钟、I/O 时钟以及跨区域时钟需求。

### 3.5 SelectIO 与高速资源

| 资源 | 说明 |
| --- | --- |
| HR I/O | 支持较宽电压范围，适合通用单端/差分接口；具体标准依 Bank 电压和器件手册而定 |
| HP I/O | 面向较高性能和较低电压接口；只在部分器件/封装中提供 |
| GTP/GTX | GTP 最高约 6.25 Gb/s，GTX 最高可达 12.5 Gb/s；数量、速率和参考时钟管脚均与器件及封装有关 |
| PCIe Block | 部分型号包含 Gen2 PCIe 硬核，并结合器件所带的 GTP 或 GTX 使用 |
| XADC | 系列内置双 12-bit、最高 1 MSPS 的 XADC；实际可用外部模拟输入数量受封装限制 |

PCIe 硬核的原生用户接口由对应 PCIe IP 定义。AXI-MM、DMA 和寄存器映射通常还需要桥接 IP、DMA IP 或用户逻辑，不能认为 PCIe 硬核天然同时提供全部上层功能。

## 4. Zynq-7000 器件选型

### 4.1 先看系列资源总表

Zynq-7000S 包含 Z-7007S、Z-7012S 和 Z-7014S，采用单核 Cortex-A9；Z-7010 至 Z-7100 采用双核 Cortex-A9。不同型号在 LUT、FF、BRAM、DSP、PCIe、高速收发器和 I/O 数量方面差异很大。

<p align="center"><a href="./Images/Zynq_Family_Resource_Comparison.png"><img src="./Images/Zynq_Family_Resource_Comparison.png" alt="Zynq-7000 和 Zynq-7000S 的 PS 与 PL 资源对比，Z-7100 已标出" width="900"></a></p>

<p align="center"><em>图 5：Zynq-7000/7000S 系列 PS 与 PL 资源对比，Z-7100 已标出</em></p>

资源表适合做第一轮筛选，但还不能直接决定器件。相同器件使用不同封装时，可用 I/O、GT 通道、参考时钟、MIO 和模拟输入数量可能不同；同时还要检查速度等级和温度等级。

### 4.2 BRAM 容量

<p align="center"><a href="./Images/Zynq_Block_RAM_Comparison.png"><img src="./Images/Zynq_Block_RAM_Comparison.png" alt="各 Zynq-7000 型号的 Block RAM 容量对比" width="820"></a></p>

<p align="center"><em>图 6：各 Zynq-7000 型号的 Block RAM 容量对比</em></p>

若设计包含雷达、无线电、图像或大规模 DSP 算法，需要大量 RAM 作为计算缓存，或者使用 MicroBlaze、宽数据 FIFO 与多级 Ping-Pong Buffer，应单独建立 BRAM 预算。

需要注意：图 6 把 Z-7045 标为 19.1 Mb，而 DS190 的系列总表给出 19.2 Mb（545 个 36 Kb Block RAM）。正式选型应以当前版本 DS190 及器件数据手册为准。

### 4.3 高速收发器

<p align="center"><a href="./Images/Zynq_Transceiver_Comparison.png"><img src="./Images/Zynq_Transceiver_Comparison.png" alt="各 Zynq-7000 型号的 GTP 或 GTX 通道数量与理论聚合线速" width="900"></a></p>

<p align="center"><em>图 7：高速收发器数量与理论聚合线速，实际可用资源取决于封装</em></p>

高速接口选型不能只计算“通道数 × 标称速率”。还需要考虑编码开销、FEC、协议 IP、参考时钟、收发器位置和实际封装引脚。例如 100GbE 曾使用 CAUI-10 的 10 × 10.3125 Gb/s，也可以使用 CAUI-4 的 4 × 25.78125 Gb/s；Zynq-7000 的 12.5 Gb/s GTX 并不能直接满足 CAUI-4 的单通道线速。

图中的聚合带宽用于展示通道数量与最高线速的乘积，不等同于应用可获得的净吞吐率，也不代表所有封装都提供图示数量的 GT 通道。

### 4.4 I/O 数量与封装

<p align="center"><a href="./Images/Zynq_IO_Count_Comparison.png"><img src="./Images/Zynq_IO_Count_Comparison.png" alt="各 Zynq-7000 型号的 PS、HR 与 HP I/O 数量对比" width="900"></a></p>

<p align="center"><em>图 8：PS、HR 与 HP I/O 数量示意；具体数量必须按器件与封装组合确认</em></p>

设计启动前至少应明确：

- 板卡所需的单端、差分和专用时钟引脚数量；
- 每个 I/O Bank 的电压、I/O 标准和驱动能力；
- PS MIO、DDR、GT、GT 参考时钟和 XADC 管脚；
- 封装可用引脚与 PCB 布线能力；
- 各电源轨、电源时序和散热条件。

图 8 是系列级别的概览，并不代表每种封装的实际最大值。例如部分 Z-7100 封装可提供的 HR I/O 数量与图中数值不同，必须使用 UG865 或 Vivado 的器件/封装视图核对。

### 4.5 订货型号如何阅读

<p align="center"><a href="./Images/Zynq_Device_Ordering_Code.png"><img src="./Images/Zynq_Device_Ordering_Code.png" alt="Zynq-7000 器件订货型号各字段的含义" width="900"></a></p>

<p align="center"><em>图 9：Zynq-7000 器件订货型号组成</em></p>

以 `XC7Z100-2FFG900I` 为例：

| 字段 | 含义 |
| --- | --- |
| `XC` | Xilinx Commercial 产品前缀 |
| `7Z100` | Xilinx 7 系列 Zynq，器件索引为 100 |
| `-2` | 速度等级 |
| `FF` | 带盖 Flip-Chip、1.0 mm 球距封装 |
| `G` | `FFG` 封装的无铅标志，官方定义为 RoHS 6/6 with Exemption 15 |
| `900` | 封装球数 |
| `I` | 工业温度等级，结温范围 −40°C～+100°C |

器件名称相近并不意味着可以直接替换。任何器件迁移都必须重新检查封装管脚、电源、Bank、MIO/DDR、GT、启动模式、速度等级和温度等级。

## 5. 工程选型方法

### 5.1 建立资源基线

项目初期很难一次准确估算全部 FPGA 资源。比较可靠的做法是：

1. 选择与目标项目最接近的历史工程或已完成模块；
2. 使用目标 Vivado 版本和目标器件重新综合、实现；
3. 记录 LUT、FF、BRAM、DSP、BUFG/MMCM、I/O、GT、功耗和时序裕量；
4. 对新增功能分别建立资源模型，再叠加到基线工程；
5. 尽早做一次完整实现，而不是只依赖综合后的资源估算。

资源评估要按类型分别进行。即使 LUT 仍有大量余量，BRAM、DSP、时钟、I/O、GT 或局部布线拥塞也可能已经成为限制因素。

### 5.2 资源余量不是固定百分比

原文建议预留约 25% 资源，这可以作为普通项目的初始工程经验值，但不是官方规则，也不能保证时序必然收敛。

> 对算法变化较大、时钟较高、跨 SLR/区域布线复杂或后续功能不确定的设计，应保留更多余量；对结构稳定且已经完成物理实现验证的量产设计，可以根据实现结果重新评估。

除了资源利用率，还应关注：

- Worst Negative Slack、Total Negative Slack 和跨时钟域约束；
- 高扇出、长连线与局部拥塞；
- BRAM、DSP 和 GT 的物理位置是否匹配数据通路；
- 时钟区域、Bank 和封装引脚是否足够；
- 实测功耗、结温和电源裕量。

### 5.3 量产降档的前提

若最终资源富余，可以评估同封装、Pin-to-Pin 的更小规格器件来降低成本，但必须满足以下条件：

- 封装和迁移规则明确支持；
- I/O Bank、电压、MIO、DDR 与启动管脚兼容；
- GT 通道、参考时钟、PCIe/XADC 等硬资源仍满足需求；
- 电源轨、速度等级和温度等级符合产品要求；
- 在新器件上重新完成综合、实现、时序验证和板级测试。

因此，更稳妥的策略通常是“开发阶段选择有余量的器件，设计冻结后再评估降档”，而不是在项目早期用极限资源利用率换取器件成本。

## 6. 总结

Zynq-7000 的优势不是简单地把 ARM 和 FPGA 放在同一封装中，而是提供了一套紧密耦合的处理器系统、可编程逻辑和高速互连：PS 适合软件、协议和系统管理，PL 适合确定性时序、并行计算和高速数据流。

器件选型时，应先判断软件、算法和接口分别放在 PS 还是 PL，再按 LUT/FF、BRAM、DSP、时钟、I/O、GT、DDR 和功耗逐项建立预算。最后还要把具体封装、速度等级、温度等级和板级约束纳入评估，不能只根据器件名称或 Logic Cell 数量作决定。

## 7. 参考资料

- [DS190：Zynq-7000 SoC Data Sheet: Overview](https://docs.amd.com/v/u/en-US/ds190-Zynq-7000-Overview)
- [UG585：Zynq-7000 SoC Technical Reference Manual](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM)
- [UG865：Zynq-7000 Packaging and Pinout](https://docs.amd.com/v/u/en-US/ug865-Zynq-7000-Pkg-Pinout)
- [UG474：7 Series FPGAs Configurable Logic Block](https://docs.amd.com/r/en-US/ug474_7Series_CLB)
- [UG473：7 Series FPGAs Memory Resources](https://docs.amd.com/v/u/en-US/ug473_7Series_Memory_Resources)
- [UG479：7 Series DSP48E1 Slice](https://docs.amd.com/v/u/en-US/ug479_7Series_DSP48E1)
- [UG472：7 Series FPGAs Clocking Resources](https://docs.amd.com/v/u/en-US/ug472_7Series_Clocking)
- [UG480：7 Series FPGAs and Zynq-7000 SoC XADC](https://docs.amd.com/r/en-US/ug480_7Series_XADC)
