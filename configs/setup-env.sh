#!/bin/sh
# -*- mode: shell-script; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
#
# Copyright (C) 2012, 2013, 2016 O.S. Systems Software LTDA.
# Authored-by:  Otavio Salvador <otavio@ossystems.com.br>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Add options for the script
# Copyright (C) 2013 Freescale Semiconductor, Inc.
# Modified for custom Yocto project structure
# Copyright (c) 2025 yangxuemmm@gmail.com.

PROGNAME="setup-env"
curpath=$(pwd)

# Check if script is being sourced
if [ -z "$ZSH_NAME" ] && echo "$0" | grep -q "$PROGNAME"; then
    echo "ERROR: This script needs to be sourced."
    SCRIPT_PATH=`readlink -f $0`
    if [ "`readlink $SHELL`" = "dash" ];then
        echo "Try run command \"set -- -h; . $SCRIPT_PATH\" to get help."
    else
        echo "Try run command \". $SCRIPT_PATH -h\" to get help."
    fi
    unset SCRIPT_PATH PROGNAME
    exit
else
    if [ -n "$BASH_SOURCE" ]; then
        SCRIPT_PATH="`readlink -f $BASH_SOURCE`"
        TOP_DIR="`dirname $SCRIPT_PATH`"
        # If we're in configs directory, go up one level
        if [ "`basename $TOP_DIR`" = "configs" ]; then
            TOP_DIR="`dirname $TOP_DIR`"
        fi
    elif [ -n "$ZSH_NAME" ]; then
        SCRIPT_PATH="`readlink -f $0`"
        TOP_DIR="`dirname $SCRIPT_PATH`"
        # If we're in configs directory, go up one level
        if [ "`basename $TOP_DIR`" = "configs" ]; then
            TOP_DIR="`dirname $TOP_DIR`"
        fi
    else
        TOP_DIR="`readlink -f $PWD`"
        # If we're in configs directory, go up one level
        if [ "`basename $TOP_DIR`" = "configs" ]; then
            TOP_DIR="`dirname $TOP_DIR`"
        fi
    fi
    if ! [ -e "$TOP_DIR/configs/$PROGNAME.sh" ];then
        echo "Go to where $PROGNAME locates, then run: . $PROGNAME <args>"
        echo "Current TOP_DIR: $TOP_DIR"
        echo "Looking for: $TOP_DIR/configs/$PROGNAME.sh"
        unset TOP_DIR PROGNAME
        return
    fi
fi

# Check if current user is root
if [ "$(whoami)" = "root" ]; then
    echo "ERROR: Do not use the BSP as root. Exiting..."
    unset TOP_DIR PROGNAME
    return
fi

MACHINE="zynqmp-generic"

OEROOTDIR=${TOP_DIR}/components/layers/core/poky
if [ -e ${TOP_DIR}/components/layers/core/oe-core ]; then
    OEROOTDIR=${TOP_DIR}/components/layers/core/oe-core
fi
FSLROOTDIR=${TOP_DIR}/components/layers/bsp/nxp/meta-freescale
PROJECT_DIR=${TOP_DIR}/build

prompt_message() {
    local i=''
    echo "Welcome to Freescale QorIQ SDK (Reference Distro)

The Yocto Project has extensive documentation about OE including a
reference manual which can be found at:
    http://yoctoproject.org/documentation

For more information about OpenEmbedded see their website:
    http://www.openembedded.org/

You can now run 'bitbake <target> or yb <target>'
    fsl-image-networking
    fsl-image-networking-full
"
    echo "To return to this build environment later please run:"
    echo "    . $PROJECT_DIR/SOURCE_THIS"
}

# Custom prompt message
prompt_com_message() {
    local i=''
    echo "Welcome to Yocto Project Build Environment

The Yocto Project has extensive documentation about OE including a
reference manual which can be found at:
    http://yoctoproject.org/documentation

For more information about OpenEmbedded see their website:
    http://www.openembedded.org/

Machine: $MACHINE
Distro: $DISTRO
BSP Layer: $MACHINE_LAYER

You can now run 'bitbake <target>' to build images, for example:
    bitbake core-image-minimal
    bitbake core-image-base
    bitbake fsl-image-networking (for Freescale machines)
    bitbake rockchip-image (for Rockchip machines)
"
    echo "To return to this build environment later please run:"
    echo "    . $PROJECT_DIR/SOURCE_THIS"
}

