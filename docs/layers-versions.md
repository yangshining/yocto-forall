# Layer Versions Reference

This document records the upstream URL, pinned commit, and Yocto series
compatibility for every layer in this workspace. Update it whenever a
submodule is bumped.

**Target Yocto series:** `scarthgap` (Yocto Project 5.0 LTS)

> **How this file was generated**
> Commit hashes were read from `.gitmodules` + `git submodule status`.
> `LAYERSERIES_COMPAT` was read from each layer's `conf/layer.conf`.
> The two NXP layers that live directly in the tree (not submodules) were
> read from their checked-in `conf/layer.conf`.

---

## Core Layers

| Layer | Path | Upstream URL | Pinned Commit | LAYERSERIES\_COMPAT | Notes |
|-------|------|--------------|---------------|---------------------|-------|
| poky | `components/layers/core/poky` | https://git.yoctoproject.org/poky | `72983ac` | *(uninitialized)* | Reference distro + BitBake |
| meta-openembedded | `components/layers/core/meta-openembedded` | https://git.openembedded.org/meta-openembedded | `2b26d30` | *(uninitialized)* | OE layer collection (meta-oe, meta-python, etc.) |
| meta-arm | `components/layers/core/meta-arm` | https://git.yoctoproject.org/meta-arm | `a81c199` | *(uninitialized)* | ARM architecture support |

---

## BSP Layers — NXP / Freescale

| Layer | Path | Upstream URL | Pinned Commit | LAYERSERIES\_COMPAT | Notes |
|-------|------|--------------|---------------|---------------------|-------|
| meta-freescale | `components/layers/bsp/nxp/meta-freescale` | https://git.yoctoproject.org/meta-freescale | `1f1dd28` | *(uninitialized)* | NXP/Freescale BSP submodule |
| meta-freescale-distro | `components/layers/bsp/nxp/meta-freescale-distro` | *(in-tree, not a submodule)* | n/a | `kirkstone` | **CONCERN:** declared compat is `kirkstone`; workspace targets `scarthgap`. Verify or update. |
| meta-qoriq | `components/layers/bsp/nxp/meta-qoriq` | *(in-tree, not a submodule)* | n/a | `honister kirkstone master` | **CONCERN:** `scarthgap` is absent from LAYERSERIES\_COMPAT. BitBake will warn on mismatch. Add `scarthgap` or confirm a fork is needed. |

---

## BSP Layers — Raspberry Pi

| Layer | Path | Upstream URL | Pinned Commit | LAYERSERIES\_COMPAT | Notes |
|-------|------|--------------|---------------|---------------------|-------|
| meta-raspberrypi | `components/layers/bsp/raspberrypi/meta-raspberrypi` | https://git.yoctoproject.org/meta-raspberrypi | `161be94` | *(uninitialized)* | RPi BSP (Pi 4 64-bit, Pi Zero 2 W) |

---

## BSP Layers — Rockchip

| Layer | Path | Upstream URL | Pinned Commit | LAYERSERIES\_COMPAT | Notes |
|-------|------|--------------|---------------|---------------------|-------|
| meta-rockchip | `components/layers/bsp/rockchip/meta-rockchip` | https://github.com/JeffyCN/meta-rockchip.git | `3e8fbe8` | *(uninitialized)* | RK3568-EVB target |

---

## BSP Layers — STM32MP

| Layer | Path | Upstream URL | Pinned Commit | LAYERSERIES\_COMPAT | Notes |
|-------|------|--------------|---------------|---------------------|-------|
| meta-st-stm32mp | `components/layers/bsp/stm32mp/meta-st-stm32mp` | https://github.com/STMicroelectronics/meta-st-stm32mp.git | `fae1c3b` | *(uninitialized)* | STM32MP15 BSP |
| meta-st-openstlinux | `components/layers/bsp/stm32mp/meta-st-openstlinux` | https://github.com/STMicroelectronics/meta-st-openstlinux.git | `14bbb30` | *(uninitialized)* | OpenSTLinux distro layer |

---

## BSP Layers — NVIDIA Tegra

| Layer | Path | Upstream URL | Pinned Commit | LAYERSERIES\_COMPAT | Notes |
|-------|------|--------------|---------------|---------------------|-------|
| meta-tegra | `components/layers/bsp/nvidia/meta-tegra` | https://github.com/OE4T/meta-tegra.git | `e79332b` | *(uninitialized)* | Tegra 210 / Tegra 186 |

---

## BSP Layers — Xilinx

