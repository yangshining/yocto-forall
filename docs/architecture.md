# Build Framework Architecture

## Purpose

This repository composes heterogeneous vendor BSPs without forcing them onto one Yocto release. One `main` branch contains several isolated Baseline Profiles, and every build target binds to exactly one profile.

The framework never checks out a different branch at setup time. Selection chooses already-pinned paths from the repository.

## Configuration Model

| Scope | Source of truth | Responsibility |
|---|---|---|
| Baseline Profile | `baselines/<profile>/baseline.conf` | Yocto series, OEROOT, and core layers |
| Platform Integration | `platforms/<platform>/platform.conf` | Platform identity and allowed profiles |
| Platform adapter | `platforms/<platform>/baselines/<profile>.conf` | BSP/tool layers, DISTRO, and platform fragment for one profile |
| Reference Machine | `platforms/<platform>/targets/<target>.conf` | MACHINE, profile binding, image, aliases, and Support Level |
| Product Integration | `products/<product>/product.conf` | Product identity, parent platform, and allowed profiles |
| Product adapter | `products/<product>/baselines/<profile>.conf` | Product-owned layer and product fragment |
| Product Machine | `products/<product>/targets/<target>.conf` | Concrete product target and evidence-backed Support Level |

Target and adapter files are shell assignments sourced by `configs/setup-env.sh`. Values are validated before a build environment is created.

## Selection Flow

```text
-T target or -m selector
          |
          v
explicit target record
          |
          +--> Baseline Profile --> OEROOT + core layers
          |
          +--> Platform adapter --> BSP/tool layers + DISTRO + fragment
          |
          +--> optional Product adapter --> product layer + fragment
          |
          v
build/<profile>/<target>/conf/{bblayers.conf,local.conf,yocto-forall.manifest}
```

`-T` accepts only a canonical target ID. `-m` is the compatibility selector and accepts a target ID, BSP MACHINE, or explicitly declared alias. `-p` asserts the target's checked-in profile; it cannot override the binding.

## Isolation Invariants

Registry validation enforces these rules:

1. Every core OEROOT and core-layer path lives under `components/layers/baselines/<profile>/`.
2. Paths are canonical repository-relative paths; `..`, `./`, duplicate separators, whitespace, and absolute paths are rejected.
3. A selected integration layer and its containing direct gitlink checkout belong to one Baseline Profile. Different sublayers from one BSP checkout cannot be split across profiles.
4. Platform targets, layers, and fragments cannot claim another `platforms/<id>/` owner or any `products/` content.
5. Product targets, layers, and fragments must remain under their matching `products/<product>/` owner.
6. A build combines layers from one target binding only. Compatibility overrides must not hide an upstream `LAYERSERIES_COMPAT` mismatch.

`platforms/common/meta-user/` is the intentional exception to profile-specific integration ownership. It is project-owned metadata whose `LAYERSERIES_COMPAT` declaration is maintained across all selected profiles.

## Generated State

Default paths are:

```text
build/<profile>/<target>/
.yocto-cache/<profile>/downloads/
.yocto-cache/<profile>/sstate-cache/
```

Each build directory contains `conf/yocto-forall.manifest`. Setup rejects reuse when the target, MACHINE, platform, product, profile, series, DISTRO, or OEROOT differs from the recorded identity.

`SOURCE_THIS` re-enters the pinned OEROOT and build directory. Sourcing another target in the same shell refreshes the active BitBake path through that target's `oe-init-build-env`.

## Support Evidence

Support Levels are defined in `CONTEXT.md`. `TARGET_SUPPORT_LEVEL` is a promise, not a marketing label:

- `Declared` requires only a valid registry entry.
- `Parse-Validated` requires a clean parse job in `.github/workflows/ci.yml`.
- Higher levels require recorded image-build and hardware evidence plus the commitments described in `CONTEXT.md`.

The CI matrix carries baseline, target, and expected MACHINE so a passing parse also verifies the selected registry identity.
