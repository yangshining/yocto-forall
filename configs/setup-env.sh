#!/bin/sh
# shellcheck shell=sh

# Source this file. It intentionally leaves the selected Yocto environment in
# the caller while cleaning up its own helper variables and functions.

YF_PROGNAME="setup-env"
YF_IS_SOURCED="true"

if [ -n "${BASH_SOURCE:-}" ] && [ "$BASH_SOURCE" = "$0" ]; then
    YF_IS_SOURCED="false"
elif [ -n "${ZSH_NAME:-}" ]; then
    case ${ZSH_EVAL_CONTEXT:-} in
        *:file|file) YF_IS_SOURCED="true" ;;
        *) YF_IS_SOURCED="false" ;;
    esac
else
    case $0 in
        *setup-env|*setup-env.sh) YF_IS_SOURCED="false" ;;
    esac
fi

if [ "$YF_IS_SOURCED" != "true" ]; then
    printf 'ERROR: This script must be sourced.\n' >&2
    printf 'Try: . configs/setup-env.sh -m <target>\n' >&2
    unset YF_PROGNAME YF_IS_SOURCED
    exit 1
fi

YF_CALLER_DIR=$(pwd -P)

if [ -n "${YOCTO_FORALL_TOP_DIR:-}" ]; then
    YF_TOP_DIR=$(CDPATH= cd -- "$YOCTO_FORALL_TOP_DIR" 2>/dev/null && pwd -P)
elif [ -n "${BASH_SOURCE:-}" ]; then
    YF_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$BASH_SOURCE")" && pwd -P)
    YF_TOP_DIR=$(CDPATH= cd -- "$YF_SCRIPT_DIR/.." && pwd -P)
elif [ -n "${ZSH_NAME:-}" ] && [ -f "$0" ]; then
    YF_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
    YF_TOP_DIR=$(CDPATH= cd -- "$YF_SCRIPT_DIR/.." && pwd -P)
elif [ -f "$YF_CALLER_DIR/configs/setup-env.sh" ]; then
    YF_TOP_DIR=$YF_CALLER_DIR
elif [ "$(basename -- "$YF_CALLER_DIR")" = "configs" ] && \
     [ -f "$YF_CALLER_DIR/setup-env.sh" ]; then
    YF_TOP_DIR=$(CDPATH= cd -- "$YF_CALLER_DIR/.." && pwd -P)
else
    printf 'ERROR: Run from the repository root or set YOCTO_FORALL_TOP_DIR.\n' >&2
    unset YF_PROGNAME YF_IS_SOURCED YF_CALLER_DIR YF_TOP_DIR YF_SCRIPT_DIR
    return 1
fi

if [ -z "$YF_TOP_DIR" ] || [ ! -d "$YF_TOP_DIR/configs" ] || \
   [ ! -d "$YF_TOP_DIR/baselines" ]; then
    printf 'ERROR: Invalid repository root: %s\n' "${YF_TOP_DIR:-<empty>}" >&2
    unset YF_PROGNAME YF_IS_SOURCED YF_CALLER_DIR YF_TOP_DIR YF_SCRIPT_DIR
    return 1
fi

if [ -z "${YF_SCRIPT_DIR:-}" ]; then
    if [ -n "${BASH_SOURCE:-}" ]; then
        YF_SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$BASH_SOURCE")" && pwd -P)
    elif [ -f "$YF_CALLER_DIR/configs/build_registry.py" ]; then
        YF_SCRIPT_DIR="$YF_CALLER_DIR/configs"
    else
        YF_SCRIPT_DIR="$YF_TOP_DIR/configs"
    fi
fi
YF_REGISTRY_SCRIPT="$YF_SCRIPT_DIR/build_registry.py"