clean_up() {
    unset PROGNAME TOP_DIR OEROOTDIR FSLROOTDIR PROJECT_DIR \
         EULA EULA_FILE LAYER_LIST MACHINE MACHINE_LAYER FSLDISTRO EXTRAROOTDIR \
         OLD_OPTIND CPUS JOBS THREADS DOWNLOADS CACHES DISTRO \
         setup_flag setup_h setup_j setup_t setup_g setup_l setup_builddir \
         setup_download setup_sstate setup_error layer append_layer \
         valid_machine valid_num BASE_LAYER_LIST BSP_LAYER_LIST CACHE_MIRROR
    unset -f usage prompt_message prompt_com_message
}

usage() {
    echo "Usage: . $PROGNAME -m <machine> [options]"

    echo -e "\n    Supported machines:"
    echo "    Freescale/NXP machines:"
    find ${TOP_DIR}/components/layers/bsp/nxp/meta-freescale/conf/machine \
        -name "*.conf" 2>/dev/null | \
        sed 's,.*/,,g;s,.conf,,g' | sort | \
        while read machine; do
            echo "      $machine"
        done
    
    echo "    Rockchip machines:"
    find ${TOP_DIR}/components/layers/bsp/meta-rockchip/conf/machine \
        -name "*.conf" 2>/dev/null | \
        sed 's,.*/,,g;s,.conf,,g' | sort | \
        while read machine; do
            echo "      $machine"
        done
    
    echo "    Xilinx machines:"
    find ${TOP_DIR}/components/layers/bsp/meta-xilinx/conf/machine \
        -name "*.conf" 2>/dev/null | \
        sed 's,.*/,,g;s,.conf,,g' | sort | \
        while read machine; do
            echo "      $machine"
        done

    echo "    STM32MP machines:"
    find ${TOP_DIR}/components/layers/bsp/stm32mp/meta-st-stm32mp/conf/machine \
        -name "*.conf" 2>/dev/null | \
        sed 's,.*/,,g;s,.conf,,g' | sort | \
        while read machine; do
            echo "      $machine"
        done

    echo "    Raspberrypi machines:"
    find ${TOP_DIR}/components/layers/bsp/raspberrypi/meta-raspberrypi/conf/machine \
        -name "*.conf" 2>/dev/null | \
        sed 's,.*/,,g;s,.conf,,g' | sort | \
        while read machine; do
            echo "      $machine"
        done

    echo -e "\n    Optional parameters:
    * [-m machine]: the target machine to be built (required).
    * [-j jobs]:    number of jobs for make to spawn during the compilation stage.
    * [-t tasks]:   number of BitBake tasks that can be issued in parallel.
    * [-b path]:    non-default path of project build folder.
    * [-d path]:    non-default path of DL_DIR (downloaded source)
    * [-c path]:    non-default path of SSTATE_DIR (shared state Cache)
    * [-h]:         help
"
    echo "    Examples:"
    echo "      . $PROGNAME -m ls1043ardb"
    echo "      . $PROGNAME -m rk3568-evb -j 8 -t 4"
    echo "      . $PROGNAME -m zynqmp-zcu102 -b /path/to/build"
    
    if [ "`readlink $SHELL`" = "dash" ];then
        echo "
    You are using dash which does not pass args when being sourced.
    To workaround this limitation, use \"set -- args\" prior to
    sourcing this script. For exmaple:
        \$ set -- -m ls1088ardb -j 3 -t 2
        \$ . $TOP_DIR/configs/$PROGNAME
"
    fi
}

# parse the parameters
OLD_OPTIND=$OPTIND
while getopts "m:j:t:b:d:c:h" setup_flag
do
    case $setup_flag in
        m) MACHINE="$OPTARG";
           ;;
        j) setup_j="$OPTARG";
           ;;
        t) setup_t="$OPTARG";
           ;;
        b) setup_builddir="$OPTARG";
           ;;
        d) setup_download="$OPTARG";
           ;;
        c) setup_sstate="$OPTARG";
           ;;
        h) setup_h='true';
           ;;
        ?) setup_error='true';
           ;;
    esac
done
OPTIND=$OLD_OPTIND

