# HARP DFE Kernel-Stall Investigation

## Evidence Status

Historical logs show an RCU stall after an Xilinx interrupt-controller probe. Access to unconfigured PL address space is a plausible cause, but this repository does not contain a recorded hardware experiment proving that diagnosis or a recorded boot proving a fix.

`harp-dfe-xczu67dr` is currently Parse-Validated. Do not cite this document as Boot-Validated evidence.

Example historical symptom:

```text
[5.666687] irq-xilinx: /pl-bus/interrupt-controller@a0000000
[26.665501] rcu: INFO: rcu_sched detected stalls on CPUs/tasks
```

## Current Metadata

The product device tree does not disable the complete PL bus or FPGA region.

`system-user.dtsi` currently:

- disables `gpio_keys`;
- disables `axi_intc_ku5p` pending an overlay;
- disables one 1588 timer instance;
- enables `debug_bridge_0` and `axi_quad_spi_0`;
- adds generic-UIO mappings beneath `amba_pl`;
- configures additional PL Ethernet and DMA nodes.

Therefore the earlier statement that all PL devices were disabled is false. A matching bitstream or a more selective device-tree policy may still be required.

## Investigation Sequence

### 1. Capture Boot State

Record the exact board revision, boot media, image commit, XSA checksum, U-Boot log, and kernel log. At the U-Boot prompt capture:

```text
version
bdinfo
printenv
help fpga
fpga info 0
```

Do not assume the PL is configured because an XSA exists in the build. The checked-in XSA contains no `.bit` file, and the repository has no active automatic U-Boot bitstream-loading flow.

### 2. Inspect the Deployed Device Tree

```bash
umask 0022
. configs/setup-env.sh -T harp-dfe-xczu67dr -p scarthgap
bitbake device-tree
mkdir -p lessons
dtc -I dtb -O dts \
  build/scarthgap/harp-dfe-xczu67dr/tmp/deploy/images/harp-dfe-xczu67dr/system.dtb \
  > lessons/harp-dfe-system.dts
```

Search for the first device named in the boot log and its parents:

```bash
rg -n 'a0000000|interrupt-controller|amba_pl|status =' lessons/harp-dfe-system.dts
```

Confirm whether a product fragment overrides the generated node and whether the node is enabled at boot.

### 3. Verify Hardware/Software Match

The bitstream, XSA, generated device tree, and kernel drivers must describe the same hardware design. A bitstream from another Vivado build is not valid evidence even if programming succeeds.

Check the XSA identity:

```bash
unzip -p products/xilinx-zynqmp-harp-dfe/hardware/system.xsa xsa.json
```

### 4. Run One Controlled Experiment

Choose one variable at a time:

- program a verified matching bitstream before Linux boots; or
- temporarily disable only the first suspect node and its dependent devices.

Do not broadly disable all PL nodes and call the product fixed. That can hide the stall by removing required product functionality.

For a device-tree experiment:

1. make the change in the product-owned DTS fragment;
2. rebuild `device-tree` and the image;
3. decompile the deployed DTB to confirm the change is present;
4. boot the same board and capture a complete log;
5. revert or narrow the experiment after identifying the failing access.

```bash
bitbake -c cleansstate device-tree
bitbake device-tree
bitbake petalinux-image-minimal
```

### 5. Record the Result

A useful boot record includes:

```text
Repository commit:
Target / Baseline:
Board serial and revision:
XSA SHA256:
Bitstream SHA256 and source build:
DTB SHA256:
Boot command:
First failing or successful kernel line:
Full log location:
Result: pass / fail
```

Only a reproducible successful boot on named hardware can support Boot-Validated status.

## About Kernel Parameters

Parameters such as `deferred_probe_timeout=0` can change deferred-probe behavior, but they do not make an unresponsive MMIO target safe. Use them only as diagnostics and do not treat them as a fix for PL bus access.

## Bitstream Path

The manual validation procedure is documented in [U-Boot FPGA Bitstream Loading Guide](UBOOT_FPGA_LOADING_GUIDE.md). It is currently a proposed experiment, not an implemented boot policy.

## Exit Criteria

The investigation is complete only when:

- the first failing access is identified;
- the XSA, bitstream, and DTB are proven to match;
- the boot result is repeatable on a named board;
- required PL functions remain available;
- the evidence is stored with the release or CI/hardware-validation record.
