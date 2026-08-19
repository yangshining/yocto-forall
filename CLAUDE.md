# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## What This Repo Is

A single-branch, multi-Baseline Yocto Build Framework. Every Reference Machine or Product Machine binds to exactly one isolated Baseline Profile. Core checkouts are side by side; never switch one shared Poky checkout at runtime and never force cross-series compatibility.

## Common Commands

```bash
git submodule update --init --recursive
. configs/setup-env.sh -V
. configs/setup-env.sh -l
. configs/setup-env.sh -T harp-dfe-xczu67dr -p scarthgap
. configs/setup-env.sh -m rk3568-evb       # compatibility selector
. build/scarthgap/harp-dfe-xczu67dr/SOURCE_THIS
bitbake petalinux-image-minimal
bitbake -p
python3 -m unittest tests.test_build_registry
bash tests/setup-env-test.sh
```

`setup-env.sh` also supports `-j`, `-t`, `-b`, `-d`, `-c`, and dry-run `-n`. `-p` verifies a checked-in binding; it does not override one.

## Architecture

```text
baselines/<profile>/baseline.conf
components/layers/baselines/<profile>/{poky,meta-openembedded,meta-arm}
components/layers/bsp/<vendor>/
platforms/<platform>/{platform.conf,baselines/,targets/,conf/,meta-*}
products/<product>/{product.conf,baselines/,targets/,conf/,meta-*,hardware/}
configs/setup-env.sh
tests/setup-env-test.sh
```

Profiles:

| Profile | Platforms |
|---|---|
| `scarthgap` | Xilinx ZynqMP, STM32MP |
| `whinlatter` | Raspberry Pi, Rockchip, Tegra |
| `kirkstone` | NXP QorIQ |

Key rules:

- Never edit upstream submodules; use project-owned platform or product layers.
- `platforms/` is reusable SoC-family integration. `products/` owns concrete boot, memory, storage, peripheral, provisioning, hardware-input, and release policy.
- Xilinx product metadata, kernel patches, device tree, low-level init, and XSA live under `products/xilinx-zynqmp-harp-dfe/`.
- Target records under `targets/*.conf` are authoritative. Do not rediscover targets by scanning upstream MACHINE files.
- Profile adapter files contain explicit repository-relative layer paths. Do not search layers by basename.
- Each selected platform/product layer and its containing gitlink checkout are owned by one Baseline Profile. A second profile needs a separate pinned checkout/path.
- Generated builds live at `build/<profile>/<target>` and carry `conf/yocto-forall.manifest`; mismatched reuse must fail.
- Default caches live under `.yocto-cache/<profile>/` and are never shared across profiles.
- Store all agent-created temporary/work artifacts, including reports, screenshots, and scratch exports, under the repository's ignored `lessons/` directory; create it if absent and do not write project artifacts to `/tmp` or outside this repository.
- Do not add compatibility overrides for upstream `LAYERSERIES_COMPAT`. Move the target to a coherent profile or port the layer honestly.

## Targets and Support

Use `. configs/setup-env.sh -l` for the current authoritative list. `harp-dfe-xczu67dr` is the intended production Product Machine, but it remains Parse-Validated until image-build, hardware-boot, ownership, and security-maintenance evidence is recorded. CI parse-validates the representative matrix in `.github/workflows/ci.yml`.

Safe aliases are explicit. `rk3568-evb` maps to BSP MACHINE `rockchip-rk3568-evb`; `stm32mp15-common` selects target `stm32mp15-disco`. Do not invent mappings for absent hardware such as the old Tegra 210/186 or ZCU102 names.

## Coding Conventions

- Shell: 4-space indentation and POSIX-compatible unless Bash is required.
- BitBake appends: `<recipe>_%.bbappend` for versioned recipes; exact `<recipe>.bbappend` for unversioned recipes.
- Patches: numeric prefix plus short subject.
- HARP DFE kernel patches belong under `products/xilinx-zynqmp-harp-dfe/meta-xilinx-zynqmp-harp-dfe/recipes-kernel/linux-xlnx/files/`.
- Commit messages: concise, scope-first imperative.

## Testing

```bash
bash -n configs/setup-env.sh
dash -n configs/setup-env.sh
bash tests/setup-env-test.sh
. configs/setup-env.sh -V
. configs/setup-env.sh -T <target>
bitbake-layers show-layers
bitbake -p
```

Boot artifacts are under `build/<profile>/<target>/tmp/deploy/images/<machine>/`.

During iterative development, run the smallest relevant local tests. Do not trigger the full remote CI matrix until the change is ready to merge, but require it before merging to `main`.

## Documentation Map

| Topic | Document |
|---|---|
| Framework model and invariants | `docs/architecture.md` |
| Approved Build Registry implementation | `docs/registry-design.md` |
| Host setup, builds, and troubleshooting | `docs/building.md` |
| Adding targets, platforms, products, or profiles | `docs/adding-support.md` |
| Pinned upstream revisions | `docs/layers-versions.md` |
| HARP DFE product state | `products/xilinx-zynqmp-harp-dfe/README.md` |

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues for this repository. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the canonical triage labels `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository: domain vocabulary lives in root `CONTEXT.md`, and architectural decisions live in `docs/adr/`. See `docs/agents/domain.md`.
