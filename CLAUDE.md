# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A multi-BSP Yocto build workspace for embedded SoC development. It supports building Linux images across Xilinx ZynqMP, NXP QorIQ, Rockchip RK3568, STM32MP, Raspberry Pi, and Tegra platforms. All vendor layers are managed as git submodules.

## Common Commands

```bash
# First-time setup: initialize all submodules (19 vendor BSP layers)
git submodule update --init --recursive

# Enter build environment for a specific machine
. configs/setup-env.sh -m zynqmp-generic

# Re-enter an existing build env (after shell restart)
. build/SOURCE_THIS

# Build full image
bitbake petalinux-image-minimal    # Xilinx default
bitbake core-image-minimal         # Generic minimal

# Rebuild a single component
bitbake -c cleansstate device-tree && bitbake device-tree

# Validation: recipe-level check (parse only, no build)
bitbake -p
```

`setup-env.sh` flags: `-m <machine>`, `-j <parallel-make-jobs>`, `-t <bb-threads>`, `-b <build-dir>`, `-d <dl-dir>`, `-c <sstate-dir>`.

## CI

GitHub Actions runs `bitbake -p` (parse-only) on every PR and push to `main` across 5 platforms. See `.github/workflows/ci.yml`. Tegra is excluded from CI until locally verified.

Known pre-existing CI warnings (do not fail the job):
- NXP (`meta-freescale`), Rockchip (`meta-rockchip`), and Raspberry Pi (`meta-raspberrypi`) BSP layers declare `whinlatter` series compatibility, not `scarthgap` — upstream issue, not caused by this repo.
- `rk3568-evb` and `stm32mp15-common` are project-level wrapper machine names with no corresponding `.conf` files in their BSP layers — also pre-existing.

## Architecture

```
components/
  layers/core/                    # poky, meta-openembedded, meta-arm (all machines)
  layers/bsp/                     # Vendor BSP layers (git submodules): xilinx/, nxp/, rockchip/, stm32mp/, raspberrypi/, nvidia/
  layers/tools/                   # meta-clang, meta-qt5
  descriptions/                   # XSA hardware definitions (Xilinx)
configs/
  setup-env.sh                    # Environment init: auto-discovers platform, configures layers and local.conf
  local-proj.conf                 # Project-wide BitBake settings (XSA path, XSCT tools, work dir exclusions)
platforms/
  common/
    meta-user/                    # Cross-platform customization layer (priority 5)
      conf/layer.conf             # Includes user_extra.conf
      conf/user_extra.conf        # IMAGE_INSTALL additions shared by all platforms
      recipes-support/watchdog/   # watchdog-feeder systemd service
  xilinx/
    platform.conf                 # Declares PLATFORM_MACHINE_LAYER, PLATFORM_BSP_LAYERS, PLATFORM_DISTRO
    conf/local.conf.fragment      # Xilinx-specific BitBake settings appended at setup time
    meta-xilinx-user/             # Xilinx customization layer (priority 6)
      recipes-bsp/                # Device tree, U-Boot, FSBL, PMU firmware overrides
      recipes-kernel/             # Kernel patches (linux-xlnx)
      recipes-support/            # low-level-init systemd service (Xilinx-only)
  nxp/ rockchip/ stm32mp/ raspberrypi/ nvidia/
    platform.conf                 # Same structure as xilinx/
    conf/local.conf.fragment
    meta-<name>-user/             # Platform-specific customization layer (priority 6)
docs/                             # Troubleshooting guides and layer version reference
```

**Key architectural rules:**
- Never edit upstream submodule layers directly. Put overrides in `platforms/<name>/meta-<name>-user/` or `configs/local-proj.conf`.
- `setup-env.sh` auto-discovers the platform by scanning `platforms/*/platform.conf`, matching `PLATFORM_MACHINE_LAYER` to the detected machine's BSP layer. No hardcoded platform lists.
- To add a new SoC platform: add a submodule under `components/layers/bsp/<vendor>/`, create `platforms/<name>/platform.conf`, `conf/local.conf.fragment`, and `meta-<name>-user/conf/layer.conf`. No changes to `setup-env.sh` required.
- `platforms/common/meta-user/` (priority 5) holds content shared across all platforms. Platform-specific layers (priority 6) take precedence.
- Xilinx device tree flow: XSA file → XSCT/HSI tool → `device-tree.bb` → `system.dtb`. Hardware definition path is set in `local-proj.conf` via `HDF_PATH` and `HDF_MACHINE = "${MACHINE}"`.
- ZynqMP boot stack: FSBL → PMU firmware → ATF (bl31) → U-Boot → Linux, all built as separate recipes.

## Supported Machines

| Machine flag | Platform | Distro |
|---|---|---|
| `zynqmp-generic`, `zynqmp-zcu102` | Xilinx ZynqMP | `petalinux` |
| `ls1043ardb`, `ls1088ardb`, `lx2160ardb`, `ls1028ardb` | NXP QorIQ | `fsl-qoriq` |
| `rk3568-evb` | Rockchip | `poky` |
| `stm32mp15-common` | STM32MP | `poky` |
| `raspberrypi4-64`, `raspberrypi0-2w` | Raspberry Pi | `poky` |
| `tegra210-generic`, `tegra186-generic` | Tegra | `poky` |

Layer version and compatibility info: `docs/layers-versions.md`.

## Coding Conventions

- Shell: 4-space indentation, POSIX-compatible.
- BitBake append files: `<recipe>_%.bbappend`.
- Patches: numeric prefix + short subject — `0001-fix-something.patch`. Store kernel patches under `platforms/xilinx/meta-xilinx-user/recipes-kernel/linux-xlnx/files/`.
- Commit messages: concise, scope-first imperative — `meta-user: enable xsct device-tree flow`, `kernel: add motorcomm phy patch`.

## Testing

No unit test suite. Validate with BitBake builds:
- Parse only (fast): `bitbake -p`
- Recipe level: `bitbake <recipe>`
- Image level: `bitbake <image>`
- Boot artifacts: check `build/tmp/deploy/images/<machine>/` after a full build.
