# Layer Versions Reference

This repository pins multiple coherent Yocto stacks side by side. A build target consumes exactly one Baseline Profile and never combines core layers from different rows below.

## Core Baseline Profiles

| Profile | Layer | Path | Pinned commit | Declared series |
|---|---|---|---|---|
| `scarthgap` | Poky | `components/layers/baselines/scarthgap/poky` | `72983ac391008ebceb45edc7a8f0f6d5f4fe715c` | `scarthgap` |
| `scarthgap` | meta-openembedded | `components/layers/baselines/scarthgap/meta-openembedded` | `2b26d30fc7f478f5735d514f0c1bc28f6a4148b6` | `scarthgap` |
| `scarthgap` | meta-arm | `components/layers/baselines/scarthgap/meta-arm` | `a81c19915b5b9e71ed394032e9a50fd06919e1cd` | `nanbield scarthgap` |
| `whinlatter` | Poky | `components/layers/baselines/whinlatter/poky` | `22905572d78c8afca7ff9d47e2b9de5c68f0bdc2` | `whinlatter` |
| `whinlatter` | meta-openembedded | `components/layers/baselines/whinlatter/meta-openembedded` | `f52f32952cb9717949f8bc3d3ccf6c4c5a59521f` | `walnascar whinlatter` |
| `whinlatter` | meta-arm | `components/layers/baselines/whinlatter/meta-arm` | `4dc2a7bf29c1853b95dda53d9527f0a23049295f` | `walnascar whinlatter` |
| `kirkstone` | Poky | `components/layers/baselines/kirkstone/poky` | `445a6223929b9a7a62b575093659e3d9e1aba982` | `kirkstone` |
| `kirkstone` | meta-openembedded | `components/layers/baselines/kirkstone/meta-openembedded` | `ce8539c941f6fcbecaca4d16640ac105c0595589` | `kirkstone` |
| `kirkstone` | meta-arm | `components/layers/baselines/kirkstone/meta-arm` | `c3e9fb12aa31d25e33d8392c4a233ed1275a3278` | `kirkstone` |
| `kirkstone` | meta-virtualization | `components/layers/baselines/kirkstone/meta-virtualization` | `92b6abcdfb6f12c4931247f0f29aaf5331984525` | `kirkstone` |

Profile definitions and their explicit layer lists are in `baselines/<profile>/baseline.conf`.

## Platform BSP Layers

