# Jetson Linux R36.4.4：源码开放边界与 Orin 自定义 BSP / Carrier Board Bring-up

本文回答两个问题：Jetson Linux R36.4.4 的哪些部分真正开源、哪些部分只是源码可见或仅提供二进制；以及使用 OE4T `meta-tegra` 为 Jetson Orin 模组定制载板 BSP 时，实际需要改什么。

## 结论先行

Jetson Linux 不是一套完全开源的 BSP，而是“可重建的开源基础 + NVIDIA 专有二进制”的组合：

- Linux 5.15 内核、公开设备树、NVIDIA 树外内核模块和显示内核模块有源码，适合做驱动、设备树和内核定制。
- UEFI 的主体源码开放，但完整 Jetson UEFI 镜像还会链接 `non-osi` 仓库中的预编译 EFI 驱动，因此完整启动固件不是纯开源产物。
- BootROM/PSCROM 固化在芯片中；MB1、MB2、BPMP、XUSB、PVA/DLA 等早期启动或协处理器固件，以及 CUDA/GPU、Argus 相机、多媒体等关键用户态实现，仍依赖 NVIDIA 二进制。
- 官方公开的 bring-up 流程针对“Jetson SOM + 自定义 carrier board”。如果“基于 SoC”是指直接采购裸 T234、自己设计 SOM/内存子系统，那么这已经超出公开 Jetson carrier-board BSP 流程，需要 NVIDIA 的商务/技术支持、受限设计资料和相应授权，不能只靠公开的 Jetson Linux 与 `meta-tegra` 完成。

