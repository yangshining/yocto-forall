# Generic Multi-Platform Build Repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the repo so every platform is self-contained under `platforms/<name>/`, `setup-env.sh` has zero hardcoded platform logic, and adding a new SOC requires only creating a new `platforms/<name>/` directory.

**Architecture:** A `platforms/<name>/platform.conf` file declares each platform's MACHINE_LAYER, BSP layers, and DISTRO. `setup-env.sh` scans all `platform.conf` files at runtime to auto-discover platforms. Platform-specific `meta-*-user/` layers and `conf/local.conf.fragment` files replace the current hardcoded `case` blocks. Generic content (watchdog-feeder, common tools) lives in `platforms/common/meta-user/`.

**Tech Stack:** POSIX shell, BitBake/Yocto (scarthgap), git

---

## File Map

**Create:**
- `platforms/xilinx/platform.conf`
- `platforms/xilinx/conf/local.conf.fragment`
- `platforms/xilinx/meta-xilinx-user/conf/layer.conf`
- `platforms/rockchip/platform.conf`
- `platforms/rockchip/conf/local.conf.fragment`
- `platforms/rockchip/meta-rockchip-user/conf/layer.conf`
- `platforms/nxp/platform.conf`
- `platforms/nxp/conf/local.conf.fragment`
- `platforms/nxp/meta-nxp-user/conf/layer.conf`
- `platforms/stm32mp/platform.conf`
- `platforms/stm32mp/conf/local.conf.fragment`
- `platforms/stm32mp/meta-stm32mp-user/conf/layer.conf`
- `platforms/raspberrypi/platform.conf`
- `platforms/raspberrypi/conf/local.conf.fragment`
- `platforms/raspberrypi/meta-rpi-user/conf/layer.conf`
- `platforms/tegra/platform.conf`
- `platforms/tegra/conf/local.conf.fragment`
- `platforms/tegra/meta-tegra-user/conf/layer.conf`
- `platforms/common/meta-user/conf/layer.conf`
- `platforms/common/meta-user/conf/user_extra.conf`

**Move (git mv):**
- `project-spec/meta-user/recipes-bsp/` → `platforms/xilinx/meta-xilinx-user/recipes-bsp/`
- `project-spec/meta-user/recipes-kernel/linux-xlnx/` → `platforms/xilinx/meta-xilinx-user/recipes-kernel/linux-xlnx/`
- `project-spec/meta-user/recipes-kernel/linux/` → `platforms/xilinx/meta-xilinx-user/recipes-kernel/linux/`
- `project-spec/meta-user/recipes-support/low-level-init/` → `platforms/xilinx/meta-xilinx-user/recipes-support/low-level-init/`
- `project-spec/meta-user/recipes-support/watchdog/` → `platforms/common/meta-user/recipes-support/watchdog/`

**Modify:**
- `configs/setup-env.sh` — replace two `case "$MACHINE_LAYER"` blocks + `usage()` + `clean_up`
- `configs/local-proj.conf` — remove all Xilinx-specific content

**Delete:**
- `project-spec/meta-user/conf/layer.conf`
- `project-spec/meta-user/conf/user_extra.conf`
- `project-spec/meta-user/` directory (after migrations)

**Update:**
- `.github/workflows/ci.yml` — add comment about matrix/platforms sync, enable Tegra

---

## Task 1: Create platform.conf for all 6 platforms

**Files:**
- Create: `platforms/xilinx/platform.conf`
- Create: `platforms/rockchip/platform.conf`
- Create: `platforms/nxp/platform.conf`
- Create: `platforms/stm32mp/platform.conf`
- Create: `platforms/raspberrypi/platform.conf`
- Create: `platforms/tegra/platform.conf`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p platforms/xilinx/conf platforms/xilinx/meta-xilinx-user/conf
mkdir -p platforms/rockchip/conf platforms/rockchip/meta-rockchip-user/conf
mkdir -p platforms/nxp/conf platforms/nxp/meta-nxp-user/conf
mkdir -p platforms/stm32mp/conf platforms/stm32mp/meta-stm32mp-user/conf
mkdir -p platforms/raspberrypi/conf platforms/raspberrypi/meta-rpi-user/conf
mkdir -p platforms/tegra/conf platforms/tegra/meta-tegra-user/conf
mkdir -p platforms/common/meta-user/conf
```

- [ ] **Step 2: Write `platforms/xilinx/platform.conf`**

```sh
# Xilinx ZynqMP / Zynq platform
# MACHINE_LAYER is derived from the BSP path by setup-env.sh
PLATFORM_MACHINE_LAYER="meta-xilinx"

# Extra BSP layers beyond the machine's own BSP layer
PLATFORM_BSP_LAYERS="\
    meta-xilinx-tools \
    meta-petalinux \
    meta-tpm \
    meta-microblaze \
    meta-xilinx-bsp \
    meta-xilinx-core \
    meta-xilinx-contrib \
    meta-xilinx-standalone \
    meta-qt5 \
    meta-virtualization \
    meta-openamp \
    meta-xilinx-tsn \
    "