yf_cleanup() {
    OPTIND=$YF_OLD_OPTIND
    unset YF_ACTION YF_BASELINE_ID YF_BASELINE_LAYERS YF_BASELINE_OEROOT
    unset YF_BASELINE_SERIES YF_BUILD_DIR YF_CACHE_MIRROR YF_CALLER_DIR
    unset YF_CONF_DIR YF_CPUS YF_DEFAULT_IMAGE
    unset YF_DOWNLOADS_DIR YF_DRY_RUN YF_EXPECTED
    unset YF_ID YF_IS_SOURCED YF_JOBS YF_LAYER YF_LAYER_ABS
    unset YF_LAYER_PATHS YF_LOCAL_CONF YF_MANIFEST
    unset YF_OLD_OPTIND YF_OLD_VALUE YF_OEROOT YF_OPTION YF_PATH
    unset YF_PLATFORM_DISTRO YF_PLATFORM_ID YF_PLATFORM_LAYERS YF_PLATFORM_LOCAL_CONF
    unset YF_PRODUCT_ID YF_PRODUCT_LAYERS YF_PRODUCT_LOCAL_CONF
    unset YF_PROFILE_ASSERTION YF_PROGNAME YF_PROTOCOL_DATA YF_PROTOCOL_KEY
    unset YF_PROTOCOL_LINE YF_PROTOCOL_STAGE YF_PROTOCOL_VALUE
    unset YF_REGISTRY_SCRIPT YF_REQUESTED_MACHINE YF_REQUESTED_TARGET YF_SAVED_DIR
    unset YF_SELECTOR YF_SELECTOR_MODE
    unset YF_SETUP_BUILDDIR YF_SETUP_DOWNLOADS
    unset YF_SETUP_SSTATE YF_SSTATE_DIR YF_STATUS YF_SUPPORT_LEVEL
    unset YF_TARGET_BASELINE YF_TARGET_ID YF_TARGET_MACHINE
    unset YF_TARGET_PLATFORM YF_TARGET_PRODUCT YF_THREADS
    unset YF_TOP_DIR YF_VALUE YF_IMAGE_LINK YF_SCRIPT_DIR
    unset -f yf_add_layer yf_cleanup yf_compute_paths yf_die yf_dquote_safe
    unset -f yf_load_protocol yf_manifest_value yf_print_selection
    unset -f yf_validate_id yf_validate_relpath
    unset -f yf_write_bblayers yf_write_local_conf yf_write_manifest yf_write_source_this
}

yf_die() {
    printf 'ERROR: %s\n' "$1" >&2
    return 1
}

yf_validate_id() {
    case ${2:-} in
        ""|*[!A-Za-z0-9._+-]*)
            yf_die "$1 has invalid identifier '${2:-}'"
            return 1
            ;;
    esac
    return 0
}

yf_validate_relpath() {
    case ${2:-} in
        ""|/*|.|./*|../*|*/./*|*/.|*/../*|*/..|*//*|*/|*" "*|*"	"*)
            yf_die "$1 must be a canonical repository-relative path, got '${2:-}'"
            return 1
            ;;
    esac
    return 0
}

