**简体中文** | [English](./Xilinx_Polyphase_Decimation_Filter_EN.md)

# 基于 FIR Compiler IP 的多相抽取滤波器设计

在 FPGA 信号处理中，降采样是一个很常见的需求。抽取滤波器可以在降低采样率的同时完成抗混叠低通滤波。Xilinx FIR Compiler IP 支持多相抽取结构，能够将滤波与抽取过程合并实现，适合用于高效的 FPGA 降采样设计。

## 1 多相抽取滤波器原理

传统抽取滤波器通常采用“FIR 低通滤波 + M 倍抽取”的级联结构。输入信号先经过 FIR 滤波，然后抽取模块每 M 个输出采样点保留 1 个。

这种方式原理简单，但 FIR 会先计算完整速率下的所有输出，而抽取后只保留其中的 1/M，其余结果都会被丢弃，产生无效乘加运算。

如下图所示，8 抽头 FIR 后接 4 倍抽取时，FIR 先得到连续输出 y0、y1、y2、……，而抽取后只保留 y0、y4、y8、……，中间输出最终都会被丢弃。

<p align="center">
  <img src="./Images/Trad_Decimation_FIR.png" alt="Trad_Decimation_FIR" width="600">
</p>

多相抽取滤波器是在传统结构基础上的一种等效优化实现。它利用“抽取后只保留部分输出采样点”这一特点，将原 FIR 滤波器的系数按照抽取倍数 M 拆分为 M 个相位分支，并将滤波与抽取过程合并实现。这样，滤波器不再先计算所有输出再丢弃其中大部分结果，而是直接计算最终会被保留下来的输出采样点，从而减少无效运算。

<p align="center">
  <img src="./Images/Polyphase_Decimation_FIR.png" alt="Polyphase_Decimation_FIR" width="600">
</p>

结合上面的多相抽取滤波器结构可以看到，原来的 8 个 FIR 系数被按照 4 倍抽取关系拆分成了 4 个相位分支。每个相位分支中只包含部分滤波器系数，例如第 1 相分支包含 C0、C4，第 2 相分支包含 C1、C5，第 3 相分支包含 C2、C6，第 4 相分支包含 C3、C7。这样，原本一个 8 抽头 FIR 滤波器就被等效拆分成了 4 个 2 抽头子滤波器。

输入数据按照抽取相位依次进入不同分支进行滤波，各相位分支完成乘加运算后，在输出端累加得到最终抽取结果。以 8 抽头 FIR、4 倍抽取为例，原滤波器被拆分为 4 个 2 抽头子滤波器，因此每拍只需要 2 个乘法器完成当前相位计算，而不需要像传统 8 抽头全并行 FIR 那样每拍使用 8 个乘法器计算完整速率输出。由于输出端只产生 y0、y4、y8、…… 这些抽取后保留的采样点，多相结构避免了先计算 y1、y2、y3 等中间结果再丢弃的无效运算。

从实现角度看，多相抽取滤波器并不改变原 FIR 的频率响应，只是改变了计算组织方式。对于 8 抽头、4 倍抽取的例子，它可以将每拍并行工作的乘法器数量由 8 个降低为 2 个，从而节省 DSP、加法器和寄存器资源，并降低后级模块的数据吞吐压力。这里的“8 个降低为 2 个”指的是每拍参与计算的并行乘法器数量，完整抽取输出仍然等效包含原 8 个 FIR 系数的作用。

## 2 FPGA实现抽取滤波

在 FPGA 中实现抽取滤波时，可以直接使用 Xilinx FIR Compiler IP。该 IP 已经集成了 FIR 滤波、多相抽取、AXI-Stream 数据接口等功能，只需要配置滤波器系数、抽取倍数、输入输出位宽等参数，就可以快速完成抽取滤波器的搭建。

![FIR Compiler 0](./Images/FIR_Compiler_0.png)

- Select Source：选择 COE File，表示使用外部 COE 文件作为滤波器系数来源。
- Coefficient File：用于指定 COE 文件路径，FIR Compiler 会根据该文件中的系数生成对应的 FIR 滤波器。
- Number of Coefficient Sets：设置为 1，表示当前只使用一组固定滤波器系数，不进行多组系数切换。
- Filter Type：选择 Decimation，表示该 IP 配置为抽取滤波器。
- Rate Change Type：选择 Integer，表示采样率变化为整数倍关系。
- Decimation Rate Value：设置为 8，表示每输入 8 个采样点，输出 1 个滤波后的采样点，即实现 8 倍抽取。

![FIR Compiler 1](./Images/FIR_Compiler_1.png)

- Number of Paths：设置为 2，用于配置 FIR 内部的数据并行路径。由于 IQ 数据通常包含 I、Q 两路分量，设置为 2 条路径可以更好地适配并行数据处理需求。
- Select Format：选择 Input Sample Period，表示使用输入采样周期来描述输入数据速率。
- Sample Period：设置为 1，表示输入数据每 1 个时钟周期输入一个采样点。