PLATFORM_DISTRO="petalinux"
```

- [ ] **Step 3: Write `platforms/rockchip/platform.conf`**

```sh
# Rockchip platform
PLATFORM_MACHINE_LAYER="meta-rockchip"
PLATFORM_BSP_LAYERS="meta-rockchip"
PLATFORM_DISTRO="poky"
```

- [ ] **Step 4: Write `platforms/nxp/platform.conf`**

```sh
# NXP QorIQ platform
PLATFORM_MACHINE_LAYER="meta-freescale"
PLATFORM_BSP_LAYERS="meta-freescale meta-qoriq meta-freescale-distro"
PLATFORM_DISTRO="fsl-qoriq"
```

- [ ] **Step 5: Write `platforms/stm32mp/platform.conf`**

```sh
# STM32MP platform
PLATFORM_MACHINE_LAYER="meta-st-stm32mp"
PLATFORM_BSP_LAYERS="meta-st-stm32mp"
PLATFORM_DISTRO="poky"
```

- [ ] **Step 6: Write `platforms/raspberrypi/platform.conf`**

```sh
# Raspberry Pi platform
PLATFORM_MACHINE_LAYER="meta-raspberrypi"
PLATFORM_BSP_LAYERS="meta-raspberrypi"
PLATFORM_DISTRO="poky"
```

- [ ] **Step 7: Write `platforms/tegra/platform.conf`**

```sh
# NVIDIA Tegra platform
PLATFORM_MACHINE_LAYER="meta-tegra"
PLATFORM_BSP_LAYERS="meta-tegra"
PLATFORM_DISTRO="poky"
```

- [ ] **Step 8: Verify**

```bash
cat platforms/*/platform.conf | grep PLATFORM_MACHINE_LAYER
```

Expected output — 6 lines, one per platform:
```
PLATFORM_MACHINE_LAYER="meta-xilinx"
PLATFORM_MACHINE_LAYER="meta-freescale"
PLATFORM_MACHINE_LAYER="meta-rockchip"
PLATFORM_MACHINE_LAYER="meta-raspberrypi"
PLATFORM_MACHINE_LAYER="meta-st-stm32mp"
PLATFORM_MACHINE_LAYER="meta-tegra"
```

- [ ] **Step 9: Commit**

```bash
git add platforms/
git commit -m "platforms: add platform.conf for all 6 platforms"
```

---

## Task 2: Create local.conf.fragment for all 6 platforms

**Files:**
- Create: `platforms/xilinx/conf/local.conf.fragment`
- Create: `platforms/rockchip/conf/local.conf.fragment`
- Create: `platforms/nxp/conf/local.conf.fragment`
- Create: `platforms/stm32mp/conf/local.conf.fragment`
- Create: `platforms/raspberrypi/conf/local.conf.fragment`
- Create: `platforms/tegra/conf/local.conf.fragment`

- [ ] **Step 1: Write `platforms/xilinx/conf/local.conf.fragment`**

This consolidates content currently split between `setup-env.sh` (Xilinx case block, lines ~560-578) and `configs/local-proj.conf`.

```bitbake
# Xilinx-specific BitBake settings

# Kernel and device tree providers
PREFERRED_PROVIDER_virtual/kernel = "linux-xlnx"
PREFERRED_PROVIDER_virtual/dtb = "device-tree"
EXTRA_IMAGEDEPENDS += "device-tree"

# License acceptance
LICENSE_FLAGS_ACCEPTED = "xilinx"

# Use XSCT tarball for Xilinx tools
USE_XSCT_TARBALL = "1"

# Enable Xilinx ESW tools for XSA-based device tree generation
XILINX_WITH_ESW = "xsct"

# XSA hardware definition file path
HDF_MACHINE = "${MACHINE}"
HDF_BASE = "file://"
HDF_PATH = "${TOPDIR}/../components/descriptions/system.xsa"

# Retain work directories for key Xilinx artifacts (needed for boot artifact access)
RM_WORK_EXCLUDE += " \
    device-tree \
    petalinux-image-minimal \
    fsbl-firmware \
    u-boot-xlnx \
    u-boot-zynq-scr \
    arm-trusted-firmware \
    "

# Install Xilinx-specific init service
IMAGE_INSTALL:append = " low-level-init"
```

- [ ] **Step 2: Write `platforms/rockchip/conf/local.conf.fragment`**

```bitbake
# Rockchip-specific BitBake settings
PREFERRED_PROVIDER_virtual/kernel = "linux-rockchip"
```

- [ ] **Step 3: Write `platforms/nxp/conf/local.conf.fragment`**

```bitbake
# NXP QorIQ-specific BitBake settings
ACCEPT_FSL_EULA = "1"

# ls1028ardb GPU acceleration (uncomment when building for ls1028ardb):
# PREFERRED_VERSION_weston = "10.0.1.imx"
# PREFERRED_VERSION_wayland-protocols = "1.25.imx"
# PREFERRED_VERSION_libdrm = "2.4.109.imx"
# PREFERRED_PROVIDER_virtual/libgl = "imx-gpu-viv"
# PREFERRED_PROVIDER_virtual/libgles1 = "imx-gpu-viv"
# PREFERRED_PROVIDER_virtual/libgles2 = "imx-gpu-viv"
# PREFERRED_PROVIDER_virtual/egl = "imx-gpu-viv"
# LICENSE_FLAGS_ACCEPTED:append = " commercial"
```

- [ ] **Step 4: Write `platforms/stm32mp/conf/local.conf.fragment`**

```bitbake
# STM32MP-specific BitBake settings
PREFERRED_PROVIDER_virtual/kernel = "linux-stm32mp"
PREFERRED_PROVIDER_u-boot = "u-boot-stm32mp"
```

- [ ] **Step 5: Write `platforms/raspberrypi/conf/local.conf.fragment`**

```bitbake
# Raspberry Pi-specific BitBake settings
PREFERRED_PROVIDER_virtual/kernel = "linux-raspberrypi"
PREFERRED_PROVIDER_virtual/bootloader = "u-boot"
PREFERRED_PROVIDER_u-boot = "u-boot"

# Enable U-Boot
RPI_USE_U_BOOT = "1"

# Hardware interface enables
ENABLE_I2C = "1"
ENABLE_SPI = "1"
ENABLE_CAMERA = "1"
ENABLE_UART = "1"

# U-Boot environment
UBOOT_ENV_SIZE = "0x20000"
UBOOT_ENV_OFFSET = "0x100000"
```

- [ ] **Step 6: Write `platforms/tegra/conf/local.conf.fragment`**

```bitbake
# NVIDIA Tegra-specific BitBake settings
PREFERRED_PROVIDER_virtual/kernel = "linux-tegra"
```

- [ ] **Step 7: Verify**

```bash
find platforms -name "local.conf.fragment" | sort
```

Expected: 6 files, one per platform directory.

- [ ] **Step 8: Commit**

```bash
git add platforms/
git commit -m "platforms: add local.conf.fragment for all 6 platforms"
```

---

## Task 3: Create meta-*-user layer.conf skeletons

**Files:**
- Create: `platforms/xilinx/meta-xilinx-user/conf/layer.conf`
- Create: `platforms/rockchip/meta-rockchip-user/conf/layer.conf`
- Create: `platforms/nxp/meta-nxp-user/conf/layer.conf`
- Create: `platforms/stm32mp/meta-stm32mp-user/conf/layer.conf`
- Create: `platforms/raspberrypi/meta-rpi-user/conf/layer.conf`
- Create: `platforms/tegra/meta-tegra-user/conf/layer.conf`
- Create: `platforms/common/meta-user/conf/layer.conf`

- [ ] **Step 1: Write `platforms/xilinx/meta-xilinx-user/conf/layer.conf`**

Priority 6 — above common meta-user (priority 5) so Xilinx can override common recipes.

```bitbake
# We have a conf and classes directory, add to BBPATH
BBPATH .= ":${LAYERDIR}"

# We have recipes-* directories, add to BBFILES
BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
    ${LAYERDIR}/recipes-*/*/*.bbappend \
"

BBFILE_COLLECTIONS += "meta-xilinx-user"
BBFILE_PATTERN_meta-xilinx-user = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-xilinx-user = "6"

LAYERSERIES_COMPAT_meta-xilinx-user = "scarthgap"
LICENSE_PATH += "${LAYERDIR}/licenses"
```

- [ ] **Step 2: Write `platforms/rockchip/meta-rockchip-user/conf/layer.conf`**

```bitbake
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
    ${LAYERDIR}/recipes-*/*/*.bbappend \
"

BBFILE_COLLECTIONS += "meta-rockchip-user"
BBFILE_PATTERN_meta-rockchip-user = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-rockchip-user = "6"

LAYERSERIES_COMPAT_meta-rockchip-user = "scarthgap"
LICENSE_PATH += "${LAYERDIR}/licenses"
```

- [ ] **Step 3: Write `platforms/nxp/meta-nxp-user/conf/layer.conf`**

```bitbake
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
    ${LAYERDIR}/recipes-*/*/*.bbappend \
"

BBFILE_COLLECTIONS += "meta-nxp-user"
BBFILE_PATTERN_meta-nxp-user = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-nxp-user = "6"

LAYERSERIES_COMPAT_meta-nxp-user = "scarthgap"
LICENSE_PATH += "${LAYERDIR}/licenses"
```

- [ ] **Step 4: Write `platforms/stm32mp/meta-stm32mp-user/conf/layer.conf`**

```bitbake
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
    ${LAYERDIR}/recipes-*/*/*.bbappend \
"

BBFILE_COLLECTIONS += "meta-stm32mp-user"
BBFILE_PATTERN_meta-stm32mp-user = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-stm32mp-user = "6"

LAYERSERIES_COMPAT_meta-stm32mp-user = "scarthgap"
LICENSE_PATH += "${LAYERDIR}/licenses"
```

- [ ] **Step 5: Write `platforms/raspberrypi/meta-rpi-user/conf/layer.conf`**

```bitbake
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
    ${LAYERDIR}/recipes-*/*/*.bbappend \
"

BBFILE_COLLECTIONS += "meta-rpi-user"
BBFILE_PATTERN_meta-rpi-user = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-rpi-user = "6"

LAYERSERIES_COMPAT_meta-rpi-user = "scarthgap"
LICENSE_PATH += "${LAYERDIR}/licenses"
```

- [ ] **Step 6: Write `platforms/tegra/meta-tegra-user/conf/layer.conf`**

```bitbake
BBPATH .= ":${LAYERDIR}"

BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
    ${LAYERDIR}/recipes-*/*/*.bbappend \
"

BBFILE_COLLECTIONS += "meta-tegra-user"
BBFILE_PATTERN_meta-tegra-user = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-tegra-user = "6"

LAYERSERIES_COMPAT_meta-tegra-user = "scarthgap"
LICENSE_PATH += "${LAYERDIR}/licenses"
```

- [ ] **Step 7: Write `platforms/common/meta-user/conf/layer.conf`**

`watchdog-feeder` lives here. No `require user_extra.conf` needed — IMAGE_INSTALL managed by `user_extra.conf` via `require` below.

```bitbake
# We have a conf and classes directory, add to BBPATH
BBPATH .= ":${LAYERDIR}"

# We have recipes-* directories, add to BBFILES
BBFILES += "${LAYERDIR}/recipes-*/*/*.bb \
    ${LAYERDIR}/recipes-*/*/*.bbappend \
"

BBFILE_COLLECTIONS += "meta-user"
BBFILE_PATTERN_meta-user = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-user = "5"

LAYERSERIES_COMPAT_meta-user = "scarthgap"
LICENSE_PATH += "${LAYERDIR}/licenses"

require user_extra.conf
```

- [ ] **Step 8: Verify all layer.conf files**

```bash
find platforms -name layer.conf | sort
```

Expected: 7 files.

- [ ] **Step 9: Commit**

```bash
git add platforms/
git commit -m "platforms: add meta-*-user layer.conf skeletons"
```

---

## Task 4: Create platforms/common/meta-user content

**Files:**
- Create: `platforms/common/meta-user/conf/user_extra.conf`
- Move: `project-spec/meta-user/recipes-support/watchdog/` → `platforms/common/meta-user/recipes-support/watchdog/`

- [ ] **Step 1: Write `platforms/common/meta-user/conf/user_extra.conf`**

`low-level-init` removed — it is Xilinx-specific and installed via `platforms/xilinx/conf/local.conf.fragment`.

```bitbake
# Common IMAGE_INSTALL additions for all platforms
COMMON_TOOLS_IMAGE = " \
    mtd-utils \
    i2c-tools \
    util-linux \
    procps \
    mmc-utils \
    iproute2 \
    "

CORE_IMAGE_EXTRA_INSTALL = " \
    watchdog-feeder \
    "

IMAGE_INSTALL:append = " \
    ${COMMON_TOOLS_IMAGE} \
    ${CORE_IMAGE_EXTRA_INSTALL} \
    "
```

- [ ] **Step 2: Move watchdog-feeder recipe**

```bash
mkdir -p platforms/common/meta-user/recipes-support
git mv project-spec/meta-user/recipes-support/watchdog \
       platforms/common/meta-user/recipes-support/watchdog
```

- [ ] **Step 3: Verify**

```bash
ls platforms/common/meta-user/recipes-support/watchdog/
```

Expected: `files/watchdog-feeder.service  watchdog-feeder.bb`

- [ ] **Step 4: Commit**

```bash
git add platforms/common/
git commit -m "platforms: add common meta-user with watchdog-feeder and user_extra.conf"
```

---

## Task 5: Migrate Xilinx recipes to platforms/xilinx/meta-xilinx-user/

**Files:**
- Move: `project-spec/meta-user/recipes-bsp/` → `platforms/xilinx/meta-xilinx-user/recipes-bsp/`
- Move: `project-spec/meta-user/recipes-kernel/` → `platforms/xilinx/meta-xilinx-user/recipes-kernel/`
- Move: `project-spec/meta-user/recipes-support/low-level-init/` → `platforms/xilinx/meta-xilinx-user/recipes-support/low-level-init/`

- [ ] **Step 1: Move recipes-bsp**

```bash
git mv project-spec/meta-user/recipes-bsp \
       platforms/xilinx/meta-xilinx-user/recipes-bsp
```

- [ ] **Step 2: Move recipes-kernel**

```bash
git mv project-spec/meta-user/recipes-kernel \
       platforms/xilinx/meta-xilinx-user/recipes-kernel
```

- [ ] **Step 3: Move low-level-init**

```bash
mkdir -p platforms/xilinx/meta-xilinx-user/recipes-support
git mv project-spec/meta-user/recipes-support/low-level-init \
       platforms/xilinx/meta-xilinx-user/recipes-support/low-level-init
```

- [ ] **Step 4: Delete now-empty project-spec/meta-user/recipes-support/**

```bash
git rm -r project-spec/meta-user/recipes-support
```

- [ ] **Step 5: Verify**

```bash
find platforms/xilinx/meta-xilinx-user -type f | sort
```

Expected output (20 files):
```
platforms/xilinx/meta-xilinx-user/conf/layer.conf
platforms/xilinx/meta-xilinx-user/recipes-bsp/device-tree/device-tree.bbappend
platforms/xilinx/meta-xilinx-user/recipes-bsp/device-tree/files/system-conf.dtsi
platforms/xilinx/meta-xilinx-user/recipes-bsp/device-tree/files/system-user.dtsi
platforms/xilinx/meta-xilinx-user/recipes-bsp/embeddedsw/fsbl-firmware_%.bbappend
platforms/xilinx/meta-xilinx-user/recipes-bsp/embeddedsw/pmu-firmware_%.bbappend
platforms/xilinx/meta-xilinx-user/recipes-bsp/u-boot/files/boot-script
platforms/xilinx/meta-xilinx-user/recipes-bsp/u-boot/u-boot-xlnx-scr.bbappend
platforms/xilinx/meta-xilinx-user/recipes-bsp/u-boot/u-boot_%.bbappend
platforms/xilinx/meta-xilinx-user/recipes-kernel/linux-xlnx/files/0001-Add-driver-for-remaining-memory-domains.patch
platforms/xilinx/meta-xilinx-user/recipes-kernel/linux-xlnx/files/0002-SPI-add-multi-spidev.patch
platforms/xilinx/meta-xilinx-user/recipes-kernel/linux-xlnx/files/0003-Update-Motorcomm-PHY-driver-to-support-additional-PH.patch
platforms/xilinx/meta-xilinx-user/recipes-kernel/linux-xlnx/files/custom-kernel-config.cfg
platforms/xilinx/meta-xilinx-user/recipes-kernel/linux-xlnx/linux-xlnx_%.bbappend
platforms/xilinx/meta-xilinx-user/recipes-kernel/linux/config
platforms/xilinx/meta-xilinx-user/recipes-support/low-level-init/files/insert-dtbo.sh
platforms/xilinx/meta-xilinx-user/recipes-support/low-level-init/files/low-level-init.service
platforms/xilinx/meta-xilinx-user/recipes-support/low-level-init/files/low-level-init.sh
platforms/xilinx/meta-xilinx-user/recipes-support/low-level-init/files/netwk-setup.sh
platforms/xilinx/meta-xilinx-user/recipes-support/low-level-init/low-level-init.bb
```

- [ ] **Step 6: Commit**

```bash
git add platforms/xilinx/ project-spec/
git commit -m "platforms: migrate Xilinx recipes to platforms/xilinx/meta-xilinx-user"
```

---

## Task 6: Delete project-spec/meta-user/ and simplify local-proj.conf

**Files:**
- Delete: `project-spec/meta-user/conf/layer.conf`
- Delete: `project-spec/meta-user/conf/user_extra.conf`
- Modify: `configs/local-proj.conf`

- [ ] **Step 1: Delete remaining project-spec/meta-user conf files**

```bash
git rm project-spec/meta-user/conf/layer.conf
git rm project-spec/meta-user/conf/user_extra.conf
```

- [ ] **Step 2: Verify project-spec/meta-user/ is now empty**

```bash
find project-spec/meta-user -type f 2>/dev/null | wc -l
```

Expected: `0`

- [ ] **Step 3: Overwrite `configs/local-proj.conf`**

All Xilinx-specific content is now in `platforms/xilinx/conf/local.conf.fragment`.

```bitbake
# Project-wide BitBake settings (non-platform-specific)
# Platform-specific settings live in platforms/<name>/conf/local.conf.fragment

# INHERIT:remove = "uninative"
```

- [ ] **Step 4: Commit**

```bash
git add configs/local-proj.conf project-spec/
git commit -m "refactor: remove project-spec/meta-user, simplify local-proj.conf"
```

---

## Task 7: Refactor setup-env.sh — platform discovery and BSP layer loading

This task replaces the hardcoded `case "$MACHINE_LAYER" in` BSP block (current lines ~302–350) and adds platform discovery after machine detection. Make all edits to `configs/setup-env.sh`.

- [ ] **Step 1: Add PLATFORM_DIR to `clean_up` unset list**

Find this line in `clean_up()`:
```sh
    unset PROGNAME TOP_DIR OEROOTDIR FSLROOTDIR PROJECT_DIR \
         EULA EULA_FILE LAYER_LIST MACHINE MACHINE_LAYER FSLDISTRO EXTRAROOTDIR \
         OLD_OPTIND CPUS JOBS THREADS DOWNLOADS CACHES DISTRO \
         setup_flag setup_h setup_j setup_t setup_g setup_l setup_builddir \
         setup_download setup_sstate setup_error layer append_layer \
         valid_machine valid_num BASE_LAYER_LIST BSP_LAYER_LIST CACHE_MIRROR
```

Replace with:
```sh
    unset PROGNAME TOP_DIR OEROOTDIR PROJECT_DIR \
         EULA EULA_FILE LAYER_LIST MACHINE MACHINE_LAYER FSLDISTRO EXTRAROOTDIR \
         OLD_OPTIND CPUS JOBS THREADS DOWNLOADS CACHES DISTRO \
         PLATFORM_DIR PLATFORM_MACHINE_LAYER PLATFORM_BSP_LAYERS PLATFORM_DISTRO \
         setup_flag setup_h setup_j setup_t setup_g setup_l setup_builddir \
         setup_download setup_sstate setup_error layer append_layer \
         valid_machine valid_num BASE_LAYER_LIST BSP_LAYER_LIST CACHE_MIRROR
```

- [ ] **Step 2: Add platform discovery after MACHINE_LAYER detection**

Find this block (after the `else` branch in machine validation, after the `echo "Found machine..."` line):
```sh
        echo "Found machine '$MACHINE' in layer: $MACHINE_LAYER"
        valid_machine=true
    fi
```

Replace with:
```sh
        echo "Found machine '$MACHINE' in layer: $MACHINE_LAYER"

        # Discover which platform handles this MACHINE_LAYER
        PLATFORM_DIR=""
        for pconf in ${TOP_DIR}/platforms/*/platform.conf; do
            [ -f "$pconf" ] || continue
            unset PLATFORM_MACHINE_LAYER PLATFORM_BSP_LAYERS PLATFORM_DISTRO
            . "$pconf"
            if [ "$PLATFORM_MACHINE_LAYER" = "$MACHINE_LAYER" ]; then
                PLATFORM_DIR="$(dirname $pconf)"
                break
            fi
        done

        if [ -z "$PLATFORM_DIR" ]; then
            echo "ERROR: No platform config found for layer '$MACHINE_LAYER'"
            echo "Create platforms/<name>/platform.conf with PLATFORM_MACHINE_LAYER=\"$MACHINE_LAYER\""
            clean_up && return
        fi
        echo "Using platform: $(basename $PLATFORM_DIR)"
        valid_machine=true
    fi
