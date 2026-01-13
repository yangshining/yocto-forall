# XSA File Usage in Yocto Build System

## Overview
This document explains how the Xilinx XSA (Xilinx Support Archive) file is used in the Yocto build process for embedded systems.

## XSA File Location
```
Path: /home2/yang.xu/tool/sources/yocto-forall/components/descriptions/system.xsa
Size: 692KB
```

## Configuration

### In local.conf:
```bitbake
HDF_MACHINE = "zynqmp-eg-generic"
HDF_BASE = "file://"
HDF_PATH = "/home2/yang.xu/tool/sources/yocto-forall/components/descriptions/system.xsa"
```

### In user_extra.conf:
```bitbake
XILINX_WITH_ESW = "xsct"
```

## XSA Processing Flow

### 1. XSA Deployment (external-hdf recipe)
- **Recipe**: `external-hdf_*.bb` (version-specific)
- **Purpose**: Locates and deploys the XSA file
- **Process**:
  ```
  Input: HDF_BASE + HDF_PATH → /path/to/system.xsa
  ↓
  Deploy to: ${DEPLOYDIR}/Xilinx-${MACHINE}.xsa
  ↓
  Provides: virtual/hdf
  ```
- **Location**: `meta-xilinx-tools/recipes-bsp/hdf/`

### 2. Device Tree Generation (device-tree recipe)
- **Recipe**: `device-tree.bb` with `device-tree_xsct.inc`
- **Dependencies**: `virtual/hdf:do_deploy`
- **Process**:
  ```
  XSA File (virtual/hdf)
  ↓
  XSCT Tool + HSI (Hardware Software Interface)
  ↓
  dtgen.tcl script execution
  ↓
  Parse XSA hardware description
  ↓
  Generate Device Tree files:
    - system-top.dts (main device tree)
    - pl.dtsi (programmable logic)
    - pcw.dtsi (processing system)
    - zynqmp-clk-ccf.dtsi (clock framework)
  ↓
  Compile to DTB: system.dtb
  ↓
  Deploy: ${DEPLOYDIR}/system.dtb
  ```

### 3. What Information XSA Contains
The XSA file is a ZIP archive containing:
- **Hardware Definition**: IP blocks, addresses, interrupts
- **Processing System Configuration**: CPU, memory, peripherals
- **Programmable Logic Design**: FPGA fabric configuration
- **Clock Configuration**: All system clocks
- **Pin Assignments**: I/O configuration
- **Bitstream** (optional): FPGA programming file

### 4. Components Using XSA

#### a. Device Tree Generation
- **Tool**: Device Tree Generator (DTG) via XSCT
- **Output**: system.dtb
- **Usage**: Linux kernel hardware description

#### b. FSBL (First Stage Bootloader)
- **Recipe**: `fsbl-firmware`
- **Uses**: Processing system initialization data
- **Output**: zynqmp_fsbl.elf

#### c. PMU Firmware (ZynqMP only)
- **Recipe**: `pmu-firmware`
- **Uses**: Power management unit configuration
- **Output**: pmufw.elf

#### d. U-Boot Configuration
- **Recipe**: `u-boot-xlnx`
- **Uses**: Hardware memory map, peripheral addresses
- **Output**: u-boot.elf

#### e. ARM Trusted Firmware
- **Recipe**: `arm-trusted-firmware`
- **Uses**: Secure boot configuration
- **Output**: bl31.elf

## XSCT Tool Chain

```
XSA File
↓
XSCT (Xilinx Software Command-line Tool)
↓
HSI (Hardware Software Interface) API
↓
Parse hardware description
↓
Generate BSP files:
  - Device Tree
  - Bootloader sources
  - Firmware configurations
```

## Key Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `XILINX_WITH_ESW` | Enable XSCT workflow | `"xsct"` |
| `HDF_BASE` | Protocol for XSA location | `"file://"` or `"git://"` |
| `HDF_PATH` | Path to XSA file | `/path/to/system.xsa` |
| `HDF_MACHINE` | Machine identifier | `"zynqmp-eg-generic"` |
| `HDF_EXT` | File extension | `"xsa"` |
| `XSCTH_HDF` | Deployed XSA location | `${DEPLOYDIR}/Xilinx-${MACHINE}.xsa` |

## TCL Scripts Used

### dtgen.tcl
- **Location**: `meta-xilinx-tools/scripts/dtgen.tcl`
- **Purpose**: Generate device tree from XSA
- **Process**:
  1. Opens XSA hardware design
  2. Sets repository path for DTG
  3. Creates device_tree software design
  4. Applies YAML configurations (if any)
  5. Generates device tree files

### base-hsi.tcl
- **Location**: `meta-xilinx-tools/scripts/base-hsi.tcl`
- **Purpose**: Common HSI utility functions
- **Functions**:
  - `set_hw_design`: Open XSA file
  - `set_properties`: Apply BSP configurations
  - `get_os_config_list`: Query available configs

## Build Process Flow

```
bitbake petalinux-image-minimal
↓
Resolve dependencies
↓
virtual/hdf required
↓
Build external-hdf
  → Copy XSA to deploy directory
  → Create symlinks
↓
Build device-tree (depends on virtual/hdf)
  → Extract XSA
  → Run dtgen.tcl
  → Generate .dts files
  → Compile to .dtb
↓
Build other components
  → fsbl-firmware
  → pmu-firmware
  → arm-trusted-firmware
  → u-boot-xlnx
  → linux-xlnx
↓
Create final image
```

## Troubleshooting

### Error: "CONFIG_DTFILE or SYSTEM_DTFILE is not defined"
**Cause**: `XILINX_WITH_ESW` not set
**Solution**: Add `XILINX_WITH_ESW = "xsct"` to configuration

### Error: "Unable to find XSA file"
**Cause**: Incorrect `HDF_PATH` or file doesn't exist
**Solution**: Verify `HDF_PATH` points to valid XSA file

### Error: "Failed to open hardware design"
**Cause**: Corrupted or incompatible XSA file
**Solution**: Regenerate XSA from Vivado/Vitis

## How to Update XSA

1. Generate new XSA from Vivado:
   ```
   File → Export → Export Hardware
   Include bitstream: Yes/No (depending on needs)
   ```

2. Copy to project location:
   ```bash
   cp /path/to/new_design.xsa \
      /home2/yang.xu/tool/sources/yocto-forall/components/descriptions/system.xsa
   ```

3. Clean and rebuild:
   ```bash
   bitbake -c cleansstate device-tree fsbl-firmware pmu-firmware
   bitbake petalinux-image-minimal
   ```

## References

- Xilinx meta-xilinx-tools Layer
- Device Tree Generator Documentation
- XSCT User Guide
- Yocto Project Documentation

## Notes

- XSA format replaced HDF format starting from Vivado 2019.2
- XSCT workflow requires Vitis/PetaLinux tools to be installed
- Device tree generation is automatic when XILINX_WITH_ESW is enabled
- Manual device tree files in meta-user are optional overlays

