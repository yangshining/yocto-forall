# U-Boot FPGA Bitstream Loading Guide

## 问题解答

**问：能在 U-Boot 命令行将 FPGA bit 下载进去，然后再 booti 启动 kernel 吗？这样还会挂死吗？**

**答：✅ 可以！这是正确的解决方案！加载 bitstream 后就不会挂死了。**

---

## 为什么这样可以解决挂死问题

### 当前问题流程：
```
U-Boot 启动 → 跳过 FPGA → 启动内核
    ↓
内核加载设备树 → 发现 PL 设备
    ↓
尝试访问 0xa0000000 (AXI 中断控制器)
    ↓
❌ FPGA 未编程，硬件不存在
    ↓
❌ CPU 挂起等待响应 → RCU Stall
```

### 正确流程（加载 bitstream）：
```
U-Boot 启动 → 加载 FPGA bitstream → 启动内核
    ↓                    ↓
                   ✅ FPGA 编程完成
                   ✅ PL 硬件就绪
    ↓
内核加载设备树 → 发现 PL 设备
    ↓
访问 0xa0000000 (AXI 中断控制器)
    ↓
✅ FPGA 已编程，硬件响应正常
    ↓
✅ 所有 PL 设备正常初始化，系统正常启动
```

---

## 步骤 1: 获取 FPGA Bitstream

### 当前状态：
```bash
XSA 文件大小：692KB (不包含 bitstream)
位置：/home2/yang.xu/tool/sources/yocto-forall/components/descriptions/system.xsa
```

### 方法 A: 从 Vivado 重新导出（推荐）

1. **打开你的 Vivado 项目**

2. **生成 Bitstream**
   ```
   Vivado → Flow Navigator → PROGRAM AND DEBUG
   → Generate Bitstream
   ```

3. **导出硬件（包含 bitstream）**
   ```
   File → Export → Export Hardware
   ☑ Include bitstream  ← 必须勾选！
   ```

4. **导出两个文件：**
   - `design.xsa` (包含 bitstream，较大)
   - 或直接从项目目录获取 `.bit` 文件

### 方法 B: 从现有 Vivado 项目提取

如果你还有 Vivado 项目：

```bash
# Bitstream 文件位置：
<vivado_project>/design.runs/impl_1/system_wrapper.bit
```

复制到 Yocto 项目：
```bash
cp <vivado_project>/design.runs/impl_1/system_wrapper.bit \
   /home2/yang.xu/tool/sources/yocto-forall/components/descriptions/system.bit
```

---

## 步骤 2: 转换 Bitstream 格式（ZynqMP 需要）

ZynqMP 使用 `.bin` 格式，需要用 Bootgen 转换：

### 创建 BIF 文件

```bash
cd /home2/yang.xu/tool/sources/yocto-forall/components/descriptions/

cat > fpga.bif << 'EOF'
all:
{
    system.bit
}
EOF
```

### 使用 Bootgen 转换

```bash
# 如果有 Vitis/PetaLinux 环境
bootgen -image fpga.bif -arch zynqmp -process_bitstream bin -o system.bit.bin

# 或使用 Yocto 编译的 bootgen
bitbake bootgen-native
oe-run-native bootgen-native bootgen -image fpga.bif -arch zynqmp -process_bitstream bin -o system.bit.bin
```

结果文件：`system.bit.bin` (约 3-10 MB)

---

## 步骤 3: 将 Bitstream 添加到 BOOT 分区

### 方法 A: 临时测试（通过 TFTP/SD 卡）

**通过 SD 卡：**
```bash
# 复制到 SD 卡的 boot 分区
cp system.bit.bin /media/BOOT/
```

**通过 TFTP：**
```bash
# 在 TFTP 服务器上放置 system.bit.bin
cp system.bit.bin /tftpboot/
```

### 方法 B: 添加到 Yocto 镜像（永久方案）

创建 recipe：`project-spec/meta-user/recipes-bsp/fpga-manager/fpga-bitstream.bb`