```

- [ ] **Step 3: Replace hardcoded BSP case block with platform.conf sourcing**

Find and delete this entire block (from `# Define BSP layer list based on machine type` through the closing `esac`):
```sh
# Define BSP layer list based on machine type
BSP_LAYER_LIST=""
case "$MACHINE_LAYER" in
    meta-freescale)
        ...
    meta-tegra)
        BSP_LAYER_LIST="meta-tegra"
        DISTRO="poky"
        ;;
    *)
        echo "ERROR: Layer not find"
        return
        ;;
esac
```

Replace with:
```sh
# Load platform configuration (BSP layers and DISTRO)
. "${PLATFORM_DIR}/platform.conf"
BSP_LAYER_LIST="$PLATFORM_BSP_LAYERS"
DISTRO="$PLATFORM_DISTRO"
```

- [ ] **Step 4: Replace hardcoded EULA_FILE case block**

Find and delete:
```sh
# Set EULA file based on BSP layer
case "$MACHINE_LAYER" in
    meta-freescale)
        EULA_FILE="$FSLROOTDIR/EULA"
        ;;
    *)
        EULA_FILE=""
        ;;
esac
```

Replace with:
```sh
# EULA acceptance is handled per-platform via local.conf.fragment
EULA_FILE=""
```

- [ ] **Step 5: Verify the file parses without errors**

