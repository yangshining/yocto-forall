# Yocto Build Integration

This context defines the language used to separate reusable multi-BSP build capabilities from concrete hardware-product behavior.

## Language

**Build Framework**:
The reusable repository-level capability for composing Yocto builds across multiple vendor and SoC families. It does not own hardware-product-specific behavior.
_Avoid_: Product BSP, board repository

**Platform Integration**:
The integration boundary for a vendor or SoC family. It exposes BSP capabilities without defining one concrete product's hardware policy.
_Avoid_: Product, board configuration

**Xilinx ZynqMP**:
The Platform Integration for the Xilinx Zynq UltraScale+ MPSoC and RFSoC family. Its canonical identifier is `xilinx-zynqmp`.
_Avoid_: Xilinx product, HARP platform

**Product Machine**:
A concrete hardware-product build target that owns its hardware-specific boot, memory, storage, peripheral, and provisioning policies.
_Avoid_: Platform, generic machine

**Reference Machine**:
A non-product build target used to validate a Platform Integration against representative vendor hardware. It can be Boot-Validated but is never Production-Supported.
_Avoid_: Product Machine, production target

**Product Integration**:
The bounded ownership context for one hardware product, containing its Product Machines and all product-specific hardware and release policy.
_Avoid_: Platform Integration, vendor platform

**Xilinx ZynqMP HARP DFE**:
The Product Integration for the HARP DFE product built on the Xilinx ZynqMP Platform Integration. Its canonical identifier is `xilinx-zynqmp-harp-dfe`.
_Avoid_: Xilinx ZynqMP, generic ZynqMP

**HARP DFE XCZU67DR**:
The Product Machine for the XCZU67DR hardware variant of Xilinx ZynqMP HARP DFE. Its canonical identifier is `harp-dfe-xczu67dr`. It is the intended production target and is currently Parse-Validated; higher support levels require recorded build, boot, ownership, and maintenance evidence.
_Avoid_: zynqmp-generic, Xilinx platform

## Support

**Yocto Series Baseline**:
The Yocto release series that defines compatibility inside one Baseline Profile. A build may consume layers from exactly one Yocto Series Baseline.
_Avoid_: Mixed baseline, forced compatibility

**Baseline Profile**:
An isolated, pinned set of core and integration layers for one Yocto Series Baseline. A Product Machine or Reference Machine binds to exactly one Baseline Profile.
_Avoid_: Runtime branch switch, shared mutable core layers

**Integration Source**:
The direct gitlink checkout containing one or more selected platform or tool layers. An Integration Source is claimed by exactly one Baseline Profile, even when different profiles would select different sublayers from that checkout.
_Avoid_: Shared BSP checkout, per-sublayer ownership

**Support Level**:
An evidence-backed promise assigned to a build target. Higher levels include the guarantees of every lower level.
_Avoid_: Supported, working

**Declared**:
The target is represented in the Build Framework, but no automated validation evidence is promised.

**Parse-Validated**:
The target's metadata is continuously checked for successful parsing in a clean CI environment.

**Build-Validated**:
The target continuously produces its declared image and required build artifacts from a clean environment.

**Boot-Validated**:
The target's built artifacts are demonstrated to boot on named hardware, with the result recorded.

**Production-Supported**:
A Boot-Validated Product Machine with explicit ownership, a pinned release baseline, and an ongoing security and update commitment.
