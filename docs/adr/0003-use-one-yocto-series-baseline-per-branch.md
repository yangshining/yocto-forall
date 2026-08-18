---
status: superseded by ADR-0004
---

# Use one Yocto Series Baseline per maintained branch

Each maintained repository branch will target exactly one Yocto Series Baseline, and build targets may not bypass incompatible upstream layer declarations with `LAYERSERIES_COMPAT_*` overrides. A Platform Integration that cannot align with the branch baseline must remain Declared or move to an explicitly named legacy branch; this gives up the appearance that every platform works on `main` in exchange for coherent APIs, meaningful compatibility checks, and support claims that can be validated.