```bash
bash -n configs/setup-env.sh && echo "Syntax OK"
```

Expected: `Syntax OK`

- [ ] **Step 6: Commit**

```bash
git add configs/setup-env.sh
git commit -m "setup-env: replace hardcoded BSP case block with platform.conf auto-discovery"
```

---

## Task 8: Refactor setup-env.sh — local.conf fragment loading and platform layer loading

This task replaces the second hardcoded `case "$MACHINE_LAYER"` block (local.conf additions, current lines ~500–635) and adds automatic loading of `platforms/<name>/meta-*/` layers.

- [ ] **Step 1: Replace the machine-specific local.conf case block**

Find and delete this entire block (from `# Add machine-specific configurations` through the closing `esac` before `for s in $HOME/.oe`):

```sh
# Add machine-specific configurations
case "$MACHINE_LAYER" in
    meta-freescale)
        ...
    meta-tegra)
        ...
        ;;
esac
```

Replace with:
```sh
# Load platform-specific local.conf settings
if [ -e "${PLATFORM_DIR}/conf/local.conf.fragment" ]; then
    cat "${PLATFORM_DIR}/conf/local.conf.fragment" >> conf/local.conf
fi

# Apply cache mirror settings if configured (applies to all platforms)
if [ -n "$CACHE_MIRROR" ]; then
    cat >> conf/local.conf <<-EOF

# Pre-mirrors
PREMIRRORS:prepend = "\
git://.*/.* file://$CACHE_MIRROR/downloads/ \
ftp://.*/.* file://$CACHE_MIRROR/downloads/ \
http://.*/.* file://$CACHE_MIRROR/downloads/ \
https://.*/.* file://$CACHE_MIRROR/downloads/"

# State mirror
SSTATE_MIRRORS = " \
file://.* file://$CACHE_MIRROR/sstate-cache/PATH"

EOF
fi
```

