#!/usr/bin/env bash

set -u

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SETUP_SCRIPT="$REPO_ROOT/configs/setup-env.sh"
FAILURES=0
OUTPUT=""
STATUS=0
TEST_TOP_DIR=""
TEST_TEMP_DIRS=""
TEST_PATH=""
TEST_PROTOCOL_FILE=""

mkdir -p "$REPO_ROOT/lessons/build-registry"

cleanup_test_temp_dirs() {
    for directory in $TEST_TEMP_DIRS; do
        rm -rf "$directory"
    done
}

trap cleanup_test_temp_dirs EXIT HUP INT TERM

capture_setup() {
    capture_path=${TEST_PATH:-$PATH}
    if [ -n "$TEST_TOP_DIR" ]; then
        OUTPUT=$(PATH="$capture_path" YF_TEST_PROTOCOL_FILE="$TEST_PROTOCOL_FILE" \
            YOCTO_FORALL_TOP_DIR="$TEST_TOP_DIR" \
            bash -c '. "$1" "${@:2}"' bash "$SETUP_SCRIPT" "$@" 2>&1)
        STATUS=$?
    else
        OUTPUT=$(cd "$REPO_ROOT" && PATH="$capture_path" \
            YF_TEST_PROTOCOL_FILE="$TEST_PROTOCOL_FILE" \
            bash -c '. "$1" "${@:2}"' bash "$SETUP_SCRIPT" "$@" 2>&1)
        STATUS=$?
    fi
}

fail() {
    printf 'not ok - %s\n' "$1"
    if [ -n "${2:-}" ]; then
        printf '  %s\n' "$2"
    fi
    FAILURES=$((FAILURES + 1))
}

pass() {
    printf 'ok - %s\n' "$1"
}

assert_status() {
    expected=$1
    label=$2
    if [ "$STATUS" -ne "$expected" ]; then
        fail "$label" "expected status $expected, got $STATUS; output: $OUTPUT"
        return 1
    fi
    return 0
}

assert_output_contains() {
    needle=$1
    label=$2
    case $OUTPUT in
        *"$needle"*) return 0 ;;
        *)
            fail "$label" "missing '$needle'; output: $OUTPUT"
            return 1
            ;;
    esac
}

assert_output_equals() {
    expected=$1
    label=$2
    if [ "$OUTPUT" != "$expected" ]; then
        fail "$label" "unexpected output: $OUTPUT"
        return 1
    fi
    return 0
}

assert_file_contains() {
    file=$1
    needle=$2
    label=$3
    if [ ! -f "$file" ]; then
        fail "$label" "missing file: $file"
        return 1
    fi
    if ! grep -Fq "$needle" "$file"; then
        fail "$label" "missing '$needle' in $file"
        return 1
    fi
    return 0
}

assert_file_order() {
    file=$1
    label=$2
    shift 2
    previous=0
    for needle in "$@"; do
        line=$(grep -nF "$needle" "$file" | sed -n '1s/:.*//p')
        if [ -z "$line" ]; then
            fail "$label" "missing '$needle' in $file"
            return 1
        fi
        if [ "$line" -le "$previous" ]; then
            fail "$label" "'$needle' is out of order in $file"
            return 1
        fi
        previous=$line
    done
    return 0
}

test_registry_listing() {
    capture_setup -l
    assert_status 0 "registry listing exits successfully" || return
    assert_output_contains "Baseline Profiles" "registry listing shows profiles" || return
    assert_output_contains "scarthgap" "registry listing includes scarthgap" || return
    assert_output_contains "whinlatter" "registry listing includes whinlatter" || return
    assert_output_contains "kirkstone" "registry listing includes kirkstone" || return
    assert_output_contains "harp-dfe-xczu67dr" "registry listing includes the product target" || return
    pass "registry listing exposes profiles and targets"
}

test_target_alias_resolution() {
    capture_setup -n -m rk3568-evb
    assert_status 0 "Rockchip alias dry-run exits successfully" || return
    assert_output_contains "target=rk3568-evb" "Rockchip alias resolves target" || return
    assert_output_contains "machine=rockchip-rk3568-evb" "Rockchip alias resolves BSP machine" || return
    assert_output_contains "baseline=whinlatter" "Rockchip target selects Whinlatter" || return
    pass "legacy machine selector resolves an explicit target"
}

test_product_target_resolution() {
    capture_setup -n -T harp-dfe-xczu67dr -p scarthgap
    assert_status 0 "product dry-run exits successfully" || return
    assert_output_contains "product=xilinx-zynqmp-harp-dfe" "product target resolves product integration" || return
    assert_output_contains "support=Parse-Validated" "product target exposes evidence-backed support contract" || return
    pass "product target binds to its product integration and support level"
}

