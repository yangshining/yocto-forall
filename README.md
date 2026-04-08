# yocto-forall

A multi-platform Yocto build workspace for embedded SoC development. Supports building Linux images across 6 hardware platforms using a shared layer structure and a single environment setup script.

## Supported Platforms

| Machine | Platform | Distro |
|---|---|---|
| `zynqmp-generic`, `zynqmp-zcu102` | Xilinx ZynqMP | petalinux |
| `ls1043ardb`, `ls1088ardb`, `lx2160ardb`, `ls1028ardb` | NXP QorIQ | fsl-qoriq |
| `rk3568-evb` | Rockchip RK3568 | poky |
| `stm32mp15-common` | STMicroelectronics STM32MP | poky |
| `raspberrypi4-64`, `raspberrypi0-2w` | Raspberry Pi | poky |
| `tegra210-generic`, `tegra186-generic` | NVIDIA Tegra | poky |

## Quick Start

**1. Clone with submodules**

```bash
git clone --recurse-submodules https://github.com/yangshining/yocto-forall.git
cd yocto-forall
```

Or if already cloned:
```bash
git submodule update --init --recursive
```

**2. Initialize the build environment**

```bash
. configs/setup-env.sh -m zynqmp-generic
```

Replace `zynqmp-generic` with your target machine. The script detects the correct BSP layers, configures `bblayers.conf` and `local.conf`, and drops you into the build directory.

**3. Build an image**

```bash
bitbake petalinux-image-minimal   # Xilinx
bitbake core-image-minimal        # other platforms
```

**Re-enter an existing build environment** (after shell restart):
```bash
. build/SOURCE_THIS
```

## Repository Structure

```
components/
  layers/core/        # poky, meta-openembedded, meta-arm
  layers/bsp/         # Vendor BSP layers (git submodules)
  layers/tools/       # meta-clang, meta-qt5
  descriptions/       # Xilinx XSA hardware definition files
configs/
  setup-env.sh        # Main environment init script
  local-proj.conf     # Project-wide BitBake configuration
project-spec/
  meta-user/          # Project customization layer (priority 5)
    recipes-bsp/      # Device tree, U-Boot, firmware overrides
    recipes-kernel/   # Kernel patches
    recipes-support/  # systemd services (watchdog, low-level-init)
docs/                 # Platform guides and troubleshooting
```

All project customizations go into `project-spec/meta-user/`. Upstream submodule layers are never modified directly.

## setup-env.sh Options

| Flag | Description |
|---|---|
| `-m <machine>` | Target machine (required) |
| `-j <n>` | `PARALLEL_MAKE` jobs (default: CPU count) |
| `-t <n>` | `BB_NUMBER_THREADS` (default: CPU count) |
| `-b <path>` | Build directory (default: `build/`) |
| `-d <path>` | Download cache directory |
| `-c <path>` | sstate cache directory |

## Validation

Parse all recipes without building (fast check, ~10–20 min):
```bash
bitbake -p
```

Rebuild a single component:
```bash
bitbake -c cleansstate device-tree && bitbake device-tree
```

## CI

GitHub Actions runs `bitbake -p` on every PR and push to `main` across 5 platforms (zynqmp-generic, ls1043ardb, rk3568-evb, stm32mp15-common, raspberrypi4-64).

## Xilinx / ZynqMP Notes

- Hardware design is provided as an XSA file at `components/descriptions/system.xsa`
- The device tree is generated from the XSA via XSCT/HSI tools — set `XILINX_WITH_ESW = "xsct"` (already in `local-proj.conf`)
- Boot stack: FSBL → PMU firmware → ATF → U-Boot → Linux
- See `docs/XSA_USAGE_GUIDE.md`, `docs/UBOOT_FPGA_LOADING_GUIDE.md`, and `docs/KERNEL_HANG_SOLUTION.md` for platform-specific guidance

## Layer Versions

Submodule pinned commits and compatibility information: [`docs/layers-versions.md`](docs/layers-versions.md)

## License

MIT
