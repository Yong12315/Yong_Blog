**简体中文** | [English](./CORDIC_Based_Frequency_Shift_EN.md)

# 基于CORDIC优化的FPGA数字变频设计

数字变频的本质是将输入信号与本振信号相乘，从而实现频谱搬移。作为数字信号处理中的关键环节，数字变频广泛应用于接收与发射链路中，并直接影响后续滤波、抽取、插值及解调等处理效果。由于 FPGA 具备较强的并行处理能力和良好的实时性，因此非常适合用于数字变频系统的实现。

## 1 数字变频原理

如下图所示，左图为输入信号 $x(t)$的频谱，其中心频率为 $f_{0}$；右图为本振信号 $e^{j2πf_{c}t}$的频谱，其频率为 $f_{c}$。

![混频前频谱](./Images/Spectrum_Before_Mixing.png)

两者在时域相乘后，时域相乘对应频域卷积，所以输入信号频谱会整体搬移 $f_{c}$，因此混频后信号的中心频率变为 $f_{0}+f_{c}$。

![混频后频谱](./Images/Figure_2.png)

数字变频的本质是通过输入信号 $x[n]$与复指数本振信号相乘，实现信号频谱的平移，其表达式为：

$$
y\left[n\right] = x[n]e^{j2π\frac{f_{c}}{f{_s}}n}
$$

其中， $f_{c}$ 表示混频本振频率， $f_{s}$ 表示输入信号的采样率。当 $f_{c}$为正时，输出频谱相对于输入频谱向高频方向平移；当 $f_{c}$为负时，输出频谱相对于输入频谱向低频方向平移。

## 2 FPGA实现数字变频

传统做法一般是先用 DDS IP 核产生本振信号，再用乘法器把输入信号和本振信号相乘完成混频。这种方案比较常见，但缺点是会占用较多 DSP48E1 资源。

为了减少资源消耗，这里采用一种基于 CORDIC 的实现方法。它利用相位旋转来完成频移，不再完全依赖传统乘法器做混频，因此更适合资源受限或多通道的 FPGA 设计场景。

### 2.1 FPGA 实现过程

1. 根据混频频率 $f_c$ 和采样率 $f_s$，计算相邻采样点之间的相位增量：

$$
\Delta\phi = 2\pi \frac{f_c}{f_s}
$$

2. 对相位增量 $\Delta\phi$ 进行逐点累加，得到本振信号在各个采样时刻对应的相位值。

3. 将累加后的相位限制在 $[-\pi,\pi]$ 范围内，便于后续送入 CORDIC 模块进行旋转运算。

4. 将输入 IQ 信号作为 CORDIC 旋转模式的输入信号，以当前相位累加值作为旋转角，对 IQ 信号进行复平面旋转。由于复数乘法在几何上等效为相位旋转，因此 CORDIC 旋转后的输出即为混频后的 IQ 信号。

*累加并限制模块中对相位进行折返处理：当累加结果大于* $π$*时减去* $2π$*，当累加结果小于* $-π$*时加上* $2π$*，从而始终将相位值限制在* $\left[-π,π\right]$*范围内。*

   ![FPGA架构图](./Images/Figure_3.png)

### 2.2 CORDIC IP配置

   ![IP配置](./Images/Figure_4.png)

- Functional Selection：选择 Rotate 模式，用于实现输入向量的旋转运算。
- Architectural Configuration：选择 Parallel 并行架构，可实现每个时钟周期输出一个结果，适合高吞吐率应用场景。
- Pipelining Mode：选择 Maximum，在各级运算之间插入尽可能多的流水寄存器，以提高可实现时钟频率并改善时序性能。
- Phase Format：选择 Radians，即相位输入采用弧度制表示。
- Round Mode：选择 Nearest Even，采用四舍六入五留双的舍入方式，以减小量化误差。
- Iteration：设置为 0，表示由 IP 自动选择迭代次数。
- Precision：设置为 0，表示由 IP 自动选择内部计算精度。
- Coarse Rotation：勾选该选项后，IP 会先对输入向量进行粗旋转预处理，从而支持更大的输入相位范围；若不使能该功能，则输入相位范围将受到限制。
- Compensation Scaling：选择 Embedded Multiplier，利用乘法器对 CORDIC 迭代过程引入的固定增益进行补偿，从而保证输出幅值的准确性；若选择 No Scale Compensation，则输出结果不对该固定增益进行补偿。

## 3 代码与仿真

1. 首先运行 MATLAB 脚本 [IQ_Generator.m](./Code/MATLAB/IQ_Generator.m)，生成用于仿真的 IQ 数据。生成后的数据会保存到 [IQ_Data.mem](./Code/MATLAB/IQ_Data.mem) 文件中，作为后续 FPGA 仿真的输入激励。

   ![IQ Data](./Images/IQ_Data.png)

2. MATLAB 生成的测试信号为采样率 122.88 MHz 的 OFDM 调制复基带信号，其频谱主要分布在 -5 MHz 到 +5 MHz 范围内，可用于验证数字变频模块对复基带信号的频谱搬移效果。

   <p align="center">
     <img src="./Images/OFDM_IQ_Spectrum.png" alt="OFDM_IQ_Spectrum" width="700">
   </p>

3. 在 Vivado 中运行仿真文件 [tb_Frequency_Shift.v](./Code/Vivado/Frequency_Shift/tb_Frequency_Shift.v)，仿真过程中，testbench 读取 IQ_Data.mem 中的 IQ 数据，并将其送入数字变频模块。本次仿真设置频移量为 +10 MHz，即通过 CORDIC 旋转运算，将输入 IQ 信号频谱整体向高频方向搬移。仿真结束后，模块输出的变频后 IQ 数据会保存到 [IQ_Result.txt](./Code/Vivado/Frequency_Shift/IQ_Result.txt)，用于后续 MATLAB 频谱分析。

   ![Modelsim](./Images/Modelsim.png)

4. 使用 MATLAB 脚本[Plot_IQ_Spect.m](./Code/MATLAB/Plot_IQ_Spect.m)读取 IQ_Result.txt，并对变频后的 IQ 数据进行 FFT 分析。从频谱结果可以看出，输入信号频谱由原来的 -5 MHz ~ +5 MHz 整体搬移到约 5 MHz ~ 15 MHz，频移量与设定的 +10 MHz 一致，说明基于 CORDIC 的数字变频模块能够正确完成频谱搬移功能。

   <p align="center">
     <img src="./Images/IQ_Result_Spectrum.png" alt="IQ_Result_Spectrum" width="700">
   </p>