| Platform | Profile | Layer | Path | Pinned commit / ownership | Declared series |
|---|---|---|---|---|---|
| Xilinx ZynqMP | `scarthgap` | meta-xilinx | `components/layers/bsp/xilinx/meta-xilinx` | `8759e6effd1996c15d16d092860ea7fa4ac1653a` | `scarthgap` |
| Xilinx ZynqMP | `scarthgap` | meta-xilinx-tools | `components/layers/bsp/xilinx/meta-xilinx-tools` | `dff87041369e5600742997e5607b776463b8c735` | `scarthgap` |
| Xilinx ZynqMP | `scarthgap` | meta-petalinux | `components/layers/bsp/xilinx/meta-petalinux` | `f54d141fc1ec0b37faf7052f3a4cb3f92ea404e4` | `scarthgap` |
| Xilinx ZynqMP | `scarthgap` | meta-openamp | `components/layers/bsp/xilinx/meta-openamp` | `68049285b561f071bd7cc093f9ecbe4f5518ddf9` | `scarthgap` |
| Xilinx ZynqMP | `scarthgap` | meta-virtualization | `components/layers/bsp/xilinx/meta-virtualization` | `f8a35f5e39eeb122be4e29b289102211bc63beea` | `nanbield scarthgap` |
| Xilinx ZynqMP | `scarthgap` | meta-security | `components/layers/bsp/xilinx/meta-security` | `459d837338ca230254baa2994f870bf6eb9d0139` | `nanbield scarthgap` |
| Xilinx ZynqMP | `scarthgap` | meta-system-controller | `components/layers/bsp/xilinx/meta-system-controller` | `6fd344008716f68f11fb6413fb0ca46786dc90eb` | `scarthgap` |
| Xilinx ZynqMP | `scarthgap` | meta-xilinx-tsn | `components/layers/bsp/xilinx/meta-xilinx-tsn` | `6a6c645f104f8c822c857933eb560bf9003843b8` | `scarthgap` |
| STM32MP | `scarthgap` | meta-st-stm32mp | `components/layers/bsp/stm32mp/meta-st-stm32mp` | `fae1c3bcad05f338da80e69fc150b8697ad874c5` | `scarthgap` |
| STM32MP | `scarthgap` | meta-st-openstlinux | `components/layers/bsp/stm32mp/meta-st-openstlinux` | `14bbb30d00473973a67d85cbb1db8a87aa8afe65` | `scarthgap` |
| Raspberry Pi | `whinlatter` | meta-raspberrypi | `components/layers/bsp/raspberrypi/meta-raspberrypi` | `161be949b9f54484f30e3da26f8ef166ae0f2056` | `whinlatter` |
| Rockchip | `whinlatter` | meta-rockchip | `components/layers/bsp/rockchip/meta-rockchip` | `3e8fbe82195686484f907195826b9d9a685ebcd8` | `whinlatter` |
| NVIDIA Tegra | `whinlatter` | meta-tegra | `components/layers/bsp/nvidia/meta-tegra` | `e79332b1c9b1fd93c57c6b6ef5a299f4d050ba3e` | `whinlatter` |
| NXP QorIQ | `kirkstone` | meta-freescale | `components/layers/bsp/nxp/meta-freescale` | `bb581c2ab90f37c5f3204f24c79d878f1a7a0976` | `kirkstone` |
| NXP QorIQ | `kirkstone` | meta-freescale-distro | `components/layers/bsp/nxp/meta-freescale-distro` | in-tree pinned copy | `kirkstone` |
| NXP QorIQ | `kirkstone` | meta-qoriq | `components/layers/bsp/nxp/meta-qoriq` | in-tree pinned copy | `honister kirkstone master` |

Not every checked-in BSP layer is enabled by the current platform adapter. The adapter in `platforms/<platform>/baselines/<profile>.conf` is authoritative.

The STM32MP Scarthgap adapter selects `meta-st-stm32mp`. Project-owned policy in `platforms/stm32mp/conf/local.conf.fragment` enables the vendor-provided `emmc` boot-device configuration only for `stm32mp15-eval`; `stm32mp15-disco` remains SD-card-only. The eval target is included in the CI parse matrix, but eMMC image-build and hardware-boot evidence are not yet claimed.

## Tool Layers

| Layer | Path | Pinned commit | Profile ownership |
|---|---|---|---|
| meta-qt5 | `components/layers/tools/meta-qt5` | `9ae2fe2696b10f5dc4253c4f467dc388139860bd` | Scarthgap / Xilinx adapter |
| meta-clang | `components/layers/tools/meta-clang` | `d0a67c76b7a3b585dbe2ba8ad509dc0fe0e58af2` | Whinlatter-compatible; not enabled by a current target |

## Compatibility Policy

- Upstream `LAYERSERIES_COMPAT` declarations are treated as contracts.
- Local platform fragments must not override an upstream declaration to claim another series.
- Registry validation assigns every selected platform/product layer and its containing gitlink checkout to exactly one Baseline Profile. Reusing any sublayer of an upstream checkout on another profile requires a separate pinned checkout/path.
- A target moves to another profile only after every selected layer is coherently ported and validated there.
- Project-owned layers may list multiple series only when their own metadata is intentionally validated across those series.

Validate registry bindings without submodules:

```bash
. configs/setup-env.sh -V
. configs/setup-env.sh -n -T <target>
```

Validate initialized layer composition:

```bash
. configs/setup-env.sh -T <target>
bitbake-layers show-layers
bitbake -p
```

## Updating Pins

Update one profile at a time. Check out the intended series in each affected submodule, record the exact gitlink, update this file, and run the profile's CI matrix. Do not use `git submodule update --remote --merge` across the whole repository because that can move unrelated Baseline Profiles independently.

```bash
cd components/layers/baselines/scarthgap/poky
git fetch origin scarthgap
git checkout <reviewed-commit>
cd <repo-root>
git add components/layers/baselines/scarthgap/poky docs/layers-versions.md
```
