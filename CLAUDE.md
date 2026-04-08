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

Known pre-existing CI warning: `ls1043ardb` emits a `LAYERSERIES_COMPAT` warning from `meta-qoriq` (declares `honister kirkstone`, not `scarthgap`) — this does not fail the job.

## Architecture

```
components/
  layers/core/          # poky, meta-openembedded, meta-arm (all machines)
  layers/bsp/           # Vendor layers: xilinx/, nxp/, rockchip/, stm32mp/, raspberrypi/, nvidia/
  layers/tools/         # meta-clang, meta-qt5
  descriptions/         # XSA hardware definitions (Xilinx)
configs/
  setup-env.sh          # Environment init: detects machine, configures layer list, sets parallelism
  local-proj.conf       # Project-wide BitBake settings (XSA path, XSCT tools, work dir exclusions)
  rk3568-evb.conf       # Machine-specific overrides for Rockchip RK3568
project-spec/meta-user/ # Custom project layer (priority 5) — the main place for local changes
  conf/layer.conf       # Layer config; includes user_extra.conf
  conf/user_extra.conf  # IMAGE_INSTALL additions
  recipes-bsp/          # Device tree, U-Boot, firmware (FSBL, PMU) customizations
  recipes-kernel/       # Kernel patches (linux-xlnx)
  recipes-support/      # Custom systemd services (watchdog-feeder, low-level-init)
docs/                   # Troubleshooting guides and layer version reference
```

**Key architectural rules:**
- Never edit upstream submodule layers directly. Put overrides in `project-spec/meta-user/` or `configs/*.conf`.
- `setup-env.sh` dynamically builds the `BBLAYERS` list based on the `-m <machine>` argument, including only the relevant BSP layers.
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
- Patches: numeric prefix + short subject — `0001-fix-something.patch`. Store kernel patches under `project-spec/meta-user/recipes-kernel/linux-xlnx/files/`.
- Commit messages: concise, scope-first imperative — `meta-user: enable xsct device-tree flow`, `kernel: add motorcomm phy patch`.

## Testing

No unit test suite. Validate with BitBake builds:
- Parse only (fast): `bitbake -p`
- Recipe level: `bitbake <recipe>`
- Image level: `bitbake <image>`
- Boot artifacts: check `build/tmp/deploy/images/<machine>/` after a full build.