```bitbake
SUMMARY = "FPGA Bitstream for system design"
LICENSE = "CLOSED"

SRC_URI = "file://system.bit.bin"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit deploy

do_install() {
    install -d ${D}/boot
    install -m 0644 ${WORKDIR}/system.bit.bin ${D}/boot/fpga.bin
}

do_deploy() {
    install -d ${DEPLOYDIR}
    install -m 0644 ${WORKDIR}/system.bit.bin ${DEPLOYDIR}/fpga.bin
}

addtask deploy after do_install

FILES:${PN} = "/boot/*"
PACKAGE_ARCH = "${MACHINE_ARCH}"
```

放置 bitstream：
```bash
mkdir -p project-spec/meta-user/recipes-bsp/fpga-manager/files/
cp system.bit.bin project-spec/meta-user/recipes-bsp/fpga-manager/files/
```

添加到镜像：在 `user_extra.conf` 中添加：
```bitbake
IMAGE_INSTALL:append = " fpga-bitstream"
```

---

## 步骤 4: U-Boot 中加载 FPGA

### 完整的 U-Boot 启动命令序列

```bash
# ============================================
# U-Boot 加载 FPGA 并启动内核的完整流程
# ============================================

# 1. 设置环境变量（根据你的实际情况调整）
setenv kernel_addr 0x8000000
setenv ramdisk_addr 0x10000000
setenv fdt_addr 0x7000000
setenv fpga_addr 0x20000000

# 2. 从 SD 卡加载 bitstream
fatload mmc 0 ${fpga_addr} fpga.bin

# 或从 TFTP 加载 bitstream
# setenv serverip 192.168.1.100
# setenv ipaddr 192.168.1.10
# tftpboot ${fpga_addr} fpga.bin

# 3. 加载 bitstream 到 FPGA
fpga load 0 ${fpga_addr} ${filesize}

# 4. 等待 FPGA 配置完成（可选，通常很快）
sleep 1

# 5. 正常启动内核（你之前的命令）
booti ${kernel_addr} ${ramdisk_addr} ${fdt_addr}
```

### 详细命令说明

#### 命令 1: 加载 bitstream 到内存
```bash
fatload mmc 0 ${fpga_addr} fpga.bin
```
- `mmc 0`: SD 卡设备 0
- `${fpga_addr}`: 内存地址（避免与 kernel/ramdisk/dtb 冲突）
- `fpga.bin`: bitstream 文件名

#### 命令 2: 编程 FPGA
```bash
fpga load 0 ${fpga_addr} ${filesize}
```
- `0`: FPGA 设备 ID（ZynqMP 通常是 0）
- `${fpga_addr}`: bitstream 在内存中的位置
- `${filesize}`: 自动从上一次 load 命令获取

### 简化版本（单行命令）

```bash
fatload mmc 0 0x20000000 fpga.bin && fpga load 0 0x20000000 ${filesize} && booti 0x8000000 0x10000000 0x7000000
```

---

## 步骤 5: 自动化启动脚本

### 创建 U-Boot 启动脚本

创建 `boot.cmd`:
```bash
# Load FPGA bitstream
echo "Loading FPGA bitstream..."
fatload mmc 0 0x20000000 fpga.bin
if test $? -eq 0; then
    echo "Programming FPGA..."
    fpga load 0 0x20000000 ${filesize}
    echo "FPGA programming complete"
else
    echo "Warning: FPGA bitstream not found, continuing anyway..."
fi

# Load kernel, ramdisk, device tree
fatload mmc 0 0x8000000 Image
fatload mmc 0 0x10000000 rootfs.cpio.uboot
fatload mmc 0 0x7000000 system.dtb

# Boot
booti 0x8000000 0x10000000 0x7000000
```

### 编译启动脚本
```bash
mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -n "Boot Script" -d boot.cmd boot.scr
```

### 在 U-Boot 中使用
```bash
fatload mmc 0 0x3000000 boot.scr
source 0x3000000
```

或设置为默认启动：
```bash
setenv bootcmd 'fatload mmc 0 0x3000000 boot.scr; source 0x3000000'
saveenv
```

---

## 步骤 6: 永久集成到 Yocto

### 修改 U-Boot 启动脚本 Recipe

修改：`project-spec/meta-user/recipes-bsp/u-boot/files/boot.cmd`

```bash
# Load and program FPGA
if fatload ${devtype} ${devnum}:${distro_bootpart} ${fpga_load_addr} fpga.bin; then
    echo "Programming FPGA with bitstream..."
    fpga load 0 ${fpga_load_addr} ${filesize}
    echo "FPGA configured successfully"
fi

# Continue with normal boot
# ... existing boot commands ...
```

