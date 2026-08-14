# FPGA Engineering Notes | FPGA 工程笔记

你好，这里是我的个人工程笔记。

这个仓库主要记录我在工作和技术实践中的一些思考与总结，包括设计思路、实现过程、仿真验证、问题排查，以及对相关技术的学习与探索。部分文章会附带源码、测试代码、脚本和完整的验证过程，希望这些记录不仅能帮助我沉淀经验，也能为遇到类似问题的开发者提供参考。

除了技术内容，这里也会收录一些关于工作、成长和生活的个人文章。

---

## 技术笔记

### 数字信号处理

* [基于 FPGA 的幅度谱计算与仿真验证](./FPGA/Magnitude_Spectrum/Magnitude_Spectrum.md)
* [基于查找表的 FPGA 定点 log₂ 计算模块设计](./FPGA/Log2_LUT/Log2_LUT.md)
* [基于 FIR Compiler IP 的多相抽取滤波器设计](./FPGA/Xilinx_Polyphase_Decimation_Filter/Xilinx_Polyphase_Decimation_Filter.md)
* [基于 CORDIC 优化的 FPGA 数字变频设计](./FPGA/CORDIC_Based_Frequency_Shift/CORDIC_Based_Frequency_Shift.md)

### 图像处理

* [基于 FPGA 的连通域标记与仿真验证](./FPGA/Connected_Component_Labeler/CCL.md)

### 接口与协议

* [Zynq PL 数据写入 PS DDR 的环形缓存机制](./FPGA/Zynq_PL_to_PS_DDR_Ring_Buffer/Zynq_PL_to_PS_DDR_Ring_Buffer.md)
* [Vivado SRIO Gen2 IP 解析](./FPGA/Vivado_SRIO_Gen2_IP/Vivado_SRIO_Gen2_IP.md)
* [Xilinx AXI 1G/2.5G Ethernet Subsystem IP 数据流解析](./FPGA/Xilinx_AXI_Ethernet_Subsystem_IP/Xilinx_AXI_Ethernet_Subsystem_IP.md)

### 安全与可靠性

* [Zynq-7000 安全启动与防护策略：AES、RSA 与 eFUSE 部署](./FPGA/Zynq7000_Secure_Boot/Zynq7000_Secure_Boot.md)

### 时序与工程实践

* [FPGA 端口静态时序分析](./FPGA/FPGA_IO_Timing_Analysis/FPGA_IO_Timing_Analysis.md)

---

## 工程之外

这里记录一些关于工作、成长和生活的个人文章。

### 年度总结

* [2025：唯易不易](./Year_End_Review/2025/2025.md)

---

这个仓库会持续整理和更新。文章中的实现方式、工具版本和设计结论，也可能随着后续实践不断补充和修正。

如果文章或代码对你有所帮助，欢迎点一个 Star。也欢迎通过 Issue 交流问题或提出建议。