yf_load_protocol() {
    YF_PROTOCOL_DATA=$1
    YF_PROTOCOL_STAGE=0
    YF_BASELINE_LAYERS=""
    YF_PLATFORM_LAYERS=""
    YF_PRODUCT_LAYERS=""

    while IFS= read -r YF_PROTOCOL_LINE; do
        case $YF_PROTOCOL_LINE in
            *=*) ;;
            *) yf_die "Invalid Build Registry protocol line: '$YF_PROTOCOL_LINE'"; return 1 ;;
        esac
        YF_PROTOCOL_KEY=${YF_PROTOCOL_LINE%%=*}
        YF_PROTOCOL_VALUE=${YF_PROTOCOL_LINE#*=}
        case $YF_PROTOCOL_KEY in
            PROTOCOL)
                [ "$YF_PROTOCOL_STAGE" -eq 0 ] && [ "$YF_PROTOCOL_VALUE" = "1" ] || {
                    yf_die "Unsupported or out-of-order Build Registry protocol"
                    return 1
                }
                YF_PROTOCOL_STAGE=1
                ;;
            TARGET_ID)
                [ "$YF_PROTOCOL_STAGE" -eq 1 ] || { yf_die "Out-of-order TARGET_ID in Build Registry protocol"; return 1; }
                YF_TARGET_ID=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=2
                ;;
            TARGET_MACHINE)
                [ "$YF_PROTOCOL_STAGE" -eq 2 ] || { yf_die "Out-of-order TARGET_MACHINE in Build Registry protocol"; return 1; }
                YF_TARGET_MACHINE=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=3
                ;;
            TARGET_BASELINE)
                [ "$YF_PROTOCOL_STAGE" -eq 3 ] || { yf_die "Out-of-order TARGET_BASELINE in Build Registry protocol"; return 1; }
                YF_TARGET_BASELINE=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=4
                ;;
            TARGET_PLATFORM)
                [ "$YF_PROTOCOL_STAGE" -eq 4 ] || { yf_die "Out-of-order TARGET_PLATFORM in Build Registry protocol"; return 1; }
                YF_TARGET_PLATFORM=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=5
                ;;
            TARGET_PRODUCT)
                [ "$YF_PROTOCOL_STAGE" -eq 5 ] || { yf_die "Out-of-order TARGET_PRODUCT in Build Registry protocol"; return 1; }
                YF_TARGET_PRODUCT=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=6
                ;;
            TARGET_SUPPORT_LEVEL)
                [ "$YF_PROTOCOL_STAGE" -eq 6 ] || { yf_die "Out-of-order TARGET_SUPPORT_LEVEL in Build Registry protocol"; return 1; }
                YF_SUPPORT_LEVEL=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=7
                ;;
            TARGET_DEFAULT_IMAGE)
                [ "$YF_PROTOCOL_STAGE" -eq 7 ] || { yf_die "Out-of-order TARGET_DEFAULT_IMAGE in Build Registry protocol"; return 1; }
                YF_DEFAULT_IMAGE=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=8
                ;;
            BASELINE_SERIES)
                [ "$YF_PROTOCOL_STAGE" -eq 8 ] || { yf_die "Out-of-order BASELINE_SERIES in Build Registry protocol"; return 1; }
                YF_BASELINE_SERIES=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=9
                ;;
            BASELINE_OEROOT)
                [ "$YF_PROTOCOL_STAGE" -eq 9 ] || { yf_die "Out-of-order BASELINE_OEROOT in Build Registry protocol"; return 1; }
                YF_BASELINE_OEROOT=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=10
                ;;
            BASELINE_LAYER)
                case $YF_PROTOCOL_STAGE in 10|11) ;; *) yf_die "Out-of-order BASELINE_LAYER in Build Registry protocol"; return 1 ;; esac
                [ -n "$YF_PROTOCOL_VALUE" ] || { yf_die "Empty BASELINE_LAYER in Build Registry protocol"; return 1; }
                YF_BASELINE_LAYERS="${YF_BASELINE_LAYERS}${YF_BASELINE_LAYERS:+ }$YF_PROTOCOL_VALUE"
                YF_PROTOCOL_STAGE=11
                ;;
            PLATFORM_DISTRO)
                [ "$YF_PROTOCOL_STAGE" -eq 11 ] || { yf_die "Out-of-order PLATFORM_DISTRO in Build Registry protocol"; return 1; }
                YF_PLATFORM_DISTRO=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=12
                ;;
            PLATFORM_LAYER)
                case $YF_PROTOCOL_STAGE in 12|13) ;; *) yf_die "Out-of-order PLATFORM_LAYER in Build Registry protocol"; return 1 ;; esac
                [ -n "$YF_PROTOCOL_VALUE" ] || { yf_die "Empty PLATFORM_LAYER in Build Registry protocol"; return 1; }
                YF_PLATFORM_LAYERS="${YF_PLATFORM_LAYERS}${YF_PLATFORM_LAYERS:+ }$YF_PROTOCOL_VALUE"
                YF_PROTOCOL_STAGE=13
                ;;
            PLATFORM_LOCAL_CONF)
                case $YF_PROTOCOL_STAGE in 12|13) ;; *) yf_die "Out-of-order PLATFORM_LOCAL_CONF in Build Registry protocol"; return 1 ;; esac
                YF_PLATFORM_LOCAL_CONF=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=14
                ;;
            PRODUCT_LAYER)
                case $YF_PROTOCOL_STAGE in 14|15) ;; *) yf_die "Out-of-order PRODUCT_LAYER in Build Registry protocol"; return 1 ;; esac
                [ -n "$YF_PROTOCOL_VALUE" ] || { yf_die "Empty PRODUCT_LAYER in Build Registry protocol"; return 1; }
                YF_PRODUCT_LAYERS="${YF_PRODUCT_LAYERS}${YF_PRODUCT_LAYERS:+ }$YF_PROTOCOL_VALUE"
                YF_PROTOCOL_STAGE=15
                ;;
            PRODUCT_LOCAL_CONF)
                case $YF_PROTOCOL_STAGE in 14|15) ;; *) yf_die "Out-of-order PRODUCT_LOCAL_CONF in Build Registry protocol"; return 1 ;; esac
                YF_PRODUCT_LOCAL_CONF=$YF_PROTOCOL_VALUE
                YF_PROTOCOL_STAGE=16
                ;;
            *)
                yf_die "Unknown Build Registry protocol key '$YF_PROTOCOL_KEY'"
                return 1
                ;;
        esac
    done <<YF_PROTOCOL_INPUT