# check the "-h" and other not supported options
if test $setup_error || test $setup_h; then
    usage && clean_up && return
fi

# Check the machine type specified
valid_machine=false

if [ -n "${MACHINE}" ];then
    # Find all machine configuration files
    valid_num=`find ${TOP_DIR}/components/layers/bsp/* \
        -name ${MACHINE}.conf 2>/dev/null |wc -l`
    
    if [ "1" -lt "$valid_num" ];then
        echo "ERROR: possible error may occur due to duplicate ${MACHINE}.conf exist:"
        find ${TOP_DIR}/components/layers/bsp/*/meta-*/conf/machine \
            -name ${MACHINE}.conf 2>/dev/null
        echo "Please remove the useless layer under ${TOP_DIR}/components/layers/bsp"
        clean_up && return
    elif [ "0" = "$valid_num" ];then
        echo "ERROR: Machine '$MACHINE' is not supported by this build setup."
        echo "Available machines:"
        find ${TOP_DIR}/components/layers/bsp/*/meta-*/conf/machine \
            -name "*.conf" 2>/dev/null | \
            sed 's,.*/,,g;s,.conf,,g' | sort | \
            # while read machine; do
            #     echo "  - $machine"
            # done
        usage && clean_up && return
    else
        # Find which layer contains this machine
        MACHINE_LAYER=`find ${TOP_DIR}/components/layers/bsp/* \
            -name ${MACHINE}.conf 2>/dev/null | head -1 | \
            sed 's,.*/components/layers/bsp/\([^/]*\)/meta-\([^/]*\)/.*,meta-\2,'`
        echo "Found machine '$MACHINE' in layer: $MACHINE_LAYER"
        valid_machine=true
    fi
else
    echo "ERROR: Machine type must be specified with -m option"
    usage && clean_up && return
fi

echo "Configuring for ${MACHINE} ..."

# Set cache mirror if environment variable is defined
if [ -n "$YOCTO_CACHE_MIRROR" ]; then
    CACHE_MIRROR="$YOCTO_CACHE_MIRROR"
    echo "Using cache mirror: $CACHE_MIRROR"
fi

# Define base layer lists
BASE_LAYER_LIST=" \
    meta-openembedded/meta-oe \
    meta-openembedded/meta-multimedia \
    meta-openembedded/meta-python \
    meta-openembedded/meta-networking \
    meta-openembedded/meta-gnome \
    meta-openembedded/meta-filesystems \
    meta-openembedded/meta-webserver \
    meta-openembedded/meta-perl \
    meta-openembedded/meta-xfce \
    meta-openembedded/meta-initramfs \
    meta-arm/meta-arm-toolchain \
    meta-arm/meta-arm \
    meta-arm/meta-arm-bsp \
"

# Define BSP layer list based on machine type
BSP_LAYER_LIST=""
case "$MACHINE_LAYER" in
    meta-freescale)
        BSP_LAYER_LIST="meta-freescale meta-virtualization meta-cloud-services meta-security"
        # Add additional layers for QorIQ machines like ls1043ardb
        if expr "$MACHINE" : "ls.*" > /dev/null || expr "$MACHINE" : "t.*" > /dev/null || expr "$MACHINE" : "p.*" > /dev/null || expr "$MACHINE" : "lx.*" > /dev/null; then
            BSP_LAYER_LIST="$BSP_LAYER_LIST meta-qoriq meta-freescale-distro"
        fi
        DISTRO="fsl-qoriq"
        ;;
    meta-rockchip)
        BSP_LAYER_LIST="meta-rockchip"
        DISTRO="poky"
        ;;
    meta-xilinx)
        BSP_LAYER_LIST=" \
            meta-xilinx-tools \
            meta-petalinux \
            meta-security \
            meta-tpm \
            meta-microblaze \
            meta-xilinx-bsp \
            meta-xilinx-core \
            meta-xilinx-contrib \
            meta-xilinx-standalone \
            meta-qt5 \
            meta-virtualization \
            meta-openamp \
            meta-ros-common  \
            meta-ros2 \
            meta-ros2-humble \
            meta-system-controller \
            meta-xilinx-tsn \
            meta-kria \
            "
        DISTRO="petalinux"
        ;;
    meta-st-stm32mp)
        BSP_LAYER_LIST="meta-st-stm32mp"
        DISTRO="poky"
        ;;
    meta-raspberrypi)
        BSP_LAYER_LIST="meta-raspberrypi"
        DISTRO="poky"
        ;;
    *)
        echo "ERROR: Layer not find"
        return
        ;;
