[简体中文](./Zynq7000_Secure_Boot.md) | **English**

# Zynq-7000 Secure Boot and Protection Strategies: AES, RSA, and eFUSE Deployment

In a Zynq-7000-based product, an attacker who obtains the complete device can usually access the PCB, boot Flash, debug interfaces, and software images directly. If the system does not establish a trusted boot chain, relying only on keeping the code private is unlikely to protect the FPGA logic and software assets over the long term.

Zynq-7000 provides AES-256-CBC encryption, HMAC-SHA-256 integrity checking, RSA-2048 public-key authentication, and on-chip key storage mechanisms such as eFUSE and BBRAM. Combining these capabilities appropriately raises the barrier against board cloning, image reverse engineering, malicious tampering, and the execution of unauthorized firmware.

This article first explains the responsibility of each security mechanism, then describes the deployment process for keys, boot images, and eFUSE. The GUI procedures near the end use Vivado/SDK 2018.3 as their reference. Menu locations may differ in newer tools, but the security architecture and key-management principles remain unchanged.

> **Important:** eFUSE is a one-time resource. Incorrectly programming an AES key, a secure-boot bit, or a JTAG-disable bit can permanently prevent a device from booting or being debugged and can affect repairability. Before mass production, the complete process must be verified on dedicated test devices. Control bits should be programmed last, after functional verification has been completed.

## 1. Define What Must Be Protected

Common risks can be divided into the following categories:

| Risk | Attack method | Primary protection objective | Corresponding Zynq-7000 capability |
| --- | --- | --- | --- |
| Product cloning | Clone the board and copy the external Flash | Prevent the copied image from running on an unauthorized device | On-chip AES key, eFUSE, or BBRAM |
| Software cracking | Read the Flash and analyze the FSBL, Bitstream, and application | Protect image confidentiality | AES-256-CBC encryption |
| Software tampering | Replace a boot partition or inject a malicious image | Verify image origin and integrity | RSA-2048 authentication |
| Debug-interface abuse | Read or control the device through JTAG, DAP, or test modes | Restrict debug access on production devices | JTAG/DFT-related eFUSE control bits |

Three concepts must be distinguished here:

- **AES encryption** addresses confidentiality by preventing an attacker from directly reading the plaintext image;
- **HMAC** provides symmetric integrity checking for encrypted images. The AES and HMAC engines in Zynq-7000 work together during secure decryption;
- **RSA authentication** addresses image origin and public-key trust and is suitable for building a public-key chain of trust from BootROM to subsequent partitions.

If the protection objective is limited to **preventing product cloning and software cracking**, the boot image can be encrypted with AES-256-CBC, and the matching AES key can be programmed into the PL eFUSE of each authorized device. Even if an attacker copies the complete external Flash, the copied image cannot be decrypted and booted on a device without the corresponding key; reading the Flash directly reveals only ciphertext. For this limited scenario, an AES-encrypted image combined with eFUSE programming on authorized devices can satisfy the primary protection requirements, and RSA authentication is not necessarily required.