test_dry_run_stdout_and_path_options() {
    fixture=$(mktemp -d "$REPO_ROOT/lessons/build-registry/dry-run.XXXXXX")
    TEST_TEMP_DIRS="$TEST_TEMP_DIRS $fixture"
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    TEST_TOP_DIR=$fixture
    downloads="$fixture/custom-downloads"
    sstate="$fixture/custom-sstate"

    capture_setup -n -T fixture-product-target -j 7 -t 5 \
        -d "$downloads" -c "$sstate"
    assert_status 0 "dry-run options exit successfully" || { TEST_TOP_DIR=""; return; }
    expected=$(printf '%s\n' \
        'target=fixture-product-target' \
        'machine=fixture-product-machine' \
        'baseline=test' \
        'series=test-series' \
        'platform=fixture-platform' \
        'product=fixture-product' \
        'support=Parse-Validated' \
        'distro=poky' \
        'default_image=fixture-image' \
        "build_dir=$fixture/build/test/fixture-product-target" \
        "downloads_dir=$downloads" \
        "sstate_dir=$sstate")
    assert_output_equals "$expected" \
        "dry-run stdout preserves its public field order" || { TEST_TOP_DIR=""; return; }

    TEST_TOP_DIR=""
    pass "dry-run preserves stdout and path-option compatibility"
}

test_profile_is_an_assertion() {
    capture_setup -n -m rk3568-evb -p scarthgap
    if [ "$STATUS" -eq 0 ]; then
        fail "profile mismatch is rejected" "output: $OUTPUT"
        return
    fi
    assert_output_contains "binds to baseline 'whinlatter'" "profile mismatch explains registry binding" || return
    pass "profile option cannot create an unsupported target/profile pair"
}

test_unknown_target_fails() {
    capture_setup -n -m not-a-real-target
    if [ "$STATUS" -eq 0 ]; then
        fail "unknown target returns non-zero" "output: $OUTPUT"
        return
    fi
    assert_output_contains "Unknown target or machine" "unknown target has a useful error" || return
    pass "unknown target fails with non-zero status"
}

test_registry_validation() {
    capture_setup -V
    assert_status 0 "registry validation exits successfully" || return
    assert_output_contains "Registry validation: ok" "registry validation reports success" || return
    pass "repository registry validates without initialized submodules"
}

test_registry_records_are_not_executed() {
    fixture=$(mktemp -d "$REPO_ROOT/lessons/build-registry/record-safety.XXXXXX")
    TEST_TEMP_DIRS="$TEST_TEMP_DIRS $fixture"
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    sentinel="$fixture/executed"
    printf 'BASELINE_DESCRIPTION="$(touch %s)"\n' "$sentinel" \
        >> "$fixture/baselines/test/baseline.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "registry records are not executed" "output: $OUTPUT"
        rm -rf "$fixture"
        return
    fi
    if [ -e "$sentinel" ]; then
        fail "registry records are not executed" "record created $sentinel"
        rm -rf "$fixture"
        return
    fi
    assert_output_contains "substitution is not allowed" \
        "record parser explains the declarative boundary" || { rm -rf "$fixture"; return; }
    rm -rf "$fixture"
    pass "setup treats registry records as declarative data"
}