- [ ] **Step 2: Add platform meta-* layer loading after the project-spec layer loop**

Find this block (the loop that adds `project-spec/meta-*` layers):
```sh
# add all meta-* layers under project-spec to bblayers.conf
for layer_dir in "${TOP_DIR}"/project-spec/meta-*; do
    if [ -d "$layer_dir" ]; then
        append_layer="$(readlink -f "$layer_dir")"
        echo "Adding layer: $append_layer"
        awk '/  "$/ && !x {print "'"  ${append_layer}"' \\"; x=1} 1' \
            conf/bblayers.conf > conf/bblayers.conf~
        mv conf/bblayers.conf~ conf/bblayers.conf
    fi
done
```

Append immediately after (keeping the project-spec loop intact):
```sh
# Add platform-specific and common meta-* layers
for layer_dir in "${PLATFORM_DIR}"/meta-* "${TOP_DIR}/platforms/common"/meta-*; do
    if [ -d "$layer_dir" ] && [ -e "${layer_dir}/conf/layer.conf" ]; then
        append_layer="$(readlink -f "$layer_dir")"
        echo "Adding layer: $append_layer"
        awk '/  "$/ && !x {print "'"  ${append_layer}"' \\"; x=1} 1' \
            conf/bblayers.conf > conf/bblayers.conf~
        mv conf/bblayers.conf~ conf/bblayers.conf
    fi
done
```

