[简体中文](./Magnitude_Spectrum.md) | **English**

# FPGA Magnitude Spectrum Calculation and Simulation Verification

Spectrum analysis is commonly used in signal processing to observe a signal's frequency distribution, bandwidth, and relative strength at different frequency bins. In a real-time FPGA signal-processing system, time-domain samples are generally converted into complex frequency-domain data through an FFT. The real and imaginary components are then used to calculate the magnitude spectrum. The resulting spectrum provides a basis for subsequent spectrum display, signal detection, and threshold decisions. This article focuses on its FPGA implementation.

## 1. Principle of Magnitude Spectrum Calculation

After the FFT converts the time-domain samples into the frequency domain, the output of each frequency bin is generally a complex value:

$$
X[k] = I[k] + jQ[k]
$$

Here, $`I[k]`$ is the real component of frequency bin $`k`$, and $`Q[k]`$ is its imaginary component. To describe the signal strength at that frequency bin, the magnitude of the complex spectrum is calculated as follows:

$$
|X[k]| = \sqrt{I[k]^2 + Q[k]^2}
$$

Calculating the magnitude for every frequency bin produces the magnitude spectrum. It represents the relative strength of the signal across different frequency components and can be used for subsequent spectrum display, signal detection, threshold decisions, and similar processing.

A direct FPGA implementation of the equation above requires squaring, addition, and square-root operations, which consume substantial logic resources and introduce relatively large computational latency. To reduce implementation complexity, this design uses the $`\alpha Max + \beta Min`$ magnitude approximation. The algorithm first takes the absolute values of the real and imaginary components and determines the larger and smaller values:

$$
Max = \max(|I[k]|, |Q[k]|)
$$

$$
Min = \min(|I[k]|, |Q[k]|)
$$

The complex magnitude is then approximated by a weighted sum:

$$
|X[k]| \approx \alpha \cdot Max + \beta \cdot Min
$$

This design uses:

$$
\alpha = \frac{15}{16}, \quad \beta = \frac{15}{32}
$$

The magnitude can therefore be approximated as:

$$
|X[k]| \approx \frac{15}{16}Max + \frac{15}{32}Min
$$

Because:

$$
\frac{15}{16}Max = Max - \frac{Max}{16}
$$

$$
\frac{15}{32}Min = \frac{Min}{2} - \frac{Min}{32}
$$

Division by $`2^n`$ can be implemented in binary hardware by shifting right by $`n`$ bits, so the expression can be rewritten as:

$$
|X[k]| \approx \left(Max - (Max \gg 4)\right) + \left((Min \gg 1) - (Min \gg 5)\right)
$$

This form requires only absolute-value operations, comparison, shifting, addition, and subtraction. It avoids squaring and square-root calculations and is therefore better suited to pipelined FPGA processing. Although the result is an approximation, it accurately represents the relative magnitude of the frequency bins and meets the needs of applications such as spectrum display, signal detection, and threshold decisions.

## 2. FPGA Implementation of Magnitude Spectrum Calculation

### 2.1 FFT IP Configuration

The Xilinx Fast Fourier Transform IP can be instantiated directly to implement the FFT on an FPGA.

![FFT configuration](./Images/FFT_Configuration.png)

- **Number of Channels**: the number of FFT channels. One complex IQ data stream corresponds to one channel.
- **Transform Length**: the FFT length. This design uses `8192` points, meaning that each frame contains 8192 complex input samples and produces 8192 frequency-domain outputs.
- **Target Clock Frequency**: the target operating clock frequency. This design uses `122 MHz` to guide Vivado's FFT architecture selection, resource estimation, and latency estimation.
- **Target Data Throughput**: the target input throughput. This design uses `122 MSPS`, meaning that the FFT IP must support a complex input stream of approximately 122 MSPS.
- **Architecture Choice**: the internal FFT implementation architecture. `Automatically Select` is used so that Vivado selects an appropriate architecture based on the target clock frequency, throughput, and FFT length.
- **Run Time Configurable Transform Length**: enables run-time FFT-length configuration. This option is disabled, so the FFT length is fixed at `8192`.

