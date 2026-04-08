# CI/CD Multi-Platform Parse Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add GitHub Actions CI that validates BitBake recipe syntax and layer configuration for all 5 supported hardware platforms on every PR and push to main.

**Architecture:** Two file changes — fix a hardcoded absolute path in `configs/local-proj.conf` that breaks portability, then create `.github/workflows/ci.yml` that runs `bitbake -p` (parse-only, no compilation) in a 5-platform matrix on ubuntu-22.04 hosted runners. Each job re-sources `build/SOURCE_THIS` between steps to restore the BitBake environment in fresh shells.

**Tech Stack:** GitHub Actions, BitBake (Yocto scarthgap), ubuntu-22.04 runners, `actions/checkout@v4`

---

## Background: How `SOURCE_THIS` Works

`setup-env.sh` generates `build/SOURCE_THIS` containing:
```sh
#!/bin/sh
cd <poky-dir>
set -- <build-dir>
. ./oe-init-build-env > /dev/null
```

Sourcing `SOURCE_THIS` calls `oe-init-build-env`, which adds `bitbake/bin` and `scripts/` to `PATH` and sets `BUILDDIR`. This is why all steps after initialization re-source it — each GitHub Actions `run:` block is a fresh shell.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `configs/local-proj.conf` | Modify line 20 | Fix hardcoded absolute `HDF_PATH` to repo-relative |
| `.github/workflows/ci.yml` | Create | GitHub Actions workflow — 5-platform matrix, `bitbake -p` |

---

## Task 1: Fix `HDF_PATH` in `local-proj.conf`

**Files:**
- Modify: `configs/local-proj.conf:20`

`local-proj.conf` is unconditionally copied into `build/conf/` for every platform. Line 20 has a hardcoded absolute path that only exists on one developer's machine.

- [ ] **Step 1: Verify the current broken value**

  Open `configs/local-proj.conf` and confirm line 20 reads:
  ```
  HDF_PATH = "/home2/yang.xu/tool/sources/yocto-forall/components/descriptions/system.xsa"
  ```

- [ ] **Step 2: Replace with repo-relative path**

  Edit `configs/local-proj.conf` line 20:

  **Before:**
  ```bitbake
  HDF_PATH = "/home2/yang.xu/tool/sources/yocto-forall/components/descriptions/system.xsa"
  ```

  **After:**
  ```bitbake
  HDF_PATH = "${TOPDIR}/../components/descriptions/system.xsa"
  ```

  `TOPDIR` is set by `oe-init-build-env` to the build directory (e.g. `<repo-root>/build`), so `${TOPDIR}/../` resolves to the repo root.

- [ ] **Step 3: Verify the XSA file exists**

  ```bash
  ls -lh components/descriptions/system.xsa
  ```
  Expected: file exists, ~692K

- [ ] **Step 4: Commit**

  ```bash
  git add configs/local-proj.conf
  git commit -m "fix: use repo-relative HDF_PATH for portability"
  ```

---

## Task 2: Create GitHub Actions workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Notes on the workflow design:**

- **Locale**: BitBake's `sanity.bbclass` checks `locale -a` at parse time and aborts if the locale is missing. Generate `en_US.UTF-8` explicitly with `locale-gen` and set both `LANG` and `LC_ALL` as job-level env vars. Do not rely on `C.UTF-8` alone — it can silently fail across runner image updates.
- **Package list**: `libsdl1.2-dev` was dropped from Ubuntu 22.04; use `libsdl2-dev`. Remove `pylint` and `xterm` (not needed for parse-only). Replace `libegl1-mesa` with `libegl-mesa0` (non-transitional). Use `libacl1-dev` (not `libacl1`) — pseudo needs the dev headers at compile time.
- **Submodule depth**: `fetch-depth: 1` is sufficient for parse validation. `fetch-depth: 0` would be needed for `git describe` or history-based operations, which parse-only does not require.
- **Environment guard**: Verify `build/SOURCE_THIS` was created before attempting to source it — surfaces `setup-env.sh` failures clearly instead of a misleading "No such file" error.
- **Machine validation**: Use `bitbake-getvar --value MACHINE` (not `-q`) to get the bare value without the variable-name prefix that `-q` still includes in scarthgap BitBake.
- **NXP layer warning**: `meta-qoriq` declares `LAYERSERIES_COMPAT` for `honister kirkstone master` (not `scarthgap`). BitBake emits a QA warning but does **not** exit non-zero — the `ls1043ardb` job will pass. This is a pre-existing repo issue.