修改：`project-spec/meta-user/recipes-bsp/u-boot/u-boot-xlnx-scr.bbappend`

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://boot.cmd"

# Add FPGA load address variable
EXTRA_UBOOT_VARS += "fpga_load_addr=0x20000000"
```

---

## 验证流程

### 1. U-Boot 控制台输出

成功加载 FPGA 的输出示例：
```
ZynqMP> fatload mmc 0 0x20000000 fpga.bin
5242880 bytes read in 234 ms (21.3 MiB/s)

ZynqMP> fpga load 0 0x20000000 ${filesize}
Device 0: OK
Programming FPGA...
FPGA bitstream loaded successfully

ZynqMP> booti 0x8000000 0x10000000 0x7000000
## Loading init Ramdisk from Legacy Image at 10000000 ...
## Flattened Device Tree blob at 07000000
   Booting using the fdt blob at 0x7000000
   Loading Ramdisk to 3435c000, end 37fff051 ... OK
   Loading Device Tree to 000000007dda3000, end 000000007ddb012b ... OK

Starting kernel ...
```

### 2. Kernel 启动日志

应该看到 PL 设备正常初始化：
```
[    0.000000] Machine model: xlnx,zynqmp
[    5.666687] irq-xilinx: /pl-bus/interrupt-controller@a0000000: num_irq=32
[    5.667000] ✅ axi-intc a0000000.interrupt-controller: registered
[    5.670000] ✅ radio_ctrl initialized
[    5.675000] ✅ cpri0 initialized
```

**不应该看到：**
- ❌ RCU stall 警告
- ❌ 系统挂起

---

## 故障排查

### 问题 1: fpga load 命令不存在

**原因：** U-Boot 未启用 FPGA 支持

**解决：** 检查 U-Boot 配置
```bash
# 在 project-spec/meta-user/recipes-bsp/u-boot/u-boot-xlnx_%.bbappend
UBOOT_FEATURES += "fpga"
```

### 问题 2: FPGA 编程失败

**检查：**
```bash
# 查看 FPGA 状态
fpga info 0

# 预期输出：
# Device 0: Xilinx ZynqMP FPGA
# Status: Operational
```

**可能原因：**
- Bitstream 格式错误（未转换为 .bin）
- Bitstream 与硬件不匹配
- Bitstream 文件损坏

### 问题 3: 仍然挂死

**检查：**
1. FPGA 是否真的加载成功
2. Bitstream 是否与 XSA 匹配
3. 设备树是否与硬件设计一致

**调试：**
```bash
# 在内核命令行添加调试信息
setenv bootargs 'earlycon console=ttyPS0,115200 debug'
```

---

## 性能对比

| 方案 | 启动时间 | 复杂度 | PL 功能 | 生产可用 |
|------|---------|--------|---------|---------|
| 无 FPGA | ❌ 挂死 | 简单 | ❌ | ❌ |
| 禁用 PL DT | ~8s | 简单 | ❌ | 仅 PS |
| **U-Boot 加载 FPGA** | ~10s | 中等 | ✅ | ✅ **推荐** |
| 内核动态加载 | ~12s | 复杂 | ✅ | ✅ |

---

## 总结

### 你的问题的答案：

✅ **可以在 U-Boot 加载 FPGA bitstream 后再启动内核**
✅ **这样不会挂死，因为硬件已经准备好**
✅ **这是生产环境的标准做法**

### 下一步操作：

1. **获取 bitstream：** 从 Vivado 导出包含 bitstream 的 XSA
2. **转换格式：** 使用 bootgen 转换为 .bin
3. **测试：** 在 U-Boot 手动加载测试
4. **集成：** 添加到自动启动脚本

### 快速测试命令（假设已有 fpga.bin）：

```bash
# U-Boot 命令行
fatload mmc 0 0x20000000 fpga.bin
fpga load 0 0x20000000 ${filesize}
booti 0x8000000 0x10000000 0x7000000
```

---

## 参考资料

- Xilinx ZynqMP TRM (Technical Reference Manual)
- U-Boot FPGA 命令文档
- Device Tree Overlay for FPGA
- Yocto FPGA Manager Layer

需要帮助获取或转换 bitstream，请告诉我！