However, AES primarily addresses image confidentiality and device authorization; it cannot replace the origin authentication provided by a vendor signature. Therefore, it is incorrect to assume that "using AES" completes every secure-boot capability. If a product requires that only vendor-signed images may run, or if it must support secure updates based on a public-key chain of trust, RSA authentication should also be evaluated. AMD documentation lists AES-CBC 256 bit, HMAC-SHA-256, and RSA 2048 bit among the Zynq-7000 secure-boot capabilities. The appropriate choice depends on the product threat model. [UG821: Secure Boot Support](https://docs.amd.com/r/en-US/ug821-zynq-7000-swdev/Secure-Boot-Support)

## 2. Zynq-7000 Security Resources

### 2.1 AES Key: PL eFUSE and BBRAM

The Zynq-7000 AES key is stored on the PL side, using either eFUSE or BBRAM as the key source.

| Key storage | Characteristics | Suitable use cases |
| --- | --- | --- |
| BBRAM | Volatile and requires battery backup; the key can be cleared and rewritten | Development and verification, or devices that require key revocation |
| PL eFUSE | Nonvolatile, one-time programmable, and battery-independent | Production devices after the process has matured |

<p align="center"><a href="./Images/Image_01_AntiClone.png"><img src="./Images/Image_01_AntiClone.png" alt="PL eFUSE and BBRAM are the two on-chip storage locations for the AES key" width="600"></a></p>

The selected key source must match the encryption state in the Boot Image Header. An encrypted image that uses an eFUSE key has a different Header identifier from one that uses a BBRAM key; a mismatch can trigger a security lockdown. [UG585: Boot Image Header](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM/Boot-Image-Header)

An anti-cloning design must also decide between a single key shared by all products and a unique key for each device:

- A shared key simplifies production and distribution of a common image, but if the key is compromised, an entire batch of devices may be affected;
- A unique key per device limits the impact of a single-device key compromise, but requires per-device image generation or a secure personalized manufacturing process.

### 2.2 RSA Root of Trust: PS eFUSE

RSA authentication uses a two-level key hierarchy:

- PPK: Primary Public Key;
- PSK: Primary Secret Key;
- SPK: Secondary Public Key;
- SSK: Secondary Secret Key.

The device stores the SHA-256 hash of the PPK in PS eFUSE, not a private key. The boot image contains the PPK, SPK, SPK signature, and partition signature. Their verification relationship is shown below:

<p align="center"><a href="./Images/Image_03.png"><img src="./Images/Image_03.png" alt="RSA authentication certificate structure" width="900"></a></p>

Labels ①②③ in the figure show how RSA authentication information is generated and placed:

1. **Generate two types of signatures (①):** Use the primary secret key PSK to sign the secondary public key SPK, producing the `SPK Signature`; use the secondary secret key SSK to sign the corresponding partition, producing the `Partition Signature`.
2. **Assemble the partition authentication certificate (②):** The `Authentication Header`, padding area, PPK, SPK, `SPK Signature`, and `Partition Signature` together form the RSA Authentication Certificate for that partition.
3. **Place each certificate with its partition (③):** Every partition that requires authentication, such as the FSBL, Bitstream, and U-Boot, has its own RSA authentication certificate. Bootgen places the certificates in the boot image so that the boot code can authenticate each partition in turn.

At device boot, verification proceeds in the reverse order of certificate generation:

1. BootROM calculates SHA-256 over the PPK in the certificate and compares it with the PPK Hash stored in PS eFUSE, first establishing that the primary public key is trusted;
2. The trusted PPK verifies the `SPK Signature`, establishing that the secondary public key SPK has not been replaced;
3. The SPK verifies the `Partition Signature`, establishing that the corresponding FSBL, Bitstream, U-Boot, or other partition comes from a trusted source and has not been modified.

If any verification level fails, the current partition is not executed as trusted code. Therefore, modifying the PPK, SPK, partition contents, or their signatures breaks the authentication chain.

The primary secret key PSK and secondary secret key SSK must be kept only in a controlled signing environment. They must never be written into a boot image, source repository, or production device. For the complete PPK/SPK structure and authentication-certificate format, see [UG821: Authentication Overview](https://docs.amd.com/r/en-US/ug821-zynq-7000-swdev/Authentication-Overview) and [UG821: Authentication Certificate](https://docs.amd.com/r/en-US/ug821-zynq-7000-swdev/Authentication-Certificate).

### 2.3 Hardware Security Modules

The main hardware resources involved in secure boot include:

- **BootROM:** On-chip read-only boot code responsible for the earliest boot operations and security-state decisions;
- **OCM:** On-chip memory into which BootROM loads the FSBL for execution;
- **AES Decryptor:** The AES-256 decryption engine in the PL;
- **HMAC Engine:** The SHA-256-based message-authentication engine;
- **PL eFUSE/BBRAM:** Stores the AES key;
- **PS eFUSE:** Stores the PPK Hash and RSA-, DFT-, and other security-control bits;
- **NVM Controller:** Accesses boot media such as QSPI, NAND, NOR, and SD.

The primary secure-boot process of Zynq-7000 uses the AES/HMAC hard blocks in the PL, so the PL must be powered during decryption. [UG585: Master Secure Boot](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM/Master-Secure-Boot)

<p align="center"><a href="./Images/Image_01.png"><img src="./Images/Image_01.png" alt="Zynq-7000 hardware related to secure boot" width="600"></a></p>

## 3. Encryption, Authentication, and Image Structure

### 3.1 AES/HMAC Processing Order

On the Bootgen side, an HMAC is generated for a software partition before AES encryption. On the device side, processing occurs in the opposite direction: RSA authentication is performed first (if enabled), followed by AES decryption and then HMAC verification. AES encrypts the partition data, HMAC signature, and HMAC key together. [XAPP1175: Secure Boot of Zynq-7000 SoC](https://docs.amd.com/v/u/en-US/xapp1175_zynq_secure_boot)

<p align="center"><a href="./Images/Image_02.png"><img src="./Images/Image_02.png" alt="Relationship among AES, HMAC, and RSA in a secure boot image" width="900"></a></p>

Labels ①②③ in the figure show the layered encapsulation of a software partition from raw data to an AES-encrypted image:

1. **Generate the HMAC signature (①):** Bootgen uses the HMAC key to process the FSBL, Bitstream, U-Boot, or another protected partition and generates the corresponding `HMAC Signature`.
2. **Form the HMAC Authenticated Image (②):** The original partition data and `HMAC Signature` are combined to form an HMAC-authenticated image containing integrity information.
3. **Form the AES Encrypted Image (③):** The entire HMAC-authenticated image is encrypted with the AES key, producing the AES-encrypted image that is written to external Flash. Only ciphertext can be read externally; the original partition contents cannot be obtained directly.

Image generation and chip boot proceed in opposite directions:

- **During image generation:** partition data → generate HMAC signature → assemble HMAC-authenticated image → AES encryption → write to Flash;
- **During device boot:** read ciphertext from Flash → decrypt with the AES key in PL eFUSE or BBRAM → verify HMAC → load and execute the partition after successful verification.

AES therefore conceals the partition contents, while HMAC verifies the integrity of the decrypted data. They work together in the Zynq-7000 encrypted-boot process.

### 3.2 Which Partitions Need Protection

A typical Zynq system may contain:

1. FSBL;
2. PL Bitstream;
3. U-Boot or a bare-metal application;
4. Linux Kernel, Device Tree, and RootFS;
5. Applications and configuration data.

<p align="center"><a href="./Images/Image_02_RSA_AES.png"><img src="./Images/Image_02_RSA_AES.png" alt="Locations of AES/HMAC encryption and RSA certificates in the boot image" width="900"></a></p>

This figure shows how the two security mechanisms are combined in BOOT.bin:

- The main contents of the FSBL, Bitstream, and U-Boot reside in the `Encrypted ... (AES + HMAC)` regions. AES conceals the original partition contents, while HMAC verifies the integrity of the decrypted data;
- Every partition requiring RSA authentication has an independent `RSA Authentication Certificate`, which verifies that the partition comes from a trusted signer and that its contents have not been modified;
- AES/HMAC and RSA provide two different protection layers: the former focuses on image confidentiality and symmetric integrity checking, while the latter focuses on public-key origin authentication. A project can use only AES/HMAC according to its threat model, or combine both mechanisms.

The arrangement in the figure also shows that security properties are configured per partition. The FSBL, Bitstream, and U-Boot can each independently select whether to use encryption and whether to use RSA authentication; the entire BOOT.bin is not restricted to one uniform policy.

To protect a component later in the chain, the loaders before it must also be trusted. If only the application is signed while an unauthenticated U-Boot loads it, an attacker may still replace U-Boot to bypass the check.

<p align="center"><a href="./Images/Image_05.png"><img src="./Images/Image_05.png" alt="Partition policy for the strictest protection scenario" width="900"></a></p>

The table above corresponds to the highest-protection scenario in which all partitions are authenticated and encrypted (Use Case 6):

- **FSBL:** The on-chip BootROM performs the initial RSA authentication and also decrypts and checks the partition using AES/HMAC;
- **Bitstream, U-Boot, Linux Kernel, Device Tree, Ramdisk, and applications:** Trusted boot code from the preceding stage continues RSA authentication and performs AES/HMAC decryption and integrity checking;
- An `x` in the table means that the corresponding capability is enabled for that partition. Only the FSBL appears in the `BootROM RSA` column because BootROM directly establishes the first software trust point in secure boot; subsequent partitions continue verification along the trusted boot chain.

This is an example of the strictest configuration and is not mandatory for every product. If the goal is only to prevent product cloning and offline software cracking, AES/HMAC can be enabled only for the partitions that require protection, with the matching AES key programmed into the PL eFUSE of authorized devices. RSA authentication is additionally required only when the origin of a vendor-signed image must be verified.

<p align="center"><a href="./Images/Image_06.png"><img src="./Images/Image_06.png" alt="Secure-boot chain of trust" width="900"></a></p>

Each arrow represents a transfer of trust. A security policy does not necessarily require every partition to be encrypted, but the code responsible for loading and verifying subsequent components must be part of the trusted chain.

## 4. Secure-Boot Process

Zynq-7000 secure boot can be divided into three stages according to responsibility.

<p align="center"><a href="./Images/Image_07.png"><img src="./Images/Image_07.png" alt="Overview of Zynq-7000 boot stages" width="600"></a></p>

<p align="center"><a href="./Images/Image_08.png"><img src="./Images/Image_08.png" alt="Zynq-7000 secure-boot block diagram" width="600"></a></p>

### 4.1 Stage 0: BootROM

1. Execute the on-chip BootROM after power-up;
2. BootROM reads the Boot Header from a boot device such as QSPI or SD;
3. Load the FSBL into OCM;
4. If RSA is enabled, verify the FSBL authentication certificate against the PPK Hash in PS eFUSE;
5. If the FSBL is encrypted, invoke the PL-side AES/HMAC engine to complete decryption and integrity checking;
6. Jump to the FSBL after successful verification.

### 4.2 Stage 1: FSBL

The FSBL processes the Bitstream, U-Boot, or a bare-metal application according to each partition's attributes:

- Verify the authentication certificate for partitions requiring RSA authentication;
- Decrypt and perform HMAC verification for partitions requiring AES encryption;
- Configure the Bitstream into the PL;
- Load software partitions into OCM or DDR;
- Transfer control to the next stage.

Bootgen generates the Boot Header, partition table, and partition data according to the BIF description. Encryption and authentication attributes can be configured independently for each partition. [UG821: Boot Image Creation](https://docs.amd.com/r/en-US/ug821-zynq-7000-swdev/Boot-Image-Creation)

### 4.3 Stage 2: U-Boot, Operating System, and Applications

Starting with U-Boot, subsequent images are normally verified by software. Whether Linux applications, update packages, and configuration files continue to be verified depends on the system's own boot scripts, key management, and update protocol.

Secure boot guarantees only that "verified code executes beginning from a trusted root"; it does not automatically eliminate runtime vulnerabilities. A product still requires robust exception recovery, runtime monitoring, and log auditing.

## 5. Vivado/SDK 2018.3 Hands-On Procedure

### 5.1 Demonstration Scheme and Environment

The main hands-on procedure in this section enables only AES/HMAC encryption and does not enable RSA in the image-generation interface. It corresponds to the product-cloning and offline-software-cracking scenario described earlier. If vendor-signature origin authentication is also required, RSA configuration can be added to the same process. Several FSBL compilation macros and boot logs in the original material came from a combined AES+RSA verification setup. This article explicitly marks them as optional rather than mixing them into the mandatory AES-only steps.

The verification environment is as follows:

- Vivado/SDK 2018.3;
- XC7Z020CLG400-2;
- Windows 10;
- QSPI boot media;
- The FSBL, Bitstream, and bare-metal application are encrypted.

The following procedure is organized as "prepare the FSBL → generate the encrypted image → program PL eFUSE → write to QSPI → verify after a power cycle." Each operation is immediately followed by its corresponding screenshot and completion criterion. The interfaces shown are from an older SDK. For mass production, use the actual device and tool versions together with current AMD documentation.

### 5.2 Step 1: Prepare the FSBL

#### 5.2.1 Export and Import the Hardware Platform

**Step 1: Export the hardware description file from Vivado.**

<p align="center"><a href="./Images/Image_09.png"><img src="./Images/Image_09.png" alt="system_wrapper.hdf exported from Vivado" width="600"></a></p>

`system_wrapper.hdf` is the hardware description file exported by Vivado 2018.3. It contains the PS configuration, peripherals, address map, and other information. The SDK uses this file to create the hardware platform so that the generated FSBL matches the current hardware design.

**Step 2: Import the hardware platform into the SDK.**

<p align="center"><a href="./Images/Image_10.png"><img src="./Images/Image_10.png" alt="Hardware platform imported into the SDK"></a></p>

After importing the HDF into the SDK, the corresponding Hardware Platform is created. Select this platform when creating the FSBL to avoid using the hardware configuration from another project or an older version.

#### 5.2.2 Create the FSBL and BSP

**Step 3: Create a new Application Project.**

<p align="center"><a href="./Images/Image_11.png"><img src="./Images/Image_11.png" alt="Creating a new Application Project" width="760"></a></p>

As highlighted in red, select **File → New → Application Project** from the SDK menu to begin creating the FSBL application project.

**Step 4: Configure the FSBL project and BSP.**

<p align="center"><a href="./Images/Image_12.png"><img src="./Images/Image_12.png" alt="Application Project configuration" width="600"></a></p>

Set the project name to `FSBL`, select `standalone` as the operating-system platform, and select `ps7_cortexa9_0` as the processor. Also select **Create New** to create the accompanying `FSBL_bsp` board support package, then click **Finish**.

**Step 5: Select the Zynq FSBL template.**

<p align="center"><a href="./Images/Image_13.png"><img src="./Images/Image_13.png" alt="Selecting the Zynq FSBL template" width="600"></a></p>

Select **Zynq FSBL** from the template list. The SDK then generates a first-stage boot loader for Zynq-7000 rather than an ordinary empty bare-metal project.

**Completion check: Confirm that the FSBL and BSP have been generated.**

<p align="center"><a href="./Images/Image_14.png"><img src="./Images/Image_14.png" alt="Generated FSBL and BSP projects"></a></p>

After creation, both the FSBL application project and its BSP should appear in Project Explorer. The former contains the boot-flow source code, while the latter provides device drivers, libraries, and hardware parameters.

#### 5.2.3 Configure FSBL Compilation Macros

**Step 6: Open the FSBL project properties.**

<p align="center"><a href="./Images/Image_15.png"><img src="./Images/Image_15.png" alt="Opening the FSBL project properties" width="760"></a></p>

Right-click the FSBL project and select **Properties** to open the compilation-options page. In the next step, configure the debug macros on the compiler's Symbols page. The RSA support macro is required only when RSA is enabled.

The original project used the following debug- and RSA-related macros:

```text
DEBUG
FSBL_DEBUG_GENERAL
FSBL_DEBUG_INFO
RSA_SUPPORT
```

<p align="center"><a href="./Images/Image_16.png"><img src="./Images/Image_16.png" alt="FSBL compiler-symbol configuration" width="760"></a></p>

The `DEBUG`, `FSBL_DEBUG_GENERAL`, and `FSBL_DEBUG_INFO` entries highlighted in red enable different levels of boot logging. `RSA_SUPPORT` compiles RSA-authentication support into the FSBL. If the project uses only AES/HMAC encryption and does not enable RSA, `RSA_SUPPORT` can be omitted.

Macro names and enablement methods depend on the specific SDK version. Check the FSBL documentation again after upgrading the tools.

### 5.3 Step 2: Generate an AES-Encrypted Image

This section uses only the SDK **Create Boot Image** graphical interface. It configures the output location, AES encryption, the eFUSE key source, and the boot partitions in sequence, then generates the encrypted `BOOT.bin` and corresponding `.nky` file.

**Step 1: Open Create Boot Image.**

<p align="center"><a href="./Images/Image_17.png"><img src="./Images/Image_17.png" alt="Opening Create Boot Image in the SDK"></a></p>

Select **Xilinx → Create Boot Image** from the SDK menu to open Bootgen's graphical configuration interface. The interface ultimately generates a BIF and invokes Bootgen to assemble the boot image.

**Step 2: Configure the output paths.**

<p align="center"><a href="./Images/Image_18.png"><img src="./Images/Image_18.png" alt="Selecting the BIF configuration and BOOT.bin output locations" width="600"></a></p>

On the **Basic** page, confirm that Architecture is `Zynq`, then configure the output paths for the BIF file and final `BOOT.bin`. The partition list is empty at this point. Add the FSBL, Bitstream, and application later in boot order.

**Step 3: Enable Encryption.**

<p align="center"><a href="./Images/Image_19.png"><img src="./Images/Image_19.png" alt="Enabling image encryption" width="600"></a></p>

Switch to **Security → Encryption** and select **Use Encryption**. After it is enabled, the interface makes the AES key file, device model, Key store, and other security options available.

**Step 4A: Import an existing key file when an NKY is available.**

<p align="center"><a href="./Images/Image_19_KeyFile.png"><img src="./Images/Image_19_KeyFile.png" alt="Importing an existing AES key file and selecting the eFUSE key source" width="600"></a></p>

If a `.nky` file already exists, select it under **Key file** and set **Key store** to `EFUSE`. The AES key used to generate the image must match the key programmed in the target device's PL eFUSE.

**Step 4B: Have Bootgen generate an NKY when none exists.**

<p align="center"><a href="./Images/Image_20.png"><img src="./Images/Image_20.png" alt="Selecting the eFUSE key source and configuring the device model" width="600"></a></p>

If no `.nky` file exists, leave **Key file** empty, enter the exact device model, and select `EFUSE`. Bootgen generates a new key file when the image is created. The device model must match the actual Zynq device.

**Step 5: Add and configure the boot partitions.**

<p align="center"><a href="./Images/Image_22.png"><img src="./Images/Image_22.png" alt="Adding partitions to the boot image" width="600"></a></p>

Click **Add** on the right to add a boot partition. Set the FSBL Partition type to `bootloader` and select `aes` under Encryption. Then add the Bitstream and application in the same way.

**Step 6: Check partition order and create the image.**

<p align="center"><a href="./Images/Image_23.png"><img src="./Images/Image_23.png" alt="Enabling encryption for the FSBL, Bitstream, and application partitions" width="600"></a></p>

The `Encrypted` column in the partition list should show `aes` for all three partitions, with the FSBL in the first position. After checking file paths, partition order, and security attributes, click **Create Image**.

**Step 7: Check the output files.**

<p align="center"><a href="./Images/Image_24.png"><img src="./Images/Image_24.png" alt="Generated BOOT.bin, BIF, and NKY files" width="600"></a></p>

After generation, the output directory contains the boot image, BIF configuration, and `.nky` key file. `BOOT.bin` is written to the boot medium, the BIF records the image composition, and the NKY stores the parameters required for this encryption operation.

**Check the NKY: Confirm that its key parameters correspond to this BOOT.bin.**

<p align="center"><a href="./Images/Image_25.png"><img src="./Images/Image_25.png" alt="AES, StartCBC, and HMAC fields in the original project NKY file" width="760"></a></p>

`Key 0` in the NKY is the AES-256 key, `StartCBC` is the initialization value used by CBC mode, and the `HMAC` field is used to generate the partition's HMAC signature. Together, these parameters correspond to the currently generated `BOOT.bin`.

### 5.4 Step 3: Program PL eFUSE

There are two common methods for programming PL eFUSE. During development, it can be programmed directly through Vivado Hardware Manager. In production, a standalone programming image can be built from the XilSKey example. Both methods target the same resource but suit different usage scenarios.

#### 5.4.1 Method A: Direct Programming with Hardware Manager (Development and Debugging)

**Step 1: Connect through JTAG and select the target device.**

<p align="center"><a href="./Images/Image_26.png"><img src="./Images/Image_26.png" alt="Connecting to the Zynq device in JTAG mode" width="480"></a></p>

Connect to the target board through JTAG in Hardware Manager. The device tree should identify `arm_dap_0` and the target Zynq device. The red box in the figure marks the `xc7z020_1` used in this procedure.

**Step 2: Open the eFUSE programming wizard.**

<p align="center"><a href="./Images/Image_27.png"><img src="./Images/Image_27.png" alt="Opening Program eFUSE Registers" width="760"></a></p>

Open **Hardware Manager**, right-click the target Zynq device, and select **Program eFUSE Registers**. This entry directly configures the device's one-time eFUSE resources.

**Step 3: Load the NKY that matches BOOT.bin.**

<p align="center"><a href="./Images/Image_28.png"><img src="./Images/Image_28.png" alt="Selecting the AES key file" width="760"></a></p>

Select **Enable AES key programming**. For the generated `BOOT.bin`, choose the matching `.nky` file. The tool parses and displays the AES Key. This page also notes that programming the AES Key affects certain USER bits. Before proceeding, verify that fields such as `USER[7:0]` conform to the product definition.

**Step 4: Select the control bits to be programmed permanently.**

<p align="center"><a href="./Images/Image_29.png"><img src="./Images/Image_29.png" alt="Configuring the eFUSE control register" width="760"></a></p>

After selecting **Enable control register programming**, choose control bits according to product requirements. The `R_EN_B_Key`, `R_EN_B_User`, and `BBRAM_Key_Disable` options selected in the figure respectively disable AES Key readback, disable User Code readback, and require secure boot to use the eFUSE Key.

**Step 5: Perform programming and check the console.**

<p align="center"><a href="./Images/Image_30.png"><img src="./Images/Image_30.png" alt="Console output after eFUSE programming" width="900"></a></p>

After programming finishes, `Device eFUSE successfully programmed` in the Tcl Console indicates that the tool has completed programming. The console also warns that an encrypted Bitstream should be loaded through a non-JTAG secure-boot path. The state should then be read again, and boot should be verified with the matching encrypted image. This log line alone is not a final acceptance criterion.

#### 5.4.2 Method B: Standalone XilSKey Programming Image (Production Process)

The `xilskey` library in the older SDK provides eFUSE programming examples. The original project emulated the internal JTAG chain through MIO so that the device could boot the programming application from SD, QSPI, or another medium without manual Hardware Manager operation. The example connections are shown below:

| MIO | JTAG signal |
| ---: | --- |
| 51 | TDI |
| 49 | TDO |
| 50 | TCK |
| 46 | TMS |

This mapping applies only to the corresponding board and schematic and must not be copied directly to other hardware. The selected MIO pins must also avoid pins with special boot-time functions.

**Step 1: Add the XilSKey library to the BSP.**

<p align="center"><a href="./Images/Image_31.png"><img src="./Images/Image_31.png" alt="Adding the XilSKey library to the BSP" width="900"></a></p>

Select `xilskey` under Supported Libraries in BSP Settings so that the eFUSE programming application can call the interfaces and low-level JTAG programming logic provided by XilSKey.

**Step 2: Import the eFUSE example project.**

<p align="center"><a href="./Images/Image_32.png"><img src="./Images/Image_32.png" alt="Importing the eFUSE programming example project" width="900"></a></p>

Click **Import Examples** in `system.mss`, select `xilskey_efuse_example`, and import it. The SDK generates the example source and the `xilskey_input.h` configuration file. Most subsequent changes are made in that header file.

**Step 3: Configure `xilskey_input.h`.**

The following code block lists the control items used in this example:

```c
#define XSK_EFUSEPL_DRIVER
/* #define XSK_EFUSEPS_DRIVER */

#define XSK_EFUSEPL_PROGRAM_AES_AND_USER_LOW_KEY  TRUE
#define XSK_EFUSEPL_DISABLE_AES_KEY_READ           TRUE
#define XSK_EFUSEPL_DISABLE_USER_KEY_READ          TRUE
#define XSK_EFUSEPL_BBRAM_KEY_DISABLE              TRUE
```

**Configuration 1: Select the PL eFUSE driver.**

<p align="center"><a href="./Images/Image_33.png"><img src="./Images/Image_33.png" alt="Enabling the PL eFUSE driver"></a></p>

Defining `XSK_EFUSEPL_DRIVER` means that this example operates on PL eFUSE. If PS eFUSE does not need to be programmed, leave `XSK_EFUSEPS_DRIVER` disabled.

**Configuration 2: Enter the AES Key that matches the NKY.**

<p align="center"><a href="./Images/Image_34.png"><img src="./Images/Image_34.png" alt="AES value assigned to XSK_EFUSEPL_AES_KEY in the original project" width="900"></a></p>

Enter the AES Key used to generate the encrypted `BOOT.bin` in `XSK_EFUSEPL_AES_KEY`. It must exactly match `Key 0` in the NKY; otherwise, the device cannot decrypt the image correctly.

**Configuration 3: Enable AES Key programming.**

<p align="center"><a href="./Images/Image_35.png"><img src="./Images/Image_35.png" alt="Enabling AES and User Low Key programming" width="760"></a></p>

Set `XSK_EFUSEPL_PROGRAM_AES_AND_USER_LOW_KEY` to `TRUE`; otherwise, the example application does not execute the AES Key and User Low Key programming flow.

**Configuration 4: Configure read protection according to product requirements.**

<p align="center"><a href="./Images/Image_36.png"><img src="./Images/Image_36.png" alt="Disabling AES Key readback" width="760"></a></p>

Setting `XSK_EFUSEPL_DISABLE_AES_KEY_READ` to `TRUE` also sets the corresponding AES Key read-protection control bit, preventing software from reading the key directly afterward.

<p align="center"><a href="./Images/Image_37.png"><img src="./Images/Image_37.png" alt="Disabling User Key readback" width="760"></a></p>

Setting `XSK_EFUSEPL_DISABLE_USER_KEY_READ` to `TRUE` disables User Key/User Code readback. Whether it should be enabled depends on whether the product uses this area.

**Configuration 5: Select the key source used for secure boot.**

<p align="center"><a href="./Images/Image_38.png"><img src="./Images/Image_38.png" alt="Disabling use of the BBRAM Key during secure boot" width="760"></a></p>

Setting `XSK_EFUSEPL_BBRAM_KEY_DISABLE` to `TRUE` specifies that secure boot uses the eFUSE Key and no longer permits the BBRAM Key.

**Configuration 6: Enter the MIO/JTAG mapping according to the schematic.**

<p align="center"><a href="./Images/Image_39.png"><img src="./Images/Image_39.png" alt="Configuring the MIO-to-JTAG signal mapping" width="600"></a></p>

Enter the MIO numbers corresponding to `TDI`, `TDO`, `TCK`, and `TMS` according to the board schematic. The values 51, 49, 50, and 46 in the figure apply only to the original verification board; the connections must be checked again when porting the design.

**Step 4: Generate and deploy the eFUSE programming image.**

<p align="center"><a href="./Images/Image_40.png"><img src="./Images/Image_40.png" alt="Creating an eFUSE programming image with Bootgen" width="760"></a></p>

Add the FSBL, Bitstream, and XilSKey eFUSE example application to a separate boot image, then use Bootgen to generate `eFUSE_BOOT.bin`, which is dedicated to key programming. This image boots the programming application; it is not the final product firmware.

<p align="center"><a href="./Images/Image_41.png"><img src="./Images/Image_41.png" alt="Generated eFUSE programming files" width="600"></a></p>

`eFUSE_BOOT.bin` in the output directory is the programming image that can be written to SD, QSPI, or another boot medium. The adjacent BIF file records its partition composition for review and repeatable builds.

**Step 5: Boot the programming application and check the status.**

<p align="center"><a href="./Images/Image_42.png"><img src="./Images/Image_42.png" alt="eFUSE status and the original project AES Key in the serial output" width="760"></a></p>

After booting, the programming application reports PL eFUSE status over the serial port, including key-write, read-control, Secure Boot, JTAG, and BBRAM Key states. The state shown is `AES Key read enabled`, so the complete AES Key programmed for this demonstration is still displayed. If the AES Key read-protection bit is programmed later, verification should rely on the state bits and successful boot of a matching image rather than key readback.

These macro and bit definitions can change with the BSP version. The programming application must be reviewed against the current `xilskey` headers, device errata, and official guides rather than being operated solely from screenshots of an older project.

### 5.5 Step 4: Write BOOT.bin to QSPI

**Step 1: Open Program Flash Memory and configure the programming parameters.**

<p align="center"><a href="./Images/Image_43.png"><img src="./Images/Image_43.png" alt="Writing BOOT.bin to QSPI through the SDK" width="600"></a></p>

In **Program Flash Memory**, select the final `BOOT.bin`, specify the FSBL that matches the hardware platform, and select the QSPI type according to the board's Flash connection. Click **Program** to write the image to the boot Flash.

After programming, set the boot mode to QSPI. Do not load the encrypted Bitstream directly over JTAG at this point. In the next step, use a complete power cycle to verify the boot chain formed by BootROM, the FSBL, and PL eFUSE.

### 5.6 Step 5: Power-Cycle and Verify Secure Boot

**Step 1: Remove power completely, power the system on again, and observe the FSBL log.**

<p align="center"><a href="./Images/Image_44_46_Annotated.png"><img src="./Images/Image_44_46_Annotated.png" alt="Secure-boot log showing Encrypted for both Bitstream and Application" width="900"></a></p>

After power-up, the FSBL log should report the correct QSPI boot mode and partition count. `Bitstream Encrypted` and `Application Encrypted`, highlighted by the red boxes, show that these partitions entered the decryption and loading path with the encryption attribute. If RSA is also enabled, authentication results such as `RSA Signed` and `Authentication Done` appear as well. The log is an observation of the process; negative tests with an incorrect key and a tampered image are still required to confirm that the protection is effective.

**Step 2: Complete positive and negative verification.**

- The correct `BOOT.bin` should load the FSBL, Bitstream, and application successfully;
- An image generated with an incorrect AES Key should fail to boot normally;
- After the encrypted image is modified, HMAC verification should fail;
- Another Zynq device without the matching eFUSE Key should not run the encrypted image.

The completion criterion is not merely observing `Encrypted` once. The correct image must boot, while an incorrect key, a modified image, and an unauthorized device must all fail verification.

### 5.7 Supplement: Multiboot Image Address Constraints

For Multiboot, XAPP1175 requires the addresses of the update image and golden image to be integer multiples of 32 KB. This requirement must not be generalized into a rule that "all authenticated QSPI images must be placed at a fixed 32 KB offset." Image placement should be designed for the specific boot mode, BIF, and official documentation.

<p align="center"><a href="./Images/Image_04.png"><img src="./Images/Image_04.png" alt="Original description of the QSPI 32 KB address requirement" width="900"></a></p>

The figure describes the address-alignment requirement for the update image and golden image in a Multiboot scenario. Image addresses need to be planned at integer multiples of 32 KB only when using the corresponding Multiboot layout. The offset rule cannot be applied directly to an ordinary single-image boot.

## 6. Risks of eFUSE Control Bits

Some Zynq-7000 eFUSE control bits have permanent effects:

- **eFUSE Secure Boot / Force Use AES Only:** Forces the device to use the eFUSE AES key for secure boot;
- **BBRAM Key Disable:** Prohibits use of the BBRAM key during secure boot;
- **JTAG Chain Disable:** Permanently disables the Arm DAP and PL TAP;
- **RSA Authentication Enable:** Enables the RSA-authenticated boot process;
- **DFT Mode/JTAG Disable:** Permanently disables the related test capabilities.

According to UG585, once certain JTAG, DFT, or forced-secure-boot bits are programmed, AMD's RMA test capability can be affected. Refer to [UG585: PL eFUSE Settings](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM/PL-eFUSE-Settings) and [UG585: PS eFUSE Settings](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM/PS-eFUSE-Settings) for the exact behavior and interaction of the control bits.

The recommended production order is: verify normal boot → verify the secure image → program the AES Key/PPK Hash → verify secure boot again → program read-protection and forced-security bits → finally evaluate and disable JTAG/DFT → archive the device record, keys, and image hashes.

Placing irreversible control bits at the end of the process reduces the risk that key, image, or board-level power problems disable an entire batch of devices.

## 7. Production Security Checklist

### Build Environment

- [ ] Private keys and AES/HMAC keys are not committed to the source repository;
- [ ] The signing workstation is isolated from the ordinary development environment;
- [ ] The BIF, Bootgen version, BOOT.bin hash, and public certificates are archived for every release;
- [ ] Build logs do not print keys or the complete contents of `.nky` files;
- [ ] At least two people review the production key file and device model.

### Device Programming

- [ ] Device power, voltage, temperature, and JTAG/MIO connections meet programming requirements;
- [ ] The complete process has been exercised once on a dedicated sample device;
- [ ] Keys are programmed first, boot is verified next, and restrictive control bits are programmed last;
- [ ] Readable status bits are read and recorded after programming;
- [ ] Positive and negative tests use correct, incorrect, and tampered images.

### Product Lifecycle

- [ ] A response plan is defined for key compromise;
- [ ] Secure update, power-loss recovery, and Golden Image strategies are defined;
- [ ] A fault-diagnosis method is defined for after JTAG has been permanently disabled;
- [ ] The impact of a compromised shared key on the entire device population is evaluated.

## 8. Security Boundaries

Zynq-7000 secure boot can substantially increase the difficulty of image copying, offline reverse engineering, and malicious replacement, but it is not a complete product-security system. The following issues still require system-level design:

- Runtime vulnerabilities in Linux, U-Boot, and applications;
- Security of network update services and operations accounts;
- Leakage of private keys or AES keys from the build environment;
- Side-channel attacks, fault injection, and high-cost physical attacks;
- Recovery and auditing after a boot failure.

A truly robust design considers device secure boot, signing infrastructure, production programming, update protocols, and software-vulnerability management within the same trust model.

## 9. References

- [UG585 — Zynq-7000 SoC Technical Reference Manual](https://docs.amd.com/r/en-US/ug585-zynq-7000-SoC-TRM/Device-Secure-Boot)
- [UG821 — Zynq-7000 SoC Software Developers Guide](https://docs.amd.com/r/en-US/ug821-zynq-7000-swdev/Boot-and-Configuration)
- [XAPP1175 — Secure Boot of Zynq-7000 SoC](https://docs.amd.com/v/u/en-US/xapp1175_zynq_secure_boot)
