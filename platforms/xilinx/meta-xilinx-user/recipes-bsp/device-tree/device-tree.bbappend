FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://system-user.dtsi \
            file://system-conf.dtsi \
            "
EXTRA_DT_INCLUDE_FILES += "system-user.dtsi system-conf.dtsi"
