SUMMARY = "Watchdog feeder service"
DESCRIPTION = "Systemd service to feed hardware watchdog"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://watchdog-feeder.service"

S = "${WORKDIR}"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "watchdog-feeder.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/watchdog-feeder.service ${D}${systemd_system_unitdir}
}

FILES:${PN} = "${systemd_system_unitdir}/watchdog-feeder.service"
