#!/usr/bin/env bash

set -euo pipefail

TOP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <target> [bitbake arguments...]" >&2
    echo "Available targets:" >&2
    bash -c '. "$1" -l' bash "$TOP_DIR/configs/setup-env.sh" >&2
    exit 2
fi

TARGET=$1
shift

if [[ $# -eq 0 ]]; then
    DEFAULT_IMAGE=$(bash -c '. "$1" -n -T "$2"' bash \
        "$TOP_DIR/configs/setup-env.sh" "$TARGET" | \
        sed -n 's/^default_image=//p')
    set -- "$DEFAULT_IMAGE"
fi

cd "$TOP_DIR"
. configs/setup-env.sh -T "$TARGET"
bitbake "$@"
