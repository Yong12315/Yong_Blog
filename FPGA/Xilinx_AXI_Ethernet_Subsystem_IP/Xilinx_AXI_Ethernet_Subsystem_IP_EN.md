[简体中文](./Xilinx_AXI_Ethernet_Subsystem_IP.md) | **English**

# Understanding the Data Flow of the Xilinx AXI 1G/2.5G Ethernet Subsystem IP

The Xilinx AXI 1G/2.5G Ethernet Subsystem uses a 32-bit AXI4-Stream interface to transfer Ethernet frames on the user side. Unlike a conventional single-channel AXI4-Stream data interface, it separates control information from frame data in the transmit direction and status information from frame data in the receive direction. Therefore, it is not sufficient to monitor only `TDATA`; the control, status, and data streams belonging to the same frame must also remain strictly aligned in time.

Using actual ILA waveforms, this article focuses on the following four interfaces:

| Direction | Interface | Purpose |
| --- | --- | --- |
| User logic → IP | TX Control | Frame type and checksum-control information for the frame to be transmitted |
| User logic → IP | TX Data | Complete Ethernet frame to be transmitted |
| IP → user logic | RX Status | Information such as the received frame address, length, and error status |
| IP → user logic | RX Data | Complete received Ethernet frame |

> This article discusses only the data organization and handshake relationships on the AXI4-Stream user interface. AXI4-Lite register configuration, PHY initialization, and the RGMII/SGMII/1000BASE-X interfaces are outside its scope.

## 1. Dual-Channel AXI4-Stream Architecture

The main interface relationships of the IP are shown below. AXI4-Lite is used for register configuration; TX Data and TX Control are two input AXI4-Stream interfaces; RX Data and RX Status are two output AXI4-Stream interfaces; and RGMII connects to the external Ethernet PHY.

<p align="center">
  <a href="./Images/System_Architecture.png">
    <img src="./Images/System_Architecture.png" alt="AXI Ethernet Subsystem IP interface diagram" width="760">
  </a>
</p>

On the AXI4-Stream user side, the data stream and the control/status stream are separate, but information belonging to the same frame must remain associated.

The two most important ordering constraints are:

1. Before transmitting a data frame, all six TX Control words associated with that frame must first be transferred into the IP;
2. After the IP receives a frame, it starts the RX Status stream before starting the corresponding RX Data stream.

In other words, TX accepts the data only after it has accepted the complete control frame, while RX starts the status stream before the data stream. The two RX transfers are independently subject to `TREADY` backpressure, so their completion order is not guaranteed to remain fixed. Although each control/status frame always contains only six 32-bit words, a data frame can range from tens to thousands of bytes. Buffering and backpressure logic must therefore preserve the one-to-one correspondence between the two streams.

## 2. AXI4-Stream Handshake and Byte Order

An AXI4-Stream transfer occurs only on a rising clock edge for which both `TVALID=1` and `TREADY=1`. If `TVALID=1` while `TREADY=0`, the source must hold `TDATA`, `TLAST`, and the valid-byte indication unchanged until the handshake completes.

The data bus in the waveforms used in this article is 32 bits wide:

- Each handshake transfers at most 4 bytes;
- `TLAST=1` indicates that the current beat is the last beat of the frame;
- `TKEEP` in the captured waveforms, and `TSTRB`/`STRB` in the official interface diagrams, indicate which byte lanes are valid in the final beat;
- A complete 4-byte beat corresponds to `0xF`. If the final beat contains fewer than 4 bytes, the value may be `0x1`, `0x3`, or `0x7`.

ILA displays `TDATA[31:0]` as one 32-bit hexadecimal value, while the first byte of an Ethernet frame is placed in the lowest byte lane. When interpreting a waveform, reconstruct the on-wire byte sequence within each 32-bit word in the order `TDATA[7:0]`, `TDATA[15:8]`, `TDATA[23:16]`, and `TDATA[31:24]`. Multi-byte network fields such as Length/Type also use network byte order, with the most significant byte first. It is therefore easy to read the byte order backwards when looking directly at the hexadecimal value shown by ILA.

## 3. Transmit Direction: TX Control and TX Data

### 3.1 Send the Control Stream Before the Data Stream

The following diagram shows the dual-channel timing for a normal frame transmission. TX Data is shown in the upper half and TX Control in the lower half. The red boxes and arrows identify the ordering relationship between the two interfaces.

<p align="center">
  <a href="./Images/TX_Dual_Stream_Timing.png">
    <img src="./Images/TX_Dual_Stream_Timing.png" alt="Timing relationship between TX Control and TX Data" width="900">
  </a>
</p>

