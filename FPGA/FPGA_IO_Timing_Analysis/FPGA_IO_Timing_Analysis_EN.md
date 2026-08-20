[简体中文](./FPGA_IO_Timing_Analysis.md) | **English**

# Static Timing Analysis for FPGA I/O Ports

FPGA designs often communicate with other devices. Static timing analysis of the I/O ports is essential for reliable communication and for avoiding metastability.

## 1 FPGA Input Ports

Static timing analysis of an input port verifies whether the setup-time and hold-time requirements are satisfied when an external signal reaches the first-stage register inside the FPGA.

### 1.1 Principle

#### 1.1.1 Setup Time

![Input setup timing](./Images/Input_Setup_Timing.png)

As shown in the figure, DATA\_IN is the FPGA data input port, and CLK\_IN is the corresponding clock input port. Differences in the lengths of the data and clock traces between the FPGA and the other device, together with the clock-to-data delay at the output of the other device, cause DATA\_IN to arrive at the FPGA with a delay of *Tdelay* relative to CLK\_IN. For example, if the data output pin of the other device is delayed by *Tchip\_delay* relative to its clock output, and the PCB routing adds a data-to-clock skew of *Troute\_delay*, then *Tdelay* = *Tchip\_delay* + *Troute\_delay*.

![Setup timing analysis](./Images/Setup_Timing_Analysis.png)

If the clock arrival time at CLK\_IN is defined as 0, the data arrives at DATA\_IN at time *Tdelay*. The data reaches the D input of the internal capture register REG1 at *Tdelay* + *Tdata内*, while the capture clock reaches REG1/CK at *Tclk内* + *Tcycle*. To capture the data correctly, it must reach REG1 at least *Tsetup* before the clock. The FPGA setup-time check must therefore satisfy the following equation:

![Setup timing formula](./Images/Setup_Timing_Formula.png)

For FPGA design software such as Vivado, *Tdelay* is the only unknown term in the equation above and must therefore be specified with a timing constraint. To ensure that the setup-time requirement is satisfied under the worst-case condition, the equation must remain valid when *Tdelay* reaches its maximum value *Tmax\_delay*. The input-port setup constraints should therefore be specified as follows so that the software can analyze the input setup timing:

1. create\_clock -period *Tcycle* -name CLK\_IN -waveform {0 *Tcycle* / 2} [get\_ports CLK\_IN]

2. set\_input\_delay -clock CLK\_IN -max *Tmax\_delay* [get\_ports DATA\_IN]

#### 1.1.2 Hold Time

![Input hold timing](./Images/Input_Hold_Timing.png)

![Hold timing analysis](./Images/Hold_Timing_Analysis.png)

If the clock arrival time at CLK\_IN is defined as 0, the data at DATA\_IN changes at time *Tdelay*. The data at the D input of the internal capture register REG1 changes at *Tdelay* + *Tdata内*, while the clock at REG1/CK captures REG1/D at time *Tclk内*. To capture the data correctly, the data must remain stable for at least *Thold* after the active clock edge at REG1. The FPGA hold-time check must therefore satisfy the following equation:

![Hold timing formula](./Images/Hold_Timing_Formula.png)

For FPGA design software such as Vivado, *Tdelay* is the only unknown term in the equation above and must therefore be specified with a timing constraint. To ensure that the hold-time requirement is satisfied under the worst-case condition, the equation must remain valid when *Tdelay* reaches its minimum value *Tmin\_delay*. The input-port hold constraints should therefore be specified as follows so that the software can analyze the input hold timing:

1. create\_clock -period *Tcycle* -name CLK\_IN -waveform {0 *Tcycle* / 2} [get\_ports CLK\_IN]

2. set\_input\_delay -clock CLK\_IN -min *Tmin\_delay* [get\_ports DATA\_IN]

### 1.2 Example

Consider the gpmc\_cs chip-select signal used when an AM5728 device communicates with an FPGA through the GPMC interface:

![Example of gpmc_cs](./Images/gpmc_cs_Example.png)

The timing relationship between the AM5728 chip-select signal gpmc\_cs and the clock gpmc\_clk can be obtained from the AM5728 datasheet.