- [ ] **Step 1: Create the workflow directory**

  ```bash
  mkdir -p .github/workflows
  ```

- [ ] **Step 2: Create `.github/workflows/ci.yml`**

  ```yaml
  name: Validate

  on:
    push:
      branches: [main]
    pull_request:
      branches: [main]

  jobs:
    validate:
      name: Validate [${{ matrix.machine }}]
      runs-on: ubuntu-22.04
      timeout-minutes: 60

      env:
        LANG: en_US.UTF-8
        LC_ALL: en_US.UTF-8

      strategy:
        fail-fast: false
        matrix:
          machine:
            - zynqmp-generic
            - ls1043ardb
            - rk3568-evb
            - stm32mp15-common
            - raspberrypi4-64

      steps:
        - name: Checkout
          uses: actions/checkout@v4
          timeout-minutes: 30
          with:
            submodules: recursive
            fetch-depth: 1

        - name: Install Yocto host dependencies
          run: |
            sudo apt-get update
            sudo apt-get install -y \
              gawk wget git diffstat unzip texinfo gcc build-essential \
              chrpath socat cpio python3 python3-pip python3-pexpect \
              xz-utils debianutils iputils-ping python3-git python3-jinja2 \
              libegl-mesa0 libsdl2-dev python3-subunit \
              mesa-common-dev zstd liblz4-tool file locales libacl1-dev

        - name: Generate locale
          run: |
            sudo locale-gen en_US.UTF-8
            sudo update-locale LANG=en_US.UTF-8

        - name: Initialize build environment
          run: |
            . configs/setup-env.sh -m ${{ matrix.machine }}

        - name: Verify environment initialized
          run: |
            test -f build/SOURCE_THIS || { echo "ERROR: SOURCE_THIS not created by setup-env.sh"; exit 1; }

        - name: Verify machine selection
          run: |
            . build/SOURCE_THIS
            actual=$(bitbake-getvar --value MACHINE)
            expected="${{ matrix.machine }}"
            if [ "$actual" != "$expected" ]; then
              echo "ERROR: MACHINE is '$actual', expected '$expected'"
              exit 1
            fi
            echo "MACHINE=$actual (ok)"

        - name: Show layers
          run: |
            . build/SOURCE_THIS
            bitbake-layers show-layers

        - name: Parse recipes
          run: |
            . build/SOURCE_THIS
            bitbake -p
  ```

- [ ] **Step 3: Verify YAML syntax**

  ```bash
  python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "OK"
  ```
  Expected: `OK`

- [ ] **Step 4: Commit**

  ```bash
  git add .github/workflows/ci.yml
  git commit -m "ci: add multi-platform Yocto parse validation workflow"
  ```

---

## Task 3: Push and verify CI runs

- [ ] **Step 1: Push to GitHub**

  ```bash
  git push origin main
  ```

- [ ] **Step 2: Open the Actions tab**

  Navigate to `https://github.com/yangshining/yocto-forall/actions` and confirm the workflow "Validate" appears and all 5 jobs are queued or running.

- [ ] **Step 3: Check job names**

  Confirm the 5 jobs appear as:
  ```
  Validate [zynqmp-generic]
  Validate [ls1043ardb]
  Validate [rk3568-evb]
  Validate [stm32mp15-common]
  Validate [raspberrypi4-64]
  ```

- [ ] **Step 4: Verify all 5 jobs pass**

  All 5 should show green. If `ls1043ardb` emits a `LAYERSERIES_COMPAT` warning in the logs, this is expected (pre-existing issue) and should not cause a failure.

  If any job fails unexpectedly, check the "Parse recipes" step log — BitBake prints the full error including the recipe file and line number.

- [ ] **Step 5: Verify PR integration**

  Create a trivial PR (e.g. add a blank line to `CLAUDE.md`) and confirm all 5 check statuses appear in the PR's "Checks" section before merge.

---

## Notes for Future Work

- **Tegra**: Add a `meta-tegra` case to `setup-env.sh`'s BSP switch, then add `tegra210-generic` to the matrix.
- **sstate cache**: Add `actions/cache` for `build/sstate-cache` once the baseline is stable — reduces parse time on repeat runs.
- **Scheduled drift detection**: Add a `schedule: cron` trigger (e.g. weekly) to detect upstream submodule breakage independently of code changes.
- **NXP layer compat**: Update `meta-qoriq` submodule or add a `LAYERSERIES_COMPAT` override in `meta-user` to eliminate the scarthgap warning.
