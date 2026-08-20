**简体中文** | [English](./CCL_EN.md)

# 基于 FPGA 的连通域标记与仿真验证

## 1. 背景

随着缺陷检测、影像诊断和目标识别等高端应用的迅速发展，业界对实时图像处理性能的需求不断提升。二值图像的连通域标记（Connected Component Labeling，CCL）是众多在线检测系统的核心环节，其处理速度、标记正确性和资源消耗会直接影响系统的吞吐率和可靠性。

在二值图像中，“连通域”指的是所有前景像素在给定邻域准则（如 4 邻域或 8 邻域）下相互连通所形成的像素集合；CCL 的任务就是为每个连通域分配唯一标签，从而实现目标分割与后续特征提取。

![Connected Component Example](./Images/Connected_Component_Example.png)

如图所示，该二值图以白色像素表示前景。左侧矩形区域内的前景像素互相连通，构成一个连通域。右侧五边形区域的前景像素同样连通，形成另一连通域。

为此，本项目实现了一种基于 FPGA 的连通域标记方法。与 DSP、CPU 等通用处理器相比，FPGA 依托大规模并行架构，可显著提高算法速度和吞吐率；相较于专用 ASIC，则具备可编程性和开发灵活性，便于算法迭代与功能扩展。

## 2. 原理

参考[《基于FPGA的图像连通域处理的研究》](./Ref/基于FPGA的图像连通域处理的研究.kdh)。

## 3. 仿真

本项目选用一张包含 7 个不同形状连通域的二值图像，并通过模拟视频流时序将其逐行数据输入连通域标记模块，以验证算法的正确性。

![Binary Test Image](./Images/Binary_Test_Image.png)

### 3.1 软件环境

Vivado 2020.1, MATLAB R2021a

### 3.2 生成二值图数据

1. 将待测试图像 [Binary_Test_Image.png](./Images/Binary_Test_Image.png) 和 MATLAB 脚本 [bin_2_txt.m](./Code/MATLAB/bin_2_txt/bin_2_txt.m) 放在同一文件夹下，便于脚本读取图像并生成后续仿真数据。

    ![Input Image Path](./Images/Input_Image_Path.png)

2. 用 MATLAB 打开并运行脚本 `bin_2_txt.m`。该脚本会读取 `Binary_Test_Image.png`，并将其转换为二值图数据文件 `binaryImg.txt`。其中，背景像素用 `0` 表示，前景像素用 `1` 表示。由于原始图像大小为 361 × 478，数据量较大，本文仅截取部分内容进行展示。

   <p align="center">
     <img src="./Images/binaryImg.png" alt="binaryImg" width="700">
   </p>

### 3.3 建立 FPGA 仿真工程

1. 打开 [labeler](./Code/Vivado/labeler) 文件夹，将该文件夹及其子目录下的所有 `.v` 源文件全部导入 Vivado 工程。其中，`labeler.v` 为顶层文件，`tb_labeler.v` 为 testbench 文件。

2. 修改 `tb_labeler.v` 中的相关参数。

    | **参数名** | **默认值** | **说明** |
    | --- | --- | --- |
    | `ROWS` | `361` | 输入图像的行数 |
    | `COLS` | `478` | 输入图像的列数 |
    | `FRONT_PIX` | `1` | 输入图像的前景像素，仅能为 `0` 或 `1` |
    | `LABEL_WIDTH` | `8` | 连通域标签位宽。由于 `0` 用于表示背景，因此最多可标记 $2^{LABEL\_WIDTH}-1$ 个前景连通域 |
    | `IMG_SRC_PATH` | `./MATLAB/bin_2_txt/binaryImg.txt` | 输入图像数据的路径 |
    | `IMG_DST_PATH` | `./MATLAB/labeled_Img/labeled_Img.txt` | 标记后图像数据的输出路径 |

    将 `IMG_SRC_PATH` 设置为二值图数据 `binaryImg.txt` 的实际路径，将 `IMG_DST_PATH` 设置为标记后图像数据 `labeled_Img.txt` 的输出路径，其余参数保持默认值即可。

3. 运行仿真工程。二值图数据会逐行输入连通域标记算法模块。整帧数据输入完毕后，算法输出的连通域数量 `num_label` 为 `7`，与测试图像中的实际连通域数量一致。

    ![FPGA_CCL_Simulation](./Images/FPGA_CCL_Simulation.png)

4. 仿真结束后，标记后的图像数据 [labeled_Img.txt](./Code/MATLAB/labeled_Img/labeled_Img.txt) 会导出到 `IMG_DST_PATH` 指定的位置。文件中，背景像素标记为 `0`，不同连通域依次标记为 `1`、`2`、`3` 等。由于数据量较大，此处仅截取部分内容进行展示。

   <p align="center">
     <img src="./Images/Labeled_Image_Data.png" alt="Labeled_Image_Data" width="700">
   </p>

### 3.4 显示标记后的图像

1. 将标记后的图像数据 `labeled_Img.txt` 和 MATLAB 脚本 [labeled_Img.m](./Code/MATLAB/labeled_Img/labeled_Img.m) 放在同一文件夹下。

    ![Output_Data_Path](./Images/Output_Data_Path.png)

2. 用 MATLAB 打开并运行脚本 `labeled_Img.m`。该脚本会读取 `labeled_Img.txt` 中的标记结果，并为每个连通域分配不同颜色，从而直观显示连通域标记结果。

   <p align="center">
     <img src="./Images/Colored_Labeling_Result.png" alt="Colored_Labeling_Result" width="700">
   </p>

从显示结果可以看出，测试图像中的 7 个连通域均被正确区分，并被赋予了不同颜色，说明 FPGA 连通域标记模块的功能仿真结果正确。

## 4. Reference

1. 刘小宇. 基于 FPGA 的图像连通域处理的研究 [D]. 哈尔滨工业大学, 2013.
