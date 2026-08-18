# HARP DFE：U-Boot 手动加载 FPGA 验证指南

## 当前状态

本指南描述一个需要上板验证的实验流程，不代表仓库已经实现自动 bitstream 加载，也不代表目标已经 Boot-Validated 或 Production-Supported。

当前仓库事实：

| 项目 | 状态 |
|---|---|
| `hardware/system.xsa` | 存在，Vivado 2024.2，XCZU67DR，归档内没有 `.bit` 文件 |
| 匹配的 `system.bit` / `fpga.bin` | 未提交 |
| bitstream Yocto recipe | 未实现 |
| 自动 U-Boot 加载流程 | 未实现 |
| `recipes-bsp/u-boot/files/boot-script` | 空文件，当前没有被有效 append 使用 |
| `u-boot_%.bbappend` | 只有注释，没有启用 FPGA 加载逻辑 |
| 硬件启动证据 | 未记录 |

因此不能承诺“加载后一定不会挂死”。只有匹配的 bitstream、设备树和硬件在同一块板上重复验证成功后，才能得出结论。

## 前置条件

准备以下信息：

1. 与当前 XSA 同一次 Vivado 构建产生的 bitstream；
2. bitstream 的生成版本、工程提交和 SHA256；
3. 板卡版本、内存布局和当前 U-Boot 环境；
4. 可恢复的启动介质或串口控制台。

先检查 XSA：

```bash
unzip -p products/xilinx-zynqmp-harp-dfe/hardware/system.xsa xsa.json
unzip -l products/xilinx-zynqmp-harp-dfe/hardware/system.xsa | rg '\.bit$'
```

第二条命令在当前仓库应无输出。

## Bitstream 格式

U-Boot 接受的格式取决于当前 Xilinx U-Boot 配置和生成流程。不要仅根据文件扩展名判断。

在使用 Bootgen 转换之前，应由硬件负责人确认输入 bitstream、目标架构和输出格式。一个常见的转换方式是：

```bash
bootgen -image fpga.bif -arch zynqmp -process_bitstream bin -o system.bit.bin
```

该命令只是示例。转换产物必须与当前 XCZU67DR 设计匹配，并记录校验和。

## 选择安全加载地址

不要直接复制旧文档中的固定地址。当前产品设备树包含保留内存区域，bitstream 大小也可能导致地址区间重叠。

在 U-Boot 中先检查：

```text
bdinfo
printenv loadaddr kernel_addr_r ramdisk_addr_r fdt_addr_r fpga_addr_r
```

根据实际 DRAM、保留内存、内核、ramdisk 和 DTB 地址选择一个不重叠的 `fpga_addr_r`。如果无法证明地址安全，停止实验。

## 手动验证流程

以下命令使用占位符，必须替换为板上确认过的设备、分区、文件名和地址。

### 1. 确认 U-Boot 支持

```text
help fpga
fpga info 0
```

如果命令不存在，需要先实现并构建正确的 U-Boot 配置；不要临时假设某个 `UBOOT_FEATURES` 变量一定适用于当前 recipe。

### 2. 从启动介质加载到内存

SD/eMMC 示例：

```text
fatload mmc <device>:<partition> ${fpga_addr_r} <bitstream-file>
```

TFTP 示例：

```text
tftpboot ${fpga_addr_r} <bitstream-file>
```

记录 `filesize` 和加载区间，确认没有覆盖其他启动对象。

### 3. 编程 PL

```text
fpga load 0 ${fpga_addr_r} ${filesize}
fpga info 0
```

保存完整串口输出。返回成功只表示 U-Boot 接受了编程操作，不证明 bitstream 与设备树匹配。

### 4. 使用原有启动路径启动 Linux

优先执行板上已经验证过的启动命令，例如：

```text
run distro_bootcmd
```

如果必须手动执行 `booti`，应使用当前环境中已确认的内核、ramdisk 和 DTB 地址，而不是本文提供固定地址。

### 5. 判断结果

至少检查：

- PL 编程命令是否成功；
- 内核是否越过历史 stall 点；
- PL 中断、DMA、Ethernet、SPI 和产品 UIO 映射是否按预期工作；
- 重启后结果是否可重复；
- 不加载 bitstream 的对照实验是否能稳定复现问题。

## 永久集成前的实现清单

手动实验通过后，永久方案仍需单独实现和评审：

1. 确定 bitstream 的所有权、许可证和更新流程；
2. 在 `products/xilinx-zynqmp-harp-dfe/` 下增加产品专属 recipe 或硬件输入；
3. 将产物部署到实际使用的启动介质；
4. 对当前 BSP 中真实存在的启动脚本 recipe 添加匹配的 bbappend；
5. 设计加载失败策略，禁止静默带着不匹配的 PL 继续启动；
6. 检查加载地址与 `system-user.dtsi` 保留内存、内核、ramdisk 和 DTB 的关系；
7. 增加镜像构建、产物校验和硬件启动记录；
8. 更新本指南和目标 Support Level。

当前 BSP 提供无版本号的 `u-boot-xlnx-scr.bb`。如果永久方案继续使用该 recipe，匹配的产品 append 应采用精确名称 `u-boot-xlnx-scr.bbappend`，并包含真实加载逻辑。不要照搬旧文档虚构 `boot.cmd` 或 `u-boot-xlnx_%.bbappend`；先通过 `bitbake-layers show-recipes` 和 `show-appends` 确认实际选择。

## 建议的证据记录

```text
Repository commit:
Board serial / revision:
Vivado project commit:
XSA SHA256:
Bitstream SHA256:
U-Boot version:
Load command and address range:
Linux boot command:
Full serial log:
PL functional checks:
Result: pass / fail
```

相关诊断见 [Kernel-Stall Investigation](KERNEL_HANG_SOLUTION.md)。
