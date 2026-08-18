#!/usr/bin/env bash

set -u

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SETUP_SCRIPT="$REPO_ROOT/configs/setup-env.sh"
FAILURES=0
OUTPUT=""
STATUS=0
TEST_TOP_DIR=""

capture_setup() {
    if [ -n "$TEST_TOP_DIR" ]; then
        OUTPUT=$(YOCTO_FORALL_TOP_DIR="$TEST_TOP_DIR" \
            bash -c '. "$1" "${@:2}"' bash "$SETUP_SCRIPT" "$@" 2>&1)
        STATUS=$?
    else
        OUTPUT=$(cd "$REPO_ROOT" && \
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

test_profiles_cannot_share_core_paths() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    mkdir -p "$fixture/baselines/other"
    sed 's/BASELINE_ID="test"/BASELINE_ID="other"/' \
        "$fixture/baselines/test/baseline.conf" \
        > "$fixture/baselines/other/baseline.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "profiles cannot share one OEROOT" "output: $OUTPUT"
        return
    fi
    assert_output_contains "OEROOT must live under" "shared OEROOT error explains physical isolation" || return
    pass "registry keeps each Baseline Profile inside its own core directory"
}

test_adapter_cannot_cross_baselines() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    sed 's#platforms/fixture-platform/meta-fixture#components/layers/baselines/other/meta#' \
        "$fixture/platforms/fixture-platform/baselines/test.conf" \
        > "$fixture/platforms/fixture-platform/baselines/test.conf.changed"
    mv "$fixture/platforms/fixture-platform/baselines/test.conf.changed" \
        "$fixture/platforms/fixture-platform/baselines/test.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "platform adapter cannot cross Baseline Profiles" "output: $OUTPUT"
        return
    fi
    assert_output_contains "crosses from baseline 'test'" "cross-profile layer error explains isolation" || return
    pass "registry rejects platform adapters that select another profile's layers"
}

test_integration_layer_has_one_baseline_owner() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    mkdir -p "$fixture/baselines/other"
    sed 's#test#other#g' \
        "$fixture/baselines/test/baseline.conf" \
        > "$fixture/baselines/other/baseline.conf"
    sed 's/PLATFORM_BASELINES="test"/PLATFORM_BASELINES="test other"/' \
        "$fixture/platforms/fixture-platform/platform.conf" \
        > "$fixture/platforms/fixture-platform/platform.conf.changed"
    mv "$fixture/platforms/fixture-platform/platform.conf.changed" \
        "$fixture/platforms/fixture-platform/platform.conf"
    sed 's/PLATFORM_BASELINE_ID="test"/PLATFORM_BASELINE_ID="other"/' \
        "$fixture/platforms/fixture-platform/baselines/test.conf" \
        > "$fixture/platforms/fixture-platform/baselines/other.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "integration layers have one Baseline owner" "output: $OUTPUT"
        return
    fi
    assert_output_contains "claimed by baselines 'other' and 'test'" \
        "shared integration layer error identifies both Baselines" || return
    pass "registry rejects integration-layer reuse across Baseline Profiles"
}

test_gitlink_source_has_one_baseline_owner() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    mkdir -p "$fixture/baselines/other"
    sed 's#test#other#g' \
        "$fixture/baselines/test/baseline.conf" \
        > "$fixture/baselines/other/baseline.conf"
    sed 's/PLATFORM_BASELINES="test"/PLATFORM_BASELINES="test other"/' \
        "$fixture/platforms/fixture-platform/platform.conf" \
        > "$fixture/platforms/fixture-platform/platform.conf.changed"
    mv "$fixture/platforms/fixture-platform/platform.conf.changed" \
        "$fixture/platforms/fixture-platform/platform.conf"
    sed 's#platforms/fixture-platform/meta-fixture#components/layers/bsp/fixture/meta-shared/meta-a#' \
        "$fixture/platforms/fixture-platform/baselines/test.conf" \
        > "$fixture/platforms/fixture-platform/baselines/test.conf.changed"
    mv "$fixture/platforms/fixture-platform/baselines/test.conf.changed" \
        "$fixture/platforms/fixture-platform/baselines/test.conf"
    sed -e 's/PLATFORM_BASELINE_ID="test"/PLATFORM_BASELINE_ID="other"/' \
        -e 's#meta-shared/meta-a#meta-shared/meta-b#' \
        "$fixture/platforms/fixture-platform/baselines/test.conf" \
        > "$fixture/platforms/fixture-platform/baselines/other.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "gitlink checkout has one Baseline owner" "output: $OUTPUT"
        return
    fi
    assert_output_contains "Integration source 'components/layers/bsp/fixture/meta-shared'" \
        "shared gitlink error identifies the checkout root" || return
    assert_output_contains "claimed by baselines 'other' and 'test'" \
        "shared gitlink error identifies both Baselines" || return
    pass "registry rejects different sublayers from one gitlink across profiles"
}

