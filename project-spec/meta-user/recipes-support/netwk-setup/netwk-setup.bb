SUMMARY = "Network setup script"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://netwk-setup.sh"

S = "${WORKDIR}"

FILESEXTRAPATHS:append := "${THISDIR}/files:"

inherit update-rc.d

INITSCRIPT_NAME = "netwk-setup"
INITSCRIPT_PARAMS = "start 99 S ."

do_install() {
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${S}/netwk-setup.sh ${D}${sysconfdir}/init.d/netwk-setup
}

FILES:${PN} = "${sysconfdir}/init.d/netwk-setup"