- [ ] **Step 3: Remove the now-unused EULA interactive logic and FSLROOTDIR**

Find and delete this entire block (after the `for s in $HOME/.oe` loop):
```sh
# Handle EULA setting (only for Freescale/NXP)
if [ "$MACHINE_LAYER" = "meta-freescale" ] && [ -n "$EULA_FILE" ]; then
    ...
fi
```

NXP EULA is now handled by `ACCEPT_FSL_EULA = "1"` in `platforms/nxp/conf/local.conf.fragment`.

Also remove the now-unused `FSLROOTDIR` variable declaration (near the top of the file, after `OEROOTDIR` definition):
```sh
FSLROOTDIR=${TOP_DIR}/components/layers/bsp/nxp/meta-freescale
```

And remove `FSLROOTDIR` from the `unset` list in `clean_up` (already updated in Task 7 Step 1 — verify it is absent).

- [ ] **Step 4: Verify syntax**

```bash
bash -n configs/setup-env.sh && echo "Syntax OK"
```

Expected: `Syntax OK`

- [ ] **Step 5: Commit**

```bash
git add configs/setup-env.sh
git commit -m "setup-env: replace local.conf case block with fragment loading, add platform layer auto-load"
```

---

## Task 9: Refactor setup-env.sh — generic usage()

