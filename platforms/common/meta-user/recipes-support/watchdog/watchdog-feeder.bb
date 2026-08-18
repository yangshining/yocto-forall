SUMMARY = "Watchdog feeder service"
DESCRIPTION = "Systemd service to feed hardware watchdog"

LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://watchdog-feeder.service"

# Files from SRC_URI moved from WORKDIR to UNPACKDIR in Yocto 5.1.
# Keep this common recipe compatible with older baselines that do not define
# UNPACKDIR while avoiding S = "${WORKDIR}" on newer baselines.
S = "${@d.getVar('UNPACKDIR') or d.getVar('WORKDIR')}"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit systemd

SYSTEMD_PACKAGES = "${PN}"
SYSTEMD_SERVICE:${PN} = "watchdog-feeder.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/watchdog-feeder.service ${D}${systemd_system_unitdir}
}

FILES:${PN} = "${systemd_system_unitdir}/watchdog-feeder.service"
