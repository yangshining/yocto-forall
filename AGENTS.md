# Repository Guidelines

## Project Structure & Module Organization
This repository is a Yocto-based multi-BSP build workspace.

- `components/layers/core/`: core layers (for example `poky`, `meta-openembedded`, `meta-arm`).
- `components/layers/bsp/`: vendor BSP layers (Xilinx, NXP, Rockchip, STM32MP, Raspberry Pi) managed as submodules.
- `components/layers/tools/`: tooling layers such as `meta-clang` and `meta-qt5`.
- `project-spec/meta-user/`: custom project layer for local overrides (`recipes-bsp/`, `recipes-kernel/`, `recipes-support/`, `conf/`).
- `configs/`: environment/bootstrap scripts and project defaults (`setup-env.sh`, `local-proj.conf`).
- `docs/`: troubleshooting and platform-specific usage notes.

## Build, Test, and Development Commands
- Initialize submodules:
  ```bash
  git submodule update --init --recursive
  ```
- Enter build environment (from repo root):
  ```bash
  . configs/setup-env -m zynqmp-generic
  ```
- Build an image:
  ```bash
  bitbake petalinux-image-minimal
  ```
- Rebuild one component during iteration:
  ```bash
  bitbake -c cleansstate device-tree && bitbake device-tree
  ```
- Return to an existing build env:
  ```bash
  . build-<machine>/SOURCE_THIS
  ```

## Coding Style & Naming Conventions
- Shell scripts use 4-space indentation and should remain POSIX-compatible unless Bash is required.
- BitBake metadata follows existing naming patterns:
  - Append files: `<recipe>_%.bbappend`
  - Patches: numeric prefix + short subject (for example `0001-fix-...patch`)
- Keep machine-specific settings in `configs/*.conf` or `platforms/<name>/meta-<name>-user/`; avoid editing upstream submodule layers directly.

## Testing Guidelines
There is no standalone top-level unit test suite in this repo. Validate changes with targeted BitBake builds:

- Recipe-level check: `bitbake <recipe>`
- Image-level smoke build: `bitbake <image>`
- For boot-impacting changes, verify artifacts under `build-<machine>/tmp/deploy/images/<machine>/`.

## Commit & Pull Request Guidelines
Current history is minimal (`add xlinx linux support`) and uses short, imperative summaries. Continue with concise, scope-first messages, for example:

- `meta-user: enable xsct device-tree flow`
- `kernel: add motorcomm phy patch`

PRs should include:
- target machine(s) and image(s),
- exact build/verification commands executed,
- changed paths (especially under `project-spec/meta-user/`),
- logs or screenshots only when behavior/output changes.
