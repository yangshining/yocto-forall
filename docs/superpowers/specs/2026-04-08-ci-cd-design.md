# CI/CD Design: Multi-Platform Yocto Parse Validation

**Date**: 2026-04-08  
**Status**: Approved  
**Scope**: GitHub Actions workflow for syntax and layer configuration validation across all supported platforms

---

## Problem

The repository has no automated validation. Errors in BitBake recipe syntax, layer configuration, or `bbappend` targets go undetected until a developer manually runs a build. With multiple hardware platforms and 19 git submodules, configuration drift is a real risk.

## Goal

Catch the most common classes of errors on every PR and push to `main`, without requiring actual compilation (which takes 2–8 hours and needs powerful hardware):

- Layer path errors (missing submodule, wrong path in bblayers.conf)
- Recipe syntax errors (malformed `.bb` / `.bbappend` files)
- `bbappend` targeting non-existent recipes
- Variable conflicts between layers
- Layer compatibility declaration mismatches

## Approach

**`bitbake -p` (parse-only)** on all supported platforms in a GitHub Actions matrix. This is the standard lightweight CI approach in the Yocto community. It runs entirely on GitHub-hosted `ubuntu-22.04` runners at no cost and completes in ~10–20 minutes.

Not in scope for this version: actual image builds, sstate caching, artifact upload, or Slack/email notifications.

---

## Pre-Implementation Fix Required

Before the workflow can be created, one existing file must be fixed:

### Fix `configs/local-proj.conf`: absolute `HDF_PATH`

`local-proj.conf` line 20 contains a hardcoded absolute path:
```
HDF_PATH = "/home2/yang.xu/tool/sources/yocto-forall/components/descriptions/system.xsa"
```

This file is unconditionally copied into `build/conf/` for every platform during `setup-env.sh`. On a GitHub runner the path does not exist, causing `bitbake -p` to fail for `zynqmp-generic`.

**Fix**: Replace with a path relative to `TOPDIR` (which is `build/` after `oe-init-build-env`):
```bitbake
HDF_PATH = "${TOPDIR}/../components/descriptions/system.xsa"
```

The file `components/descriptions/system.xsa` already exists in the repository (692 KB), so this path resolves correctly on any checkout.

---

## Workflow Design

### File

`.github/workflows/ci.yml`

### Triggers

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

### Platform Matrix

`setup-env.sh` supports 5 platforms (Xilinx, NXP, Rockchip, STM32MP, Raspberry Pi). Tegra is **excluded** because `setup-env.sh` has no `meta-tegra` case in its BSP switch — it hits the `*` wildcard and returns an error. Tegra support must be added to `setup-env.sh` before it can be validated in CI.

| Machine | Platform | Special handling |
|---------|----------|-----------------|
| `zynqmp-generic` | Xilinx ZynqMP | requires `HDF_PATH` fix above |
| `ls1043ardb` | NXP QorIQ | EULA auto-accepted by `setup-env.sh` — no extra step needed |
| `rk3568-evb` | Rockchip RK3568 | none |
| `stm32mp15-common` | STMicroelectronics STM32MP | none |
| `raspberrypi4-64` | Raspberry Pi 4 | none |

### Host Dependencies

Install the official Yocto scarthgap package list for ubuntu-22.04:

```bash
sudo apt-get update
sudo apt-get install -y \
  gawk wget git diffstat unzip texinfo gcc build-essential \
  chrpath socat cpio python3 python3-pip python3-pexpect \
  xz-utils debianutils iputils-ping python3-git python3-jinja2 \
  libegl1-mesa libsdl1.2-dev pylint xterm python3-subunit \
  mesa-common-dev zstd liblz4-tool file locales libacl1
```

### Job Steps (per matrix entry)

1. **Checkout** with submodules — `timeout-minutes: 30` on this step (19 submodules over public git hosts)
   ```yaml
   uses: actions/checkout@v4
   with:
     submodules: recursive
     fetch-depth: 1
   ```
   Note: `fetch-depth: 1` applies to the parent repo. Submodule checkout uses the pinned commit from `.gitmodules`; `actions/checkout` fetches submodules at full depth by default unless `submodules-fetch-depth` is specified (added in v4.2+). For parse-only validation, full submodule history is not needed — set `submodules-fetch-depth: 1` if on v4.2+.

2. **Install host dependencies** (see package list above)

3. **Initialize build environment**
   ```bash
   . configs/setup-env.sh -m ${{ matrix.machine }}
   ```
   Note: the actual script is `configs/setup-env.sh`, not `configs/setup-env`.

4. **Layer check**
   ```bash
   bitbake-layers show-layers
   ```

5. **Parse validation**
   ```bash
   bitbake -p
   ```

### Timeouts

- Per-job timeout: `60` minutes
- Step 1 (checkout) timeout: `30` minutes — set `timeout-minutes: 30` on the checkout step

### Job Naming

```
Validate [zynqmp-generic]
Validate [ls1043ardb]
Validate [rk3568-evb]
Validate [stm32mp15-common]
Validate [raspberrypi4-64]
```

Each job is independently reported in the PR checks list, so a failure on one platform does not obscure the status of others.

### Known Pre-existing Issues

- **NXP layer compatibility warning**: `meta-qoriq` declares `LAYERSERIES_COMPAT = "honister kirkstone master"` while the project uses `scarthgap`. `bitbake -p` will emit a layer compatibility warning for `ls1043ardb`. This is a pre-existing issue in the repo — CI will expose it, which is the correct behavior.

### Error Handling

- Non-zero exit from `bitbake -p` → job fails → PR blocked
- BitBake error output is printed to stdout and visible in the GitHub Actions job log

---

## What This Does Not Cover

- Actual image compilation (requires self-hosted runner with 50+ GB disk, 8+ cores)
- Tegra platform (requires `setup-env.sh` to add `meta-tegra` case first)
- Boot artifact verification
- sstate cache (can be added later once baseline is stable)
- Upstream submodule drift detection (scheduled builds can be added in a follow-up)

---

## File Changes

| File | Change |
|------|--------|
| `configs/local-proj.conf` | Fix `HDF_PATH` to use `${TOPDIR}/../` relative path |
| `.github/workflows/ci.yml` | New file |