![FIR Compiler 2](./Images/FIR_Compiler_2.png)

- Coefficient Type：选择 Signed，表示滤波器系数采用有符号数。
- Quantization：选择 Quantize Only，表示 IP 只对导入的滤波器系数进行定点量化，不对系数进行额外缩放。
- Coefficient Width：设置为 16，表示量化后的 FIR 系数位宽为 16 bit。
- Best Precision Fraction Length：保持勾选，由 IP 自动选择合适的小数位长度，以尽量减小系数量化误差。
- Coefficient Structure：选择 Inferred，表示 IP 自动判断系数是否具有对称性，并在可能的情况下进行资源优化。
- Input Data Type：选择 Signed，表示输入数据为有符号数。
- Input Data Width：设置为 16，表示输入数据位宽为 16 bit。
- Input Data Fractional Bits：设置为 0，表示输入数据按整数格式处理，而不是小数定点格式。
- Output Rounding Mode：选择 Truncate LSBs，表示输出结果通过截断低位的方式缩短到目标位宽。
- Output Width：设置为 17，表示 FIR 输出数据位宽为 17 bit。这里选择 17 bit 是为了完整保留滤波结果的整数位，避免输出截位导致滤波后信号幅度和能量变小。

![FIR Compiler 3](./Images/FIR_Compiler_3.png)

Detailed Implementation 页面主要用于配置 IP 的具体实现结构和资源优化方式，该页面一般保持默认配置即可。

![FIR Compiler 4](./Images/FIR_Compiler_4.png)

Interface 页面主要用于配置 FIR Compiler 的 AXI-Stream 接口。

## 3 仿真

1. 运行 MATLAB 脚本 [IQ_Generator.m](./Code/MATLAB/IQ_Generator.m) 生成仿真输入数据。脚本生成一个复数 IQ 信号，该信号由 1 MHz 和 20 MHz 两个单音分量叠加得到，并将 I/Q 数据按照低 16 位为 I、高 16 位为 Q 的格式打包，生成 [IQ_Data.mem](./Code/MATLAB/IQ_Data.mem) 文件作为仿真激励。

   ![IQ_Data](./Images/IQ_Data.png)

2. 对原始 IQ 数据进行频谱分析，可以看到信号在 +1 MHz 和 +20 MHz 处各有一个单音峰值。

   <p align="center">
     <img src="./Images/Origin_IQ_Spectrum.png" alt="Origin_IQ_Spectrum" width="700">
   </p>

3. 在 Vivado 中生成 FIR Compiler IP，并导入设计好的 [FIR 抽头系数](./Code/Vivado/FIR_COE/DDC_FIR.coe)。该滤波器为复基带 8 倍抽取低通 FIR，通带范围为 -Fs/16 到 +Fs/16。对于 122.88 MHz 的输入采样率，通带范围对应 -7.68 MHz 到 +7.68 MHz。

    ![FIR Frequency Response](./Images/FIR_Frequency_Response.png)

4. 根据第二章中的参数完成 FIR Compiler IP 配置后，该 216 抽头、8 倍抽取 FIR 仅使用了 30 个 DSP。由于多相结构只计算抽取后需要保留的输出采样点，因此可以显著降低 DSP 资源占用。

    ![Implement Resource](./Images/Implement_Resource.png)

5. 在 Vivado 中运行 [tb_FIR.v](./Code/Vivado/tb_FIR.v) 进行功能仿真。仿真过程中，testbench 读取 `IQ_Data.mem` 中的 IQ 数据，并将其送入 FIR 模块。由于输入信号由 1 MHz 和 20 MHz 两个单音分量叠加得到，经过 FIR 抽取滤波后，通带内的 1 MHz 分量会被保留，通带外的 20 MHz 分量会被抑制。同时，输出采样率由原来的 122.88 MHz 降为 15.36 MHz，即变为原采样率的 1/8。仿真结束后，FIR 输出的 IQ 数据会保存到 [IQ_Result.txt](./Code/Vivado/IQ_Result.txt)，用于后续 MATLAB 频谱分析。

   ![Modelsim](./Images/Modelsim.png)

6. 使用 MATLAB 脚本 [Plot_IQ_Spect.m](./Code/MATLAB/Plot_IQ_Spect.m) 读取 `IQ_Result.txt`，并对 FIR 输出数据进行 FFT 分析。从频谱结果可以看到，原始信号中的 20 MHz 分量被明显抑制，输出信号主要保留 1 MHz 分量，说明 FIR Compiler IP 实现的多相抽取低通滤波器功能正常。

   <p align="center">
     <img src="./Images/IQ_Result_Spectrum.png" alt="IQ_Result_Spectrum" width="700">
   </p>