test_malformed_registry_protocol_is_rejected() {
    fixture=$(mktemp -d "$REPO_ROOT/lessons/build-registry/protocol.XXXXXX")
    TEST_TEMP_DIRS="$TEST_TEMP_DIRS $fixture"
    TEST_PROTOCOL_FILE="$fixture/protocol"
    TEST_PATH="$fixture:$PATH"
    printf '%s\n' '#!/bin/sh' 'sed -n '\''p'\'' "$YF_TEST_PROTOCOL_FILE"' \
        > "$fixture/python3"
    chmod +x "$fixture/python3"

    cat > "$fixture/valid-protocol" <<'EOF'
PROTOCOL=1
TARGET_ID=fixture-target
TARGET_MACHINE=fixture-machine
TARGET_BASELINE=test
TARGET_PLATFORM=fixture-platform
TARGET_PRODUCT=
TARGET_SUPPORT_LEVEL=Parse-Validated
TARGET_DEFAULT_IMAGE=core-image-minimal
BASELINE_SERIES=test-series
BASELINE_OEROOT=components/layers/baselines/test/poky
BASELINE_LAYER=components/layers/baselines/test/poky/meta
PLATFORM_DISTRO=poky
PLATFORM_LOCAL_CONF=
PRODUCT_LOCAL_CONF=
EOF

    sed '2iUNKNOWN_KEY=value' "$fixture/valid-protocol" > "$TEST_PROTOCOL_FILE"
    capture_setup -n -T fixture-target
    [ "$STATUS" -ne 0 ] || { fail "unknown protocol key is rejected" "output: $OUTPUT"; return; }
    assert_output_contains "Unknown Build Registry protocol key" \
        "unknown protocol key is rejected" || return

    sed '/^PRODUCT_LOCAL_CONF=/d' "$fixture/valid-protocol" > "$TEST_PROTOCOL_FILE"
    capture_setup -n -T fixture-target
    [ "$STATUS" -ne 0 ] || { fail "missing protocol key is rejected" "output: $OUTPUT"; return; }
    assert_output_contains "Incomplete Build Registry protocol" \
        "missing protocol key is rejected" || return

    sed '3iTARGET_ID=duplicate' "$fixture/valid-protocol" > "$TEST_PROTOCOL_FILE"
    capture_setup -n -T fixture-target
    [ "$STATUS" -ne 0 ] || { fail "duplicate protocol key is rejected" "output: $OUTPUT"; return; }
    assert_output_contains "Out-of-order TARGET_ID" \
        "duplicate protocol key is rejected" || return

    sed '2iTARGET_MACHINE=fixture-machine' "$fixture/valid-protocol" > "$TEST_PROTOCOL_FILE"
    capture_setup -n -T fixture-target
    [ "$STATUS" -ne 0 ] || { fail "out-of-order protocol key is rejected" "output: $OUTPUT"; return; }
    assert_output_contains "Out-of-order TARGET_MACHINE" \
        "out-of-order protocol key is rejected" || return

    TEST_PATH=""
    TEST_PROTOCOL_FILE=""
    pass "setup rejects malformed Build Registry protocols"
}

test_stm32mp15_eval_enables_emmc_boot_policy() {
    fixture=$(mktemp -d "$REPO_ROOT/lessons/build-registry/stm32mp15-eval.XXXXXX")
    TEST_TEMP_DIRS="$TEST_TEMP_DIRS $fixture"
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"

    mv "$fixture/platforms/fixture-platform" "$fixture/platforms/stm32mp"
    sed -i 's/fixture-platform/stm32mp/g' \
        "$fixture/platforms/stm32mp/platform.conf" \
        "$fixture/platforms/stm32mp/baselines/test.conf" \
        "$fixture/platforms/stm32mp/targets/fixture-target.conf"
    mv "$fixture/platforms/stm32mp/targets/fixture-target.conf" \
        "$fixture/platforms/stm32mp/targets/stm32mp15-eval.conf"
    sed -i \
        -e 's/TARGET_ID="fixture-target"/TARGET_ID="stm32mp15-eval"/' \
        -e 's/TARGET_MACHINE="fixture-machine"/TARGET_MACHINE="stm32mp15-eval"/' \
        -e 's/TARGET_ALIASES="fixture-machine"/TARGET_ALIASES=""/' \
        "$fixture/platforms/stm32mp/targets/stm32mp15-eval.conf"
    rm -f "$fixture/platforms/stm32mp/targets/second-target.conf"
    rm -rf "$fixture/products"
    cp "$REPO_ROOT/platforms/stm32mp/conf/local.conf.fragment" \
        "$fixture/platforms/stm32mp/conf/local.conf.fragment"
    TEST_TOP_DIR=$fixture

    capture_setup -T stm32mp15-eval
    assert_status 0 "STM32MP15 eval setup exits successfully" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$fixture/build/test/stm32mp15-eval/conf/local.conf" \
        'BOOTDEVICE_LABELS:append:stm32mp15-eval = " emmc"' \
        "STM32MP15 eval generated configuration enables eMMC" || { TEST_TOP_DIR=""; return; }

    TEST_TOP_DIR=""
    pass "STM32MP15 eval owns an explicit eMMC boot policy"
}

test_direct_execution_and_dash_compatibility() {
    OUTPUT=$("$SETUP_SCRIPT" -h 2>&1)
    STATUS=$?
    if [ "$STATUS" -eq 0 ]; then
        fail "direct execution is rejected" "output: $OUTPUT"
        return
    fi
    case $OUTPUT in
        *"must be sourced"*) ;;
        *) fail "direct execution explains sourcing" "output: $OUTPUT"; return ;;
    esac

    OUTPUT=$(cd "$REPO_ROOT" && dash -c \
        'set -- -n -m rk3568-evb; . configs/setup-env.sh' 2>&1)
    STATUS=$?
    assert_status 0 "Dash dry-run exits successfully" || return
    assert_output_contains "baseline=whinlatter" "Dash resolves the same target profile" || return
    pass "setup rejects execution and supports POSIX Dash sourcing"
}

