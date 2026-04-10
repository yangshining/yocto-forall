# Generic Multi-Platform Yocto Build Repo — Design Spec

**Date:** 2026-04-10  
**Status:** Approved  
**Scope:** Restructure repo to support generic multi-SOC Yocto builds with clean per-platform isolation and easy extensibility.

---

## Goal

Make the repo fully generic so that:
1. Each SOC platform is self-contained and does not pollute the shared framework.
2. Adding a new platform requires no changes to `setup-env.sh` or any shared file.
3. SOC-specific patches and recipes live in `platforms/<name>/meta-<name>-user/`; generic cross-platform recipes live in `platforms/common/meta-user/`.
4. The repo can be forked and used as a starting point for any multi-BSP Yocto project.

Breaking changes to the existing setup are acceptable.

---

## Directory Structure

```
platforms/
  common/
    meta-user/
      conf/layer.conf               # Priority 5
      conf/user_extra.conf          # IMAGE_INSTALL cross-platform tools
      recipes-support/
        watchdog-feeder/
        low-level-init/

  xilinx/
    platform.conf                   # MACHINE_LAYER, BSP layers, DISTRO declaration
    conf/local.conf.fragment        # Xilinx-specific BitBake settings
    meta-xilinx-user/
      conf/layer.conf               # Priority 6
      recipes-bsp/
        device-tree/
        embeddedsw/                 # FSBL, PMU firmware appends
        u-boot/
      recipes-kernel/
        linux-xlnx/                 # Kernel patches and config fragments

  rockchip/
    platform.conf
    conf/local.conf.fragment
    meta-rockchip-user/
      conf/layer.conf               # Empty shell, ready for future recipes

  nxp/
    platform.conf
    conf/local.conf.fragment
    meta-nxp-user/
      conf/layer.conf

  stm32mp/
    platform.conf
    conf/local.conf.fragment
    meta-stm32mp-user/
      conf/layer.conf

  raspberrypi/
    platform.conf
    conf/local.conf.fragment
    meta-rpi-user/
      conf/layer.conf

  tegra/
    platform.conf
    conf/local.conf.fragment
    meta-tegra-user/
      conf/layer.conf

configs/
  setup-env.sh                      # Fully generic, zero platform-specific code
  local-proj.conf                   # Only non-platform-specific project settings

project-spec/                       # Optional: project-level overrides (not platform-specific)
  meta-<projectname>/               # Created by user if needed

components/                         # Unchanged
  layers/
    core/
    bsp/
    tools/
  descriptions/
```

---

## `platform.conf` Format

Each `platforms/<name>/platform.conf` is sourced by `setup-env.sh` and must define these shell variables:

```sh
# Which MACHINE_LAYER value (auto-detected from BSP) this platform handles
PLATFORM_MACHINE_LAYER="meta-xilinx"

# Extra BSP layers to add beyond the machine's own layer (space-separated)
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

# BitBake DISTRO for this platform
PLATFORM_DISTRO="petalinux"
```

---

## `setup-env.sh` Refactoring

All platform-specific `case` blocks are removed. The script becomes fully generic through five changes:

### 1. Platform discovery after MACHINE_LAYER detection

```sh
PLATFORM_DIR=""
for pconf in ${TOP_DIR}/platforms/*/platform.conf; do
    . $pconf
    if [ "$PLATFORM_MACHINE_LAYER" = "$MACHINE_LAYER" ]; then
        PLATFORM_DIR="$(dirname $pconf)"
        break
    fi
done

if [ -z "$PLATFORM_DIR" ]; then
    echo "ERROR: No platform found for MACHINE_LAYER '$MACHINE_LAYER'"
    clean_up && return
fi
```

### 2. BSP layer list from platform.conf (replaces hardcoded case block)

```sh
. ${PLATFORM_DIR}/platform.conf
BSP_LAYER_LIST="$PLATFORM_BSP_LAYERS"
DISTRO="$PLATFORM_DISTRO"
```

### 3. local.conf platform fragment (replaces hardcoded case block)

```sh
if [ -e "${PLATFORM_DIR}/conf/local.conf.fragment" ]; then
    cat ${PLATFORM_DIR}/conf/local.conf.fragment >> conf/local.conf
fi
```

### 4. Automatic layer loading for platform and common meta-* directories

```sh
for layer_dir in "${PLATFORM_DIR}"/meta-* "${TOP_DIR}/platforms/common"/meta-*; do
    if [ -d "$layer_dir" ] && [ -e "$layer_dir/conf/layer.conf" ]; then
        echo "Adding layer: $layer_dir"
        awk '/  "$/ && !x {print "'"  ${layer_dir}"' \\"; x=1} 1' \
            conf/bblayers.conf > conf/bblayers.conf~
        mv conf/bblayers.conf~ conf/bblayers.conf
    fi
done
```

### 5. usage() auto-lists machines per platform

