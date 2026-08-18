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

yf_cleanup() {
    OPTIND=$YF_OLD_OPTIND
    unset BASELINE_DESCRIPTION BASELINE_ID BASELINE_LAYERS BASELINE_OEROOT BASELINE_SERIES
    unset PLATFORM_BASELINE_ID PLATFORM_BASELINES PLATFORM_DISTRO PLATFORM_ID
    unset PLATFORM_LAYERS PLATFORM_LOCAL_CONF
    unset PRODUCT_BASELINE_ID PRODUCT_BASELINES PRODUCT_ID PRODUCT_LAYERS
    unset PRODUCT_LOCAL_CONF PRODUCT_PLATFORM
    unset TARGET_ALIASES TARGET_BASELINE TARGET_DEFAULT_IMAGE TARGET_ID TARGET_MACHINE
    unset TARGET_PLATFORM TARGET_PRODUCT TARGET_SUPPORT_LEVEL
    unset YF_ACTION YF_ALL_SELECTORS
    unset YF_BASELINE_FILE YF_BASELINE_ID YF_BASELINE_LAYERS YF_BASELINE_OEROOT
    unset YF_BASELINE_SERIES YF_BUILD_DIR YF_CACHE_MIRROR YF_CALLER_DIR
    unset YF_CLAIM_BASELINE YF_CLAIM_PATH YF_CLAIMED_BASELINE YF_CLAIMED_PATH
    unset YF_CONF_DIR YF_COUNT YF_CPUS YF_DEFAULT_IMAGE
    unset YF_DOWNLOADS_DIR YF_DRY_RUN YF_EXPECTED YF_FILE
    unset YF_ID YF_IS_SOURCED YF_JOBS YF_LAYER YF_LAYER_ABS YF_LAYER_OWNER
    unset YF_LAYER_PATHS YF_LAYER_CLAIMS YF_LAYER_SOURCE YF_LAYER_SOURCE_MATCH
    unset YF_LOCAL_CONF YF_MANIFEST YF_MATCH YF_MATCH_COUNT
    unset YF_OLD_OPTIND YF_OLD_VALUE YF_OEROOT YF_OPTION YF_PATH
    unset YF_PLATFORM_ADAPTER YF_PLATFORM_BASELINES YF_PLATFORM_DISTRO
    unset YF_PLATFORM_FILE YF_PLATFORM_ID YF_PLATFORM_LAYERS YF_PLATFORM_LOCAL_CONF
    unset YF_PRODUCT_ADAPTER YF_PRODUCT_BASELINES YF_PRODUCT_FILE YF_PRODUCT_ID
    unset YF_PRODUCT_LAYERS YF_PRODUCT_LOCAL_CONF YF_PRODUCT_PLATFORM
    unset YF_PROFILE_ASSERTION YF_PROGNAME
    unset YF_REQUESTED_MACHINE YF_REQUESTED_TARGET YF_SAVED_DIR YF_SEEN
    unset YF_SEEN_BASELINE_LAYERS YF_SEEN_OEROOTS YF_SELECTOR YF_SELECTOR_MODE
    unset YF_SETUP_BUILDDIR YF_SETUP_DOWNLOADS
    unset YF_SETUP_SSTATE YF_SSTATE_DIR YF_STATUS YF_SUPPORT_LEVEL
    unset YF_TARGET_BASELINE YF_TARGET_ID YF_TARGET_MACHINE YF_TARGET_OWNER
    unset YF_TARGET_PATH YF_TARGET_PLATFORM YF_TARGET_PRODUCT YF_THREADS
    unset YF_THIS_SEEN YF_TOKEN YF_TOP_DIR YF_VALUE YF_IMAGE_LINK
    unset YF_SCRIPT_DIR
    unset YF_SOURCE
    unset -f yf_add_layer yf_claim_integration_layer yf_cleanup yf_compute_paths
    unset -f yf_die yf_dquote_safe yf_resolve_integration_source
    unset -f yf_list_registry yf_load_selected yf_manifest_value yf_print_selection
    unset -f yf_registry_files yf_reset_baseline yf_reset_platform yf_reset_product
    unset -f yf_reset_target yf_resolve_target yf_support_level_valid
    unset -f yf_validate_id yf_validate_registry yf_validate_relpath yf_word_in_list
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

yf_word_in_list() {
    case " $2 " in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

yf_resolve_integration_source() {
    YF_LAYER_SOURCE=$1
    YF_LAYER_SOURCE_MATCH=""
    if [ -f "$YF_TOP_DIR/.gitmodules" ]; then
        for YF_SOURCE in $(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' "$YF_TOP_DIR/.gitmodules"); do
            case $1 in
                "$YF_SOURCE"|"$YF_SOURCE"/*)
                    if [ -z "$YF_LAYER_SOURCE_MATCH" ] || \
                       [ "${#YF_SOURCE}" -lt "${#YF_LAYER_SOURCE_MATCH}" ]; then
                        YF_LAYER_SOURCE_MATCH=$YF_SOURCE
                    fi
                    ;;
            esac
        done
    fi
    if [ -n "$YF_LAYER_SOURCE_MATCH" ]; then
        YF_LAYER_SOURCE=$YF_LAYER_SOURCE_MATCH
    fi
}

yf_claim_integration_layer() {
    YF_CLAIM_BASELINE=$1
    YF_CLAIM_PATH=$2
    yf_resolve_integration_source "$YF_CLAIM_PATH"
    set -- $YF_LAYER_CLAIMS
    while [ "$#" -ge 2 ]; do
        YF_CLAIMED_BASELINE=$1
        YF_CLAIMED_PATH=$2
        if [ "$YF_CLAIMED_PATH" = "$YF_LAYER_SOURCE" ]; then
            if [ "$YF_CLAIMED_BASELINE" != "$YF_CLAIM_BASELINE" ]; then
                yf_die "Integration source '$YF_LAYER_SOURCE' (layer '$YF_CLAIM_PATH') is claimed by baselines '$YF_CLAIM_BASELINE' and '$YF_CLAIMED_BASELINE'"
                return 1
            fi
            return 0
        fi
        shift 2
    done
    YF_LAYER_CLAIMS="$YF_LAYER_CLAIMS $YF_CLAIM_BASELINE $YF_LAYER_SOURCE"
    return 0
}

yf_support_level_valid() {
    case $1 in
        Declared|Parse-Validated|Build-Validated|Boot-Validated|Production-Supported)
            return 0
            ;;
        *) return 1 ;;
    esac
}

yf_reset_baseline() {
    unset BASELINE_DESCRIPTION BASELINE_ID BASELINE_LAYERS BASELINE_OEROOT BASELINE_SERIES
}

yf_reset_platform() {
    unset PLATFORM_BASELINE_ID PLATFORM_BASELINES PLATFORM_DISTRO PLATFORM_ID
    unset PLATFORM_LAYERS PLATFORM_LOCAL_CONF
}

yf_reset_product() {
    unset PRODUCT_BASELINE_ID PRODUCT_BASELINES PRODUCT_ID PRODUCT_LAYERS
    unset PRODUCT_LOCAL_CONF PRODUCT_PLATFORM
}

yf_reset_target() {
    unset TARGET_ALIASES TARGET_BASELINE TARGET_DEFAULT_IMAGE TARGET_ID TARGET_MACHINE
    unset TARGET_PLATFORM TARGET_PRODUCT TARGET_SUPPORT_LEVEL
}

yf_registry_files() {
    if [ -d "$YF_TOP_DIR/platforms" ]; then
        find "$YF_TOP_DIR/platforms" -path '*/targets/*.conf' -type f -print
    fi
    if [ -d "$YF_TOP_DIR/products" ]; then
        find "$YF_TOP_DIR/products" -path '*/targets/*.conf' -type f -print
    fi
}

yf_validate_registry() {
    YF_SEEN=" "
    YF_SEEN_OEROOTS=" "
    YF_SEEN_BASELINE_LAYERS=" "
    YF_COUNT=0
    for YF_FILE in "$YF_TOP_DIR"/baselines/*/baseline.conf; do
        [ -f "$YF_FILE" ] || continue
        yf_reset_baseline
        . "$YF_FILE" || return 1
        yf_validate_id "BASELINE_ID in $YF_FILE" "${BASELINE_ID:-}" || return 1
        yf_validate_id "BASELINE_SERIES in $YF_FILE" "${BASELINE_SERIES:-}" || return 1
        yf_validate_relpath "BASELINE_OEROOT in $YF_FILE" "${BASELINE_OEROOT:-}" || return 1
        [ -n "${BASELINE_LAYERS:-}" ] || { yf_die "BASELINE_LAYERS is empty in $YF_FILE"; return 1; }
        YF_EXPECTED=$(basename -- "$(dirname -- "$YF_FILE")")
        [ "$BASELINE_ID" = "$YF_EXPECTED" ] || {
            yf_die "Baseline directory '$YF_EXPECTED' declares BASELINE_ID '$BASELINE_ID'"
            return 1
        }
        case $BASELINE_OEROOT in
            components/layers/baselines/"$BASELINE_ID"/*) ;;
            *)
                yf_die "Baseline '$BASELINE_ID' OEROOT must live under components/layers/baselines/$BASELINE_ID/"
                return 1
                ;;
        esac
        case $YF_SEEN in
            *" $BASELINE_ID "*) yf_die "Duplicate baseline '$BASELINE_ID'"; return 1 ;;
        esac
        YF_SEEN="$YF_SEEN$BASELINE_ID "
        case $YF_SEEN_OEROOTS in
            *" $BASELINE_OEROOT "*)
                yf_die "Baseline '$BASELINE_ID' shares BASELINE_OEROOT '$BASELINE_OEROOT' with another profile"
                return 1
                ;;
        esac
        YF_SEEN_OEROOTS="$YF_SEEN_OEROOTS$BASELINE_OEROOT "
        for YF_PATH in $BASELINE_LAYERS; do
            yf_validate_relpath "BASELINE_LAYERS in $YF_FILE" "$YF_PATH" || return 1
            case $YF_PATH in
                components/layers/baselines/"$BASELINE_ID"/*) ;;
                *)
                    yf_die "Baseline '$BASELINE_ID' core layer '$YF_PATH' is outside its profile directory"
                    return 1
                    ;;
            esac
            case $YF_SEEN_BASELINE_LAYERS in
                *" $YF_PATH "*)
                    yf_die "Baseline '$BASELINE_ID' shares core layer path '$YF_PATH' with another profile"
                    return 1
                    ;;
            esac
            YF_SEEN_BASELINE_LAYERS="$YF_SEEN_BASELINE_LAYERS$YF_PATH "
        done
        YF_COUNT=$((YF_COUNT + 1))
    done
    [ "$YF_COUNT" -gt 0 ] || { yf_die "No Baseline Profiles found under baselines/"; return 1; }

    YF_SEEN=" "
    YF_LAYER_CLAIMS=""
    for YF_FILE in "$YF_TOP_DIR"/platforms/*/platform.conf; do
        [ -f "$YF_FILE" ] || continue
        yf_reset_platform
        . "$YF_FILE" || return 1
        yf_validate_id "PLATFORM_ID in $YF_FILE" "${PLATFORM_ID:-}" || return 1
        [ -n "${PLATFORM_BASELINES:-}" ] || { yf_die "PLATFORM_BASELINES is empty in $YF_FILE"; return 1; }
        YF_EXPECTED=$(basename -- "$(dirname -- "$YF_FILE")")
        [ "$PLATFORM_ID" = "$YF_EXPECTED" ] || {
            yf_die "Platform directory '$YF_EXPECTED' declares PLATFORM_ID '$PLATFORM_ID'"
            return 1
        }
        case $YF_SEEN in
            *" $PLATFORM_ID "*) yf_die "Duplicate platform '$PLATFORM_ID'"; return 1 ;;
        esac
        YF_SEEN="$YF_SEEN$PLATFORM_ID "
        YF_PLATFORM_ID=$PLATFORM_ID
        YF_PLATFORM_BASELINES=$PLATFORM_BASELINES
        for YF_ID in $YF_PLATFORM_BASELINES; do
            yf_validate_id "PLATFORM_BASELINES in $YF_FILE" "$YF_ID" || return 1
            [ -f "$YF_TOP_DIR/baselines/$YF_ID/baseline.conf" ] || {
                yf_die "Platform '$YF_PLATFORM_ID' references unknown baseline '$YF_ID'"
                return 1
            }
            YF_PLATFORM_ADAPTER="$YF_TOP_DIR/platforms/$YF_PLATFORM_ID/baselines/$YF_ID.conf"
            [ -f "$YF_PLATFORM_ADAPTER" ] || {
                yf_die "Platform '$YF_PLATFORM_ID' is missing baseline adapter '$YF_ID.conf'"
                return 1
            }
            yf_reset_platform
            . "$YF_PLATFORM_ADAPTER" || return 1
            [ "${PLATFORM_BASELINE_ID:-}" = "$YF_ID" ] || {
                yf_die "Platform '$YF_PLATFORM_ID' adapter '$YF_ID.conf' declares '${PLATFORM_BASELINE_ID:-}'"
                return 1
            }
            [ -n "${PLATFORM_DISTRO:-}" ] || {
                yf_die "Platform '$YF_PLATFORM_ID' adapter '$YF_ID.conf' has no PLATFORM_DISTRO"
                return 1
            }
            for YF_PATH in ${PLATFORM_LAYERS:-}; do
                yf_validate_relpath "PLATFORM_LAYERS in $YF_PLATFORM_ADAPTER" "$YF_PATH" || return 1
                case $YF_PATH in
                    products/*)
                        yf_die "Platform '$YF_PLATFORM_ID' adapter '$YF_ID.conf' must not reference product layer '$YF_PATH'"
                        return 1
                        ;;
                    platforms/*)
                        YF_LAYER_OWNER=${YF_PATH#platforms/}
                        YF_LAYER_OWNER=${YF_LAYER_OWNER%%/*}
                        if [ "$YF_LAYER_OWNER" != "$YF_PLATFORM_ID" ]; then
                            yf_die "Platform '$YF_PLATFORM_ID' adapter '$YF_ID.conf' must not reference layer owned by platform '$YF_LAYER_OWNER': '$YF_PATH'"
                            return 1
                        fi
                        ;;
                    components/layers/baselines/*)
                        case $YF_PATH in
                            components/layers/baselines/"$YF_ID"/*) ;;
                            *)
                                yf_die "Platform '$YF_PLATFORM_ID' adapter crosses from baseline '$YF_ID' to layer '$YF_PATH'"
                                return 1
                                ;;
                        esac
                        ;;
                esac
                yf_claim_integration_layer "$YF_ID" "$YF_PATH" || return 1
            done
            if [ -n "${PLATFORM_LOCAL_CONF:-}" ]; then
                yf_validate_relpath "PLATFORM_LOCAL_CONF in $YF_PLATFORM_ADAPTER" "$PLATFORM_LOCAL_CONF" || return 1
                case $PLATFORM_LOCAL_CONF in
                    products/*)
                        yf_die "Platform '$YF_PLATFORM_ID' adapter '$YF_ID.conf' must not reference product fragment '$PLATFORM_LOCAL_CONF'"
                        return 1
                        ;;
                    platforms/*)
                        YF_LAYER_OWNER=${PLATFORM_LOCAL_CONF#platforms/}
                        YF_LAYER_OWNER=${YF_LAYER_OWNER%%/*}
                        if [ "$YF_LAYER_OWNER" != "$YF_PLATFORM_ID" ]; then
                            yf_die "Platform '$YF_PLATFORM_ID' adapter '$YF_ID.conf' must not reference fragment owned by platform '$YF_LAYER_OWNER': '$PLATFORM_LOCAL_CONF'"
                            return 1
                        fi
                        ;;
                esac
                [ -f "$YF_TOP_DIR/$PLATFORM_LOCAL_CONF" ] || {
                    yf_die "Platform '$YF_PLATFORM_ID' local fragment '$PLATFORM_LOCAL_CONF' is missing"
                    return 1
                }
            fi
        done
    done

    YF_SEEN=" "
    for YF_FILE in "$YF_TOP_DIR"/products/*/product.conf; do
        [ -f "$YF_FILE" ] || continue
        yf_reset_product
        . "$YF_FILE" || return 1
        yf_validate_id "PRODUCT_ID in $YF_FILE" "${PRODUCT_ID:-}" || return 1
        yf_validate_id "PRODUCT_PLATFORM in $YF_FILE" "${PRODUCT_PLATFORM:-}" || return 1
        [ -n "${PRODUCT_BASELINES:-}" ] || { yf_die "PRODUCT_BASELINES is empty in $YF_FILE"; return 1; }
        YF_EXPECTED=$(basename -- "$(dirname -- "$YF_FILE")")
        [ "$PRODUCT_ID" = "$YF_EXPECTED" ] || {
            yf_die "Product directory '$YF_EXPECTED' declares PRODUCT_ID '$PRODUCT_ID'"
            return 1
        }
        case $YF_SEEN in
            *" $PRODUCT_ID "*) yf_die "Duplicate product '$PRODUCT_ID'"; return 1 ;;
        esac
        YF_SEEN="$YF_SEEN$PRODUCT_ID "
        YF_PRODUCT_ID=$PRODUCT_ID
        YF_PRODUCT_PLATFORM=$PRODUCT_PLATFORM
        YF_PRODUCT_BASELINES=$PRODUCT_BASELINES

        YF_PLATFORM_FILE="$YF_TOP_DIR/platforms/$YF_PRODUCT_PLATFORM/platform.conf"
        [ -f "$YF_PLATFORM_FILE" ] || {
            yf_die "Product '$YF_PRODUCT_ID' references unknown platform '$YF_PRODUCT_PLATFORM'"
            return 1
        }
        yf_reset_platform
        . "$YF_PLATFORM_FILE" || return 1
        [ "$PLATFORM_ID" = "$YF_PRODUCT_PLATFORM" ] || {
            yf_die "Platform file for '$YF_PRODUCT_PLATFORM' declares '$PLATFORM_ID'"
            return 1
        }

        for YF_ID in $YF_PRODUCT_BASELINES; do
            yf_validate_id "PRODUCT_BASELINES in $YF_FILE" "$YF_ID" || return 1
            [ -f "$YF_TOP_DIR/baselines/$YF_ID/baseline.conf" ] || {
                yf_die "Product '$YF_PRODUCT_ID' references unknown baseline '$YF_ID'"
                return 1
            }
            yf_word_in_list "$YF_ID" "$PLATFORM_BASELINES" || {
                yf_die "Product '$YF_PRODUCT_ID' binds platform '$YF_PRODUCT_PLATFORM' to unsupported baseline '$YF_ID'"
                return 1
            }
            YF_PRODUCT_ADAPTER="$YF_TOP_DIR/products/$YF_PRODUCT_ID/baselines/$YF_ID.conf"
            [ -f "$YF_PRODUCT_ADAPTER" ] || {
                yf_die "Product '$YF_PRODUCT_ID' is missing baseline adapter '$YF_ID.conf'"
                return 1
            }
            yf_reset_product
            . "$YF_PRODUCT_ADAPTER" || return 1
            [ "${PRODUCT_BASELINE_ID:-}" = "$YF_ID" ] || {
                yf_die "Product '$YF_PRODUCT_ID' adapter '$YF_ID.conf' declares '${PRODUCT_BASELINE_ID:-}'"
                return 1
            }
            for YF_PATH in ${PRODUCT_LAYERS:-}; do
                yf_validate_relpath "PRODUCT_LAYERS in $YF_PRODUCT_ADAPTER" "$YF_PATH" || return 1
                case $YF_PATH in
                    products/"$YF_PRODUCT_ID"/*) ;;
                    *)
                        yf_die "Product '$YF_PRODUCT_ID' must own layer paths under products/$YF_PRODUCT_ID/, got '$YF_PATH'"
                        return 1
                        ;;
                esac
                yf_claim_integration_layer "$YF_ID" "$YF_PATH" || return 1
            done
            if [ -n "${PRODUCT_LOCAL_CONF:-}" ]; then
                yf_validate_relpath "PRODUCT_LOCAL_CONF in $YF_PRODUCT_ADAPTER" "$PRODUCT_LOCAL_CONF" || return 1
                case $PRODUCT_LOCAL_CONF in
                    products/"$YF_PRODUCT_ID"/*) ;;
                    *)
                        yf_die "Product '$YF_PRODUCT_ID' must own its local fragment under products/$YF_PRODUCT_ID/, got '$PRODUCT_LOCAL_CONF'"
                        return 1
                        ;;
                esac
                [ -f "$YF_TOP_DIR/$PRODUCT_LOCAL_CONF" ] || {
                    yf_die "Product '$YF_PRODUCT_ID' local fragment '$PRODUCT_LOCAL_CONF' is missing"
                    return 1
                }
            fi
        done
    done

    YF_SEEN=" "
    YF_ALL_SELECTORS=" "
    YF_COUNT=0
    for YF_FILE in $(yf_registry_files | sort); do
        yf_reset_target
        . "$YF_FILE" || return 1
        yf_validate_id "TARGET_ID in $YF_FILE" "${TARGET_ID:-}" || return 1
        yf_validate_id "TARGET_MACHINE in $YF_FILE" "${TARGET_MACHINE:-}" || return 1
        yf_validate_id "TARGET_PLATFORM in $YF_FILE" "${TARGET_PLATFORM:-}" || return 1
        yf_validate_id "TARGET_BASELINE in $YF_FILE" "${TARGET_BASELINE:-}" || return 1
        [ -n "${TARGET_DEFAULT_IMAGE:-}" ] || { yf_die "TARGET_DEFAULT_IMAGE is empty in $YF_FILE"; return 1; }
        yf_support_level_valid "${TARGET_SUPPORT_LEVEL:-}" || {
            yf_die "Invalid TARGET_SUPPORT_LEVEL '${TARGET_SUPPORT_LEVEL:-}' in $YF_FILE"
            return 1
        }
        if [ "$TARGET_SUPPORT_LEVEL" = "Production-Supported" ] && [ -z "${TARGET_PRODUCT:-}" ]; then
            yf_die "Target '$TARGET_ID' cannot be Production-Supported without TARGET_PRODUCT"
            return 1
        fi
        if [ -n "${TARGET_PRODUCT:-}" ]; then
            yf_validate_id "TARGET_PRODUCT in $YF_FILE" "$TARGET_PRODUCT" || return 1
        fi
        YF_TARGET_PATH=${YF_FILE#"$YF_TOP_DIR"/}
        case $YF_TARGET_PATH in
            platforms/*/targets/*.conf)
                YF_TARGET_OWNER=${YF_TARGET_PATH#platforms/}
                YF_TARGET_OWNER=${YF_TARGET_OWNER%%/*}
                if [ "$TARGET_PLATFORM" != "$YF_TARGET_OWNER" ]; then
                    yf_die "Target '$TARGET_ID' is under platform '$YF_TARGET_OWNER' but declares TARGET_PLATFORM '$TARGET_PLATFORM'"
                    return 1
                fi
                if [ -n "${TARGET_PRODUCT:-}" ]; then
                    yf_die "Platform target '$TARGET_ID' must not declare TARGET_PRODUCT"
                    return 1
                fi
                ;;
            products/*/targets/*.conf)
                YF_TARGET_OWNER=${YF_TARGET_PATH#products/}
                YF_TARGET_OWNER=${YF_TARGET_OWNER%%/*}
                if [ -z "${TARGET_PRODUCT:-}" ]; then
                    yf_die "Product target '$TARGET_ID' under products/$YF_TARGET_OWNER/ must declare TARGET_PRODUCT"
                    return 1
                fi
                if [ "$TARGET_PRODUCT" != "$YF_TARGET_OWNER" ]; then
                    yf_die "Target '$TARGET_ID' is under product '$YF_TARGET_OWNER' but declares TARGET_PRODUCT '$TARGET_PRODUCT'"
                    return 1
                fi
                ;;
            *)
                yf_die "Target '$TARGET_ID' is outside a platforms/<id>/targets or products/<id>/targets boundary"
                return 1
                ;;
        esac
        YF_EXPECTED=$(basename -- "$YF_FILE" .conf)
        [ "$TARGET_ID" = "$YF_EXPECTED" ] || {
            yf_die "Target file '$YF_EXPECTED.conf' declares TARGET_ID '$TARGET_ID'"
            return 1
        }
        case $YF_SEEN in
            *" $TARGET_ID "*) yf_die "Duplicate target '$TARGET_ID'"; return 1 ;;
        esac
        YF_SEEN="$YF_SEEN$TARGET_ID "

        [ -f "$YF_TOP_DIR/baselines/$TARGET_BASELINE/baseline.conf" ] || {
            yf_die "Target '$TARGET_ID' references unknown baseline '$TARGET_BASELINE'"
            return 1
        }
        YF_PLATFORM_FILE="$YF_TOP_DIR/platforms/$TARGET_PLATFORM/platform.conf"
        [ -f "$YF_PLATFORM_FILE" ] || {
            yf_die "Target '$TARGET_ID' references unknown platform '$TARGET_PLATFORM'"
            return 1
        }
        yf_reset_platform
        . "$YF_PLATFORM_FILE" || return 1
        [ "$PLATFORM_ID" = "$TARGET_PLATFORM" ] || {
            yf_die "Platform file for '$TARGET_PLATFORM' declares '$PLATFORM_ID'"
            return 1
        }
        yf_word_in_list "$TARGET_BASELINE" "$PLATFORM_BASELINES" || {
            yf_die "Target '$TARGET_ID' binds platform '$TARGET_PLATFORM' to unsupported baseline '$TARGET_BASELINE'"
            return 1
        }

        if [ -n "${TARGET_PRODUCT:-}" ]; then
            YF_PRODUCT_FILE="$YF_TOP_DIR/products/$TARGET_PRODUCT/product.conf"
            [ -f "$YF_PRODUCT_FILE" ] || {
                yf_die "Target '$TARGET_ID' references unknown product '$TARGET_PRODUCT'"
                return 1
            }
            yf_reset_product
            . "$YF_PRODUCT_FILE" || return 1
            [ "$PRODUCT_ID" = "$TARGET_PRODUCT" ] || {
                yf_die "Product file for '$TARGET_PRODUCT' declares '$PRODUCT_ID'"
                return 1
            }
            [ "$PRODUCT_PLATFORM" = "$TARGET_PLATFORM" ] || {
                yf_die "Product '$TARGET_PRODUCT' uses platform '$PRODUCT_PLATFORM', target uses '$TARGET_PLATFORM'"
                return 1
            }
            yf_word_in_list "$TARGET_BASELINE" "$PRODUCT_BASELINES" || {
                yf_die "Product '$TARGET_PRODUCT' does not support baseline '$TARGET_BASELINE'"
                return 1
            }
        fi

        YF_THIS_SEEN=" "
        for YF_TOKEN in "$TARGET_ID" "$TARGET_MACHINE" ${TARGET_ALIASES:-}; do
            yf_validate_id "selector in $YF_FILE" "$YF_TOKEN" || return 1
            case $YF_THIS_SEEN in
                *" $YF_TOKEN "*) continue ;;
            esac
            YF_THIS_SEEN="$YF_THIS_SEEN$YF_TOKEN "
            case $YF_ALL_SELECTORS in
                *" $YF_TOKEN "*)
                    yf_die "Target selector '$YF_TOKEN' is owned by more than one target"
                    return 1
                    ;;
            esac
            YF_ALL_SELECTORS="$YF_ALL_SELECTORS$YF_TOKEN "
        done
        YF_COUNT=$((YF_COUNT + 1))
    done
    [ "$YF_COUNT" -gt 0 ] || { yf_die "No targets found under platforms/ or products/"; return 1; }
    return 0
}

yf_list_registry() {
    printf 'Baseline Profiles:\n'
    for YF_FILE in "$YF_TOP_DIR"/baselines/*/baseline.conf; do
        [ -f "$YF_FILE" ] || continue
        yf_reset_baseline
        . "$YF_FILE" || return 1
        printf '  %-12s series=%-12s %s\n' "$BASELINE_ID" "$BASELINE_SERIES" "${BASELINE_DESCRIPTION:-}"
    done
    printf '\nTargets:\n'
    for YF_FILE in $(yf_registry_files | sort); do
        yf_reset_target
        . "$YF_FILE" || return 1
        printf '  %-26s machine=%-28s baseline=%-11s support=%s\n' \
            "$TARGET_ID" "$TARGET_MACHINE" "$TARGET_BASELINE" "$TARGET_SUPPORT_LEVEL"
    done
}

yf_resolve_target() {
    YF_MATCH_COUNT=0
    for YF_FILE in $(yf_registry_files | sort); do
        yf_reset_target
        . "$YF_FILE" || return 1
        YF_MATCH="false"
        if [ "$YF_SELECTOR_MODE" = "target" ]; then
            [ "$TARGET_ID" = "$YF_SELECTOR" ] && YF_MATCH="true"
        else
            if [ "$TARGET_ID" = "$YF_SELECTOR" ] || [ "$TARGET_MACHINE" = "$YF_SELECTOR" ]; then
                YF_MATCH="true"
            elif yf_word_in_list "$YF_SELECTOR" "${TARGET_ALIASES:-}"; then
                YF_MATCH="true"
            fi
        fi
        [ "$YF_MATCH" = "true" ] || continue
        YF_MATCH_COUNT=$((YF_MATCH_COUNT + 1))
        YF_TARGET_ID=$TARGET_ID
        YF_TARGET_MACHINE=$TARGET_MACHINE
        YF_TARGET_PLATFORM=$TARGET_PLATFORM
        YF_TARGET_PRODUCT=${TARGET_PRODUCT:-}
        YF_TARGET_BASELINE=$TARGET_BASELINE
        YF_SUPPORT_LEVEL=$TARGET_SUPPORT_LEVEL
        YF_DEFAULT_IMAGE=$TARGET_DEFAULT_IMAGE
    done
    if [ "$YF_MATCH_COUNT" -eq 0 ]; then
        yf_die "Unknown target or machine '$YF_SELECTOR'. Use -l to list targets."
        return 1
    fi
    if [ "$YF_MATCH_COUNT" -gt 1 ]; then
        yf_die "Selector '$YF_SELECTOR' is ambiguous; use -T with a canonical target ID."
        return 1
    fi
    return 0
}

yf_load_selected() {
    YF_BASELINE_FILE="$YF_TOP_DIR/baselines/$YF_TARGET_BASELINE/baseline.conf"
    yf_reset_baseline
    . "$YF_BASELINE_FILE" || return 1
    YF_BASELINE_ID=$BASELINE_ID
    YF_BASELINE_SERIES=$BASELINE_SERIES
    YF_BASELINE_OEROOT=$BASELINE_OEROOT
    YF_BASELINE_LAYERS=$BASELINE_LAYERS

    YF_PLATFORM_FILE="$YF_TOP_DIR/platforms/$YF_TARGET_PLATFORM/platform.conf"
    yf_reset_platform
    . "$YF_PLATFORM_FILE" || return 1
    YF_PLATFORM_ID=$PLATFORM_ID
    YF_PLATFORM_ADAPTER="$YF_TOP_DIR/platforms/$YF_PLATFORM_ID/baselines/$YF_BASELINE_ID.conf"
    yf_reset_platform
    . "$YF_PLATFORM_ADAPTER" || return 1
    [ "$PLATFORM_BASELINE_ID" = "$YF_BASELINE_ID" ] || {
        yf_die "Platform adapter declares '$PLATFORM_BASELINE_ID', expected '$YF_BASELINE_ID'"
        return 1
    }
    YF_PLATFORM_DISTRO=$PLATFORM_DISTRO
    YF_PLATFORM_LAYERS=$PLATFORM_LAYERS
    YF_PLATFORM_LOCAL_CONF=${PLATFORM_LOCAL_CONF:-}

    YF_PRODUCT_ID=""
    YF_PRODUCT_LAYERS=""
    YF_PRODUCT_LOCAL_CONF=""
    if [ -n "$YF_TARGET_PRODUCT" ]; then
        YF_PRODUCT_FILE="$YF_TOP_DIR/products/$YF_TARGET_PRODUCT/product.conf"
        yf_reset_product
        . "$YF_PRODUCT_FILE" || return 1
        YF_PRODUCT_ID=$PRODUCT_ID
        YF_PRODUCT_ADAPTER="$YF_TOP_DIR/products/$YF_PRODUCT_ID/baselines/$YF_BASELINE_ID.conf"
        yf_reset_product
        . "$YF_PRODUCT_ADAPTER" || return 1
        [ "$PRODUCT_BASELINE_ID" = "$YF_BASELINE_ID" ] || {
            yf_die "Product adapter declares '$PRODUCT_BASELINE_ID', expected '$YF_BASELINE_ID'"
            return 1
        }
        YF_PRODUCT_LAYERS=${PRODUCT_LAYERS:-}
        YF_PRODUCT_LOCAL_CONF=${PRODUCT_LOCAL_CONF:-}
    fi

    if [ -n "$YF_PROFILE_ASSERTION" ] && [ "$YF_PROFILE_ASSERTION" != "$YF_BASELINE_ID" ]; then
        yf_die "Target '$YF_TARGET_ID' binds to baseline '$YF_BASELINE_ID', not '$YF_PROFILE_ASSERTION'."
        return 1
    fi
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

if ! yf_validate_registry; then
    yf_cleanup
    return 1
fi

if [ "$YF_ACTION" = "validate" ]; then
    printf 'Registry validation: ok\n'
    yf_cleanup
    return 0
fi

if [ "$YF_ACTION" = "list" ]; then
    if yf_list_registry; then
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
    YF_SELECTOR_MODE="target"
elif [ -n "$YF_REQUESTED_MACHINE" ]; then
    YF_SELECTOR=$YF_REQUESTED_MACHINE
    YF_SELECTOR_MODE="machine"
else
    yf_die "A target is required. Use -m <name>, -T <target-id>, or -l."
    yf_cleanup
    return 1
fi

yf_validate_id "target selector" "$YF_SELECTOR" || { yf_cleanup; return 1; }
if [ -n "$YF_PROFILE_ASSERTION" ]; then
    yf_validate_id "profile assertion" "$YF_PROFILE_ASSERTION" || { yf_cleanup; return 1; }
fi

yf_resolve_target || { yf_cleanup; return 1; }
yf_load_selected || { yf_cleanup; return 1; }
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
