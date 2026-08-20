[简体中文](./Xilinx_Polyphase_Decimation_Filter.md) | **English**

# Polyphase Decimation Filter Design Using the FIR Compiler IP

Downsampling is a common requirement in FPGA signal processing. A decimation filter performs anti-aliasing low-pass filtering while reducing the sampling rate. The Xilinx FIR Compiler IP supports a polyphase decimation structure that combines filtering and decimation, making it suitable for efficient FPGA downsampling designs.

## 1 Principle of a Polyphase Decimation Filter

A conventional decimation filter generally uses a cascaded structure consisting of an FIR low-pass filter followed by M-fold decimation. The input signal first passes through the FIR filter, and the decimator then keeps one out of every M output samples.

This approach is conceptually simple, but the FIR filter first calculates every output at the full sample rate. Only 1/M of those outputs are retained after decimation, while the rest are discarded, resulting in unnecessary multiply-accumulate operations.

As shown below, when an 8-tap FIR filter is followed by 4-fold decimation, the FIR filter first produces the continuous outputs y0, y1, y2, and so on, while the decimator keeps only y0, y4, y8, and so on. All intermediate outputs are ultimately discarded.

<p align="center">
  <img src="./Images/Trad_Decimation_FIR.png" alt="Conventional decimation FIR" width="600">
</p>

A polyphase decimation filter is an equivalent optimized implementation of the conventional structure. It takes advantage of the fact that only a subset of the output samples is retained after decimation. The coefficients of the original FIR filter are divided into M phase branches according to the decimation factor M, and filtering and decimation are implemented together. Instead of calculating every output and then discarding most of them, the filter directly calculates the output samples that will be retained, thereby reducing unnecessary operations.

<p align="center">
  <img src="./Images/Polyphase_Decimation_FIR.png" alt="Polyphase decimation FIR" width="600">
</p>

The polyphase structure above shows that the original eight FIR coefficients are divided into four phase branches for 4-fold decimation. Each phase branch contains only a subset of the coefficients. For example, phase 1 contains C0 and C4, phase 2 contains C1 and C5, phase 3 contains C2 and C6, and phase 4 contains C3 and C7. The original 8-tap FIR filter is therefore equivalently decomposed into four 2-tap subfilters.

Input samples enter the phase branches in sequence according to the decimation phase. After each phase branch completes its multiply-accumulate operation, the branch results are accumulated at the output to produce the final decimated sample. For an 8-tap FIR filter with 4-fold decimation, the original filter is decomposed into four 2-tap subfilters. Only two multipliers are therefore required in each cycle to calculate the current phase, rather than the eight multipliers required by a conventional fully parallel 8-tap FIR implementation to calculate a full-rate output every cycle. Because the output produces only the retained samples y0, y4, y8, and so on, the polyphase structure avoids calculating and then discarding intermediate results such as y1, y2, and y3.

From an implementation perspective, a polyphase decimation filter does not change the frequency response of the original FIR filter; it only changes how the calculations are organized. In the 8-tap, 4-fold-decimation example, the number of multipliers operating in parallel each cycle can be reduced from eight to two. This saves DSP, adder, and register resources and reduces the data-throughput pressure on downstream modules. Here, “from eight to two” refers to the number of parallel multipliers involved in each cycle. A complete decimated output still equivalently includes the effect of all eight original FIR coefficients.

## 2 Implementing Decimation Filtering on FPGA

The Xilinx FIR Compiler IP can be used directly to implement decimation filtering on an FPGA. The IP integrates FIR filtering, polyphase decimation, and AXI4-Stream data interfaces. A decimation filter can be built quickly by configuring the filter coefficients, decimation factor, input and output widths, and related parameters.

![FIR Compiler 0](./Images/FIR_Compiler_0.png)

- Select Source: select COE File to use an external COE file as the source of the filter coefficients.
- Coefficient File: specifies the path to the COE file. FIR Compiler generates the corresponding FIR filter from the coefficients in this file.
- Number of Coefficient Sets: set to 1 because only one fixed coefficient set is used and no coefficient-set switching is required.
- Filter Type: select Decimation to configure the IP as a decimation filter.
- Rate Change Type: select Integer because the sampling-rate change is an integer ratio.
- Decimation Rate Value: set to 8 so that one filtered output sample is generated for every eight input samples, implementing 8-fold decimation.

![FIR Compiler 1](./Images/FIR_Compiler_1.png)

