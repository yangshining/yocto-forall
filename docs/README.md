# Documentation

The files below describe the current repository. Declarative Registry records compiled by `configs/build_registry.py`, together with the `configs/setup-env.sh` environment adapter, remain the implementation source of truth when prose and metadata disagree.

## Build Framework

- [Architecture](architecture.md): registry model, selection flow, ownership boundaries, and build/cache isolation.
- [Architecture review](architecture-review.html): evidence-backed module-deepening opportunities, priorities, and before/after diagrams.
- [Build Registry design](registry-design.md): approved first-phase scope, interfaces, validation model, tests, migration, and acceptance criteria.
- [Building](building.md): host prerequisites, setup commands, re-entry, validation, and common failures.
- [Adding support](adding-support.md): add targets, platforms, products, or Baseline Profiles without creating unsafe combinations.
- [Layer versions](layers-versions.md): pinned core, BSP, and tool-layer revisions.
- [Domain language](../CONTEXT.md): canonical terms and evidence-backed Support Levels.
- [Architectural decisions](adr/): decisions that constrain future changes.

## Product Integrations

- [Xilinx ZynqMP HARP DFE](../products/xilinx-zynqmp-harp-dfe/README.md)

## Agent Workflows

- [Issue tracker](agents/issue-tracker.md)
- [Triage labels](agents/triage-labels.md)
- [Domain-doc conventions](agents/domain.md)

Completed implementation plans are intentionally not kept as live documentation. Git history preserves them; this index points only to documents that should guide current work.