The transmission of one frame can be divided into three stages:

1. User logic first sends six 32-bit control words on the TX Control channel and asserts `TLAST` on the sixth word;
2. Only after the IP has accepted the complete control frame does it allow `TREADY` on the TX Data channel to go high;
3. User logic then sends the Ethernet frame data, asserts `TLAST` on the final valid data beat, and uses `TKEEP`/`TSTRB` to indicate the valid bytes in that beat.

After accepting the control frame, the IP does not accept control information for the next frame until the current data frame has ended. This prevents the next frame's control words from being associated with the current data frame.

### 3.2 TX Control Word Format

A normal TX Control frame always consists of six 32-bit words, Word 0 through Word 5.

<p align="center">
  <a href="./Images/TX_Control_Words.png">
    <img src="./Images/TX_Control_Words.png" alt="Field definitions of the six TX Control words" width="900">
  </a>
</p>

The purpose of each control word is summarized below:

| Control word | Main fields | Description |
| --- | --- | --- |
| Word 0 | `Flag[31:28]` | `0xA` indicates a normal transmit frame; `0x5` indicates a forwarded receive-status frame, commonly used in direct RX-to-TX or loopback paths |
| Word 1 | `TxCsumCntrl[1:0]` | `00`: no checksum offload; `01`: partial checksum offload; `10`: full IP/TCP/UDP checksum offload |
| Word 2 | `TxCsBegin[31:16]`, `TxCsInsert[15:0]` | Specify the start position of the checksum calculation and the position at which the checksum is inserted, respectively |
| Word 3 | `TxCsInit[15:0]` | 16-bit initial value used for a partial checksum calculation |
| Word 4 | Reserved | Reserved; do not use it to carry custom user data |
| Word 5 | Reserved | Reserved; do not use it to carry custom user data; assert `TLAST` when this word is transferred |

The relevant fields in Word 1 through Word 3 participate in the calculation only when the transmit checksum function has been enabled in the IP. When checksum offload is not used, the simplest and clearest configuration is to set Word 0 to `0xA0000000` and Word 1 through Word 5 to zero.

### 3.3 Actual TX Control Waveform

The following ILA waveform shows the control stream for a normal transmitted frame. The first word in the red box is `0xA0000000`, meaning `Flag=0xA`. The remaining five APP words are all zero, indicating that IP checksum offload is not enabled for this frame. The final control word completes its handshake in the same cycle in which `TLAST` is asserted.

<p align="center">
  <a href="./Images/TX_Control_ILA.png">
    <img src="./Images/TX_Control_ILA.png" alt="TX Control ILA waveform with Flag equal to 0xA" width="900">
  </a>
</p>

In the figure, `TVALID` is not continuously high because it follows the transmission rate of the upstream logic; this does not violate the protocol. What must be guaranteed is that each control word is counted only when `TVALID && TREADY`, and that exactly six valid handshakes occur in each control frame.

### 3.4 Actual TX Data Waveform

After the complete control stream has been accepted, the IP asserts `TREADY` on TX Data and user logic begins transmitting the frame. The destination MAC address, source MAC address, Length/Type field, and subsequent data are highlighted in different colors below.

<p align="center">
  <a href="./Images/TX_Data_ILA.png">
    <img src="./Images/TX_Data_ILA.png" alt="ILA waveform of an Ethernet frame on TX Data" width="900">
  </a>
</p>

The frame can be reconstructed as follows:

| Field | Content |
| --- | --- |
| Destination MAC address | `00-35-0A-01-02-55` |
| Source MAC address | `01-02-03-04-05-06` |
| Length/Type | `0x03E8`, which represents a data length of 1000 bytes in this frame |
| Data | Incrementing repeatedly from `0x00` through `0xFF` |

Every complete data beat in the waveform has `TKEEP=0xF`. If the total frame length is not an integer multiple of 4 bytes, the final beat must provide the correct `TKEEP`; otherwise, downstream logic cannot determine which bytes in the final 32-bit word are valid.

## 4. Receive Direction: RX Status and RX Data

### 4.1 Start the Status Stream Before the Data Stream

The RX interface directions are the reverse of TX. After the IP receives a frame from the physical interface, it starts transferring the status of that frame on RX Status before it starts transferring the frame contents on RX Data. The two interfaces can be backpressured independently. Therefore, the fact that the status stream starts first does not mean that all six status words must always complete before the data stream begins.

Downstream logic must provide `TREADY` independently for the status and data streams and must not rely on a fixed completion-time difference between them. When two DMA engines or FIFOs receive the status and data separately, the descriptor or local-queue design must preserve their frame order.

### 4.2 RX Status Word Format