NVIDIA 对 R36.4.4 的官方定义也体现了这种组合：BSP 包含 Linux Kernel、UEFI、NVIDIA drivers、刷写工具和 Ubuntu 22.04 rootfs；它同时单独提供 Driver Package、Public Sources 和专有 Software License Agreement。[Jetson Linux R36.4.4 下载页](https://developer.nvidia.com/embedded/jetson-linux-r3644)

## 如何理解下面的分类

- **开源**：源码在 OSI/FSF 常见开源许可证下提供，可以在许可证条件内修改、重建和分发。
- **源码可得但非完全开源**：能够下载源码或部分源码，但整体受 NVIDIA 专有条款约束，或者构建时仍混入专有二进制。
- **二进制依赖**：官方 BSP 提供可执行镜像、固件或库，但公开 source manifest 中没有对应完整源码。对这类组件的定制通常只能通过 BCT、DT、配置文件或 NVIDIA 定义的接口完成。

“能够下载源代码”不自动等于“开源”。R36.4.4 的 NVIDIA Driver License 允许修改 NVIDIA 以 source format 交付的部分，但对 binary form 明确禁止反向工程、反编译、反汇编和修改；二进制再分发还要求保持不修改，并随附该协议。[NVIDIA Driver License Agreement](https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v4.4/release/tegra_software_license_agreement-tegra-linux.txt)

## 组件开放情况

| 组件 | 分类 | 能否自行修改/重建 | 依据与实际影响 |
|---|---|---|---|
| Linux 5.15.148 内核 | 开源，GPL-2.0 | 可以 | NVIDIA 文档提供 Git 同步和 `kernel_src.tbz2`；R36.4.4 内核定制文档明确支持重建。[Kernel Customization](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/Kernel/KernelCustomization.html#obtaining-the-kernel-sources)；当前 OE4T 配方也声明 GPL-2.0，并固定到 OE4T 的 5.15.148 分支。[OE4T kernel recipe](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/recipes-kernel/linux/linux-jammy-nvidia-tegra_5.15.bb) |
| T234 公开 kernel DTS、板级 DTS | 开源/可编辑源码 | 可以，是载板 bring-up 的核心 | NVIDIA 的 source manifest 包含 `t23x-public-dts` 和 `tegra-public-dts`；官方 bring-up 文档要求为非参考载板移植 Linux kernel device tree。[Working With Sources](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/WorkingWithSources.html)；[Orin NX/Nano DT porting](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonOrinNxNanoSeries.html#porting-the-linux-kernel-device-tree) |
| NVIDIA OOT 内核模块、`nvgpu`、以太网 RM、显示内核驱动 | 开源源码组合，GPL/BSD/MIT | 可以重建和打补丁 | 官方列出 `linux-nv-oot`、`linux-nvgpu`、`nvethernetrm` 和 display-driver source；OE4T 将其许可证建模为 GPL-2.0/BSD-3-Clause/MIT。[Working With Sources](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/WorkingWithSources.html)；[OE4T OOT recipe](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/recipes-kernel/nvidia-kernel-oot/nvidia-kernel-oot.inc) |
| UEFI：EDK2、EDK2 Platforms、`edk2-nvidia` | 主体开源，BSD-2-Clause-Patent | 可以修改和重建主体 | NVIDIA 文档明确给出 UEFI source/build 入口；`edk2-nvidia` 的许可证是 BSD-2-Clause-Patent。[UEFI Adaptation](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/Bootloader/UEFI.html#sources-and-compilation)；[`edk2-nvidia` license](https://github.com/NVIDIA/edk2-nvidia/blob/r36.4.4-updates/LICENSE) |
| 完整 Jetson UEFI 镜像 | 混合：开源主体 + 专有预编译模块 | 可重建，但不是完全开源 | R36.4.4 构建同时拉取 `edk2-nvidia-non-osi` 和 `edk2-non-osi`；前者包含预编译 GOP/虚拟化 EFI 驱动及 NVIDIA proprietary notice。OE4T 因而把完整配方声明为 `BSD-2-Clause-Patent & Proprietary`。[OE4T UEFI recipe](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/recipes-bsp/uefi/edk2-firmware-tegra-36.4.4.inc)；[`edk2-nvidia-non-osi`](https://github.com/NVIDIA/edk2-nvidia-non-osi/tree/r36.4.4-updates) |
| ARM Trusted Firmware | 开源，BSD-3-Clause | 可以重建 | R36.4.4 public sources 中提供 `atf_src.tbz2`；OE4T 从该归档构建并声明 BSD-3-Clause。[Working With Sources](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/WorkingWithSources.html)；[OE4T ATF recipe](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/recipes-bsp/arm-trusted-firmware/arm-trusted-firmware_2.8-l4t-r36.4.4.bb) |
| OP-TEE | 混合 | 大部分可重建，但 NVIDIA 平台部分不能视为纯开源 | 官方提供 `nvidia-jetson-optee-source.tbz2`；OE4T 对 OP-TEE OS 的整体许可证建模为 `BSD-2-Clause & Proprietary`，client/test/sample 则分别按 BSD/GPL 构建。[Working With Sources](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/WorkingWithSources.html)；[OE4T OP-TEE recipe](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/recipes-security/optee/optee-os-l4t.inc) |
| MB1 | 仅二进制、NVIDIA 所有 | 不能替换；只能通过 MB1-BCT 配置 | NVIDIA 明确说明 MB1 用 NVIDIA 自有密钥签名和加密，由 NVIDIA 以 binary 提供；平台通过 MB1-BCT 配置 pinmux、GPIO、pad voltage、SDRAM、PMIC、carveout 等。[Orin Boot Flow — MB1](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/AR/BootArchitecture/JetsonOrinSeriesBootFlow.html#mb1) |
| BootROM、PSCROM | 芯片内固化实现 | 不能替换 | BootROM hard-wired in SoC，PSCROM 是芯片内硬件组件并持有认证/解密所需密钥。[Orin Boot Flow — BootROM/PSCROM](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/AR/BootArchitecture/JetsonOrinSeriesBootFlow.html#bootrom) |
| MB2 / MB2 applet | 实际按二进制依赖处理 | 不能按公开源码重建；通过 MB2-BCT 和刷写参数适配 | 官方 package manifest 将 `mb2_t234.bin`、`mb2rf_t234.bin` 明确列为 MB2 binaries；R36.4.4 的公开 source list 未列出 MB2 源码。[Package Manifest](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/RM/PackageManifest.html#bootloader)；[Working With Sources](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/WorkingWithSources.html) |
| BPMP、XUSB、PVA/DLA、DCE、摄像头 RTCPU、GPU 等固件 | 主要为专有二进制 | 一般不能修改；选择匹配 SKU 的 NVIDIA 固件和可编辑 DT/BCT | 官方 manifest 列出 `bpmp_t234-*.bin`、`xusb_t234_prod.bin`、`nvpva_*.fw` 等；OE4T 的 `tegra-firmware` 从 NVIDIA deb/BSP 拷贝固件并继承 proprietary license。[Package Manifest](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/RM/PackageManifest.html#bootloader)；[OE4T firmware recipe](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/recipes-bsp/tegra-binaries/tegra-firmware_36.4.4.bb) |
| TegraFlash、签名和刷写工具链 | 混合，但整体应按 NVIDIA BSP 专有工具对待 | 可以调整公开脚本/配置；不能假设底层工具全部开放 | 官方 manifest 同时列出 Python scripts 和二进制刷写组件；OE4T 从整体声明为 `Proprietary` 的 Driver Package 提取这些工具。[Package Manifest](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/RM/PackageManifest.html#bootloader)；[OE4T binary BSP recipe](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/recipes-bsp/tegra-binaries/tegra-binaries-36.4.4.inc) |
| CUDA driver、OpenGL/Vulkan、NVENC/NVDEC、Argus/ISP、DLA/PVA 用户态库 | 主要为专有二进制 | 通常只能使用公开 API 和配置，不能重建核心实现 | NVIDIA manifest 将 `libcuda.so`、`libnvpva.so`、`nvargus-daemon` 等列为交付文件；OE4T 从 NVIDIA deb 包中直接安装这些库，公共基类许可证为 `Proprietary`。[Package Manifest](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/RM/PackageManifest.html#root-file-system)；[OE4T binary-library class](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/recipes-bsp/tegra-binaries/tegra-debian-libraries-common.inc) |
| GStreamer/Multimedia API 示例和部分插件 | 源码可得，但许可证混合 | 可改公开部分；仍依赖专有底层库 | public sources 列出多项 `gst-*`、V4L2、Argus sample 源码；OE4T 对不同插件分别标为 LGPL/BSD/MIT 与 Proprietary 的组合。应逐配方和逐文件审计，不能把整个 multimedia stack 归为开源。[Working With Sources](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/WorkingWithSources.html) |
| Ubuntu sample rootfs 和普通发行版软件包 | 依各上游包许可证，多数为开源 | 可以按发行版规则重建/替换 | NVIDIA 单独发布 sample root filesystem 及其 source archive；这不改变注入 rootfs 的 NVIDIA 专有 deb/库的许可证。[R36.4.4 downloads](https://developer.nvidia.com/embedded/jetson-linux-r3644) |

一个实用判断方法是：`public_sources.tbz2` 中出现某个归档，只能证明“有源码”；最终是否开源必须继续查看该归档的许可证。反过来，`Jetson_Linux_R36.4.4_aarch64.tbz2`、NVIDIA deb 包和 `non-osi` 仓库中的文件，应默认按随附的 NVIDIA 或第三方专有条款处理。

## 先确认硬件边界：Jetson 模组还是裸 T234 SoC

### Jetson SOM + 自定义载板

这是 NVIDIA 公开文档和 OE4T 直接支持的场景。官方以 Orin NX/Nano 为例说明，P3767 SOM 与 P3768 carrier 各自有 EEPROM；换成非 P3768 载板时，必须修改：

- Linux kernel device tree；
- MB1 configuration；
- MB2 configuration；
- ODM data；
- flashing configuration。

来源：[Jetson Orin NX/Nano Platform Adaptation and Bring-Up](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonOrinNxNanoSeries.html#board-configuration)。AGX Orin 使用对应的 [AGX Orin guide](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonAgxOrinSeries.html)。

### 裸 T234 SoC / 自研 SOM

公开指南的对象明确是 Jetson **module/SOM 与 carrier board**，不是裸 SoC 的 DDR、PMIC、boot media 和 module-level 设计。MB1 又由 NVIDIA 签名加密，并依赖 Memory BCT、PMIC/安全配置和 SKU 对应的 NVIDIA 固件。由此可知，裸 T234 自研 SOM 不能照搬 carrier-board 流程完成：应先与 NVIDIA 确认芯片供货资格、受限 TRM/设计指南、DRAM training/Memory BCT、签名固件、制造与支持条件。公开 `meta-tegra` 也把自己定义为 “BSP layer for NVIDIA Jetson Modules”，不是通用裸 Tegra SoC BSP。[OE4T meta-tegra README](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/README.md)

因此，若目标是可控风险的量产产品，推荐选择对应的 production Jetson module，只自定义 carrier board 和产品软件。

## 使用 `meta-tegra` 做自定义载板 BSP 的建议流程

### 1. 固定模块、Jetson Linux 和参考 MACHINE

先确定精确 module SKU、容量和 carrier 拓扑。例如 Orin NX 16GB、Orin Nano 8GB、AGX Orin 32GB 不能只用“Orin”笼统表示；它们的 chip SKU、BPMP DTB/firmware、WB0 SDRAM BCT、分区和 BUP specs 可能不同。

从最接近的 OE4T machine 开始，而不是从空文件创建：

- AGX Orin：参考 `jetson-agx-orin-devkit.conf` 和 `agx-orin.inc`；
- Orin NX：参考 `p3768-0000-p3767-0000.conf` 和 `orin-nx.inc`；
- Orin Nano：参考对应 P3767 SKU machine 和 `orin-nano.inc`。

这些配置展示了 `KERNEL_DEVICETREE`、`TEGRA_BUPGEN_SPECS`、partition layout 和全部 `TEGRA_FLASHVAR_*` 的真实 R36.4.4 组合。[OE4T machine configs](https://github.com/OE4T/meta-tegra/tree/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/conf/machine)

在本仓库中，应把新 machine、DTS/BCT、配方 append 和产品策略放到项目自己的 `products/<product>/` 元数据中，不要直接修改 `components/layers/bsp/nvidia/meta-tegra` 子模块。OE4T 自己也建议在自有 metadata layer 中创建 `conf/machine/<machine>.conf`；其文档还提醒 custom MACHINE 名不得超过 31 个字符。[Creating a Custom MACHINE](https://oe4t.github.io/master/Creating-a-custom-MACHINE.html)

### 2. 先完成硬件设计输入，再生成 pinmux/BCT

在 layout 冻结前完成接口和 lane 分配，尤其是：

- 电源时序、`POWER_EN` / `CARRIER_PWR_ON` / `SYS_RESET*`；
- Force Recovery USB 和 debug UART；
- UPHY lane 在 PCIe、USB 3、UFS/DisplayPort 之间的复用；
- boot storage、NVMe、SD/eMMC；
- GPIO 默认方向、pull、tristate 和 pad voltage；
- carrier EEPROM 是否存在以及 board ID 规划。

NVIDIA 明确要求使用对应模块的 Pinmux spreadsheet 生成 pinmux/GPIO/pad-voltage DTSI，并在 bring-up 前结合 Product Design Guide/TRM 审核 lane mapping。[Orin NX/Nano MB1 pinmux changes](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonOrinNxNanoSeries.html#pinmux-changes)；[UPHY Lane Configuration](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/Bootloader/UphyLaneConfig.html)

在 R36.4.4 的 `meta-tegra` 中，由 machine variables 生成 `flashvars`。自定义 machine 至少要逐项审核，而不是只换 DTB：

- `TEGRA_FLASHVAR_PINMUX_CONFIG`
- `TEGRA_FLASHVAR_PMC_CONFIG`
- `TEGRA_FLASHVAR_MB2BCT_CFG`
- `TEGRA_FLASHVAR_UPHY_CONFIG` / `ODMDATA`
- `TEGRA_FLASHVAR_PMIC_CONFIG`
- `TEGRA_FLASHVAR_GPIOINT_CONFIG`
- `TEGRA_FLASHVAR_BPFDTB_FILE` 与对应 BPMP firmware
- `TEGRA_FLASHVAR_WB0SDRAM_BCT`
- internal/external `PARTITION_LAYOUT_*`

参考当前 [AGX Orin include](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/conf/machine/include/agx-orin.inc) 和 [Orin NX include](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/conf/machine/include/orin-nx.inc)。自定义文件应由自己 layer 的 `tegra-bootfiles_36.4.4.bbappend` 安装到 `${datadir}/tegraflash/`，并由 machine 中的 `TEGRA_FLASHVAR_*` 指向它们。[OE4T custom MACHINE guide](https://oe4t.github.io/master/Creating-a-custom-MACHINE.html#jetson-orin)

若载板没有 EEPROM，不能只把硬件留空；官方要求将 MB2 BCT 的 `cvb_eeprom_read_size` 从 `0x100` 改为 `0x0`。[Orin NX/Nano EEPROM modifications](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonOrinNxNanoSeries.html#eeprom-modifications)

### 3. 建立产品 kernel DT，并只在需要时改内核

设备树应先覆盖能启动和访问根文件系统的最小闭环：

1. regulators、电源 GPIO、pinctrl；
2. debug UART、I2C/EEPROM；
3. boot storage 或 NVMe；
4. Recovery USB、USB host/device 与 XUSB padctl；
5. PCIe controller、`pipe2uphy`、clock/reset；
6. Ethernet、CAN、SPI、I2C、UART；
7. camera、display、audio；
8. thermal、fan、power mode 和 suspend/resume。

对自定义 PCIe，官方步骤包含选择匹配载板的 UPHY configuration/ODMDATA、使能 controller DT node、正确配置 MB1 pinmux/GPIO，并给 controller 加 `pipe2uphy` phandle。[Enable PCIe in a Customer Carrier Board](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonOrinNxNanoSeries.html#enabling-pcie-in-a-customer-carrier-board-design)

`meta-tegra` 默认由 `nvidia-kernel-oot-dtb` 提供 Jetson DTB，并从 OOT source 构建设备树。可以在产品 layer 中 patch/fork NVIDIA OOT device-tree source，或使用独立 devicetree recipe，再让 `KERNEL_DEVICETREE` 指向产品 DTB；不要把产品 DTS 塞回上游子模块。[OE4T provider selection](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/conf/machine/include/tegra-common.inc)

### 4. 仅在启动策略需要时修改 UEFI

多数 carrier-board bring-up 不需要改 UEFI C 源码；boot order、boot mode 等可先用 `L4TConfiguration.dtbo` 或 UEFI variables 配置。若要增加 UEFI 驱动、裁剪 shell、改变早期界面或实现产品级启动策略，再 fork/pin `edk2-nvidia` 并由 OE4T 配方重建。[UEFI Adaptation](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/Bootloader/UEFI.html)

必须保留完整镜像对 `non-osi` EFI binary 的依赖和相应许可证；“能从源码编出 UEFI”不代表最终镜像不含专有代码。

### 5. 生成独立刷写包并保留串口/刷写日志

`meta-tegra` 的 image class 默认加入 `tegraflash.tar.zst`，包内生成 `doflash.sh`；如果配置 external rootfs，还会生成对应 external flash 脚本。该包组合 kernel、DTB、BCT、boot firmware、UEFI、partition XML 和 rootfs，是开发与工厂刷写的可追溯交付物。[OE4T image class](https://github.com/OE4T/meta-tegra/blob/e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e/classes-recipe/image_types_tegra.bbclass)

bring-up 初期至少保存：

- TegraFlash 完整 host log；
- boot/combined UART 从上电开始的完整 log；
- 构建所用 `MACHINE`、Jetson Linux/OE4T commit、DTB/BCT 文件 hash；
- module board ID、SKU、FAB、RAM code；
- 示波器/逻辑分析仪的电源时序和关键链路测量。

### 6. 按“最小可启动 → 外设 → 电源/性能 → 量产安全”推进

推荐顺序：

1. 上电前检查短路、供电和模组连接；
2. 验证 Force Recovery、USB enumeration 和 debug UART；
3. 使用最小 rootfs 完成刷写并看到 MB1/MB2/UEFI/kernel 日志；
4. 验证 rootfs storage 和有线网络；
5. 逐项启用 USB/PCIe/Ethernet/CAN/I2C/SPI/UART；
6. 再做 display/camera/audio 和 GPU/multimedia；
7. 验证温控、风扇、功耗模式、SC7/suspend-resume；
8. 最后验证 A/B、OTA、镜像签名、Secure Boot 和量产烧录。

NVIDIA 提供了专门的硬件与软件 bring-up checklist，包含上电、recovery、TegraFlash、UEFI、UART、USB、PCIe、显示和信号完整性项目，应作为板级验收基线。[Jetson Module Adaptation and Bring-Up Checklists](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/Checklists.html)

Secure Boot 必须放在普通板卡 bring-up 稳定之后。Orin fuse 一旦由 0 烧成 1 就不能恢复为 0，`SecurityMode` 置位后还会阻止后续普通 fuse 写入；官方也警告错误的 fuse 依赖顺序可能使设备不可用。[Secure Boot — Fuses and Security](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/Security/SecureBoot.html#fuses-and-security)

## 关键限制和工程决策

### 不能做什么

- 不能替换或重建 BootROM、PSCROM、MB1；MB1 的板级适配入口是 BCT，不是源码。
- 不能把 proprietary binary 反编译后修改，也不能任意修改后二次分发。
- 不能只换 kernel DTB 就认为完成了载板适配；MB1/MB2 BCT、pinmux/pad voltage、UPHY/ODMDATA、flash layout 同样属于板级 BSP。
- 不能随意混用不同 Jetson Linux release 的 MB1/MB2/BPMP/UEFI/OOT modules/用户态 GPU 和 multimedia 库；应把 R36.4.4 当作一个经过配套验证的版本集合。
- 不能因 `edk2-nvidia` 和 kernel 有源码，就宣称完整产品 BSP 是“100% 开源”。

### 可以掌控什么

- 产品 machine、DT/BCT/overlay、partition layout 和刷写包；
- Linux 配置、补丁、in-tree/OOT 驱动和产品设备树；
- 大部分 UEFI 策略和源码；
- rootfs、systemd services、容器、应用和 OTA 框架；
- OEM keys、签名流程、UEFI Secure Boot、A/B 与生产刷写基础设施。

### 量产许可证注意事项

若产品需要对外分发刷写包或系统镜像，应做 recipe/package 级 SBOM 和许可证归档。NVIDIA 协议允许在规定条件下随 OS 分发未修改的 NVIDIA binary，但要求 binary 不被修改并向接收方提供协议；独立的开源/第三方组件则继续受各自许可证约束。[NVIDIA Driver License Agreement, sections 1 and 6](https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v4.4/release/tegra_software_license_agreement-tegra-linux.txt)

## 对当前仓库的落地建议

建议把一个新 Jetson 产品拆成以下边界：

```text
products/<product>/
├── product.conf
├── targets/<target>.conf
├── baselines/whinlatter.conf
├── conf/local.conf.fragment
└── meta-<product>/
    ├── conf/layer.conf
    ├── conf/machine/<machine>.conf
    ├── recipes-bsp/tegra-binaries/
    │   ├── tegra-bootfiles_36.4.4.bbappend
    │   └── files/             # pinmux/GPIO/pad-voltage/MB1/MB2 BCT
    ├── recipes-kernel/
    │   ├── nvidia-kernel-oot/
    │   └── linux/             # only if kernel patches/config are needed
    └── recipes-bsp/uefi/            # only if UEFI customization is needed
```

`product.conf` 继承现有 `tegra` Platform Integration，`baselines/whinlatter.conf` 只注册产品自己的 metadata layer；上游 `components/layers/bsp/nvidia/meta-tegra` 保持不变。

第一阶段交付物应是：一个明确绑定 R36.4.4/OE4T commit 的 custom MACHINE、产品 DTB、完整 BCT/flashvars、可重复生成的 `tegraflash.tar.zst`、以及通过 NVIDIA bring-up checklist 的测试记录。等这些稳定后，再加入 Secure Boot、A/B、OTA 和生产密钥流程。

## 主要一手资料

- [NVIDIA Jetson Linux R36.4.4 release/download page](https://developer.nvidia.com/embedded/jetson-linux-r3644)
- [NVIDIA Jetson Linux Developer Guide R36.4.4](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/index.html)
- [NVIDIA Working With Sources](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/WorkingWithSources.html)
- [NVIDIA Orin Boot Flow](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/AR/BootArchitecture/JetsonOrinSeriesBootFlow.html)
- [NVIDIA Orin NX/Nano Platform Adaptation and Bring-Up](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonOrinNxNanoSeries.html)
- [NVIDIA AGX Orin Platform Adaptation and Bring-Up](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonAgxOrinSeries.html)
- [NVIDIA R36.4.4 Package Manifest](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/RM/PackageManifest.html)
- [NVIDIA Driver License Agreement](https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v4.4/release/tegra_software_license_agreement-tegra-linux.txt)
- [OE4T meta-tegra repository](https://github.com/OE4T/meta-tegra)
- [OE4T Creating a Custom MACHINE](https://oe4t.github.io/master/Creating-a-custom-MACHINE.html)