This task replaces the per-platform hardcoded `find` calls in `usage()` with a loop over `platforms/*/platform.conf`.

- [ ] **Step 1: Replace the `usage()` function body**

Find the entire `usage()` function and replace it with:

```sh
usage() {
    echo "Usage: . $PROGNAME -m <machine> [options]"

    echo -e "\n    Supported machines:"
    for pconf in ${TOP_DIR}/platforms/*/platform.conf; do
        [ -f "$pconf" ] || continue
        unset PLATFORM_MACHINE_LAYER PLATFORM_BSP_LAYERS PLATFORM_DISTRO
        . "$pconf"
        platform_name="$(basename $(dirname $pconf))"
        echo "    ${platform_name} machines:"
        find ${TOP_DIR}/components/layers/bsp -name "*.conf" 2>/dev/null | \
            while read conf; do
                layer=$(echo "$conf" | sed 's,.*/components/layers/bsp/[^/]*/meta-\([^/]*\)/.*,meta-\1,')
                if [ "$layer" = "$PLATFORM_MACHINE_LAYER" ]; then
                    echo "$conf" | sed 's,.*/,,g;s,.conf,,g'
                fi
            done | sort | while read m; do echo "      $m"; done
    done

    echo -e "\n    Optional parameters:
    * [-m machine]: the target machine to be built (required).
    * [-j jobs]:    number of jobs for make to spawn during the compilation stage.
    * [-t tasks]:   number of BitBake tasks that can be issued in parallel.
    * [-b path]:    non-default path of project build folder.
    * [-d path]:    non-default path of DL_DIR (downloaded source)
    * [-c path]:    non-default path of SSTATE_DIR (shared state Cache)
    * [-h]:         help
"
    echo "    Examples:"
    echo "      . $PROGNAME -m zynqmp-generic"
    echo "      . $PROGNAME -m rk3568-evb -j 8 -t 4"
    echo "      . $PROGNAME -m ls1043ardb -b /path/to/build"

    if [ "\`readlink $SHELL\`" = "dash" ];then
        echo "
    You are using dash which does not pass args when being sourced.
    To workaround this limitation, use \"set -- args\" prior to
    sourcing this script. For example:
        \$ set -- -m ls1088ardb -j 3 -t 2
        \$ . $TOP_DIR/configs/$PROGNAME
"
    fi
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n configs/setup-env.sh && echo "Syntax OK"
```

Expected: `Syntax OK`

- [ ] **Step 3: Verify help output lists platforms**

```bash
set -- -h; . configs/setup-env.sh
```

Expected: prints `xilinx machines:`, `nxp machines:`, `rockchip machines:`, etc. (order depends on filesystem). If submodules are not initialized, machine lists will be empty — this is expected.

