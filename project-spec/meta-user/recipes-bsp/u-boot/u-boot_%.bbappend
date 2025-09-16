FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
        file://0001-u-boot-spl-zynq-init.inc \
        "

DEPENDS += "dtc-native u-boot-mkimage-native u-boot-mkenvimage-native"


common_uboot_patch_list = " \
        0001-u-boot-spl-zynq-init.inc \
        "

do_patch[depends] += "u-boot-mkimage-native:do_populate_sysroot u-boot-mkenvimage-native:do_populate_sysroot"