test_layer_paths_must_be_canonical() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    sed 's#platforms/fixture-platform/meta-fixture#platforms/fixture-platform/./meta-fixture#' \
        "$fixture/platforms/fixture-platform/baselines/test.conf" \
        > "$fixture/platforms/fixture-platform/baselines/test.conf.changed"
    mv "$fixture/platforms/fixture-platform/baselines/test.conf.changed" \
        "$fixture/platforms/fixture-platform/baselines/test.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "layer paths must be canonical" "output: $OUTPUT"
        return
    fi
    assert_output_contains "must be a canonical repository-relative path" \
        "non-canonical path error explains the requirement" || return
    pass "registry rejects lexical aliases for layer paths"
}

test_platform_target_cannot_declare_product() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    sed 's/TARGET_PRODUCT=""/TARGET_PRODUCT="fixture-product"/' \
        "$fixture/platforms/fixture-platform/targets/fixture-target.conf" \
        > "$fixture/platforms/fixture-platform/targets/fixture-target.conf.changed"
    mv "$fixture/platforms/fixture-platform/targets/fixture-target.conf.changed" \
        "$fixture/platforms/fixture-platform/targets/fixture-target.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "platform target cannot declare a product" "output: $OUTPUT"
        return
    fi
    assert_output_contains "Platform target 'fixture-target' must not declare TARGET_PRODUCT" \
        "platform target ownership error explains the boundary" || return
    pass "registry keeps product targets out of platforms/"
}

test_platform_target_matches_owning_directory() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    sed 's/TARGET_PLATFORM="fixture-platform"/TARGET_PLATFORM="other-platform"/' \
        "$fixture/platforms/fixture-platform/targets/fixture-target.conf" \
        > "$fixture/platforms/fixture-platform/targets/fixture-target.conf.changed"
    mv "$fixture/platforms/fixture-platform/targets/fixture-target.conf.changed" \
        "$fixture/platforms/fixture-platform/targets/fixture-target.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "platform target matches its owning directory" "output: $OUTPUT"
        return
    fi
    assert_output_contains "is under platform 'fixture-platform' but declares TARGET_PLATFORM 'other-platform'" \
        "platform target ownership error identifies the mismatch" || return
    pass "registry binds every platform target to its platforms/<id>/ owner"
}

test_product_target_matches_owning_directory() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    mkdir -p "$fixture/products/wrong-product/targets"
    mv "$fixture/products/fixture-product/targets/fixture-product-target.conf" \
        "$fixture/products/wrong-product/targets/fixture-product-target.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "product target matches its owning directory" "output: $OUTPUT"
        return
    fi
    assert_output_contains "is under product 'wrong-product' but declares TARGET_PRODUCT 'fixture-product'" \
        "product target ownership error identifies the mismatch" || return
    pass "registry binds every product target to its products/<id>/ owner"
}

test_platform_adapter_cannot_reference_products() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    sed 's#platforms/fixture-platform/meta-fixture#products/fixture-product/meta-fixture-product#' \
        "$fixture/platforms/fixture-platform/baselines/test.conf" \
        > "$fixture/platforms/fixture-platform/baselines/test.conf.changed"
    mv "$fixture/platforms/fixture-platform/baselines/test.conf.changed" \
        "$fixture/platforms/fixture-platform/baselines/test.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "platform adapter cannot reference products" "output: $OUTPUT"
        return
    fi
    assert_output_contains "must not reference product layer" \
        "platform adapter error explains product leakage" || return
    pass "registry keeps Platform Integrations product-agnostic"
}

