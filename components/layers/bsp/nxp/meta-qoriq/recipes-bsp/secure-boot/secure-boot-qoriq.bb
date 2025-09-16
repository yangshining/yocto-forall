DESCRIPTION = "NXP secure bootloader for qoriq devices"
SECTION = "bootloaders"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0-only;md5=801f80980d171dd6425610833a22dbe6"

SRC_URI = "file://create_secure_boot_image.sh \
    file://memorylayout.cfg \
    file://${MACHINE}.manifest \
"

inherit deploy

#set ROOTFS_IMAGE = "fsl-image-mfgtool" in local.conf
#set KERNEL_ITS = "kernel-all.its" in local.conf
ITB_IMAGE = "fsl-image-kernelitb"
DEPENDS = "u-boot-mkimage-native qoriq-cst-native qoriq-atf"
DEPENDS:ls1021atwr = "u-boot-mkimage-native qoriq-cst-native u-boot"
do_deploy[depends] += "virtual/kernel:do_deploy ${ITB_IMAGE}:do_build"

BOOT_TYPE ??= ""
BOOT_TYPE:ls1043ardb ?= "nor sd"
BOOT_TYPE:ls1046ardb ?= "qspi sd"
BOOT_TYPE:ls1046afrwy ?= "qspi sd"
BOOT_TYPE:ls1088a ?= "qspi sd"
BOOT_TYPE:ls2088ardb ?= "nor"
BOOT_TYPE:lx2160a ?= "xspi sd"
BOOT_TYPE:lx2162a ?= "xspi sd"
BOOT_TYPE:ls1012ardb ?= "qspi"
BOOT_TYPE:ls1012afrwy ?= "qspi"
BOOT_TYPE:ls1021atwr ?= "nor sd"
BOOT_TYPE:ls1028ardb ?= "xspi sd"

IMA_EVM = "${@bb.utils.contains('DISTRO_FEATURES', 'ima-evm', 'true', 'false', d)}"
ENCAP = "${@bb.utils.contains('DISTRO_FEATURES', 'encap', 'true', 'false', d)}"
SECURE = "${@bb.utils.contains('DISTRO_FEATURES', 'secure', 'true', 'false', d)}"
EDS = "${@bb.utils.contains('DISTRO_FEATURES', 'edgescale', 'true', 'false', d)}"

S = "${WORKDIR}"

do_deploy[nostamp] = "1"
do_patch[noexec] = "1"
do_configure[noexec] = "1"
do_compile[noexec] = "1"

do_deploy () {
    cd ${RECIPE_SYSROOT_NATIVE}/usr/bin/cst
    cp ${S}/*.sh ./
    cp ${S}/${MACHINE}.manifest ./
    cp ${S}/memorylayout.cfg ./
    if [ ${SECURE} = "true" ]; then
        if [ ! -f srk.pri ] && [ -f ${DEPLOY_DIR_IMAGE}/srk.pri ]; then
            cp ${DEPLOY_DIR_IMAGE}/srk.pri ./
            cp ${DEPLOY_DIR_IMAGE}/srk.pub ./
        elif [ ! -f srk.pri ] && [ ! -f ${DEPLOY_DIR_IMAGE}/srk.pri ]; then
            ./gen_keys 1024
        fi
    fi
 
    for d in ${BOOT_TYPE}; do
        ./create_secure_boot_image.sh -m ${MACHINE} -t ${d} -d . -s ${DEPLOY_DIR_IMAGE} -e ${ENCAP} -i ${IMA_EVM} -o ${SECURE}
    done
    if [ "${EDS}" = "true" ];then
        install -d ${DEPLOY_DIR_IMAGE}/bootpartition
        cp ${DEPLOY_DIR_IMAGE}/Image ${DEPLOY_DIR_IMAGE}/bootpartition
        cp ${DEPLOY_DIR_IMAGE}/${MACHINE}_boot.scr ${DEPLOY_DIR_IMAGE}/bootpartition
    fi
}

addtask deploy before do_build after do_compile

PACKAGE_ARCH = "${MACHINE_ARCH}"

COMPATIBLE_MACHINE = "(qoriq-arm|qoriq-arm64)"