esac

# Combine all layers
LAYER_LIST="$BASE_LAYER_LIST $BSP_LAYER_LIST"

# Set EULA file based on BSP layer
case "$MACHINE_LAYER" in
    meta-freescale)
        EULA_FILE="$FSLROOTDIR/EULA"
        ;;
    *)
        EULA_FILE=""
        ;;
esac

# set default jobs and threads
CPUS=`grep -c processor /proc/cpuinfo`
JOBS=`grep -c processor /proc/cpuinfo`
THREADS=`grep -c processor /proc/cpuinfo`

# check optional jobs and threads
if echo "$setup_j" | egrep -q "^[0-9]+$"; then
    JOBS=$setup_j
fi
if echo "$setup_t" | egrep -q "^[0-9]+$"; then
    THREADS=$setup_t
fi

# set project folder location and name
if [ -n "$setup_builddir" ]; then
    if echo $setup_builddir |grep -q ^/;then
        PROJECT_DIR="${setup_builddir}"
    else
        PROJECT_DIR="`pwd`/${setup_builddir}"
    fi
else
    PROJECT_DIR=${TOP_DIR}/build
fi
mkdir -p $PROJECT_DIR

if [ -n "$setup_download" ]; then
    if echo $setup_download |grep -q ^/;then
        DOWNLOADS="${setup_download}"
    else
        DOWNLOADS="`pwd`/${setup_download}"
    fi
else
    DOWNLOADS="$PROJECT_DIR/downloads"
fi
mkdir -p $DOWNLOADS
DOWNLOADS=`readlink -f "$DOWNLOADS"`

if [ -n "$setup_sstate" ]; then
    if echo $setup_sstate |grep -q ^/;then
        CACHES="${setup_sstate}"
    else
        CACHES="`pwd`/${setup_sstate}"
    fi
else
    CACHES="$PROJECT_DIR/sstate-cache"
fi
mkdir -p $CACHES
CACHES=`readlink -f "$CACHES"`

# check if project folder was created before
if [ -e "$PROJECT_DIR/SOURCE_THIS" ]; then
    echo "$PROJECT_DIR was created before."
    . $PROJECT_DIR/SOURCE_THIS
    echo "Nothing is changed."
    clean_up && return
fi

# source oe-init-build-env to init build env
cd $OEROOTDIR
set -- $PROJECT_DIR
. ./oe-init-build-env > /dev/null

# if conf/local.conf not generated, no need to go further
if [ ! -e conf/local.conf ]; then
    echo "ERROR: the local.conf is not created, Exit ..."
    clean_up && cd $TOP_DIR && return
fi

# Remove comment lines and empty lines
sed -i -e '/^#.*/d' -e '/^$/d' conf/local.conf

# Change settings according to the environment
sed -e "s,MACHINE ??=.*,MACHINE ??= '$MACHINE',g" \
        -e "s,DISTRO ?=.*,DISTRO ?= '$DISTRO',g" \
        -i conf/local.conf

# Clean up PATH, because if it includes tokens to current directories somehow,
# wrong binaries can be used instead of the expected ones during task execution
export PATH="`echo $PATH | sed 's/\(:.\|:\)*:/:/g;s/^.\?://;s/:.\?$//'`"

# add layers
for layer in $(eval echo $LAYER_LIST); do
    append_layer=""
    # Check in core layers first
    if [ -e ${TOP_DIR}/components/layers/core/${layer} ]; then
        append_layer="${TOP_DIR}/components/layers/core/${layer}"
    # Check in tools layers
    elif [ -e ${TOP_DIR}/components/layers/tools/${layer} ]; then
        append_layer="${TOP_DIR}/components/layers/tools/${layer}"
    # Then check in BSP layers (support new vendor directory structure)
    elif [ -e ${TOP_DIR}/components/layers/bsp/${layer} ]; then
        append_layer="${TOP_DIR}/components/layers/bsp/${layer}"
    else
        # Check in all subdirectories
        append_layer=`find ${TOP_DIR}/components/layers/ -name ${layer} -type d | head -1`
    fi
    
    if [ -n "${append_layer}" ]; then
        append_layer=`readlink -f $append_layer`
        echo "Adding layer: $append_layer"
        awk '/  "$/ && !x {print "'"  ${append_layer}"' \\"; x=1} 1' \
            conf/bblayers.conf > conf/bblayers.conf~
        mv conf/bblayers.conf~ conf/bblayers.conf
    else
        echo "Warning: Layer '$layer' not found, skipping..."
    fi
