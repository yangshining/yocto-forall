# yocto-forall

A single-branch Yocto Build Framework for heterogeneous SoC BSPs. Each build target binds to one isolated, pinned Baseline Profile; profiles never switch a shared Poky checkout and never use `LAYERSERIES_COMPAT` overrides to hide cross-series mismatches.

## Baseline Profiles

| Profile | Yocto series | Platform Integrations |
|---|---|---|
| `scarthgap` | Scarthgap (5.0 LTS) | Xilinx ZynqMP, STM32MP |
| `whinlatter` | Whinlatter | Raspberry Pi, Rockchip, NVIDIA Tegra |
| `kirkstone` | Kirkstone (4.0 LTS) | NXP QorIQ |

Core layers are checked out side by side under `components/layers/baselines/<profile>/`. A target selects its profile through checked-in registry metadata; `-p` only verifies that binding and cannot override it. Every selected platform or product layer—and its containing gitlink checkout—is claimed by exactly one profile. Supporting the same upstream BSP on another Yocto series therefore requires a second pinned checkout/path rather than selecting different sublayers from one shared worktree.

## Targets

| Target | BSP MACHINE | Profile | Support Level |
|---|---|---|---|
| `harp-dfe-xczu67dr` | `harp-dfe-xczu67dr` | `scarthgap` | Parse-Validated |
| `zynqmp-generic` | `zynqmp-generic` | `scarthgap` | Parse-Validated |
| `stm32mp15-disco` | `stm32mp15-disco` | `scarthgap` | Parse-Validated |
| `stm32mp15-eval` | `stm32mp15-eval` | `scarthgap` | Declared |
| `ls1043ardb` | `ls1043ardb` | `kirkstone` | Parse-Validated |
| `ls1088ardb`, `lx2160ardb`, `ls1028ardb` | same as target | `kirkstone` | Declared |
| `rk3568-evb` | `rockchip-rk3568-evb` | `whinlatter` | Parse-Validated |
| `raspberrypi4-64` | `raspberrypi4-64` | `whinlatter` | Parse-Validated |
| `raspberrypi0-2w` | `raspberrypi0-2w` | `whinlatter` | Declared |
| `jetson-orin-nano-devkit`, `jetson-agx-orin-devkit` | same as target | `whinlatter` | Declared |

`stm32mp15-common` remains a safe selector alias for `stm32mp15-disco`. Removed names such as `tegra210-generic`, `tegra186-generic`, and `zynqmp-zcu102` are not present in the pinned BSP revisions and are not silently remapped to different hardware.

List the authoritative registry at any time:

```bash
. configs/setup-env.sh -l
```

## Quick Start

```bash
git clone --recurse-submodules https://github.com/yangshining/yocto-forall.git
cd yocto-forall

# Existing clone:
git submodule update --init --recursive

# Fast metadata check; does not require initialized submodules:
. configs/setup-env.sh -V

# Initialize a target. The profile assertion is optional but useful in CI.
. configs/setup-env.sh -T harp-dfe-xczu67dr -p scarthgap
bitbake petalinux-image-minimal
```

The compatibility form remains supported:

```bash
. configs/setup-env.sh -m rk3568-evb
```

Default state is isolated as follows:

```text
build/<profile>/<target>/
.yocto-cache/<profile>/downloads/
.yocto-cache/<profile>/sstate-cache/
```

Re-enter a build later with:

```bash
. build/<profile>/<target>/SOURCE_THIS
```

Every generated build contains `conf/yocto-forall.manifest`. Reusing a build directory for a different target, machine, platform, product, profile, series, distro, or OEROOT is rejected.

## Setup Options

| Flag | Description |
|---|---|
| `-T <target>` | Canonical target ID |
| `-m <name>` | Target ID, BSP MACHINE, or declared safe alias |
| `-p <profile>` | Assert the target's profile; never overrides it |
| `-j <n>` | `PARALLEL_MAKE` jobs |
| `-t <n>` | `BB_NUMBER_THREADS` tasks |
| `-b <path>` | Custom build directory |
| `-d <path>` | Custom download cache |
| `-c <path>` | Custom sstate cache |
| `-n` | Resolve and print the selection without initializing Yocto |
| `-l` | List profiles and targets |
| `-V` | Validate registry metadata |

## Repository Structure

```text
baselines/<profile>/baseline.conf        profile-owned OEROOT and core layers
components/layers/baselines/<profile>/  side-by-side Poky/OE/meta-arm gitlinks
components/layers/bsp/                  vendor BSP gitlinks and pinned in-tree layers
platforms/<platform>/
  platform.conf                          platform identity and allowed profiles
  baselines/<profile>.conf               profile-specific BSP layers and distro
  targets/<target>.conf                  Reference Machine registry entries
  conf/local.conf.fragment               platform policy
products/<product>/
  product.conf                           product identity and Platform Integration
  baselines/<profile>.conf               product layer selection
  targets/<target>.conf                  Product Machine registry entries
  meta-*/                                product-owned metadata
platforms/common/meta-user/              genuinely cross-profile metadata
configs/setup-env.sh                     registry resolver and environment generator
tests/setup-env-test.sh                  fast executable setup contracts
```

Do not edit upstream submodule layers. Reusable SoC-family integration belongs under `platforms/`; concrete hardware policy belongs under `products/`. The HARP DFE XSA, device tree, boot policy, kernel patches, and low-level initialization are therefore owned by `products/xilinx-zynqmp-harp-dfe/`.

## Adding Support

- New target on an existing stack: add `platforms/<id>/targets/<target>.conf` or `products/<id>/targets/<target>.conf` and run `. configs/setup-env.sh -V`.
- New platform on an existing profile: add `platform.conf`, `baselines/<profile>.conf`, target records, and a project-owned layer if needed.
- New Yocto series: add a fully independent core stack under `components/layers/baselines/<profile>/` plus `baselines/<profile>/baseline.conf`. Add separate pinned paths for every selected BSP/tool layer that another profile already owns; registry validation rejects cross-profile path reuse.
- Series-specific adaptation belongs in `baselines/<profile>.conf`; a bbappend or fragment is not required to support every series.

## Validation

```bash
bash tests/setup-env-test.sh
. configs/setup-env.sh -V
. configs/setup-env.sh -T <target>
bitbake-layers show-layers
bitbake -p
```

CI runs the setup contracts and a `(baseline, target)` parse matrix. See `.github/workflows/ci.yml` and `docs/layers-versions.md`.

## Xilinx ZynqMP HARP DFE

The product hardware input is `products/xilinx-zynqmp-harp-dfe/hardware/system.xsa`. Product-specific guides are under `products/xilinx-zynqmp-harp-dfe/docs/`.

## License

MIT
