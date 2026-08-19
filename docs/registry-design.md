# Build Registry Design

Status: implemented for the first architecture-deepening phase.

The Build Registry is the authoritative set of Baseline Profile, Platform Integration, Product Integration, Reference Machine, and Product Machine declarations. This design deepens that module while preserving the existing sourced setup interface and generated build state.

## Goal

Replace repeated shell execution, global-variable resets, and duplicated registry rules with one structured Build Registry implementation:

```text
declarative registry records
          |
          v
Python Build Registry
parse -> validate -> index -> resolve -> compose
          |
          v
versioned internal protocol
          |
          v
POSIX setup-env.sh adapter
```

The desired depth is a small interface that hides record parsing, domain invariants, Integration Source claims, selector indexing, deterministic diagnostics, and selected-record composition.

## Confirmed Decisions

1. The first phase changes only the Build Registry. Resolved Build Plan, Build Directory State, CI generation, common image policy, and product release composition are deferred.
2. Existing setup flags, stdout fields and ordering, exit behavior, and generated configuration remain compatible. Stderr wording may improve while retaining its meaning and identifying context.
3. The Build Registry uses standard-library-only Python 3.8+ behind the existing POSIX-shell adapter.
4. Existing `.conf` paths and fields remain, but records become assignment-only declarative data and are never executed.
5. Python owns loading, validation, indexing, selector resolution, and selected-record composition. Shell owns sourcing semantics, setup options, environment entry, and generated-state integration.
6. Python and shell communicate through a versioned, white-listed, line-oriented key/value protocol. The shell never uses `eval` or sources generated assignments.
7. Records are discovered from the existing ownership directories. No central registry manifest is introduced.
8. The complete Build Registry is compiled atomically for validation, listing, resolution, and setup. One invalid formal record invalidates the registry for every target.
9. Validation reports all independent errors in deterministic order while suppressing errors that only cascade from an already reported root cause.
10. Development uses focused local tests. The full remote CI matrix remains a pre-merge gate rather than part of each edit cycle.
11. Python tests own Build Registry domain behavior. Shell tests own adapter behavior and external compatibility; duplicated shell invariant tests are removed during cutover.
12. Migration uses temporary test-only parity against the legacy shell implementation, followed by one cutover that removes the old registry logic. There is no runtime fallback.
13. `platforms/common/meta-user` remains outside the Build Registry in this phase; its current composition behavior stays unchanged.
14. No persistent registry cache is written. Each command compiles the current worktree once in memory.

The durable trade-offs are recorded in:

- [ADR-0005: Implement the Build Registry in Python](adr/0005-implement-the-build-registry-in-python.md)
- [ADR-0006: Treat Build Registry records as declarative data](adr/0006-treat-build-registry-records-as-declarative-data.md)
- [ADR-0007: Compile the Build Registry atomically](adr/0007-compile-the-build-registry-atomically.md)

## Scope

The Python implementation owns:

- deterministic record discovery;
- assignment parsing and schema checks;
- immutable structured records;
- Baseline Profile isolation;
- Platform Integration and Product Integration ownership;
- Reference Machine and Product Machine bindings;
- selector uniqueness and compatibility aliases;
- Integration Source resolution and cross-profile claims;
- target resolution and profile assertions;
- selected Baseline, Platform, Product, and Target composition;
- registry listing data;
- deterministic issue collection and rendering.

The POSIX shell adapter continues to own:

- detection that `setup-env.sh` is sourced;
- existing option parsing;
- `-b`, `-d`, `-c`, `-j`, and `-t` behavior;
- build, download, and sstate path calculation in this phase;
- Yocto `oe-init-build-env` entry;
- common layer addition;
- `bblayers.conf`, `local.conf`, manifest, and `SOURCE_THIS` generation.

## Explicit Non-goals

This phase does not:

- migrate records to JSON, TOML, or YAML;
- redesign the public setup command;
- change target, MACHINE, image, layer, fragment, or Support Level declarations;
- change layer order or generated BitBake configuration;
- move `platforms/common/meta-user` into the Build Registry;
- generate CI or README content;
- add Build-Validated or Boot-Validated evidence;
- redesign Platform/Product local configuration fragments;
- introduce a registry daemon or persistent cache.

## Record Format

The accepted syntax is deliberately smaller than shell:

- blank lines;
- comment lines;
- one allowed field assignment per statement;
- double-quoted scalar values;
- double-quoted multiline values for declared lists.

The parser rejects:

- unknown or duplicate fields;
- unquoted assignments;
- command or process substitution;
- variable expansion;
- `export`, functions, conditionals, loops, redirections, and commands;
- trailing executable tokens;
- unterminated strings;
- control characters in resulting values.

Each record type has an explicit field schema. Required fields remain required, optional fields remain explicit, and list values become ordered lists instead of whitespace-dependent shell strings.

## Discovery and Ordering

Discovery uses the existing ownership layout:

```text
baselines/*/baseline.conf
platforms/*/platform.conf
platforms/*/baselines/*.conf
platforms/*/targets/*.conf
products/*/product.conf
products/*/baselines/*.conf
products/*/targets/*.conf
```

Paths are sorted before parsing. Owner declarations determine which Baseline adapters are expected. Missing adapters, unexpected adapters, orphaned records, and owner/path mismatches are validation errors.