done

# add all meta-* layers under project-spec to bblayers.conf
for layer_dir in "${TOP_DIR}"/project-spec/meta-*; do
    if [ -d "$layer_dir" ]; then
        append_layer="$(readlink -f "$layer_dir")"
        echo "Adding layer: $append_layer"
        awk '/  "$/ && !x {print "'"  ${append_layer}"' \\"; x=1} 1' \
            conf/bblayers.conf > conf/bblayers.conf~
        mv conf/bblayers.conf~ conf/bblayers.conf
    fi
done

cat >> conf/local.conf <<-EOF

# Parallelism Options
BB_NUMBER_THREADS = "$THREADS"
PARALLEL_MAKE = "-j $JOBS"
DL_DIR = "$DOWNLOADS"
SSTATE_DIR = "$CACHES"

EOF

# Add machine-specific configurations
case "$MACHINE_LAYER" in
    meta-freescale)
        # Freescale/NXP specific configurations
        if expr "$MACHINE" : lx216;then
           cat >>conf/local.conf <<-EOF

# Specify DISTRO_FEATURES to select Chain of Trust(COT) for Trusted Board Boot
# feature in ATF. Two options:
# 1. secure: generate COT by cst from NXP
# 2. arm-cot: generate COT by cert_create from ATF
# uncomment below line to choose one:
#DISTRO_FEATURES:append = " secure"

EOF
        fi

        if [ "$MACHINE" = "ls1028ardb" ]; then
           cat >>conf/local.conf <<-EOF
PREFERRED_VERSION_weston = "10.0.1.imx"
PREFERRED_VERSION_wayland-protocols = "1.25.imx"
PREFERRED_VERSION_libdrm = "2.4.109.imx"
PREFERRED_PROVIDER_virtual/libgl  = "imx-gpu-viv"
PREFERRED_PROVIDER_virtual/libgles1 = "imx-gpu-viv"
PREFERRED_PROVIDER_virtual/libgles2 = "imx-gpu-viv"
PREFERRED_PROVIDER_virtual/egl      = "imx-gpu-viv"

# Some gstream plugins require "commercial" be set in LICENSE_FLAGS_ACCEPTED
# For exmaple, gstreamer1.0-plugins-ugly-asf/gstreamer1.0-libav
# uncomment the below one line to include them into fsl-image-multimedia-full
LICENSE_FLAGS_ACCEPTED:append = " commercial"

EOF
        fi

        # Add mirror configuration for Freescale machines if needed
        if [ -n "$CACHE_MIRROR" ]; then
           cat >>conf/local.conf <<-EOF

#Add Pre-mirrors
PREMIRRORS:prepend = "\
git://.*/.* file://$CACHE_MIRROR/downloads/ \
ftp://.*/.* file://$CACHE_MIRROR/downloads/ \
http://.*/.* file://$CACHE_MIRROR/downloads/ \
https://.*/.* file://$CACHE_MIRROR/downloads/"

#State mirror settings
SSTATE_MIRRORS = " \
file://.* file://$CACHE_MIRROR/sstate-cache/PATH"

EOF
        fi
        ;;
    meta-rockchip)
        # Rockchip specific configurations
        cat >>conf/local.conf <<-EOF

# Rockchip specific settings
PREFERRED_PROVIDER_virtual/kernel = "linux-rockchip"

EOF
        ;;
    meta-xilinx)
        # Xilinx specific configurations
        cat >>conf/local.conf <<-EOF

# Xilinx specific settings
PREFERRED_PROVIDER_virtual/kernel = "linux-xlnx"
LICENSE_FLAGS_ACCEPTED = "xilinx"

USE_XSCT_TARBALL = "1"

EOF
        ;;
    meta-st-stm32mp)
        # ST STM32MP specific configurations
        cat >>conf/local.conf <<-EOF

