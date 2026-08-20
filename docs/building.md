# Building Targets

## Host Prerequisites

Use a Yocto-supported Linux host. The CI reference environment is Ubuntu 22.04 and installs its package set in `.github/workflows/ci.yml`.

Registry validation and setup require Python 3.8 or later and use only the Python standard library.

Before setup:

```bash
git submodule update --init --recursive
umask 0022
```

Yocto rejects a restrictive umask that prevents required read/execute permissions. The Whinlatter profile also requires Python 3.9 or later and a GCC/G++ toolchain with C++20 support (GCC 10.1 or later); Ubuntu 20.04's default Python 3.8 and GCC 9 are insufficient.

## Discover and Validate

The setup script must be sourced:

```bash
. configs/setup-env.sh -V
. configs/setup-env.sh -l
. configs/setup-env.sh -n -T harp-dfe-xczu67dr
```

`-V` validates registry structure without requiring initialized layer checkouts. `-n` resolves a target and prints its profile, paths, image, and Support Level without creating a build environment.

## Configure and Build

Canonical target selection:

```bash
. configs/setup-env.sh -T harp-dfe-xczu67dr -p scarthgap
bitbake petalinux-image-minimal
```

Compatibility selection:

```bash
. configs/setup-env.sh -m rk3568-evb
bitbake core-image-minimal
```

`-p` is optional and useful in automation. It fails when the requested profile differs from the target record.

The Bash wrapper selects the target's default image when no BitBake arguments are supplied:

```bash
./proj_build.sh harp-dfe-xczu67dr
./proj_build.sh ls1043ardb -c compile virtual/kernel
```

### Jetson AGX Orin

On an older host, enter the Yocto 5.2.3 extended-buildtools environment first. Then configure the Whinlatter target and build its default image:

```bash
. "$HOME/.yocto/buildtools/5.2.3/environment-setup-x86_64-pokysdk-linux"
umask 0022
. configs/setup-env.sh \
    -T jetson-agx-orin-devkit \
    -p whinlatter \
    -j 32 \
    -t 32

bitbake -c fetch linux-jammy-nvidia-tegra nvidia-kernel-oot
bitbake core-image-minimal
```

The Tegra profile uses depth-one Git fetches for the pinned OE4T kernel sources and forces those fetches to HTTP/1.1. This avoids mirroring the full NVIDIA kernel history and improves reliability through proxies that reset long GitHub transfers. The first kernel fetch can still take several minutes because the current source tree is large; subsequent builds reuse the shallow tarball in `.yocto-cache/whinlatter/downloads/`.

### STM32MP15 Eval eMMC

The `stm32mp15-eval` target enables both the vendor SD-card flow and the STM32MP157F-EV1 eMMC FlashLayout flow:

```bash
umask 0022
. configs/setup-env.sh -T stm32mp15-eval -p scarthgap
bitbake core-image-minimal
```

The eMMC opt-in makes BitBake build the `opteemin-emmc` TF-A/FIP configuration and generate an eMMC TSV under:

```text
build/scarthgap/stm32mp15-eval/tmp/deploy/images/stm32mp15-eval/
  flashlayout_core-image-minimal/opteemin/*emmc*.tsv
```

Use the generated TSV and referenced binaries with STM32CubeProgrammer. This target is Parse-Validated; successful image generation and booting from eMMC still require build and board evidence before raising its Support Level.

## Re-enter a Build

```bash
. build/<profile>/<target>/SOURCE_THIS
```

Build artifacts are normally deployed under:

```text
build/<profile>/<target>/tmp/deploy/images/<machine>/
```

The repository also maintains a best-effort convenience symlink at `images/<target>` after setup.

## Custom Paths

```bash
. configs/setup-env.sh -T <target> \
    -b /path/to/build \
    -d /path/to/downloads \
    -c /path/to/sstate-cache \
    -j 16 \
    -t 12
```

Custom build directories still receive a manifest and cannot be reused for another target identity. Sharing downloads or sstate across different Baseline Profiles is not recommended.

## Validation Commands

```bash
python3 -m unittest tests.test_build_registry
bash tests/setup-env-test.sh
. configs/setup-env.sh -V
. configs/setup-env.sh -T <target>
bitbake-layers show-layers
bitbake -p
bitbake <recipe-or-image>
```

Use `bitbake -p` for metadata validation. It does not prove that an image builds or boots.

## Common Failures

| Message or symptom | Resolution |
|---|---|
| `This script must be sourced` | Run `. configs/setup-env.sh ...`, not `./configs/setup-env.sh`. |
| Unknown target or machine | Run `. configs/setup-env.sh -l`; do not invent aliases for absent hardware. |
| Target binds to another baseline | Remove the incorrect `-p` assertion or update the checked-in target after validating a real port. |
| Build directory belongs to another target | Use the default isolated path or choose a new `-b` directory. Do not delete the manifest to bypass the guard. |
| Required layer is missing | Initialize submodules recursively and verify the pinned gitlink exists. |
| Yocto reports an unsafe umask | Start a build shell with `umask 0022`, then source setup again. |
| BitBake requires newer Python/GCC | Use Ubuntu 22.04, a supported buildtools tarball, or equivalent Python/GCC versions. Do not disable the sanity check. |
| Jetson fetch reports `curl 56`, `SSL_ERROR_SYSCALL`, or `early EOF` | Re-run setup so the generated `local.conf` includes the Tegra shallow-fetch and HTTP/1.1 settings, then retry the failed fetch task. Do not delete unrelated download-cache mirrors. |
| XSCT deprecation warning on Xilinx | The current Scarthgap Xilinx adapter still uses the XSCT flow. Treat the warning as upstream migration work, not a parse failure. |