$YF_PROTOCOL_DATA
YF_PROTOCOL_INPUT

    [ "$YF_PROTOCOL_STAGE" -eq 16 ] || {
        yf_die "Incomplete Build Registry protocol"
        return 1
    }
    for YF_PROTOCOL_VALUE in \
        "$YF_TARGET_ID" "$YF_TARGET_MACHINE" "$YF_TARGET_BASELINE" \
        "$YF_TARGET_PLATFORM" "$YF_SUPPORT_LEVEL" "$YF_DEFAULT_IMAGE" \
        "$YF_BASELINE_SERIES" "$YF_BASELINE_OEROOT" "$YF_BASELINE_LAYERS" \
        "$YF_PLATFORM_DISTRO"; do
        [ -n "$YF_PROTOCOL_VALUE" ] || {
            yf_die "Build Registry protocol is missing a required value"
            return 1
        }
    done
    YF_BASELINE_ID=$YF_TARGET_BASELINE
    YF_PLATFORM_ID=$YF_TARGET_PLATFORM
    YF_PRODUCT_ID=$YF_TARGET_PRODUCT
    return 0
}

yf_compute_paths() {
    YF_OEROOT="$YF_TOP_DIR/$YF_BASELINE_OEROOT"
    if [ -n "$YF_SETUP_BUILDDIR" ]; then
        case $YF_SETUP_BUILDDIR in
            /*) YF_BUILD_DIR=$YF_SETUP_BUILDDIR ;;
            *) YF_BUILD_DIR="$YF_CALLER_DIR/$YF_SETUP_BUILDDIR" ;;
        esac
    else
        YF_BUILD_DIR="$YF_TOP_DIR/build/$YF_BASELINE_ID/$YF_TARGET_ID"
    fi
    if [ -n "$YF_SETUP_DOWNLOADS" ]; then
        case $YF_SETUP_DOWNLOADS in
            /*) YF_DOWNLOADS_DIR=$YF_SETUP_DOWNLOADS ;;
            *) YF_DOWNLOADS_DIR="$YF_CALLER_DIR/$YF_SETUP_DOWNLOADS" ;;
        esac
    else
        YF_DOWNLOADS_DIR="$YF_TOP_DIR/.yocto-cache/$YF_BASELINE_ID/downloads"
    fi
    if [ -n "$YF_SETUP_SSTATE" ]; then
        case $YF_SETUP_SSTATE in
            /*) YF_SSTATE_DIR=$YF_SETUP_SSTATE ;;
            *) YF_SSTATE_DIR="$YF_CALLER_DIR/$YF_SETUP_SSTATE" ;;
        esac
    else
        YF_SSTATE_DIR="$YF_TOP_DIR/.yocto-cache/$YF_BASELINE_ID/sstate-cache"
    fi
}

yf_add_layer() {
    yf_validate_relpath "layer path" "$1" || return 1
    case " $YF_LAYER_PATHS " in
        *" $1 "*) return 0 ;;
    esac
    YF_LAYER_PATHS="$YF_LAYER_PATHS $1"
}

yf_print_selection() {
    printf 'target=%s\n' "$YF_TARGET_ID"
    printf 'machine=%s\n' "$YF_TARGET_MACHINE"
    printf 'baseline=%s\n' "$YF_BASELINE_ID"
    printf 'series=%s\n' "$YF_BASELINE_SERIES"
    printf 'platform=%s\n' "$YF_PLATFORM_ID"
    printf 'product=%s\n' "${YF_PRODUCT_ID:-none}"
    printf 'support=%s\n' "$YF_SUPPORT_LEVEL"
    printf 'distro=%s\n' "$YF_PLATFORM_DISTRO"
    printf 'default_image=%s\n' "$YF_DEFAULT_IMAGE"
    printf 'build_dir=%s\n' "$YF_BUILD_DIR"
    printf 'downloads_dir=%s\n' "$YF_DOWNLOADS_DIR"
    printf 'sstate_dir=%s\n' "$YF_SSTATE_DIR"
}

yf_dquote_safe() {
    case $2 in
        *\"*) yf_die "$1 may not contain a double quote"; return 1 ;;
    esac
    return 0
}

yf_manifest_value() {
    sed -n "s/^$2=\"\(.*\)\"$/\1/p" "$1" | sed -n '1p'
}

yf_write_bblayers() {
    {
        printf '%s\n' 'POKY_BBLAYERS_CONF_VERSION = "2"'
        printf '%s\n' 'BBPATH = "${TOPDIR}"'
        printf '%s\n' 'BBFILES ?= ""'
        printf '%s\n' 'BBLAYERS ?= " \'
        for YF_LAYER in $YF_LAYER_PATHS; do
            printf '  %s \\\n' "$YF_TOP_DIR/$YF_LAYER"
        done
        printf '%s\n' '  "'
    } > "$YF_CONF_DIR/bblayers.conf"
}

yf_write_local_conf() {
    YF_LOCAL_CONF="$YF_CONF_DIR/local.conf"
    sed '/^# YOCTO_FORALL_BEGIN$/,/^# YOCTO_FORALL_END$/d' "$YF_LOCAL_CONF" \
        > "$YF_LOCAL_CONF.yocto-forall" || return 1
    mv "$YF_LOCAL_CONF.yocto-forall" "$YF_LOCAL_CONF" || return 1

    cp "$YF_TOP_DIR/configs/local-proj.conf" "$YF_CONF_DIR/local-proj.conf" || return 1

    {
        printf '\n# YOCTO_FORALL_BEGIN\n'
        printf '# Generated by configs/setup-env.sh; rerun setup instead of editing this block.\n'
        printf 'MACHINE = "%s"\n' "$YF_TARGET_MACHINE"
        printf 'DISTRO = "%s"\n' "$YF_PLATFORM_DISTRO"
        printf 'BB_NUMBER_THREADS = "%s"\n' "$YF_THREADS"
        printf 'PARALLEL_MAKE = "-j %s"\n' "$YF_JOBS"
        printf 'DL_DIR = "%s"\n' "$YF_DOWNLOADS_DIR"
        printf 'SSTATE_DIR = "%s"\n' "$YF_SSTATE_DIR"
        printf 'YOCTO_FORALL_REPO_ROOT = "%s"\n' "$YF_TOP_DIR"
        printf 'YOCTO_FORALL_TARGET = "%s"\n' "$YF_TARGET_ID"
        printf 'YOCTO_FORALL_BASELINE = "%s"\n' "$YF_BASELINE_ID"
        printf 'include conf/local-proj.conf\n'
        if [ -n "$YF_PLATFORM_LOCAL_CONF" ]; then
            printf '\n# Platform: %s\n' "$YF_PLATFORM_ID"
            sed -n 'p' "$YF_TOP_DIR/$YF_PLATFORM_LOCAL_CONF"
        fi
        if [ -n "$YF_PRODUCT_LOCAL_CONF" ]; then
            printf '\n# Product: %s\n' "$YF_PRODUCT_ID"
            sed -n 'p' "$YF_TOP_DIR/$YF_PRODUCT_LOCAL_CONF"
        fi
        if [ -n "$YF_CACHE_MIRROR" ]; then
            printf '\nPREMIRRORS:prepend = "\\\n'
            printf 'git://.*/.* file://%s/downloads/ \\\n' "$YF_CACHE_MIRROR"
            printf 'ftp://.*/.* file://%s/downloads/ \\\n' "$YF_CACHE_MIRROR"
            printf 'http://.*/.* file://%s/downloads/ \\\n' "$YF_CACHE_MIRROR"
            printf 'https://.*/.* file://%s/downloads/"\n' "$YF_CACHE_MIRROR"
            printf 'SSTATE_MIRRORS = "file://.* file://%s/sstate-cache/PATH"\n' "$YF_CACHE_MIRROR"
        fi
        printf '# YOCTO_FORALL_END\n'
    } >> "$YF_LOCAL_CONF"
}

