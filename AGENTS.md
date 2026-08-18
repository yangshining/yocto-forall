# Repository Guidelines

## Project Structure & Module Organization

This repository is a multi-Baseline Yocto Build Framework.

- `baselines/<profile>/baseline.conf`: defines one pinned Yocto Series Baseline and its explicit core-layer paths.
- `components/layers/baselines/<profile>/`: separate Poky, meta-openembedded, and meta-arm gitlinks for each profile.
- `components/layers/bsp/`: vendor BSP layers. Never edit upstream submodule layers directly.
- `platforms/<name>/`: reusable vendor/SoC-family integration, profile adapters, Reference Machine targets, and platform-owned metadata.
- `products/<name>/`: Product Machines and all concrete hardware policy. The HARP DFE XSA and metadata live under `products/xilinx-zynqmp-harp-dfe/`.
- `platforms/common/meta-user/`: customizations verified across all declared profiles.
- `configs/`: environment/bootstrap scripts and project defaults.
- `tests/`: fast setup/registry contract tests.

## Build, Test, and Development Commands

```bash
git submodule update --init --recursive
. configs/setup-env.sh -V
. configs/setup-env.sh -l
. configs/setup-env.sh -T harp-dfe-xczu67dr -p scarthgap
bitbake petalinux-image-minimal
```

Compatibility selection remains available with `. configs/setup-env.sh -m <target-or-machine>`.

Re-enter a build with:

```bash
. build/<profile>/<target>/SOURCE_THIS
```

Run fast contracts with `bash tests/setup-env-test.sh`. Rebuild one component with `bitbake -c cleansstate <recipe> && bitbake <recipe>`.

## Coding Style & Naming Conventions

- Shell scripts use 4-space indentation and remain POSIX-compatible unless Bash is explicitly required.
- BitBake append files use `<recipe>_%.bbappend` for versioned recipes and exact `<recipe>.bbappend` names for unversioned recipes; patches use a numeric prefix and short subject.
- A target binds to exactly one Baseline Profile. `-p` is an assertion, not a switch.
- A selected integration layer and its containing gitlink checkout belong to one Baseline Profile. Add another pinned checkout/path before using that source on another profile.
- Keep series-specific layer lists/fragments in `platforms/<id>/baselines/` or `products/<id>/baselines/`.
- Do not add `LAYERSERIES_COMPAT_*` overrides to force an upstream layer onto another series.
- Keep product behavior out of `platforms/`; product-specific content belongs under `products/<product>/`.

## Testing Guidelines

- Registry/setup contracts: `bash tests/setup-env-test.sh`
- Registry structure: `. configs/setup-env.sh -V`
- Layer composition: `bitbake-layers show-layers`
- Recipe parse: `bitbake -p`
- Recipe/image checks: `bitbake <recipe-or-image>`
- Boot artifacts: `build/<profile>/<target>/tmp/deploy/images/<machine>/`

## Commit & Pull Request Guidelines

Use concise, scope-first imperative commit messages, for example `build: add whinlatter baseline profile` or `harp-dfe: update device tree`.

PRs should include target(s), Baseline Profile(s), image(s), exact verification commands, changed platform/product paths, and logs only when behavior or output changes.
