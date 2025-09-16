#!/bin/bash
# build-proj.sh
TOP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POKY_DIR="${TOP_DIR}/components/layers/core/poky"
BUILD_DIR="${TOP_DIR}/build"

cd "${POKY_DIR}"
source oe-init-build-env "${BUILD_DIR}"

#function
bb () {
    bitbake $@
}

cd ../