[简体中文](./CORDIC_Based_Frequency_Shift.md) | **English**

# CORDIC-Optimized Digital Frequency Shifting on FPGA

Digital frequency shifting multiplies an input signal by a local-oscillator signal to translate its spectrum. As a key operation in digital signal processing, frequency shifting is widely used in receive and transmit chains and directly affects subsequent filtering, decimation, interpolation, and demodulation. The strong parallel-processing capability and real-time performance of an FPGA make it well suited to implementing a digital frequency-shifting system.

## 1 Principle of Digital Frequency Shifting

In the figure below, the left side shows the spectrum of the input signal $x(t)$, whose center frequency is $f_{0}$, while the right side shows the spectrum of the local-oscillator signal $e^{j2πf_{c}t}$ at frequency $f_{c}$.

![Spectrum before mixing](./Images/Spectrum_Before_Mixing.png)

After multiplication in the time domain, which corresponds to convolution in the frequency domain, the entire input spectrum is shifted by $f_{c}$. The center frequency of the mixed signal therefore becomes $f_{0}+f_{c}$.

![Spectrum after mixing](./Images/Figure_2.png)

Digital frequency shifting translates the signal spectrum by multiplying the input signal $x[n]$ by a complex-exponential local oscillator:

$$
y\left[n\right] = x[n]e^{j2π\frac{f_{c}}{f{_s}}n}
$$

Here, $f_{c}$ is the local-oscillator frequency used for mixing, and $f_{s}$ is the input sampling rate. When $f_{c}$ is positive, the output spectrum shifts toward higher frequencies relative to the input spectrum. When $f_{c}$ is negative, the output spectrum shifts toward lower frequencies.

## 2 FPGA Implementation of Digital Frequency Shifting

A conventional implementation first uses a DDS IP core to generate the local-oscillator signal and then multiplies it by the input signal to perform mixing. This common approach consumes a relatively large number of DSP48E1 resources.

To reduce resource consumption, this design uses a CORDIC-based implementation. It performs the frequency shift through phase rotation instead of relying entirely on conventional multipliers, making it more suitable for resource-constrained or multichannel FPGA designs.

### 2.1 FPGA Implementation Procedure

1. Calculate the phase increment between adjacent samples from the mixing frequency $f_c$ and sampling rate $f_s$:

$$
\Delta\phi = 2\pi \frac{f_c}{f_s}
$$

2. Accumulate the phase increment $\Delta\phi$ for each sample to obtain the phase of the local-oscillator signal at every sampling instant.

3. Limit the accumulated phase to $[-\pi,\pi]$ before sending it to the CORDIC module for rotation.

4. Use the input IQ signal as the input vector of the CORDIC rotation mode and the current accumulated phase as the rotation angle. The IQ signal is then rotated in the complex plane. Because complex multiplication is geometrically equivalent to phase rotation, the CORDIC output is the frequency-shifted IQ signal.

*The phase accumulator and limiter wrap the phase as follows: subtract* $2π$ *when the accumulated result exceeds* $π$*, and add* $2π$ *when it falls below* $-π$*. This keeps the phase within* $\left[-π,π\right]$ *at all times.*

   ![FPGA architecture](./Images/Figure_3.png)

### 2.2 CORDIC IP Configuration

   ![IP configuration](./Images/Figure_4.png)

- Functional Selection: select Rotate mode to rotate the input vector.
- Architectural Configuration: select the Parallel architecture so that one result can be produced every clock cycle, which is suitable for high-throughput applications.
- Pipelining Mode: select Maximum to insert as many pipeline registers as possible between computation stages, increasing the achievable clock frequency and improving timing performance.
- Phase Format: select Radians so that the phase input is represented in radians.
- Round Mode: select Nearest Even, which rounds to the nearest value with ties rounded to even, reducing quantization error.
- Iteration: set to 0 so that the IP automatically selects the number of iterations.
- Precision: set to 0 so that the IP automatically selects the internal computation precision.
- Coarse Rotation: when enabled, the IP first performs a coarse prerotation of the input vector to support a wider input-phase range. Without this option, the supported phase range is limited.
- Compensation Scaling: select Embedded Multiplier to compensate for the fixed gain introduced by the CORDIC iterations and preserve the output amplitude. If No Scale Compensation is selected, this fixed gain is not compensated in the output.

## 3 Source Code and Simulation

1. First run the MATLAB script [IQ_Generator.m](./Code/MATLAB/IQ_Generator.m) to generate the IQ data used for simulation. The generated samples are saved to [IQ_Data.mem](./Code/MATLAB/IQ_Data.mem) as the input stimulus for the subsequent FPGA simulation.

   ![IQ data](./Images/IQ_Data.png)

2. The MATLAB test signal is an OFDM-modulated complex-baseband signal sampled at 122.88 MHz. Its spectrum is mainly distributed between -5 MHz and +5 MHz, making it suitable for verifying spectral translation by the digital frequency-shifting module.

   <p align="center">
     <img src="./Images/OFDM_IQ_Spectrum.png" alt="OFDM IQ spectrum" width="700">
   </p>

3. Run the simulation file [tb_Frequency_Shift.v](./Code/Vivado/Frequency_Shift/tb_Frequency_Shift.v) in Vivado. During simulation, the testbench reads the IQ samples from IQ_Data.mem and sends them to the digital frequency-shifting module. This simulation uses a +10 MHz shift, so the CORDIC rotation moves the entire input IQ spectrum toward higher frequencies. At the end of the simulation, the shifted output IQ data is saved to [IQ_Result.txt](./Code/Vivado/Frequency_Shift/IQ_Result.txt) for subsequent MATLAB spectrum analysis.

   ![ModelSim simulation](./Images/Modelsim.png)

4. Use the MATLAB script [Plot_IQ_Spect.m](./Code/MATLAB/Plot_IQ_Spect.m) to read IQ_Result.txt and perform FFT analysis on the shifted IQ data. The result shows that the input spectrum, originally spanning -5 MHz to +5 MHz, is shifted to approximately 5 MHz to 15 MHz. The measured shift matches the configured +10 MHz, confirming that the CORDIC-based digital frequency-shifting module performs the spectral translation correctly.

   <p align="center">
     <img src="./Images/IQ_Result_Spectrum.png" alt="Shifted IQ spectrum" width="700">
   </p>