# STM32MP specific settings
PREFERRED_PROVIDER_virtual/kernel = "linux-stm32mp"
PREFERRED_PROVIDER_u-boot = "u-boot-stm32mp"

EOF
        ;;
    meta-raspberrypi)
        # Raspberrypi specific configurations
        cat >>conf/local.conf <<-EOF

# Raspberrypi specific settings
PREFERRED_PROVIDER_virtual/kernel = "linux-raspberrypi"
PREFERRED_PROVIDER_virtual/bootloader = "u-boot"
PREFERRED_PROVIDER_u-boot = "u-boot"

# Enable U-Boot for Raspberry Pi
RPI_USE_U_BOOT = "1"

# U-Boot specific configurations
# Note: UBOOT_MACHINE and UBOOT_ARCH will be set by machine config
# For 64-bit RPi: UBOOT_MACHINE = "rpi_arm64_config", KERNEL_BOOTCMD = "booti", KERNEL_IMAGETYPE_UBOOT = "Image"
# For 32-bit RPi: UBOOT_MACHINE = "rpi_config", KERNEL_BOOTCMD = "bootm", KERNEL_IMAGETYPE_UBOOT = "uImage"

# Enable I2C and SPI by default
ENABLE_I2C = "1"
ENABLE_SPI = "1"

# Enable camera interface
ENABLE_CAMERA = "1"

# Enable UART
ENABLE_UART = "1"

# U-Boot environment configuration
UBOOT_ENV_SIZE = "0x20000"
UBOOT_ENV_OFFSET = "0x100000"

EOF
        ;;
esac

for s in $HOME/.oe $HOME/.yocto; do
    if [ -e $s/site.conf ]; then
        echo "Linking $s/site.conf to conf/site.conf"
        ln -s $s/site.conf conf
    fi
done

if echo "$MACHINE" |egrep -q "^(b4|p5|t1|t2|t4)"; then
    # disable prelink (for multilib scenario) for now
    sed -i s/image-mklibs.image-prelink/image-mklibs/g conf/local.conf
fi

# Handle EULA setting (only for Freescale/NXP)
if [ "$MACHINE_LAYER" = "meta-freescale" ] && [ -n "$EULA_FILE" ]; then
    if [ -z "$EULA" ] && ! grep -q '^ACCEPT_FSL_EULA\s*=' conf/local.conf; then
        EULA='ask'
    fi

    if [ "$EULA" = "ask" ]; then
        cat <<EOF

Proprietary and third party software is subject to agreement and compliance
with, Freescale's End User License Agreement. To have the right to use these
binaries in your images, you must read and accept the following terms.  If
there are conflicting terms embedded in the software, the terms embedded in
the Software will control.

In all cases,  open source software is licensed under the terms of the
applicable open source license(s), such as the BSD License, Apache License or
the GNU Lesser General Public License.  Your use of the open source software
is subject to the terms of each applicable license.  You must agree to the
terms of each applicable license, or you cannot use the open source software.

EOF
        # Auto accept EULA for simple setup
        EULA="1"
    fi

    if grep -q '^ACCEPT_FSL_EULA\s*=' conf/local.conf; then
        sed -i "s/^#*ACCEPT_FSL_EULA\s*=.*/ACCEPT_FSL_EULA = \"$EULA\"/g" conf/local.conf
    else
        echo "ACCEPT_FSL_EULA = \"$EULA\"" >> conf/local.conf
    fi
fi

# add local-proj.conf for boot-up
echo "" >> conf/local.conf
echo "include conf/local-proj.conf" >> conf/local.conf
cp -f $TOP_DIR/configs/local-proj.conf conf/local-proj.conf

# make a SOURCE_THIS file
if [ ! -e SOURCE_THIS ]; then
    echo "#!/bin/sh" >> SOURCE_THIS
    echo "cd $OEROOTDIR" >> SOURCE_THIS
    echo "set -- $PROJECT_DIR" >> SOURCE_THIS
    echo ". ./oe-init-build-env > /dev/null" >> SOURCE_THIS
    echo "echo \"Back to build project $PROJECT_DIR.\"" >> SOURCE_THIS
fi

prompt_com_message
# cd $PROJECT_DIR
cd $TOP_DIR
clean_up