![gpmc_cs timing](./Images/gpmc_cs_Timing.png)

The frequency of gpmc\_clk is 100 MHz. The delay of gpmc\_cs relative to gpmc\_clk ranges from -1.48 ns to 3.84 ns. Assuming that the PCB traces are length-matched and that the board-level delay difference between them can be ignored, gpmc\_cs can be considered to arrive at the FPGA between -1.48 ns and 3.84 ns relative to gpmc\_clk.

The input-delay constraint for gpmc\_cs can therefore be specified in the Vivado XDC as follows:

![Vivado setup constraint](./Images/Vivado_Setup_Setting.png)

## 2 FPGA Output Ports

Static timing analysis of an FPGA output port verifies whether a signal can propagate from the final register inside the FPGA to the output port and become stable within the required time, thereby satisfying the setup-time and hold-time requirements of the external device.

### 2.1 Principle

#### 2.1.1 Setup Time

![Output setup timing](./Images/Output_Setup_Timing.png)

As shown in the figure, DATA\_OUT is the FPGA data output port, and CLK\_OUT is the corresponding clock output port. Assume that the data output by the FPGA leads the clock by *TFPGA* and that the clock and data PCB traces are length-matched (*Troute* = 0). The data arriving at the other device then leads the clock by *TFPGA*. To satisfy the setup-time requirement of the other device, the input data generally must become stable at least (*Tdata内* + *Tsetup* – *Tclk\_内*) before the clock. This requirement is usually specified in the device datasheet. The setup-time requirement of the other device is therefore satisfied when *TFPGA* ≥ (*Tdata内* + *Tsetup* – *Tclk\_内*).

FPGA design software such as Vivado must be given *TFPGA* so that it can analyze whether the output data becomes stable that amount of time before the clock. The timing constraint `set_output_delay` is used to specify *Tdelay*. The output-port setup constraint should therefore be specified as follows:

1、set\_output\_delay -clock CLKM -max *TFPGA* [get\_ports DATA\_OUT]

2.1.2 Hold Time

![Output hold timing](./Images/Output_Hold_Timing.png)

As shown in the figure, DATA\_OUT is the FPGA data output port, and CLK\_OUT is the corresponding clock output port. Assume that the data output by the FPGA leads the clock by *TFPGA* and that the clock and data PCB traces are length-matched (*Troute* = 0). At the input of the other device, the data transition is then delayed by -*TFPGA* relative to the clock. To satisfy the hold-time requirement of the other device, the input data generally must not change until at least (*Tclk* + *Thold* – *Tdata内*) after the clock. This requirement is usually specified in the device datasheet. The hold-time requirement is therefore satisfied when *TFPGA* ≤ -(*Tclk* + *Thold* – *Tdata内*).

FPGA design software such as Vivado must be given *TFPGA* so that it can analyze whether the output data changes with the required delay relative to the clock. The output-port hold constraint should therefore be specified as follows:

1.set\_output\_delay -clock CLKM -min *TFPGA* [get\_ports DATA\_OUT]

### 2.1 Example

Consider the gpmc\_ad data signal used when an AM5728 device communicates with an FPGA through the GPMC interface:

![Example of gpmc_ad](./Images/gpmc_ad_Example.png)

The timing relationship between the AM5728 data signal gpmc\_ad and the clock gpmc\_clk can be obtained from the AM5728 datasheet.

![gpmc_ad timing](./Images/gpmc_ad_Timing.png)

The frequency of gpmc\_clk is 100 MHz. The gpmc\_ad signal must be stable 2.69 ns before the rising edge of gpmc\_clk and cannot change until 1.53 ns after that rising edge.

The output-delay constraint for gpmc\_ad can therefore be specified in the Vivado XDC as follows:

![Vivado hold constraint](./Images/Vivado_Hold_Setting.png)

## 3 REFERENCES

1. https://blog.csdn.net/aaaaaaaa585/article/details/118862049
2. https://blog.csdn.net/aaaaaaaa585/article/details/118859268
3. Rakesh Chadha, J. Bhasker (auth.) - Static Timing Analysis for Nanometer Designs\_ A Practical Approach (2009, Springer) [10.1007\_978-0-387-93820-2]