RX Status also always consists of six 32-bit words, but their contents differ from TX Control.

<p align="center">
  <a href="./Images/RX_Status_Words.png">
    <img src="./Images/RX_Status_Words.png" alt="Field definitions of the six RX Status words" width="900">
  </a>
</p>

The main contents of each status word are summarized below:

| Status word | Main fields | Description |
| --- | --- | --- |
| Word 0 | `Flag[31:28]` | Fixed at `0x5`, indicating a receive-status frame |
| Word 1 | `MCAST_ADR_U[15:0]` | Upper 16 bits of the multicast destination MAC address; meaningful only when the multicast flag is valid |
| Word 2 | `MCAST_ADR_L[31:0]` | Lower 32 bits of the multicast destination MAC address; meaningful only when the multicast flag is valid |
| Word 3 | Receive status bits | Contains information including frame length, multicast/broadcast status, FCS errors, bad-frame status, good-frame status, and receive-checksum status |
| Word 4 | `T_L_TPID[31:16]`, `RX_CSRAW[15:0]` | For a non-VLAN frame, the former is Length/Type; the latter is the raw receive checksum |
| Word 5 | `VLAN_TAG[31:16]`, `RX_BYTECNT[15:0]` | VLAN information and the actual number of frame bytes delivered to RX Data; assert `TLAST` when this word is transferred |

Word 3 is the key to deciding whether a received frame is usable. Frequently used fields include `GOOD_FRAME`, `BAD_FRAME`, `FCS_ERR`, `LEN_FIELD_ERR`, and `LENGTH_BYTES`. Receive logic should not assume that a frame is valid merely because data appears on RX Data; it should first parse the corresponding RX Status.

An important detail is that Word 1 and Word 2 do not unconditionally provide the normal unicast destination MAC address for every frame. They carry multicast-address information and should be interpreted only when the corresponding multicast-status flag is valid. The destination address of a normal frame must still be read from RX Data.

### 4.3 Actual RX Status Waveform

The following status stream corresponds to a correctly received frame. The first word is `0x50000000`, meaning `Flag=0x5`. The subsequent status words provide receive status, Length/Type, and the received byte count.

<p align="center">
  <a href="./Images/RX_Status_ILA.png">
    <img src="./Images/RX_Status_ILA.png" alt="RX Status ILA waveform with Flag equal to 0x5" width="900">
  </a>
</p>

The yellow “destination address” annotation in the figure was formed by concatenating the observed values of Word 1 and Word 2, and it happens to match the destination address of this frame. However, `MAC_MCAST_FLAG=0` for this frame. According to PG138, the two multicast-address fields are invalid in this case and must not be treated as an ordinary unicast destination address. The reliable unicast destination address must still be parsed from the RX Data frame header that follows.

The actual value of Word 3 is `0x001FD040`: `GOOD_FRAME=1`, `BAD_FRAME=0`, `FCS_ERR=0`, and `RX_CS_STS=000`. This indicates that the frame was received correctly and that receive-checksum verification was not performed in this example.

Three length values that are easy to confuse appear in this waveform:

- Length/Type in Word 4 is `0x03E8`. Because this value is less than `0x0600`, it represents a MAC data-field length of 1000 bytes in this frame;
- `LENGTH_BYTES` in Word 3 is `0x03FA`, or 1018 bytes, corresponding to the 14-byte Ethernet header, 1000 bytes of data, and the 4-byte FCS;
- `RX_BYTECNT` in Word 5 is `0x03F6`, or 1014 bytes, representing the frame length actually delivered on RX Data after the 4-byte FCS has been removed.

The difference between `0x03F6` and `0x03E8` is 14 bytes, exactly matching the 6-byte destination MAC address, 6-byte source MAC address, and 2-byte Length/Type field. `0x03FA` is another 4 bytes larger than `0x03F6`, corresponding to the FCS at the end of the frame on the physical link. These three values confirm one another: the current RX Data stream contains the Ethernet header and 1000 bytes of data, but not the received FCS.

### 4.4 Actual RX Data Waveform

After RX Status starts, the IP subsequently presents the corresponding frame on RX Data. The upper half of the following figure highlights the Ethernet header, while the lower half shows the continuous data contents.

<p align="center">
  <a href="./Images/RX_Data_ILA.png">
    <img src="./Images/RX_Data_ILA.png" alt="ILA waveform of an Ethernet frame on RX Data" width="900">
  </a>
</p>

The frame can be reconstructed as follows:

| Field | Content |
| --- | --- |
| Destination MAC address | `00-35-0A-01-02-33` |
| Source MAC address | `01-02-03-04-05-06` |
| Length/Type | `0x03E8` |
| Data | Incrementing repeatedly from `0x00` through `0xFF` |