- Number of Paths: set to 2 to configure the parallel data paths inside the FIR filter. IQ data generally contains separate I and Q components, so two paths better accommodate parallel data processing.
- Select Format: select Input Sample Period so that the input data rate is described by the input sample period.
- Sample Period: set to 1, indicating that one input sample is provided every clock cycle.

![FIR Compiler 2](./Images/FIR_Compiler_2.png)

- Coefficient Type: select Signed so that the filter coefficients use signed values.
- Quantization: select Quantize Only so that the IP performs fixed-point quantization of the imported coefficients without applying additional scaling.
- Coefficient Width: set to 16, giving the quantized FIR coefficients a width of 16 bits.
- Best Precision Fraction Length: leave this option enabled so that the IP automatically selects an appropriate fractional length to minimize coefficient quantization error.
- Coefficient Structure: select Inferred so that the IP automatically detects coefficient symmetry and performs resource optimization where possible.
- Input Data Type: select Signed because the input data is signed.
- Input Data Width: set to 16, giving the input data a width of 16 bits.
- Input Data Fractional Bits: set to 0 so that the input is treated as an integer rather than as a fractional fixed-point value.
- Output Rounding Mode: select Truncate LSBs so that the output is reduced to the target width by truncating its least-significant bits.
- Output Width: set to 17, giving the FIR output a width of 17 bits. A width of 17 bits is used here to preserve all integer bits of the filtering result and prevent output truncation from reducing the amplitude and energy of the filtered signal.

![FIR Compiler 3](./Images/FIR_Compiler_3.png)

The Detailed Implementation page configures the specific implementation architecture and resource-optimization options of the IP. The default settings are generally sufficient on this page.

![FIR Compiler 4](./Images/FIR_Compiler_4.png)

The Interface page configures the AXI4-Stream interfaces of FIR Compiler.

## 3 Simulation

1. Run the MATLAB script [IQ_Generator.m](./Code/MATLAB/IQ_Generator.m) to generate the simulation input data. The script generates a complex IQ signal composed of 1 MHz and 20 MHz single-tone components. It packs the I/Q data with I in the lower 16 bits and Q in the upper 16 bits, and generates [IQ_Data.mem](./Code/MATLAB/IQ_Data.mem) as the simulation stimulus.

   ![IQ data](./Images/IQ_Data.png)

2. Spectrum analysis of the original IQ data shows a single-tone peak at +1 MHz and another at +20 MHz.

   <p align="center">
     <img src="./Images/Origin_IQ_Spectrum.png" alt="Original IQ spectrum" width="700">
   </p>

3. Generate the FIR Compiler IP in Vivado and import the designed [FIR tap coefficients](./Code/Vivado/FIR_COE/DDC_FIR.coe). This filter is a complex-baseband, 8-fold-decimation low-pass FIR filter with a passband from -Fs/16 to +Fs/16. For an input sampling rate of 122.88 MHz, the passband corresponds to -7.68 MHz to +7.68 MHz.

    ![FIR frequency response](./Images/FIR_Frequency_Response.png)

4. After configuring FIR Compiler with the parameters from Section 2, this 216-tap, 8-fold-decimation FIR filter uses only 30 DSP blocks. Because the polyphase structure calculates only the output samples retained after decimation, it can significantly reduce DSP resource usage.

    ![Implementation resources](./Images/Implement_Resource.png)

5. Run [tb_FIR.v](./Code/Vivado/tb_FIR.v) in Vivado for functional simulation. During simulation, the testbench reads the IQ data from `IQ_Data.mem` and sends it to the FIR module. Because the input signal contains 1 MHz and 20 MHz single-tone components, the 1 MHz component inside the passband is retained after FIR decimation filtering, while the 20 MHz component outside the passband is attenuated. The output sampling rate is reduced from 122.88 MHz to 15.36 MHz, or one-eighth of the original sampling rate. At the end of the simulation, the FIR output IQ data is saved to [IQ_Result.txt](./Code/Vivado/IQ_Result.txt) for subsequent MATLAB spectrum analysis.

   ![ModelSim simulation](./Images/Modelsim.png)

6. Use the MATLAB script [Plot_IQ_Spect.m](./Code/MATLAB/Plot_IQ_Spect.m) to read `IQ_Result.txt` and perform FFT analysis on the FIR output data. The spectrum shows that the 20 MHz component in the original signal is significantly attenuated, while the output mainly retains the 1 MHz component. This confirms that the polyphase decimation low-pass filter implemented with the FIR Compiler IP operates correctly.

   <p align="center">
     <img src="./Images/IQ_Result_Spectrum.png" alt="Output IQ spectrum" width="700">
   </p>
