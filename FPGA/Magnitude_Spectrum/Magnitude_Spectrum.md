**简体中文** | [English](./Magnitude_Spectrum_EN.md)

# 基于 FPGA 的幅度谱计算与仿真验证

在信号处理中，频谱分析常用于观察信号的频率分布、带宽及频点强弱。对于 FPGA 实时信号处理系统，通常先通过 FFT 将时域采样数据转换为复数频谱数据，再对其实部和虚部进行模值计算，得到幅度谱。幅度谱可为后续频谱显示、信号检测和门限判断提供依据，本文主要介绍其在 FPGA 中的实现方法。

## 1. 幅度谱计算原理

FFT 将时域采样数据转换到频域后，每个频点的输出结果通常为复数形式：

$$
X[k] = I[k] + jQ[k]
$$

其中，$`I[k]`$ 表示第 $`k`$ 个频点的实部，$`Q[k]`$ 表示第 $`k`$ 个频点的虚部。为了描述该频点上的信号强弱，需要对复数频谱进行模值计算，得到对应的幅度值：

$$
|X[k]| = \sqrt{I[k]^2 + Q[k]^2}
$$

对所有频点分别计算模值后，即可得到信号的幅度谱。幅度谱反映了信号在不同频率分量上的强弱，可用于后续的频谱显示、信号检测和门限判断等处理。

在 FPGA 中，如果直接按照上述公式实现，需要完成平方、加法和开方运算，会消耗较多逻辑资源并引入较大的计算延迟。为了降低硬件实现复杂度，本文采用 $`\alpha Max + \beta Min`$ 近似求模算法计算幅度值。该算法首先对实部和虚部取绝对值，并得到二者中的较大值和较小值：

$$
Max = \max(|I[k]|, |Q[k]|)
$$

$$
Min = \min(|I[k]|, |Q[k]|)
$$

然后通过加权求和近似计算复数模值：

$$
|X[k]| \approx \alpha \cdot Max + \beta \cdot Min
$$

本文选取：

$$
\alpha = \frac{15}{16}, \quad \beta = \frac{15}{32}
$$

因此幅度值可近似表示为：

$$
|X[k]| \approx \frac{15}{16}Max + \frac{15}{32}Min
$$

由于：

$$
\frac{15}{16}Max = Max - \frac{Max}{16}
$$

$$
\frac{15}{32}Min = \frac{Min}{2} - \frac{Min}{32}
$$

在二进制硬件实现中，除以 $`2^n`$ 可以通过右移 $`n`$ 位实现，因此上式可进一步写为：

$$
|X[k]| \approx \left(Max - (Max \gg 4)\right) + \left((Min \gg 1) - (Min \gg 5)\right)
$$

由此可见，该形式只需要通过取绝对值、比较、移位、加法和减法即可实现，避免了平方和开方运算，更适合 FPGA 中的流水线处理。虽然该方法得到的是近似幅度值，但其计算结果能够较好反映各频点幅度的相对大小，满足频谱显示、信号检测和门限判断等应用需求。

## 2. FPGA 实现幅度谱计算

### 2.1 FFT IP 配置

Xilinx FPGA 实现 FFT 计算时可以直接调用 IP 核 Fast Fourier Transform。

![FFT Configuration](./Images/FFT_Configuration.png)

- **Number of Channels**：FFT 通道数。一路复数 IQ 数据流对应 1 个通道。
- **Transform Length**：FFT 点数。本文配置为 `8192` 点，即每帧输入 8192 个复数采样点，并输出 8192 个频域点。
- **Target Clock Frequency**：目标工作时钟频率。本文配置为 `122 MHz`，用于指导 Vivado 进行 FFT IP 架构选择、资源估算和延迟估算。
- **Target Data Throughput**：目标输入数据吞吐率。本文配置为 `122 MSPS`，表示 FFT IP 需要支持约 122 MSPS 的复数输入采样流。
- **Architecture Choice**：FFT 内部实现架构。本文选择 `Automatically Select`，由 Vivado 根据目标时钟频率、数据吞吐率和 FFT 点数自动选择合适的实现架构。
- **Run Time Configurable Transform Length**：运行时可配置 FFT 点数。本文未勾选该选项，表示 FFT 点数固定为 `8192`。