yf_write_manifest() {
    {
        printf 'TARGET_ID="%s"\n' "$YF_TARGET_ID"
        printf 'MACHINE="%s"\n' "$YF_TARGET_MACHINE"
        printf 'PLATFORM_ID="%s"\n' "$YF_PLATFORM_ID"
        printf 'PRODUCT_ID="%s"\n' "$YF_PRODUCT_ID"
        printf 'BASELINE_ID="%s"\n' "$YF_BASELINE_ID"
        printf 'BASELINE_SERIES="%s"\n' "$YF_BASELINE_SERIES"
        printf 'OEROOT="%s"\n' "$YF_OEROOT"
        printf 'DISTRO="%s"\n' "$YF_PLATFORM_DISTRO"
        printf 'SUPPORT_LEVEL="%s"\n' "$YF_SUPPORT_LEVEL"
    } > "$YF_MANIFEST"
}

yf_write_source_this() {
    {
        printf '#!/bin/sh\n'
        printf 'cd "%s" || return 1\n' "$YF_OEROOT"
        printf 'set -- "%s"\n' "$YF_BUILD_DIR"
        printf '. ./oe-init-build-env > /dev/null || return 1\n'
        printf 'printf '\''Back to %s (%s / %s).\\n'\''\n' \
            "$YF_TARGET_ID" "$YF_BASELINE_ID" "$YF_TARGET_MACHINE"
    } > "$YF_BUILD_DIR/SOURCE_THIS"
}

