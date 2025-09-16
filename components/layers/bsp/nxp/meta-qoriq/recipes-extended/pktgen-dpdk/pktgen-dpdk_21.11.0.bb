DESCRIPTION = "PKTGEN DPDK"
LICENSE = "BSD"
LIC_FILES_CHKSUM = "file://LICENSE;md5=0245ceedaef59ae0129500b0ce1e8a45"

DEPENDS += "libpcap dpdk lua lua-native numactl"

SRC_URI = "git://github.com/pktgen/Pktgen-DPDK.git;protocol=https;nobranch=1"
SRCREV = "178c06ff7ca242b2485d65ae427fd82b62a71601"

S = "${WORKDIR}/git"

DPAA_VER ?= "dpaa"
export RTE_TARGET = "arm64-${DPAA_VER}-linuxapp-gcc"
export RTE_SDK = "${RECIPE_SYSROOT}/usr/share/dpdk"

inherit meson pkgconfig

MESON_BUILDTYPE = "release"
EXTRA_OEMESON += '-Dc_args="-DRTE_FORCE_INTRINSICS"'

do_configure:prepend() {
    sed -i "/^add_project_arguments('-march=native'/s/^/#&/" ${S}/meson.build
}

do_install() {
    install -d ${D}${bindir}/
    install -m 0755 app/pktgen ${D}${bindir}/
    install -m 0644 ${S}/Pktgen.lua ${D}${bindir}/
}

INSANE_SKIP:${PN} = "ldflags"
INHIBIT_PACKAGE_STRIP = "1"
PACKAGE_ARCH = "${MACHINE_ARCH}"
PARALLEL_MAKE = ""
COMPATIBLE_MACHINE = "(qoriq-arm64)"