test_platform_adapter_cannot_reference_another_platform() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    sed 's#platforms/fixture-platform/meta-fixture#platforms/other-platform/meta-fixture#' \
        "$fixture/platforms/fixture-platform/baselines/test.conf" \
        > "$fixture/platforms/fixture-platform/baselines/test.conf.changed"
    mv "$fixture/platforms/fixture-platform/baselines/test.conf.changed" \
        "$fixture/platforms/fixture-platform/baselines/test.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "platform adapter cannot reference another platform" "output: $OUTPUT"
        return
    fi
    assert_output_contains "must not reference layer owned by platform 'other-platform'" \
        "platform layer ownership error identifies the other owner" || return
    pass "registry keeps platform-owned layers inside their Platform Integration"
}

test_platform_fragment_stays_in_platform() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    mkdir -p "$fixture/platforms/other-platform/conf"
    cp "$fixture/platforms/fixture-platform/conf/local.conf.fragment" \
        "$fixture/platforms/other-platform/conf/local.conf.fragment"
    sed 's#platforms/fixture-platform/conf/local.conf.fragment#platforms/other-platform/conf/local.conf.fragment#' \
        "$fixture/platforms/fixture-platform/baselines/test.conf" \
        > "$fixture/platforms/fixture-platform/baselines/test.conf.changed"
    mv "$fixture/platforms/fixture-platform/baselines/test.conf.changed" \
        "$fixture/platforms/fixture-platform/baselines/test.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "platform fragment stays in platform" "output: $OUTPUT"
        return
    fi
    assert_output_contains "must not reference fragment owned by platform 'other-platform'" \
        "platform fragment ownership error identifies the other owner" || return
    pass "registry keeps platform fragments inside their Platform Integration"
}

test_product_adapter_layers_stay_in_product() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    rm "$fixture/products/fixture-product/targets/fixture-product-target.conf"
    sed 's#products/fixture-product/meta-fixture-product#platforms/fixture-platform/meta-fixture#' \
        "$fixture/products/fixture-product/baselines/test.conf" \
        > "$fixture/products/fixture-product/baselines/test.conf.changed"
    mv "$fixture/products/fixture-product/baselines/test.conf.changed" \
        "$fixture/products/fixture-product/baselines/test.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "product adapter layers stay in product" "output: $OUTPUT"
        return
    fi
    assert_output_contains "must own layer paths under products/fixture-product/" \
        "product layer error explains its ownership boundary" || return
    pass "registry keeps Product Integration layers under their product owner"
}

test_product_adapter_fragment_stays_in_product() {
    fixture=$(mktemp -d)
    cp -R "$REPO_ROOT/tests/fixtures/minimal/." "$fixture/"
    rm "$fixture/products/fixture-product/targets/fixture-product-target.conf"
    sed 's#products/fixture-product/conf/local.conf.fragment#platforms/fixture-platform/conf/local.conf.fragment#' \
        "$fixture/products/fixture-product/baselines/test.conf" \
        > "$fixture/products/fixture-product/baselines/test.conf.changed"
    mv "$fixture/products/fixture-product/baselines/test.conf.changed" \
        "$fixture/products/fixture-product/baselines/test.conf"
    TEST_TOP_DIR=$fixture

    capture_setup -V
    TEST_TOP_DIR=""
    if [ "$STATUS" -eq 0 ]; then
        fail "product adapter fragment stays in product" "output: $OUTPUT"
        return
    fi
    assert_output_contains "must own its local fragment under products/fixture-product/" \
        "product fragment error explains its ownership boundary" || return
    pass "registry keeps Product Integration fragments under their product owner"
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
    fixture=$(mktemp -d)
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
test_profile_is_an_assertion
test_unknown_target_fails
test_registry_validation
test_profiles_cannot_share_core_paths
test_adapter_cannot_cross_baselines
test_integration_layer_has_one_baseline_owner
test_gitlink_source_has_one_baseline_owner
test_layer_paths_must_be_canonical
test_platform_target_cannot_declare_product
test_platform_target_matches_owning_directory
test_product_target_matches_owning_directory
test_platform_adapter_cannot_reference_products
test_platform_adapter_cannot_reference_another_platform
test_platform_fragment_stays_in_platform
test_product_adapter_layers_stay_in_product
test_product_adapter_fragment_stays_in_product
test_direct_execution_and_dash_compatibility
test_generated_configuration_and_manifest_guard

if [ "$FAILURES" -ne 0 ]; then
    printf '\n%d test assertion(s) failed\n' "$FAILURES"
    exit 1
fi

printf '\nall setup-env tests passed\n'