YF_OLD_OPTIND=${OPTIND:-1}
OPTIND=1
YF_ACTION="setup"
YF_DRY_RUN="false"
YF_REQUESTED_MACHINE=""
YF_REQUESTED_TARGET=""
YF_PROFILE_ASSERTION=""
YF_SETUP_BUILDDIR=""
YF_SETUP_DOWNLOADS=""
YF_SETUP_SSTATE=""
YF_JOBS=""
YF_THREADS=""

while getopts ':m:T:p:j:t:b:d:c:nlVh' YF_OPTION; do
    case $YF_OPTION in
        m) YF_REQUESTED_MACHINE=$OPTARG ;;
        T) YF_REQUESTED_TARGET=$OPTARG ;;
        p) YF_PROFILE_ASSERTION=$OPTARG ;;
        j) YF_JOBS=$OPTARG ;;
        t) YF_THREADS=$OPTARG ;;
        b) YF_SETUP_BUILDDIR=$OPTARG ;;
        d) YF_SETUP_DOWNLOADS=$OPTARG ;;
        c) YF_SETUP_SSTATE=$OPTARG ;;
        n) YF_DRY_RUN="true" ;;
        l) YF_ACTION="list" ;;
        V) YF_ACTION="validate" ;;
        h) YF_ACTION="help" ;;
        :) yf_die "Option -$OPTARG requires a value."; yf_cleanup; return 1 ;;
        \?) yf_die "Unknown option -$OPTARG. Use -h for help."; yf_cleanup; return 1 ;;
    esac
done

if [ "$YF_ACTION" = "help" ]; then
    printf 'Usage: . configs/setup-env.sh -m <target-or-machine> [options]\n'
    printf '       . configs/setup-env.sh -T <target-id> [options]\n\n'
    printf '  -m <name>     Compatibility selector: target ID, BSP MACHINE, or safe alias\n'
    printf '  -T <target>   Canonical target ID\n'
    printf '  -p <profile>  Assert (do not override) the target Baseline Profile\n'
    printf '  -j <jobs>     PARALLEL_MAKE job count\n'
    printf '  -t <tasks>    BB_NUMBER_THREADS task count\n'
    printf '  -b <path>     Build directory (default: build/<profile>/<target>)\n'
    printf '  -d <path>     Download cache directory\n'
    printf '  -c <path>     sstate cache directory\n'
    printf '  -n            Resolve and print selection without initializing Yocto\n'
    printf '  -l            List Baseline Profiles and targets\n'
    printf '  -V            Validate registry metadata without initialized submodules\n'
    printf '  -h            Show this help\n'
    yf_cleanup
    return 0
fi

if [ "$YF_ACTION" = "validate" ]; then
    if python3 "$YF_REGISTRY_SCRIPT" --root "$YF_TOP_DIR" validate; then
        yf_cleanup
        return 0
    fi
    yf_cleanup
    return 1
fi

if [ "$YF_ACTION" = "list" ]; then
    if python3 "$YF_REGISTRY_SCRIPT" --root "$YF_TOP_DIR" list; then
        yf_cleanup
        return 0
    fi
    yf_cleanup
    return 1
fi

if [ -n "$YF_REQUESTED_MACHINE" ] && [ -n "$YF_REQUESTED_TARGET" ]; then
    yf_die "Use either -m or -T, not both."
    yf_cleanup
    return 1
fi
if [ -n "$YF_REQUESTED_TARGET" ]; then
    YF_SELECTOR=$YF_REQUESTED_TARGET
    YF_SELECTOR_MODE="canonical"
elif [ -n "$YF_REQUESTED_MACHINE" ]; then
    YF_SELECTOR=$YF_REQUESTED_MACHINE
    YF_SELECTOR_MODE="compat"