Machine conf files do not declare their layer — the layer is derived from the directory path using the same sed regex as the main machine detection logic. For each platform, we filter all BSP machine confs to those whose derived MACHINE_LAYER matches `PLATFORM_MACHINE_LAYER`:

```sh
for pconf in ${TOP_DIR}/platforms/*/platform.conf; do
    platform_name="$(basename $(dirname $pconf))"
    . $pconf
    echo "    ${platform_name} machines:"
    find ${TOP_DIR}/components/layers/bsp -name "*.conf" 2>/dev/null | \
        while read conf; do
            layer=$(echo "$conf" | sed 's,.*/components/layers/bsp/[^/]*/meta-\([^/]*\)/.*,meta-\1,')
            if [ "$layer" = "$PLATFORM_MACHINE_LAYER" ]; then
                echo "$conf" | sed 's,.*/,,g;s,.conf,,g'
            fi
        done | sort | while read m; do echo "      $m"; done
done
```

---

## File Migration Map

| Current location | New location |
|-----------------|-------------|
| `project-spec/meta-user/recipes-bsp/` | `platforms/xilinx/meta-xilinx-user/recipes-bsp/` |
| `project-spec/meta-user/recipes-kernel/` | `platforms/xilinx/meta-xilinx-user/recipes-kernel/` |
| `project-spec/meta-user/recipes-support/` | `platforms/common/meta-user/recipes-support/` |
| `project-spec/meta-user/conf/user_extra.conf` | `platforms/common/meta-user/conf/user_extra.conf` |
| `project-spec/meta-user/conf/layer.conf` | Split: `platforms/common/meta-user/conf/layer.conf` + `platforms/xilinx/meta-xilinx-user/conf/layer.conf` |
| `configs/local-proj.conf` (Xilinx-specific lines) | `platforms/xilinx/conf/local.conf.fragment` |
| `setup-env.sh` Xilinx local.conf block | `platforms/xilinx/conf/local.conf.fragment` |
| `setup-env.sh` Rockchip local.conf block | `platforms/rockchip/conf/local.conf.fragment` |
| `setup-env.sh` RPi local.conf block | `platforms/raspberrypi/conf/local.conf.fragment` |
| `setup-env.sh` STM32MP local.conf block | `platforms/stm32mp/conf/local.conf.fragment` |
| `setup-env.sh` NXP local.conf block | `platforms/nxp/conf/local.conf.fragment` |
| `setup-env.sh` Tegra local.conf block | `platforms/tegra/conf/local.conf.fragment` |
| `project-spec/meta-user/` | Deleted (fully migrated) |

---

## `configs/local-proj.conf` After Refactoring

Only project-wide, non-platform-specific settings remain. After migration this file will be nearly empty — a placeholder for future project-wide settings:

```bitbake
# Project-wide BitBake settings (non-platform-specific)
# Platform-specific settings live in platforms/<name>/conf/local.conf.fragment

# INHERIT:remove = "uninative"
```

All Xilinx-specific lines (`HDF_PATH`, `XILINX_WITH_ESW`, `PREFERRED_PROVIDER_virtual/dtb`, `RM_WORK_EXCLUDE` for Xilinx-specific recipes) move to `platforms/xilinx/conf/local.conf.fragment`.

---

## CI Changes

`.github/workflows/ci.yml` changes are minimal:

1. Matrix remains manually maintained (GitHub Actions cannot dynamically read files for matrix values). Add a comment requiring it to stay in sync with `platforms/` directories.
2. Tegra can be uncommented in the matrix once `platforms/tegra/platform.conf` is validated locally.
3. No changes to job steps — `setup-env.sh` command is unchanged.

---

## How to Add a New SOC Platform (After Refactoring)

```
1. git submodule add <bsp-repo-url> components/layers/bsp/<vendor>/meta-<name>
2. mkdir -p platforms/<name>/conf platforms/<name>/meta-<name>-user/conf
3. Write platforms/<name>/platform.conf
      → set PLATFORM_MACHINE_LAYER, PLATFORM_BSP_LAYERS, PLATFORM_DISTRO
4. Write platforms/<name>/conf/local.conf.fragment
      → PREFERRED_PROVIDER_virtual/kernel and any other platform settings
5. Write platforms/<name>/meta-<name>-user/conf/layer.conf
      → minimal layer declaration, LAYERSERIES_COMPAT = "scarthgap"
6. (Optional) Add recipes under meta-<name>-user/ for SOC-specific patches
7. Add machine to CI matrix in .github/workflows/ci.yml
```

No changes to `setup-env.sh`, `local-proj.conf`, or any shared file.

---

## Out of Scope

- NXP layer compatibility fix (`meta-qoriq` LAYERSERIES_COMPAT) — separate task
- U-Boot recipe completion for non-Xilinx platforms — separate task
- CI image-level builds (beyond parse-only) — separate task
