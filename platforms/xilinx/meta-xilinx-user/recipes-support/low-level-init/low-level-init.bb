SUMMARY = "Low-level initialization service"
DESCRIPTION = "Systemd service to execute low-level initialization scripts in sequence"
SECTION = "PETALINUX/apps"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

PR = "r01"

SRC_URI = "file://insert-dtbo.sh \
           file://netwk-setup.sh \
           file://low-level-init.sh \
           file://low-level-init.service \
          "

S = "${WORKDIR}"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "low-level-init.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/insert-dtbo.sh ${D}${bindir}/insert-dtbo.sh
    install -m 0755 ${WORKDIR}/netwk-setup.sh ${D}${bindir}/netwk-setup.sh
    install -m 0755 ${WORKDIR}/low-level-init.sh ${D}${bindir}/low-level-init.sh
    
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/low-level-init.service ${D}${systemd_system_unitdir}
}

FILES:${PN} = "${bindir}/insert-dtbo.sh \
               ${bindir}/netwk-setup.sh \
               ${bindir}/low-level-init.sh \
               ${systemd_system_unitdir}/low-level-init.service \
               "