![FFT implementation](./Images/FFT_Implementation.png)

- **Data Format**: the FFT data format. `Fixed Point` is selected so that the FFT IP uses fixed-point arithmetic, which is suitable for FPGA implementation.
- **Scaling Options**: the FFT scaling method. `Unscaled` is selected, meaning that no scaling is performed between FFT stages and that the output retains the word-length growth introduced by the FFT. This avoids precision loss due to scaling, but downstream modules must account for the increased output width.
- **Rounding Modes**: the rounding method. `Convergent Rounding` is selected to reduce DC bias caused by rounding during fixed-point truncation.
- **Input Data Width**: the input data width. Both the real and imaginary FFT input components are configured as `16 bit`.
- **Phase Factor Width**: the twiddle-factor width. The internal FFT twiddle factors use `16 bit` fixed-point precision. This parameter can generally be set to the same width as the input data.
- **Output Ordering**: the output order. `Natural Order` is selected so that FFT bins are output in natural order, simplifying subsequent spectrum analysis by bin index.
- **Cyclic Prefix Insertion**: enables cyclic-prefix insertion. This option is disabled. It is primarily used in applications such as OFDM and is generally unnecessary for ordinary spectrum analysis.
- **XK_INDEX**: enables the frequency-bin index output. With this option enabled, the FFT IP provides the current bin index in the output `tuser` field, allowing downstream modules to identify the position of each frequency bin.
- **OVFLO**: enables the overflow-flag output. This option is disabled, so the FFT does not output an overflow flag.
- **Throttle Scheme**: the data-flow control scheme. `Non Real Time` is selected so that the FFT IP supports AXI4-Stream flow control and can perform handshake transfers with downstream modules.

The **Detailed Implementation** tab configures the specific resource implementation of the FFT IP, including memory and multiplier resources. The default settings are generally sufficient, allowing Vivado to choose an implementation based on the FFT length, throughput, and target clock frequency.

### 2.2 Generating Simulation Data

1. First run the MATLAB script [IQ_Generator.m](./Code/MATLAB/IQ_Generator.m) to generate IQ data for simulation. The generated data is saved to [IQ_Data.mem](./Code/MATLAB/IQ_Data.mem) and used as the input stimulus for the subsequent FPGA simulation.

   ![IQ data](./Images/IQ_Data.png)

2. The MATLAB test signal is an OFDM-modulated complex-baseband signal sampled at 122.88 MHz. Its spectrum is distributed from -20 MHz to +20 MHz and can be used to verify the FPGA magnitude-spectrum calculation.

   ![OFDM IQ spectrum](./Images/OFDM_IQ_Spectrum.png)

### 2.3 Vivado Simulation Verification

1. Run the simulation file [tb_Full_Band_PowerSpec.v](./Code/Vivado/tb_Full_Band_PowerSpec.v) in Vivado. During simulation, the testbench reads the IQ samples from IQ_Data.mem and sends them to the FFT IP. The FFT result is then passed to the magnitude-spectrum module [Full_Band_PowerSpec.v](./Code/Vivado/Full_Band_PowerSpec.v), which calculates the final magnitude spectrum.

   ![Simulation result](./Images/Sim_Result.png)

2. The simulation result shows that the frequency distribution of the magnitude spectrum calculated by the FPGA is generally consistent with the MATLAB result. In both cases, the main signal bandwidth is concentrated between -20 MHz and +20 MHz. Because the FPGA uses the αMax + βMin magnitude approximation, its magnitude values differ slightly from MATLAB's exact square-and-square-root calculation. Nevertheless, the spectral envelope and relative strength of the frequency bins remain consistent, satisfying the requirements of subsequent spectrum display and threshold detection.