else
    yf_die "A target is required. Use -m <name>, -T <target-id>, or -l."
    yf_cleanup
    return 1
fi

yf_validate_id "target selector" "$YF_SELECTOR" || { yf_cleanup; return 1; }
if [ -n "$YF_PROFILE_ASSERTION" ]; then
    yf_validate_id "profile assertion" "$YF_PROFILE_ASSERTION" || { yf_cleanup; return 1; }
fi

if [ -n "$YF_PROFILE_ASSERTION" ]; then
    YF_PROTOCOL_DATA=$(python3 "$YF_REGISTRY_SCRIPT" \
        --root "$YF_TOP_DIR" resolve --mode "$YF_SELECTOR_MODE" \
        --selector "$YF_SELECTOR" --profile "$YF_PROFILE_ASSERTION")
else
    YF_PROTOCOL_DATA=$(python3 "$YF_REGISTRY_SCRIPT" \
        --root "$YF_TOP_DIR" resolve --mode "$YF_SELECTOR_MODE" \
        --selector "$YF_SELECTOR")
fi
YF_STATUS=$?
if [ "$YF_STATUS" -ne 0 ]; then
    yf_cleanup
    return 1
fi
yf_load_protocol "$YF_PROTOCOL_DATA" || { yf_cleanup; return 1; }
yf_compute_paths

YF_CPUS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1')
case $YF_CPUS in ""|*[!0-9]*) YF_CPUS=1 ;; esac
case $YF_JOBS in "") YF_JOBS=$YF_CPUS ;; *[!0-9]*|0) yf_die "-j must be a positive integer"; yf_cleanup; return 1 ;; esac
case $YF_THREADS in "") YF_THREADS=$YF_CPUS ;; *[!0-9]*|0) yf_die "-t must be a positive integer"; yf_cleanup; return 1 ;; esac

YF_LAYER_PATHS=""
for YF_LAYER in $YF_BASELINE_LAYERS $YF_PLATFORM_LAYERS $YF_PRODUCT_LAYERS; do
    yf_add_layer "$YF_LAYER" || { yf_cleanup; return 1; }
done
if [ -f "$YF_TOP_DIR/platforms/common/meta-user/conf/layer.conf" ]; then
    yf_add_layer "platforms/common/meta-user" || { yf_cleanup; return 1; }
fi

if [ "$YF_DRY_RUN" = "true" ]; then
    yf_print_selection
    yf_cleanup
    return 0
fi

if [ "$(id -u)" -eq 0 ] && [ "${YOCTO_FORALL_ALLOW_ROOT:-0}" != "1" ]; then
    yf_die "Do not initialize a Yocto build as root."
    yf_cleanup
    return 1
fi

for YF_PATH in "$YF_TOP_DIR" "$YF_OEROOT" "$YF_BUILD_DIR" "$YF_DOWNLOADS_DIR" "$YF_SSTATE_DIR"; do
    yf_dquote_safe "path" "$YF_PATH" || { yf_cleanup; return 1; }
done
YF_CACHE_MIRROR=${YOCTO_CACHE_MIRROR:-}
if [ -n "$YF_CACHE_MIRROR" ]; then
    yf_dquote_safe "YOCTO_CACHE_MIRROR" "$YF_CACHE_MIRROR" || { yf_cleanup; return 1; }
fi

if [ ! -f "$YF_OEROOT/oe-init-build-env" ]; then
    yf_die "Baseline '$YF_BASELINE_ID' is not initialized at '$YF_OEROOT'. Run: git submodule update --init --recursive"
    yf_cleanup
    return 1
fi
for YF_LAYER in $YF_LAYER_PATHS; do
    YF_LAYER_ABS="$YF_TOP_DIR/$YF_LAYER"
    if [ ! -f "$YF_LAYER_ABS/conf/layer.conf" ]; then
        yf_die "Required layer '$YF_LAYER' is missing or uninitialized. Run: git submodule update --init --recursive"
        yf_cleanup
        return 1
    fi
done

mkdir -p "$YF_BUILD_DIR" "$YF_DOWNLOADS_DIR" "$YF_SSTATE_DIR" || {
    yf_die "Unable to create build or cache directories."
    yf_cleanup
    return 1
}
YF_BUILD_DIR=$(CDPATH= cd -- "$YF_BUILD_DIR" && pwd -P)
YF_DOWNLOADS_DIR=$(CDPATH= cd -- "$YF_DOWNLOADS_DIR" && pwd -P)
YF_SSTATE_DIR=$(CDPATH= cd -- "$YF_SSTATE_DIR" && pwd -P)
YF_CONF_DIR="$YF_BUILD_DIR/conf"
YF_MANIFEST="$YF_CONF_DIR/yocto-forall.manifest"