| Layer | Path | Upstream URL | Pinned Commit | LAYERSERIES\_COMPAT | Notes |
|-------|------|--------------|---------------|---------------------|-------|
| meta-xilinx | `components/layers/bsp/xilinx/meta-xilinx` | https://github.com/Xilinx/meta-xilinx.git | `8759e6e` | *(uninitialized)* | Core Xilinx BSP (ZynqMP) |
| meta-xilinx-tools | `components/layers/bsp/xilinx/meta-xilinx-tools` | https://github.com/Xilinx/meta-xilinx-tools.git | `dff8704` | *(uninitialized)* | XSCT/HSI toolchain recipes |
| meta-petalinux | `components/layers/bsp/xilinx/meta-petalinux` | https://github.com/Xilinx/meta-petalinux.git | `f54d141` | *(uninitialized)* | PetaLinux distro layer |
| meta-openamp | `components/layers/bsp/xilinx/meta-openamp` | https://github.com/Xilinx/meta-openamp.git | `6804928` | *(uninitialized)* | OpenAMP / RPMsg support |
| meta-virtualization | `components/layers/bsp/xilinx/meta-virtualization` | https://github.com/Xilinx/meta-virtualization.git | `f8a35f5` | *(uninitialized)* | KVM / Xen / Docker support |
| meta-security | `components/layers/bsp/xilinx/meta-security` | https://github.com/Xilinx/meta-security.git | `459d837` | *(uninitialized)* | Security features (IMA, SELinux) |
| meta-system-controller | `components/layers/bsp/xilinx/meta-system-controller` | https://github.com/Xilinx/meta-system-controller.git | `6fd3440` | *(uninitialized)* | System Controller firmware |
| meta-xilinx-tsn | `components/layers/bsp/xilinx/meta-xilinx-tsn` | https://github.com/Xilinx/meta-xilinx-tsn.git | `6a6c645` | *(uninitialized)* | Time-Sensitive Networking |

---

## Tools Layers

| Layer | Path | Upstream URL | Pinned Commit | LAYERSERIES\_COMPAT | Notes |
|-------|------|--------------|---------------|---------------------|-------|
| meta-clang | `components/layers/tools/meta-clang` | https://github.com/kraj/meta-clang.git | `d0a67c7` | *(uninitialized)* | Clang/LLVM toolchain |
| meta-qt5 | `components/layers/tools/meta-qt5` | https://github.com/meta-qt5/meta-qt5.git | `9ae2fe2` | *(uninitialized)* | Qt 5 framework recipes |

---

## Known Compatibility Concerns

| Layer | Issue | Action Required |
|-------|-------|-----------------|
| `meta-freescale-distro` | `LAYERSERIES_COMPAT` is `kirkstone`; workspace targets `scarthgap` | Update to `kirkstone scarthgap` (or `scarthgap`) in `conf/layer.conf` |
| `meta-qoriq` | `LAYERSERIES_COMPAT` is `honister kirkstone master`; `scarthgap` is missing | Add `scarthgap` to `LAYERSERIES_COMPAT_meta-qoriq` in `conf/layer.conf` |
| All 19 submodules | Listed as uninitialized (`-` prefix in `git submodule status`); `LAYERSERIES_COMPAT` could not be read | Run `git submodule update --init --recursive` before a build. Re-read `conf/layer.conf` files and update this table after initialization. |

---

## How to Update a Submodule

### Bump a single submodule to a newer upstream commit

```bash
# 1. Enter the submodule directory
cd components/layers/core/poky          # change to the target submodule

# 2. Fetch upstream changes
git fetch origin

# 3. Check out the desired branch or tag
git checkout scarthgap                  # use the correct branch/tag name

# 4. Return to repo root and record the new commit
cd <repo-root>
git add components/layers/core/poky
git commit -m "layers: bump poky to scarthgap <new-short-sha>"
```

### Update ALL submodules to the latest commit on their tracked branch

```bash
git submodule update --remote --merge
git add components/layers/
git commit -m "layers: bump all submodules to latest upstream"
```

### Initialize submodules after a fresh clone

```bash
git submodule update --init --recursive
```

### After bumping: refresh this document

1. Re-run: `git submodule status` — paste the new short hashes into the table.
2. Check each changed layer's `conf/layer.conf` for `LAYERSERIES_COMPAT` changes.
3. Re-run: `grep -r "LAYERSERIES_COMPAT" components/layers/*/conf/layer.conf components/layers/*/*/conf/layer.conf 2>/dev/null`
4. Update the **Known Compatibility Concerns** section if new mismatches appear.
5. Commit with: `git commit -m "docs: update layers-versions for <release>"`
