# Adding Targets and Baseline Support

Run `. configs/setup-env.sh -V` after every registry change. The registry is deliberately strict so an apparently convenient change cannot silently mix Yocto series or product ownership.

Registry `.conf` files are declarative data, not shell scripts. Use only blank lines, comments, and allowed `FIELD="value"` assignments. Declared list fields may use a multiline double-quoted value. Variable expansion, command substitution, `export`, functions, conditionals, redirections, duplicate fields, unknown fields, and trailing commands are rejected.

## Target Record

Each `targets/<target>.conf` defines:

| Field | Meaning |
|---|---|
| `TARGET_ID` | Canonical selector; must match the filename |
| `TARGET_MACHINE` | BSP `MACHINE` value |
| `TARGET_ALIASES` | Optional, explicit compatibility selectors |
| `TARGET_PLATFORM` | Matching `platforms/<id>/` owner |
| `TARGET_PRODUCT` | Empty for Reference Machines; matching `products/<id>/` for Product Machines |
| `TARGET_BASELINE` | One checked-in Baseline Profile |
| `TARGET_SUPPORT_LEVEL` | Evidence-backed level from `CONTEXT.md` |
| `TARGET_DEFAULT_IMAGE` | Image used by `proj_build.sh` when no BitBake target is supplied |

Selectors must be globally unique across target IDs, MACHINE values, and aliases.

## Add a Reference Machine

Create `platforms/<platform>/targets/<target>.conf`:

```sh
TARGET_ID="example-board"
TARGET_MACHINE="vendor-machine"
TARGET_ALIASES=""
TARGET_PLATFORM="example-platform"
TARGET_PRODUCT=""
TARGET_BASELINE="scarthgap"
TARGET_SUPPORT_LEVEL="Declared"
TARGET_DEFAULT_IMAGE="core-image-minimal"
```

The target's baseline must be listed by `PLATFORM_BASELINES` and have a matching platform adapter.

## Add a Product Machine

Product policy must not be added to a platform directory.

1. Create `products/<product>/product.conf` with `PRODUCT_ID`, `PRODUCT_PLATFORM`, and `PRODUCT_BASELINES`.
2. Add `products/<product>/baselines/<profile>.conf` with product-owned layers and an optional local fragment.
3. Put concrete metadata, hardware inputs, and release policy under `products/<product>/`.
4. Add `products/<product>/targets/<target>.conf` with `TARGET_PRODUCT="<product>"`.

Product adapters are validated even when no target currently references them.

Every profile named in `PRODUCT_BASELINES` requires exactly one matching `baselines/<profile>.conf`. Undeclared, mismatched, or orphaned adapters invalidate the complete Registry.

## Add a Platform to an Existing Profile

1. Pin the vendor BSP source under `components/layers/bsp/` or an appropriate tool path.
2. Add `platforms/<platform>/platform.conf`:

   ```sh
   PLATFORM_ID="example-platform"
   PLATFORM_BASELINES="scarthgap"
   ```

3. Add `platforms/<platform>/baselines/scarthgap.conf`:

   ```sh
   PLATFORM_BASELINE_ID="scarthgap"
   PLATFORM_DISTRO="poky"
   PLATFORM_LAYERS="components/layers/bsp/example/meta-example"
   PLATFORM_LOCAL_CONF="platforms/example-platform/conf/local.conf.fragment"
   ```

4. Add at least one target record.
5. Record pins in `docs/layers-versions.md` and add the chosen parse representative to CI before claiming `Parse-Validated`.

Platform adapters may use their own `platforms/<id>/` metadata but cannot reference another platform or any product path.

Every profile named in `PLATFORM_BASELINES` requires exactly one matching `baselines/<profile>.conf`. Adapter filenames and their `PLATFORM_BASELINE_ID` values must agree.

## Support One Platform on Another Baseline

Do not reuse the existing BSP gitlink, even if each profile selects a different sublayer. Registry validation resolves layer paths to their containing direct gitlink and assigns that checkout to one profile.

Instead:

1. Add a second pinned checkout at a distinct repository path.
2. Verify every selected layer declares the intended Yocto series.
3. Add the new profile to `PLATFORM_BASELINES`.
4. Add `platforms/<platform>/baselines/<new-profile>.conf` pointing only at the new checkout.
5. Add or move explicit targets to the new binding and run the profile's CI matrix.

Never add a local `LAYERSERIES_COMPAT_*` override merely to silence an incompatible upstream declaration.

## Add a Baseline Profile

1. Pin an independent Poky checkout under `components/layers/baselines/<profile>/poky`.
2. Pin compatible meta-openembedded, meta-arm, and any baseline-owned layers under the same profile directory.
3. Add `baselines/<profile>/baseline.conf` with `BASELINE_ID`, `BASELINE_SERIES`, `BASELINE_OEROOT`, and explicit `BASELINE_LAYERS`.
4. Add profile-specific platform/product adapters and target bindings.
5. Update `.gitmodules`, `docs/layers-versions.md`, README tables, and CI.

Core paths must remain inside their own profile directory and cannot be shared with another profile.

## Choose a Support Level

- Start at `Declared` while only registry metadata exists.
- Use `Parse-Validated` only when the target is continuously present in the clean CI parse matrix.
- Use `Build-Validated` only with a clean image-build job and required artifact checks.
- Use `Boot-Validated` only with a recorded result on named hardware.
- Use `Production-Supported` only for a Product Machine that also has explicit ownership and security/update commitments.

Do not promote a target based on a one-off developer build.

## Completion Checklist

```bash
python3 -m unittest tests.test_build_registry
bash -n configs/setup-env.sh proj_build.sh tests/setup-env-test.sh
dash -n configs/setup-env.sh
bash tests/setup-env-test.sh
. configs/setup-env.sh -V
. configs/setup-env.sh -n -T <target>
. configs/setup-env.sh -T <target>
bitbake-layers show-layers
bitbake -p
```

Python tests own Build Registry parsing, validation, indexing, resolution, and protocol behavior. Shell tests own the sourced interface, Bash/Dash compatibility, protocol consumption, generated configuration, and build-directory guards.

For build- or boot-impacting changes, also build the declared image and record the exact command, artifact path, hardware identity, and result.