The waveform shows that the frame header and payload are output continuously on the same RX Data stream; the IP does not strip the MAC header into a separate interface. If downstream logic requires only the payload, it must parse past the 6-byte destination address, 6-byte source address, and 2-byte Length/Type field. VLAN, IPv4/IPv6, and other frame types require the parsing offset to be adjusted further according to the fields that follow.

## 5. Common Design and Debugging Issues

### 5.1 Do Not Allow the Control and Data Streams to Lose Frame Alignment

TX Control and TX Data must be paired strictly by frame. A recommended upstream design is to latch the control descriptor and data descriptor from the same “frame commit” event and permit transmission of the corresponding data frame only after all six control-word handshakes have completed. Do not count based only on how long `TVALID` remains asserted; count only `TVALID && TREADY` handshakes.

In the RX direction, record RX Status and RX Data separately in frame order. The two transfers can overlap in time because each may experience independent backpressure, so they cannot be paired using a fixed delay. If the two channels enter different FIFOs, the system-level design must account for backpressure propagation when either FIFO becomes full, preventing the status and data queues from losing synchronization.

### 5.2 The Control/Status Frames Have Fixed Lengths; the Data Frames Do Not

TX Control and RX Status both always contain six 32-bit words, with `TLAST` asserted on Word 5. The lengths of TX Data and RX Data depend on the actual Ethernet frame, so the position of `TLAST` must not be hard-coded.

### 5.3 Pay Attention to the Valid Bytes in the Final Beat

For a 32-bit data channel, a complete data beat has a valid-byte indication of `0xF`. If the final beat contains fewer than 4 bytes, provide `0x1`, `0x3`, or `0x7` according to the number of remaining bytes. During ILA debugging, capture `TDATA`, `TVALID`, `TREADY`, `TLAST`, and `TKEEP`/`TSTRB` together. Looking only at `TDATA` makes frame boundaries difficult to identify.

### 5.4 Do Not Read Network Fields Directly as 32-Bit Values

The displayed ordering of the Ethernet byte stream, AXI byte lanes, and ILA hexadecimal values differs. A useful debugging script should first expand every valid `TDATA` word from its lowest byte to its highest byte, and then reassemble the Ethernet protocol fields. This avoids reading MAC addresses, Length/Type, or multi-byte fields in protocol headers in reverse order.

### 5.5 Checksum Fields Depend on the IP Configuration

`TxCsumCntrl`, `TxCsBegin`, `TxCsInsert`, and `TxCsInit` in TX Control take effect only if the corresponding checksum-offload function was enabled when the IP was generated. `RX_CSRAW` and `RX_CS_STS` in RX Status likewise depend on the receive-checksum configuration. If the relevant function is disabled, treat these fields as invalid or set them to zero as specified in the official documentation; do not interpret reserved waveform values as protocol data.

## 6. Summary

The most important aspect of the AXI Ethernet Subsystem user interface is not either AXI4-Stream data bus in isolation, but the relationship between the two channels associated with the same frame:

- TX: send six control words first, then send the frame data;
- RX: the status stream starts before the data stream, and each stream independently follows AXI4-Stream backpressure;
- Control/status frames always contain six 32-bit words, while data-frame length is variable;
- RX Status provides metadata such as whether the frame is valid, Length/Type, and the received byte count;
- When analyzing ILA waveforms, account for the handshake, frame boundaries, valid bytes, and byte-lane order together.

Once these relationships are handled correctly, the same approach can be used to diagnose interactions among the control, status, and data streams whether the downstream connection uses AXI DMA, AXI FIFO, or custom transmit/receive logic.

## 7. References

1. [AMD AXI 1G/2.5G Ethernet Subsystem Product Guide (PG138)](https://docs.amd.com/r/en-US/pg138-axi-ethernet)
2. [AMD PG138: AXI4-Stream Interface](https://docs.amd.com/r/en-US/pg138-axi-ethernet/AXI4-Stream-Interface)
3. [AMD PG138: Transmit AXI4-Stream Interface](https://docs.amd.com/r/en-US/pg138-axi-ethernet/Transmit-AXI4-Stream-Interface)
4. [AMD PG138: Normal Transmit AXI4-Stream Control Words](https://docs.amd.com/r/en-US/pg138-axi-ethernet/Normal-Transmit-AXI4-Stream-Control-Words)
5. [AMD PG138: Receive AXI4-Stream Interface](https://docs.amd.com/r/en-US/pg138-axi-ethernet/Receive-AXI4-Stream-Interface)