- [ ] **Step 4: Commit**

```bash
git add configs/setup-env.sh
git commit -m "setup-env: generic usage() via platforms/ auto-discovery"
```

---

## Task 10: Update CI

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Add sync comment and enable Tegra in matrix**

Find:
```yaml
    strategy:
      fail-fast: false
      matrix:
        machine:
          - zynqmp-generic
          - ls1043ardb
          - rk3568-evb
          - stm32mp15-common
          - raspberrypi4-64
```

Replace with:
```yaml
    strategy:
      fail-fast: false
      matrix:
        # Keep this list in sync with platforms/ directory.
        # Each entry must have a corresponding platforms/<name>/platform.conf.
        machine:
          - zynqmp-generic
          - ls1043ardb
          - rk3568-evb
          - stm32mp15-common
          - raspberrypi4-64
          # tegra210-generic  # enable after local parse-only validation passes
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add matrix sync comment, note Tegra pending validation"
```

---

## Task 11: End-to-end validation

Validate that `setup-env.sh` correctly configures each platform. Submodules must be initialized for this step.

- [ ] **Step 1: Initialize submodules if not already done**

```bash
git submodule update --init --recursive
```

- [ ] **Step 2: Validate Xilinx**

```bash
rm -rf build
. configs/setup-env.sh -m zynqmp-generic
. build/SOURCE_THIS
bitbake-layers show-layers 2>&1 | grep -E "meta-xilinx-user|meta-user|meta-petalinux"
```

Expected: `meta-xilinx-user` (priority 6) and `meta-user` (priority 5) both appear.

```bash
bitbake-getvar --value DISTRO
```

Expected: `petalinux`

```bash
bitbake -p 2>&1 | tail -5
```

Expected: no ERROR lines.

- [ ] **Step 3: Validate NXP**

```bash
rm -rf build
. configs/setup-env.sh -m ls1043ardb
. build/SOURCE_THIS
bitbake-getvar --value DISTRO
```

Expected: `fsl-qoriq`

```bash
bitbake-getvar --value ACCEPT_FSL_EULA
```

Expected: `1`

```bash
bitbake -p 2>&1 | grep -i error | grep -v WARNING | grep -v "NOTE:" | head -10
```

Expected: no unexpected errors (known warning about LAYERSERIES_COMPAT from meta-qoriq is acceptable).

- [ ] **Step 4: Validate Rockchip**

```bash
rm -rf build
. configs/setup-env.sh -m rk3568-evb
. build/SOURCE_THIS
bitbake-getvar --value PREFERRED_PROVIDER_virtual/kernel
```

Expected: `linux-rockchip`

```bash
bitbake -p 2>&1 | tail -5
```

Expected: no ERROR lines.

- [ ] **Step 5: Validate STM32MP**

```bash
rm -rf build
. configs/setup-env.sh -m stm32mp15-common
. build/SOURCE_THIS
bitbake-getvar --value PREFERRED_PROVIDER_virtual/kernel
```

Expected: `linux-stm32mp`

```bash
bitbake -p 2>&1 | tail -5
```

Expected: no ERROR lines.

- [ ] **Step 6: Validate Raspberry Pi**

```bash
rm -rf build
. configs/setup-env.sh -m raspberrypi4-64
. build/SOURCE_THIS
bitbake-getvar --value RPI_USE_U_BOOT
```

Expected: `1`

```bash
bitbake -p 2>&1 | tail -5
```

Expected: no ERROR lines.

- [ ] **Step 7: Final commit with summary**

```bash
git add -A
git commit -m "refactor: complete generic multi-platform restructure

- platforms/<name>/ contains platform.conf, local.conf.fragment, meta-*-user/
- setup-env.sh auto-discovers platforms via platforms/*/platform.conf
- Zero hardcoded platform logic in setup-env.sh or local-proj.conf
- Xilinx recipes in platforms/xilinx/meta-xilinx-user/
- Common recipes in platforms/common/meta-user/
- Adding a new SOC: create platforms/<name>/ directory only"
```

---

## Adding a New SOC Platform (Reference)

After this refactoring, the complete workflow to add a new platform is:

```bash
# 1. Add BSP submodule
git submodule add <url> components/layers/bsp/<vendor>/meta-<name>

# 2. Create platform directory structure
mkdir -p platforms/<name>/conf platforms/<name>/meta-<name>-user/conf

# 3. Write platform.conf
cat > platforms/<name>/platform.conf <<'EOF'
PLATFORM_MACHINE_LAYER="meta-<name>"
PLATFORM_BSP_LAYERS="meta-<name>"
PLATFORM_DISTRO="poky"
EOF

# 4. Write local.conf.fragment
cat > platforms/<name>/conf/local.conf.fragment <<'EOF'
PREFERRED_PROVIDER_virtual/kernel = "linux-<name>"
EOF

# 5. Write meta-<name>-user/conf/layer.conf (copy from any existing platform, update names)

# 6. Test
. configs/setup-env.sh -m <machine-name>
. build/SOURCE_THIS && bitbake -p

# 7. Add to CI matrix in .github/workflows/ci.yml
```
