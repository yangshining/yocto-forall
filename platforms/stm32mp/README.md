# STM32MP Platform Integration

This Platform Integration exposes the pinned STMicroelectronics STM32MP BSP on the `scarthgap` Baseline Profile.

## Reference Machines

| Target | BSP MACHINE | Boot-device policy | Support Level |
|---|---|---|---|
| `stm32mp15-disco` | `stm32mp15-disco` | SD card | Parse-Validated |
| `stm32mp15-eval` | `stm32mp15-eval` | SD card and eMMC | Parse-Validated |

Both targets are Reference Machines. They validate reusable STM32MP Platform Integration behavior and are not Product Machines.

## eMMC Ownership

The pinned vendor machine already declares the STM32MP157F-EV1 eMMC device tree and provides TF-A, FIP, rootfs partition, and FlashLayout generation for the `emmc` boot-device label. The vendor machine leaves that label disabled by default.

Project policy enables it without editing the upstream submodule:

```bitbake
BOOTDEVICE_LABELS:append:stm32mp15-eval = " emmc"
```

The override lives in `conf/local.conf.fragment` because it adapts one vendor Reference Machine inside this Platform Integration. Its machine override keeps `stm32mp15-disco` SD-card-only.

## Build and Inspect

```bash
umask 0022
. configs/setup-env.sh -T stm32mp15-eval -p scarthgap
bitbake-getvar --value BOOTDEVICE_LABELS
bitbake-getvar --value TF_A_CONFIG
bitbake-getvar --value FIP_CONFIG
bitbake-getvar --value FLASHLAYOUT_CONFIG_LABELS
bitbake core-image-minimal
```

Expected metadata includes `emmc`, `opteemin-emmc`, and both `emmc` and `sdcard` FlashLayout labels.

After the image build, inspect:

```text
build/scarthgap/stm32mp15-eval/tmp/deploy/images/stm32mp15-eval/
```

The generated `flashlayout_core-image-minimal/opteemin/*emmc*.tsv` file and its referenced binaries form the STM32CubeProgrammer input. Actual eMMC flashing and boot results must be recorded before changing the target to Build-Validated or Boot-Validated.

## Validation

```bash
python3 -m unittest tests.test_build_registry
bash tests/setup-env-test.sh
. configs/setup-env.sh -V
. configs/setup-env.sh -T stm32mp15-eval -p scarthgap
bitbake-layers show-layers
bitbake -p
```