Declared layer order is preserved because it affects BitBake behavior. Listing and diagnostics use deterministic path/identifier ordering compatible with the current output.

## Python Module Shape

Start with one importable `configs/build_registry.py` module and one public command entry point. This avoids creating several shallow files before internal seams have earned their keep.

The implementation may use private dataclasses and helpers for parsing, validation, indexing, issue collection, and protocol encoding. These remain implementation details. Split private modules later only when doing so improves locality without expanding the public interface.

The command surface is limited to registry operations needed by the shell adapter:

```text
validate
list
resolve --mode canonical|compat --selector <value> [--profile <assertion>]
```

Expected validation and selection failures produce concise diagnostics without Python tracebacks.

## Internal Protocol

The selected result uses a private versioned line protocol:

```text
PROTOCOL=1
TARGET_ID=harp-dfe-xczu67dr
TARGET_MACHINE=harp-dfe-xczu67dr
TARGET_BASELINE=scarthgap
TARGET_PLATFORM=xilinx-zynqmp
TARGET_PRODUCT=xilinx-zynqmp-harp-dfe
TARGET_SUPPORT_LEVEL=Parse-Validated
TARGET_DEFAULT_IMAGE=petalinux-image-minimal
BASELINE_LAYER=components/...
PLATFORM_LAYER=components/...
PRODUCT_LAYER=products/...
```

Rules:

- the protocol version is mandatory;
- scalar keys occur exactly once;
- ordered collections use repeated keys;
- keys are white-listed by the shell adapter;
- values contain no newline or control characters;
- unknown, missing, duplicate, or out-of-order protocol metadata is fatal;
- diagnostics go to stderr and protocol data goes to stdout;
- shell parses fields with explicit `case` branches and never executes protocol text.

This protocol is an internal seam, not a new supported user interface.

## Validation Model

Compilation proceeds in stages so independent errors can be collected without producing cascades:

1. Discover expected record paths.
2. Parse syntax and enforce per-record schemas.
3. Build records whose syntax and local fields are valid.
4. Validate identifiers, canonical paths, and filename/owner consistency.
5. Validate Baseline, Platform, Product, adapter, and target relationships.
6. Build the global selector index.
7. Resolve Integration Sources from root `.gitmodules` paths and validate cross-profile claims.
8. Publish an immutable registry only if no issues remain.

Issues carry at least a path, optional field, stable rule code, and human-readable message. They sort deterministically by path, field, and rule code.

The implementation continues to validate without initialized submodules. It checks registry paths and declarations but does not parse upstream `layer.conf` files during `-V`.

## Test Strategy

Add standard-library Python tests for:

- every allowed and rejected assignment form;
- required, optional, unknown, and duplicate fields;
- all current ownership and Baseline isolation invariants;
- selector ID, MACHINE, and alias collisions;
- Integration Source resolution;
- atomic compilation;
- independent error aggregation and cascade suppression;
- deterministic ordering;
- canonical and compatibility target resolution;
- profile assertions;
- protocol encoding.

Keep shell contracts for:

- direct-execution rejection and sourced invocation;
- Dash compatibility;
- existing options and stdout;
- protocol parsing;
- environment selection;
- generated layer/configuration order;
- manifest protection and `SOURCE_THIS`.

Detailed invariant cases move from shell text mutation into Python fixtures. Temporary legacy/Python parity tests are deleted after cutover.

Recommended local loop:

```bash
python3 -m unittest tests.test_build_registry
bash tests/setup-env-test.sh
. configs/setup-env.sh -V
```

Run only the smallest relevant command while iterating. Run the repository's full remote CI matrix when the change is ready to merge into `main`.

## Migration Sequence

1. Add parser/model/validation tests with the legacy shell still active.
2. Implement Build Registry compilation and deterministic diagnostics.
3. Implement listing, resolution, selected composition, and protocol encoding.
4. Add temporary parity tests against the current valid registry and representative failures.
5. Add the POSIX shell protocol adapter without changing generated configuration.
6. Cut all registry actions over together.
7. Delete shell record sourcing, resets, validation, listing, resolution, loading, and duplicated tests.
8. Run focused unit and shell contracts locally.
9. Update current architecture and adding-support documentation to describe declarative records.
10. Run the full CI matrix before merge.

## Acceptance Criteria

- Current registry records require no semantic changes.
- Existing setup options, success output, machine-readable `-n` fields, exit behavior, and generated files remain compatible.
- No registry record is executed as shell.
- A command compiles the registry once.
- Shell contains no duplicate registry ownership or selector rules.
- The legacy shell registry implementation and temporary parity harness are removed.
- All Build Registry domain behavior is directly testable through the Python module interface.
- All shell adapter contracts pass under Bash and Dash.
- `. configs/setup-env.sh -V` works with Python 3.8 and without initialized submodules.
- The full pre-merge CI matrix passes.

## Deferred Work

After this phase, evaluate these independently:

- Resolved Build Plan and coherent Build Directory State;
- Support Evidence and vendor artifact contracts;
- common recipe implementation versus image package policy;
- Product Integration release images and package groups;
- Platform policy fragments;
- Integration Source provenance and in-tree vendor copies;
- whether the assignment record format should eventually migrate or be renamed.
