SUMMARY = "Network setup script"
DESCRIPTION = ""
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://netwk-setup.sh"

S = "${WORKDIR}"

FILEEXTRAPATHS:prepend := "${THISDIR}/files:"

inherit update-rc.d

INITSCRIPT_NAME = "netwk-setup"
INITSCRIPT_PARAMS = "start 99 S ."
INIT_D_DIR = "${sysconfdir}/init.d"

do_install() {
    install -d ${D}${INIT_D_DIR}
    install -m 0755 ${S}/netwk-setup.sh ${D}${INIT_D_DIR}/netwk-setup
}
FILES_${PN} += "${sysconfdir}"