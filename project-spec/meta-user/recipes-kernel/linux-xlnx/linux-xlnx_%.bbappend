FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
            file://0001-Add-driver-for-remaining-memory-domains.patch \
            file://0002-SPI-add-multi-spidev.patch \
            file://0003-Update-Motorcomm-PHY-driver-to-support-additional-PH.patch \
            file://custom-kernel-config.cfg \
            "