# CI/CD Design: Multi-Platform Yocto Parse Validation

**Date**: 2026-04-08  
**Status**: Approved  
**Scope**: GitHub Actions workflow for syntax and layer configuration validation across all 6 supported platforms

---

## Problem

The repository has no automated validation. Errors in BitBake recipe syntax, layer configuration, or `bbappend` targets go undetected until a developer manually runs a build. With 6 hardware platforms and 20 git submodules, configuration drift is a real risk.

## Goal

Catch the most common classes of errors on every PR and push to `main`, without requiring actual compilation (which takes 2–8 hours and needs powerful hardware):

- Layer path errors (missing submodule, wrong path in bblayers.conf)
- Recipe syntax errors (malformed `.bb` / `.bbappend` files)
- `bbappend` targeting non-existent recipes
- Variable conflicts between layers
- Layer compatibility declaration mismatches

## Approach

**`bitbake -p` (parse-only)** on all 6 platforms in a GitHub Actions matrix. This is the standard lightweight CI approach in the Yocto community. It runs entirely on GitHub-hosted `ubuntu-22.04` runners at no cost and completes in ~10–20 minutes.

Not in scope for this version: actual image builds, sstate caching, artifact upload, or Slack/email notifications.

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

All 6 configured platforms run as independent parallel jobs:

| Machine | Platform | Special handling |
|---------|----------|-----------------|
| `zynqmp-generic` | Xilinx ZynqMP | none |
| `ls1043ardb` | NXP QorIQ | `ACCEPT_FSL_EULA=1` required |
| `rk3568-evb` | Rockchip RK3568 | none |
| `stm32mp15-common` | STMicroelectronics STM32MP | none |
| `raspberrypi4-64` | Raspberry Pi 4 | none |
| `tegra210-generic` | NVIDIA Tegra 210 | none |

### Job Steps (per matrix entry)

1. **Checkout** with submodules (shallow, `--depth=1` to minimize transfer)
2. **Install Yocto host dependencies** via `apt-get` (standard Yocto scarthgap package list)
3. **Set NXP EULA** env var (only for `ls1043ardb`)
4. **Initialize build environment**: `. configs/setup-env -m ${{ matrix.machine }}`
5. **Layer check**: `bitbake-layers show-layers` — confirms all layer paths resolve
6. **Parse validation**: `bitbake -p` — parses all recipes, fails on any syntax or configuration error

### Timeouts

- Per-job timeout: `60` minutes
- Submodule checkout step timeout: `30` minutes (20 submodules over public git hosts can be slow)

### Job Naming

```
Validate [zynqmp-generic]
Validate [ls1043ardb]
Validate [rk3568-evb]
Validate [stm32mp15-common]
Validate [raspberrypi4-64]
Validate [tegra210-generic]
```

Each job is independently reported in the PR checks list, so a failure on one platform does not obscure the status of others.

### Error Handling

- Non-zero exit from `bitbake -p` → job fails → PR blocked
- BitBake error output is printed to stdout and visible in the GitHub Actions job log
- No special log upload needed; the inline output is sufficient for parse errors

---

## What This Does Not Cover

- Actual image compilation (requires self-hosted runner with 50+ GB disk, 8+ cores)
- Boot artifact verification
- sstate cache (can be added later once baseline is stable)
- Upstream submodule drift detection (scheduled builds can be added in a follow-up)

---

## File Structure After Implementation

```
.github/
└── workflows/
    └── ci.yml          ← new file
```

No other files are added or modified.
