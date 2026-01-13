# Kernel Hang Problem - Root Cause and Solutions

## Problem Analysis

### Symptoms
```
[5.666687] irq-xilinx: /pl-bus/interrupt-controller@a0000000
[26.665501] rcu: INFO: rcu_sched detected stalls on CPUs/tasks:
[26.680464] rcu: (detected by 1, t=5252 jiffies, g=-283, q=18 ncpus=4)
```

Kernel hangs at ~26 seconds when probing FPGA (PL) devices.

### Root Cause

**The FPGA (Programmable Logic) is NOT programmed, but the device tree contains PL IP configurations**

Your XSA file contains FPGA IP cores:
- `interrupt-controller@a0000000` - AXI Interrupt Controller
- `radio_ctrl_axi@a0004000` - Radio Control IP
- `cpri0_axi`, `cpri1_axi`, `cpri_top_axi` - CPRI Interface IPs
- `pwr_axi@a0006000` - Power Management IP
- `pap_axi@a0007000` - PAP IP
- `inter_link_axi@a0008000` - Inter-link IP
- `axi_firewall@a000c000` - AXI Firewall

**Problem Flow:**
```
Boot → Load Device Tree → Kernel probes PL devices
    → Access address 0xa0000000 
    → FPGA not programmed, no response
    → CPU hangs waiting for response
    → RCU stall detected
```

## Solutions

### Solution 1: Disable PL Devices in Device Tree (IMPLEMENTED ✅)

**What I Did:**

1. **Modified:** `project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dts`
   ```dts
   /include/ "system-conf.dtsi"

   / {
   };

   /* Disable PL devices until FPGA is programmed */
   &axi_intc_0 {
       status = "disabled";
   };

   &fpga_region {
       status = "disabled";
   };
   ```

2. **Modified:** `project-spec/meta-user/recipes-bsp/device-tree/device-tree_%.bbappend`
   ```bitbake
   FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

   SRC_URI += "file://system-user.dts"

   # Apply user device tree overlay
   EXTRA_DT_INCLUDE_FILES += "system-user.dts"
   ```

**To Apply:**
```bash
cd /home2/yang.xu/tool/sources/yocto-forall
bitbake -c cleansstate device-tree
bitbake device-tree
bitbake petalinux-image-minimal
```

**Result:** System will boot without trying to access PL devices.

---

### Solution 2: Modify Kernel Command Line

Add kernel parameter to disable deferred probe timeout:

**Option A: Temporary (U-Boot command line)**
```
setenv bootargs 'earlycon console=ttyPS0,115200 deferred_probe_timeout=0'
```

**Option B: Permanent (modify boot script)**

Create `/project-spec/meta-user/recipes-bsp/u-boot/files/boot-script`:
```
bootargs=earlycon console=ttyPS0,115200 root=/dev/ram0 rw deferred_probe_timeout=0
```

---

### Solution 3: Load FPGA Bitstream Before Kernel Boot (RECOMMENDED for Production)

**Prerequisites:**
1. Extract bitstream from Vivado design
2. Add bitstream to image

**Steps:**

1. **Export bitstream from Vivado:**
   ```
   Vivado → File → Export → Export Bitstream
   ```

2. **Add to Yocto build:**

   Create `project-spec/meta-user/recipes-bsp/fpga-bitstream/fpga-bitstream.bb`:
   ```bitbake
   SUMMARY = "FPGA Bitstream for ZynqMP"
   LICENSE = "CLOSED"

   SRC_URI = "file://system.bit"

   FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

   inherit deploy

   do_install() {
       install -d ${D}/lib/firmware
       install -m 0644 ${WORKDIR}/system.bit ${D}/lib/firmware/
   }

   do_deploy() {
       install -d ${DEPLOYDIR}
       install -m 0644 ${WORKDIR}/system.bit ${DEPLOYDIR}/
   }

   addtask deploy after do_install
   FILES:${PN} = "/lib/firmware/*"
   ```

3. **Load bitstream in U-Boot:**
   ```
   fpga load 0 ${loadaddr} ${filesize}
   ```

---

### Solution 4: Disable PL Clock in Device Tree

If you want PS-only operation:

**Modify device tree:**
```dts
&amba_pl {
    status = "disabled";
};

&fpga_full {
    status = "disabled";
};
```

---

## Quick Fix Commands

### Temporary Boot Fix (U-Boot)

At U-Boot prompt:
```bash
setenv bootargs 'earlycon console=ttyPS0,115200 deferred_probe_timeout=0'
booti 0x8000000 0x10000000 0x7000000
```

### Rebuild After Changes

```bash
cd /home2/yang.xu/tool/sources/yocto-forall

# Clean and rebuild device tree
bitbake -c cleansstate device-tree
bitbake device-tree

# Rebuild image
bitbake petalinux-image-minimal

# New DTB location
ls -lh build/tmp/deploy/images/zynqmp-eg-generic/system.dtb
```

---

## Understanding the XSA → Device Tree Flow

```
system.xsa (contains FPGA design)
    ↓
[XSCT + Device Tree Generator]
    ↓
Extracts ALL IP configurations:
    - PS (Processing System) ✅ Works
    - PL (Programmable Logic) ⚠️ Needs bitstream
    ↓
Generates system-top.dts with ALL devices
    ↓
Kernel tries to probe ALL devices
    ↓
⚠️ PROBLEM: PL devices not ready → HANG
```

---

## Recommended Approach

### For Development/Testing:
**Use Solution 1** (Disable PL devices in device tree)
- Fast to implement ✅
- Already done
- Just rebuild

### For Production:
**Use Solution 3** (Load bitstream)
- Proper hardware initialization
- All IP cores functional
- Requires bitstream from Vivado

---

## How to Generate Bitstream from XSA

If you need the bitstream:

1. **Check if XSA contains bitstream:**
   ```bash
   unzip -l system.xsa | grep .bit
   ```

2. **If YES, extract it:**
   ```bash
   unzip system.xsa '*.bit' -d bitstream/
   ```

3. **If NO, regenerate XSA in Vivado with bitstream:**
   ```
   Vivado → File → Export → Export Hardware
   ☑ Include bitstream
   ```

---

## Verification Steps

After applying Solution 1 and rebuilding:

1. **Check device tree:**
   ```bash
   dtc -I dtb -O dts build/tmp/deploy/images/zynqmp-eg-generic/system.dtb | grep "status.*disabled"
   ```

2. **Boot and check dmesg:**
   ```bash
   # Should NOT see:
   # - irq-xilinx: /pl-bus/interrupt-controller@a0000000
   # - FPGA Region probed
   ```

3. **Expected boot time:**
   - Should complete in < 10 seconds
   - No RCU stall warnings

---

## Summary

| Solution | Speed | Complexity | Production Ready |
|----------|-------|------------|------------------|
| 1. Disable PL DT | Fast ✅ | Low | No (PS-only) |
| 2. Kernel cmdline | Fast | Low | Maybe |
| 3. Load bitstream | Medium | Medium | Yes ✅ |
| 4. Disable PL clock | Fast | Low | No (PS-only) |

**Current Status:** Solution 1 implemented, needs rebuild.

**Next Step:** Rebuild device-tree and image to test.