if [ -f "$YF_MANIFEST" ]; then
    YF_OLD_VALUE=$(yf_manifest_value "$YF_MANIFEST" TARGET_ID)
    if [ "$YF_OLD_VALUE" != "$YF_TARGET_ID" ]; then
        yf_die "Build directory '$YF_BUILD_DIR' belongs to target '$YF_OLD_VALUE', not '$YF_TARGET_ID'."
        yf_cleanup
        return 1
    fi
    for YF_EXPECTED in \
        "MACHINE:$YF_TARGET_MACHINE" \
        "PLATFORM_ID:$YF_PLATFORM_ID" \
        "PRODUCT_ID:$YF_PRODUCT_ID" \
        "BASELINE_ID:$YF_BASELINE_ID" \
        "BASELINE_SERIES:$YF_BASELINE_SERIES" \
        "OEROOT:$YF_OEROOT" \
        "DISTRO:$YF_PLATFORM_DISTRO"; do
        YF_ID=${YF_EXPECTED%%:*}
        YF_VALUE=${YF_EXPECTED#*:}
        YF_OLD_VALUE=$(yf_manifest_value "$YF_MANIFEST" "$YF_ID")
        if [ "$YF_OLD_VALUE" != "$YF_VALUE" ]; then
            yf_die "Build directory '$YF_BUILD_DIR' has $YF_ID '$YF_OLD_VALUE', expected '$YF_VALUE'."
            yf_cleanup
            return 1
        fi
    done
elif [ -e "$YF_CONF_DIR/local.conf" ] || [ -e "$YF_CONF_DIR/bblayers.conf" ]; then
    yf_die "Build directory '$YF_BUILD_DIR' predates the profile manifest; choose a new directory."
    yf_cleanup
    return 1
fi

YF_SAVED_DIR=$(pwd)
cd "$YF_OEROOT" || { yf_die "Cannot enter OEROOT '$YF_OEROOT'."; yf_cleanup; return 1; }
set -- "$YF_BUILD_DIR"
. ./oe-init-build-env > /dev/null
YF_STATUS=$?
if [ "$YF_STATUS" -ne 0 ] || [ ! -f "$YF_CONF_DIR/local.conf" ]; then
    cd "$YF_SAVED_DIR" || return 1
    yf_die "oe-init-build-env failed for baseline '$YF_BASELINE_ID'."
    yf_cleanup
    return 1
fi

yf_write_bblayers || { yf_die "Failed to write bblayers.conf."; yf_cleanup; return 1; }
yf_write_local_conf || { yf_die "Failed to write local.conf."; yf_cleanup; return 1; }
yf_write_manifest || { yf_die "Failed to write build manifest."; yf_cleanup; return 1; }
yf_write_source_this || { yf_die "Failed to write SOURCE_THIS."; yf_cleanup; return 1; }

mkdir -p "$YF_TOP_DIR/images" 2>/dev/null || true
if [ -d "$YF_TOP_DIR/images" ]; then
    YF_IMAGE_LINK="$YF_TOP_DIR/images/$YF_TARGET_ID"
    rm -f "$YF_IMAGE_LINK" 2>/dev/null || true
    ln -s "$YF_BUILD_DIR/tmp/deploy/images/$YF_TARGET_MACHINE" \
        "$YF_IMAGE_LINK" 2>/dev/null || true
fi

printf 'Configured target %s\n' "$YF_TARGET_ID"
printf '  machine:  %s\n' "$YF_TARGET_MACHINE"
printf '  baseline: %s (%s)\n' "$YF_BASELINE_ID" "$YF_BASELINE_SERIES"
printf '  platform: %s\n' "$YF_PLATFORM_ID"
if [ -n "$YF_PRODUCT_ID" ]; then
    printf '  product:  %s\n' "$YF_PRODUCT_ID"
fi
printf '  support:  %s\n' "$YF_SUPPORT_LEVEL"
printf '  build:    %s\n' "$YF_BUILD_DIR"
printf '  image:    %s\n' "$YF_DEFAULT_IMAGE"
printf 'Re-enter later with: . "%s/SOURCE_THIS"\n' "$YF_BUILD_DIR"

yf_cleanup
return 0