![FFT Implementation](./Images/FFT_Implementation.png)

- **Data Format**：FFT 数据格式。本文选择 `Fixed Point`，表示 FFT IP 内部采用定点数进行计算，适合 FPGA 硬件实现。
- **Scaling Options**：FFT 缩放方式。本文选择 `Unscaled`，表示 FFT 各级运算过程中不进行缩放处理，输出结果会保留 FFT 运算带来的位宽增长。该方式可以避免因缩放造成的数据精度损失，但需要在后续模块中考虑输出位宽增长问题。
- **Rounding Modes**：舍入方式。本文选择 `Convergent Rounding`，即收敛舍入方式，可在定点运算截位时降低舍入误差带来的直流偏差。
- **Input Data Width**：输入数据位宽。本文配置为 `16 bit`，表示输入 FFT 的实部和虚部数据均为 16 bit。
- **Phase Factor Width**：旋转因子位宽。本文配置为 `16 bit`，表示 FFT 内部旋转因子采用 16 bit 定点精度。通常情况下，该参数与输入数据位宽保持一致即可。
- **Output Ordering**：输出顺序。本文选择 `Natural Order`，表示 FFT 输出频点按照自然顺序排列，便于后续根据频点索引进行频谱分析。
- **Cyclic Prefix Insertion**：循环前缀插入功能。本文未勾选该选项。该功能主要用于 OFDM 等应用场景，普通频谱分析中通常不需要使用。
- **XK_INDEX**：频点索引输出。本文勾选该选项，FFT IP 会在输出数据的 `tuser` 字段中给出当前频点索引，便于后续模块定位每个频点的位置。
- **OVFLO**：溢出标志输出。本文未启用该选项，因此不输出 FFT 运算过程中的溢出标志。
- **Throttle Scheme**：数据流控方式。本文选择 `Non Real Time`，表示 FFT IP 支持 AXI-Stream 流控机制，适合与后级模块进行握手传输。

**Detailed Implementation** 标签页用于设置 FFT IP 的具体资源实现方式，例如存储资源和乘法器资源等。一般情况下保持默认配置即可，由 Vivado 根据当前 FFT 点数、吞吐率和目标时钟频率自动选择合适的实现方案。

### 2.2 仿真数据生成

1. 首先运行 MATLAB 脚本 [IQ_Generator.m](./Code/MATLAB/IQ_Generator.m)，生成用于仿真的 IQ 数据。生成后的数据会保存到 [IQ_Data.mem](./Code/MATLAB/IQ_Data.mem) 文件中，作为后续 FPGA 仿真的输入激励。

   ![IQ Data](./Images/IQ_Data.png)

2. MATLAB 生成的测试信号为采样率 122.88 MHz 的 OFDM 调制复基带信号，其频谱分布在 -20 MHz 到 +20 MHz 范围内，可用于验证 FPGA 的幅度谱计算的正确性。

   ![OFDM IQ Spectrum](./Images/OFDM_IQ_Spectrum.png)

### 2.3 Vivado 仿真验证

1. 在 Vivado 中运行仿真文件 [tb_Full_Band_PowerSpec.v](./Code/Vivado/tb_Full_Band_PowerSpec.v)，仿真过程中，testbench 读取 IQ_Data.mem 中的 IQ 数据，并将其送入 FFT IP 核，FFT IP 核的计算结果再输入到幅度谱计算模块[Full_Band_PowerSpec.v](./Code/Vivado/Full_Band_PowerSpec.v)，最终能够计算出幅度谱。

   ![Sim Result](./Images/Sim_Result.png)

2. 从仿真结果可以看到，FPGA 计算得到的幅度谱在频率分布上与 MATLAB 计算结果基本一致，主信号带宽均集中在 -20 MHz 到 +20 MHz 范围内。由于 FPGA 端采用 αMax + βMin 近似求模算法，因此幅度值与 MATLAB 中精确平方开方计算结果会存在一定误差，但频谱包络和频点强弱关系保持一致，能够满足后续频谱显示和门限检测需求。