test_generated_configuration_and_manifest_guard() {
    fixture=$(mktemp -d "$REPO_ROOT/lessons/build-registry/setup-env-test.XXXXXX")
    TEST_TEMP_DIRS="$TEST_TEMP_DIRS $fixture"
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    TEST_TOP_DIR=$fixture

    capture_setup -T fixture-target
    assert_status 0 "fixture setup exits successfully" || { TEST_TOP_DIR=""; return; }

    build_dir="$fixture/build/test/fixture-target"
    assert_file_contains "$build_dir/conf/yocto-forall.manifest" \
        'TARGET_ID="fixture-target"' "manifest records target" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$build_dir/conf/yocto-forall.manifest" \
        'BASELINE_ID="test"' "manifest records baseline" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$build_dir/conf/local.conf" \
        'MACHINE = "fixture-machine"' "local.conf records BSP machine" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$build_dir/conf/local.conf" \
        'FIXTURE_PLATFORM_SETTING = "1"' "platform fragment is applied" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$build_dir/conf/bblayers.conf" \
        "$fixture/platforms/fixture-platform/meta-fixture" "platform layer is explicit" || { TEST_TOP_DIR=""; return; }
    if [ ! -f "$build_dir/SOURCE_THIS" ]; then
        fail "SOURCE_THIS is generated" "missing $build_dir/SOURCE_THIS"
        TEST_TOP_DIR=""
        return
    fi
    OUTPUT=$(bash -c '. "$1"; printf "MACHINE=%s\\n" "$MACHINE"' bash \
        "$build_dir/SOURCE_THIS" 2>&1)
    STATUS=$?
    assert_status 0 "SOURCE_THIS re-entry exits successfully" || { TEST_TOP_DIR=""; return; }

    product_build="$fixture/product-build"
    product_downloads="$fixture/product-downloads"
    product_sstate="$fixture/product-sstate"
    capture_setup -T fixture-product-target -b "$product_build" \
        -d "$product_downloads" -c "$product_sstate" -j 7 -t 5
    assert_status 0 "product setup with explicit options exits successfully" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$product_build/conf/local.conf" \
        'BB_NUMBER_THREADS = "5"' "-t controls BitBake threads" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$product_build/conf/local.conf" \
        'PARALLEL_MAKE = "-j 7"' "-j controls make jobs" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$product_build/conf/local.conf" \
        "DL_DIR = \"$product_downloads\"" "-d controls downloads" || { TEST_TOP_DIR=""; return; }
    assert_file_contains "$product_build/conf/local.conf" \
        "SSTATE_DIR = \"$product_sstate\"" "-c controls sstate" || { TEST_TOP_DIR=""; return; }
    assert_file_order "$product_build/conf/bblayers.conf" \
        "generated layers preserve baseline/platform/product/common order" \
        "$fixture/components/layers/baselines/test/poky/meta" \
        "$fixture/components/layers/baselines/test/poky/meta-poky" \
        "$fixture/components/layers/baselines/test/meta-openembedded/meta-oe" \
        "$fixture/platforms/fixture-platform/meta-fixture" \
        "$fixture/products/fixture-product/meta-fixture-product" \
        "$fixture/platforms/common/meta-user" || { TEST_TOP_DIR=""; return; }
    assert_file_order "$product_build/conf/local.conf" \
        "generated fragments preserve platform/product order" \
        '# Platform: fixture-platform' \
        'FIXTURE_PLATFORM_SETTING = "1"' \
        '# Product: fixture-product' \
        'FIXTURE_PRODUCT_SETTING = "1"' || { TEST_TOP_DIR=""; return; }

    shared_build="$fixture/shared-build"
    capture_setup -T fixture-target -b "$shared_build"
    assert_status 0 "first shared-build setup exits successfully" || { TEST_TOP_DIR=""; return; }
    capture_setup -T second-target -b "$shared_build"
    if [ "$STATUS" -eq 0 ]; then
        fail "build manifest rejects target reuse" "output: $OUTPUT"
        TEST_TOP_DIR=""
        return
    fi
    assert_output_contains "belongs to target 'fixture-target'" "manifest mismatch explains ownership" || { TEST_TOP_DIR=""; return; }

    TEST_TOP_DIR=""
    pass "generated configuration is deterministic and build reuse is guarded"
}

test_registry_listing
test_target_alias_resolution
test_product_target_resolution
test_dry_run_stdout_and_path_options
test_profile_is_an_assertion
test_unknown_target_fails
test_registry_validation
test_registry_records_are_not_executed
test_malformed_registry_protocol_is_rejected
test_stm32mp15_eval_enables_emmc_boot_policy
test_direct_execution_and_dash_compatibility
test_generated_configuration_and_manifest_guard

if [ "$FAILURES" -ne 0 ]; then
    printf '\n%d test assertion(s) failed\n' "$FAILURES"
    exit 1
fi

printf '\nall setup-env tests passed\n'
