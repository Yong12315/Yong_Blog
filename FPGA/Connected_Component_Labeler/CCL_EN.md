[简体中文](./CCL.md) | **English**

# Connected-Component Labeling on FPGA: Design and Simulation Verification

## 1. Background

As advanced applications such as defect inspection, medical-image diagnosis, and object recognition continue to develop, demand for real-time image-processing performance is increasing. Connected Component Labeling (CCL) of binary images is a core operation in many online inspection systems. Its processing speed, labeling accuracy, and resource consumption directly affect overall system throughput and reliability.

In a binary image, a connected component is a set of foreground pixels that are connected under a specified neighborhood rule, such as 4-connectivity or 8-connectivity. CCL assigns a unique label to each connected component, enabling object segmentation and subsequent feature extraction.

![Connected-component example](./Images/Connected_Component_Example.png)

In the figure, white pixels represent the foreground of the binary image. The connected foreground pixels inside the rectangle on the left form one connected component. The connected foreground pixels in the pentagonal region on the right form another connected component.

This project implements a connected-component labeling method on FPGA. Compared with general-purpose processors such as DSPs and CPUs, the FPGA's massively parallel architecture can significantly improve algorithm speed and throughput. Compared with a dedicated ASIC, it retains programmability and development flexibility, making algorithm iteration and feature expansion easier.

## 2. Principle

Refer to [Research on FPGA-Based Image Connected-Component Processing](./Ref/基于FPGA的图像连通域处理的研究.kdh).

## 3. Simulation

The project uses a binary test image containing seven connected components with different shapes. Its rows are presented to the connected-component labeling module using simulated video-stream timing to verify the correctness of the algorithm.

![Binary test image](./Images/Binary_Test_Image.png)

### 3.1 Software Environment

Vivado 2020.1, MATLAB R2021a

### 3.2 Generating Binary-Image Data

1. Place the test image [Binary_Test_Image.png](./Images/Binary_Test_Image.png) and the MATLAB script [bin_2_txt.m](./Code/MATLAB/bin_2_txt/bin_2_txt.m) in the same directory so that the script can read the image and generate data for the subsequent simulation.

    ![Input image path](./Images/Input_Image_Path.png)

2. Open and run `bin_2_txt.m` in MATLAB. The script reads `Binary_Test_Image.png` and converts it into the binary-image data file `binaryImg.txt`. Background pixels are represented by `0`, while foreground pixels are represented by `1`. Because the original image is 361 × 478 pixels and contains a large amount of data, only part of the generated file is shown here.

   <p align="center">
     <img src="./Images/binaryImg.png" alt="Binary-image data" width="700">
   </p>

### 3.3 Creating the FPGA Simulation Project

1. Open the [labeler](./Code/Vivado/labeler) directory and import all `.v` source files from that directory and its subdirectories into the Vivado project. `labeler.v` is the top-level file, and `tb_labeler.v` is the testbench.

2. Modify the relevant parameters in `tb_labeler.v`.

    | **Parameter** | **Default value** | **Description** |
    | --- | --- | --- |
    | `ROWS` | `361` | Number of rows in the input image |
    | `COLS` | `478` | Number of columns in the input image |
    | `FRONT_PIX` | `1` | Foreground-pixel value of the input image; it can only be `0` or `1` |
    | `LABEL_WIDTH` | `8` | Connected-component label width. Because `0` represents the background, up to $2^{LABEL\_WIDTH}-1$ foreground connected components can be labeled |
    | `IMG_SRC_PATH` | `./MATLAB/bin_2_txt/binaryImg.txt` | Path to the input image data |
    | `IMG_DST_PATH` | `./MATLAB/labeled_Img/labeled_Img.txt` | Output path for the labeled image data |

    Set `IMG_SRC_PATH` to the actual path of the binary-image data file `binaryImg.txt`, and set `IMG_DST_PATH` to the desired output path for the labeled image data file `labeled_Img.txt`. The remaining parameters can keep their default values.

3. Run the simulation. The binary-image data is sent to the connected-component labeling module one row at a time. After the complete frame has been provided, the algorithm reports `num_label` as `7`, matching the actual number of connected components in the test image.

    ![FPGA CCL simulation](./Images/FPGA_CCL_Simulation.png)

4. After simulation, the labeled image data [labeled_Img.txt](./Code/MATLAB/labeled_Img/labeled_Img.txt) is exported to the location specified by `IMG_DST_PATH`. Background pixels are labeled `0`, while different connected components are labeled `1`, `2`, `3`, and so on. Because the file contains a large amount of data, only part of it is shown here.

   <p align="center">
     <img src="./Images/Labeled_Image_Data.png" alt="Labeled image data" width="700">
   </p>

### 3.4 Displaying the Labeled Image

1. Place the labeled image data file `labeled_Img.txt` and the MATLAB script [labeled_Img.m](./Code/MATLAB/labeled_Img/labeled_Img.m) in the same directory.

    ![Output data path](./Images/Output_Data_Path.png)

2. Open and run `labeled_Img.m` in MATLAB. The script reads the labels from `labeled_Img.txt` and assigns a different color to each connected component, providing a visual representation of the labeling result.

   <p align="center">
     <img src="./Images/Colored_Labeling_Result.png" alt="Colored labeling result" width="700">
   </p>

The displayed result shows that all seven connected components in the test image are correctly separated and assigned different colors, confirming the functional correctness of the FPGA connected-component labeling module in simulation.

## 4. Reference

1. Liu Xiaoyu. Research on FPGA-Based Image Connected-Component Processing [D]. Harbin Institute of Technology, 2013.
