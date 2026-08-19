from contextlib import contextmanager
from io import StringIO
import shutil
import tempfile
import unittest
from pathlib import Path

from configs.build_registry import (
    BuildRegistry,
    RegistryError,
    RegistryIssue,
    ResolutionError,
    main,
)


FIXTURE_ROOT = Path(__file__).resolve().parent / "fixtures" / "minimal"
REPO_ROOT = FIXTURE_ROOT.parents[2]
WORK_ROOT = REPO_ROOT / "lessons" / "build-registry"
WORK_ROOT.mkdir(parents=True, exist_ok=True)


@contextmanager
def registry_fixture():
    with tempfile.TemporaryDirectory(dir=str(WORK_ROOT)) as temporary_directory:
        root = Path(temporary_directory) / "registry"
        shutil.copytree(str(FIXTURE_ROOT), str(root))
        yield root


class BuildRegistryTests(unittest.TestCase):
    def test_compiles_quoted_scalars_and_multiline_lists(self):
        registry = BuildRegistry.compile(FIXTURE_ROOT)

        baseline = registry.baselines["test"]
        self.assertEqual("test-series", baseline.series)
        self.assertEqual(
            (
                "components/layers/baselines/test/poky/meta",
                "components/layers/baselines/test/poky/meta-poky",
                "components/layers/baselines/test/meta-openembedded/meta-oe",
            ),
            baseline.layers,
        )

    def test_rejects_unknown_fields(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8") + 'BASELINE_UNKNOWN="nope"\n',
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("unknown field BASELINE_UNKNOWN", str(raised.exception))

    def test_rejects_duplicate_fields(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8") + 'BASELINE_ID="other"\n',
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("duplicate field BASELINE_ID", str(raised.exception))

    def test_rejects_command_substitution_without_executing_it(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            sentinel = root / "executed"
            path.write_text(
                path.read_text(encoding="utf-8")
                + 'BASELINE_DESCRIPTION="$(touch {})"\n'.format(sentinel),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

            self.assertFalse(sentinel.exists())

        self.assertIn("substitution is not allowed", str(raised.exception))

    def test_reports_missing_required_fields(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'BASELINE_SERIES="test-series"\n', ""
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("missing required field BASELINE_SERIES", str(raised.exception))

    def test_rejects_unquoted_assignments(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'BASELINE_ID="test"', "BASELINE_ID=test"
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("expected a quoted field assignment", str(raised.exception))

    def test_compiles_all_registry_record_types(self):
        registry = BuildRegistry.compile(FIXTURE_ROOT)

        platform = registry.platforms["fixture-platform"]
        self.assertEqual(("test",), platform.baselines)

        platform_adapter = registry.platform_adapters[("fixture-platform", "test")]
        self.assertEqual("poky", platform_adapter.distro)
        self.assertEqual(
            ("platforms/fixture-platform/meta-fixture",), platform_adapter.layers
        )

        product = registry.products["fixture-product"]
        self.assertEqual("fixture-platform", product.platform)

        product_adapter = registry.product_adapters[("fixture-product", "test")]
        self.assertEqual(
            ("products/fixture-product/meta-fixture-product",),
            product_adapter.layers,
        )

        target = registry.targets["fixture-product-target"]
        self.assertEqual("fixture-product", target.product)
        self.assertEqual("fixture-image", target.default_image)

    def test_reports_unterminated_quoted_values(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'BASELINE_ID="test"', 'BASELINE_ID="test'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("unterminated quoted value", str(raised.exception))

    def test_rejects_trailing_executable_tokens(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'BASELINE_ID="test"', 'BASELINE_ID="test"; false'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("trailing tokens are not allowed", str(raised.exception))

    def test_rejects_control_characters_in_values(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_bytes(path.read_bytes() + b'BASELINE_DESCRIPTION="bad\x00value"\n')

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("control characters are not allowed", str(raised.exception))

    def test_aggregates_independent_record_errors_deterministically(self):
        with registry_fixture() as root:
            baseline_path = root / "baselines" / "test" / "baseline.conf"
            baseline_path.write_text(
                baseline_path.read_text(encoding="utf-8")
                + 'BASELINE_UNKNOWN="nope"\n',
                encoding="utf-8",
            )
            target_path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            target_path.write_text(
                target_path.read_text(encoding="utf-8") + 'TARGET_UNKNOWN="nope"\n',
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertEqual(
            [
                ("baselines/test/baseline.conf", "unknown-field"),
                (
                    "platforms/fixture-platform/targets/fixture-target.conf",
                    "unknown-field",
                ),
            ],
            [(issue.path, issue.code) for issue in raised.exception.issues],
        )

    def test_aggregates_independent_errors_within_one_record(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8")
                + 'BASELINE_UNKNOWN="nope"\n'
                + 'BASELINE_ID="duplicate"\n',
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertEqual(
            ["duplicate-field", "unknown-field"],
            sorted(
                issue.code
                for issue in raised.exception.issues
                if issue.path == "baselines/test/baseline.conf"
                and issue.code in {"duplicate-field", "unknown-field"}
            ),
        )

    def test_rejects_each_executable_shell_form(self):
        cases = (
            ("false\n", "invalid-syntax"),
            ('export BASELINE_DESCRIPTION="bad"\n', "invalid-syntax"),
            ('bad_function() { :; }\n', "invalid-syntax"),
            ('if true; then :; fi\n', "invalid-syntax"),
            ('for item in bad; do :; done\n', "invalid-syntax"),
            ('BASELINE_DESCRIPTION="bad" > ignored\n', "trailing-tokens"),
            ('BASELINE_DESCRIPTION=<(printf bad)\n', "invalid-syntax"),
            ('BASELINE_DESCRIPTION="`printf bad`"\n', "substitution-not-allowed"),
            ('BASELINE_DESCRIPTION="$SHELL_VALUE"\n', "substitution-not-allowed"),
        )
        for record_line, expected_code in cases:
            with self.subTest(record_line=record_line):
                with registry_fixture() as root:
                    path = root / "baselines" / "test" / "baseline.conf"
                    path.write_text(
                        path.read_text(encoding="utf-8") + record_line,
                        encoding="utf-8",
                    )

                    with self.assertRaises(RegistryError) as raised:
                        BuildRegistry.compile(root)

                self.assertIn(
                    expected_code,
                    [issue.code for issue in raised.exception.issues],
                )

    def test_accepts_blank_lines_and_comments(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                "\n# Baseline declaration\n"
                + path.read_text(encoding="utf-8")
                + "\n# End of declaration\n",
                encoding="utf-8",
            )

            registry = BuildRegistry.compile(root)

        self.assertIn("test", registry.baselines)

    def test_invalid_required_assignment_does_not_cascade_to_missing_field(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'BASELINE_ID="test"', "BASELINE_ID=test"
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        baseline_issues = [
            issue
            for issue in raised.exception.issues
            if issue.path == "baselines/test/baseline.conf"
        ]
        self.assertIn("invalid-syntax", [issue.code for issue in baseline_issues])
        self.assertNotIn(
            ("BASELINE_ID", "missing-field"),
            [(issue.field, issue.code) for issue in baseline_issues],
        )

    def test_issue_order_handles_record_and_field_issues_on_the_same_path(self):
        error = RegistryError(
            (
                RegistryIssue("record.conf", "FIELD", "field-rule", "field issue"),
                RegistryIssue("record.conf", None, "record-rule", "record issue"),
            )
        )

        self.assertEqual(
            [(None, "record-rule"), ("FIELD", "field-rule")],
            [(issue.field, issue.code) for issue in error.issues],
        )

    def test_unreadable_record_is_reported_without_a_python_decode_error(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_bytes(b"\xff")

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "could not read declarative record as UTF-8",
            str(raised.exception),
        )

    def test_requires_at_least_one_baseline_profile(self):
        with registry_fixture() as root:
            shutil.rmtree(str(root / "baselines"))

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("no Baseline Profiles found under baselines/", str(raised.exception))

    def test_baseline_identifier_matches_owning_directory(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'BASELINE_ID="test"', 'BASELINE_ID="other"'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Baseline directory 'test' declares BASELINE_ID 'other'",
            str(raised.exception),
        )

    def test_baseline_oeroot_stays_inside_its_profile(self):
        with registry_fixture() as root:
            source = root / "baselines" / "test" / "baseline.conf"
            destination = root / "baselines" / "other" / "baseline.conf"
            destination.parent.mkdir(parents=True)
            destination.write_text(
                source.read_text(encoding="utf-8").replace(
                    'BASELINE_ID="test"', 'BASELINE_ID="other"'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Baseline 'other' OEROOT must live under "
            "components/layers/baselines/other/",
            str(raised.exception),
        )

    def test_layer_paths_must_be_canonical_repository_relative_paths(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "platforms/fixture-platform/meta-fixture",
                    "platforms/fixture-platform/./meta-fixture",
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "must be a canonical repository-relative path",
            str(raised.exception),
        )

    def test_platform_adapter_cannot_cross_baseline_profiles(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "platforms/fixture-platform/meta-fixture",
                    "components/layers/baselines/other/meta",
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "adapter crosses from baseline 'test'",
            str(raised.exception),
        )

    def test_platform_target_cannot_declare_a_product(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_PRODUCT=""', 'TARGET_PRODUCT="fixture-product"'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Platform target 'fixture-target' must not declare TARGET_PRODUCT",
            str(raised.exception),
        )

    def test_platform_target_matches_its_owning_directory(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_PLATFORM="fixture-platform"',
                    'TARGET_PLATFORM="other-platform"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "is under platform 'fixture-platform' but declares "
            "TARGET_PLATFORM 'other-platform'",
            str(raised.exception),
        )

    def test_product_target_matches_its_owning_directory(self):
        with registry_fixture() as root:
            source = (
                root
                / "products"
                / "fixture-product"
                / "targets"
                / "fixture-product-target.conf"
            )
            destination = (
                root
                / "products"
                / "wrong-product"
                / "targets"
                / source.name
            )
            destination.parent.mkdir(parents=True)
            source.rename(destination)

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "is under product 'wrong-product' but declares "
            "TARGET_PRODUCT 'fixture-product'",
            str(raised.exception),
        )

    def test_platform_requires_each_declared_baseline_adapter(self):
        with registry_fixture() as root:
            adapter = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            adapter.unlink()

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Platform 'fixture-platform' is missing baseline adapter 'test.conf'",
            str(raised.exception),
        )

    def test_platform_rejects_undeclared_baseline_adapters(self):
        with registry_fixture() as root:
            baseline_source = root / "baselines" / "test" / "baseline.conf"
            baseline_destination = root / "baselines" / "other" / "baseline.conf"
            baseline_destination.parent.mkdir(parents=True)
            baseline_destination.write_text(
                baseline_source.read_text(encoding="utf-8").replace(
                    "test", "other"
                ),
                encoding="utf-8",
            )
            adapter_source = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            adapter_destination = adapter_source.with_name("other.conf")
            adapter_destination.write_text(
                adapter_source.read_text(encoding="utf-8").replace(
                    'PLATFORM_BASELINE_ID="test"',
                    'PLATFORM_BASELINE_ID="other"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Platform 'fixture-platform' has unexpected baseline adapter "
            "'other.conf'",
            str(raised.exception),
        )

    def test_platform_adapter_baseline_matches_its_filename(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'PLATFORM_BASELINE_ID="test"',
                    'PLATFORM_BASELINE_ID="other"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "adapter 'test.conf' declares 'other'",
            str(raised.exception),
        )

    def test_platform_identifier_matches_owning_directory(self):
        with registry_fixture() as root:
            path = root / "platforms" / "fixture-platform" / "platform.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'PLATFORM_ID="fixture-platform"',
                    'PLATFORM_ID="other-platform"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Platform directory 'fixture-platform' declares PLATFORM_ID "
            "'other-platform'",
            str(raised.exception),
        )

    def test_product_requires_each_declared_baseline_adapter(self):
        with registry_fixture() as root:
            adapter = (
                root
                / "products"
                / "fixture-product"
                / "baselines"
                / "test.conf"
            )
            adapter.unlink()

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Product 'fixture-product' is missing baseline adapter 'test.conf'",
            str(raised.exception),
        )

    def test_product_adapter_layers_stay_under_the_product_owner(self):
        with registry_fixture() as root:
            path = (
                root
                / "products"
                / "fixture-product"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "products/fixture-product/meta-fixture-product",
                    "platforms/fixture-platform/meta-fixture",
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "must own layer paths under products/fixture-product/",
            str(raised.exception),
        )

    def test_product_adapter_fragment_stays_under_the_product_owner(self):
        with registry_fixture() as root:
            path = (
                root
                / "products"
                / "fixture-product"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "products/fixture-product/conf/local.conf.fragment",
                    "platforms/fixture-platform/conf/local.conf.fragment",
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "must own its local fragment under products/fixture-product/",
            str(raised.exception),
        )

    def test_platform_adapter_cannot_reference_product_layers(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "platforms/fixture-platform/meta-fixture",
                    "products/fixture-product/meta-fixture-product",
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("must not reference product layer", str(raised.exception))

    def test_platform_adapter_cannot_reference_another_platform_layer(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "platforms/fixture-platform/meta-fixture",
                    "platforms/other-platform/meta-fixture",
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "must not reference layer owned by platform 'other-platform'",
            str(raised.exception),
        )

    def test_platform_adapter_fragment_stays_under_the_platform_owner(self):
        with registry_fixture() as root:
            other_fragment = (
                root
                / "platforms"
                / "other-platform"
                / "conf"
                / "local.conf.fragment"
            )
            other_fragment.parent.mkdir(parents=True)
            other_fragment.write_text("OTHER = \"1\"\n", encoding="utf-8")
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "platforms/fixture-platform/conf/local.conf.fragment",
                    "platforms/other-platform/conf/local.conf.fragment",
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "must not reference fragment owned by platform 'other-platform'",
            str(raised.exception),
        )

    def test_platform_adapter_local_fragment_must_exist(self):
        with registry_fixture() as root:
            fragment = (
                root
                / "platforms"
                / "fixture-platform"
                / "conf"
                / "local.conf.fragment"
            )
            fragment.unlink()

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("local fragment", str(raised.exception))
        self.assertIn("is missing", str(raised.exception))

    def test_target_selectors_are_globally_unique(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "second-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_MACHINE="second-machine"',
                    'TARGET_MACHINE="fixture-machine"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Target selector 'fixture-machine' is owned by more than one target",
            str(raised.exception),
        )

    def test_target_identifier_matches_its_filename(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_ID="fixture-target"', 'TARGET_ID="other-target"'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Target file 'fixture-target.conf' declares TARGET_ID 'other-target'",
            str(raised.exception),
        )

    def test_requires_at_least_one_target(self):
        with registry_fixture() as root:
            shutil.rmtree(str(root / "platforms" / "fixture-platform" / "targets"))
            shutil.rmtree(str(root / "products" / "fixture-product" / "targets"))

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("no targets found under platforms/ or products/", str(raised.exception))

    def test_gitlink_integration_source_has_one_baseline_owner(self):
        with registry_fixture() as root:
            baseline_source = root / "baselines" / "test" / "baseline.conf"
            baseline_destination = root / "baselines" / "other" / "baseline.conf"
            baseline_destination.parent.mkdir(parents=True)
            baseline_destination.write_text(
                baseline_source.read_text(encoding="utf-8").replace(
                    "test", "other"
                ),
                encoding="utf-8",
            )
            platform_path = (
                root / "platforms" / "fixture-platform" / "platform.conf"
            )
            platform_path.write_text(
                platform_path.read_text(encoding="utf-8").replace(
                    'PLATFORM_BASELINES="test"',
                    'PLATFORM_BASELINES="test other"',
                ),
                encoding="utf-8",
            )
            adapter_source = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            adapter_source.write_text(
                adapter_source.read_text(encoding="utf-8").replace(
                    "platforms/fixture-platform/meta-fixture",
                    "components/layers/bsp/fixture/meta-shared/meta-a",
                ),
                encoding="utf-8",
            )
            adapter_destination = adapter_source.with_name("other.conf")
            adapter_destination.write_text(
                adapter_source.read_text(encoding="utf-8")
                .replace(
                    'PLATFORM_BASELINE_ID="test"',
                    'PLATFORM_BASELINE_ID="other"',
                )
                .replace("meta-shared/meta-a", "meta-shared/meta-b"),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Integration source 'components/layers/bsp/fixture/meta-shared'",
            str(raised.exception),
        )
        self.assertIn("claimed by baselines 'other' and 'test'", str(raised.exception))

    def test_target_references_a_known_baseline(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_BASELINE="test"', 'TARGET_BASELINE="other"'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Target 'fixture-target' references unknown baseline 'other'",
            str(raised.exception),
        )

    def test_target_references_a_known_platform(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_PLATFORM="fixture-platform"',
                    'TARGET_PLATFORM="unknown-platform"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Target 'fixture-target' references unknown platform 'unknown-platform'",
            str(raised.exception),
        )

    def test_product_references_a_known_platform(self):
        with registry_fixture() as root:
            path = root / "products" / "fixture-product" / "product.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'PRODUCT_PLATFORM="fixture-platform"',
                    'PRODUCT_PLATFORM="other-platform"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Product 'fixture-product' references unknown platform 'other-platform'",
            str(raised.exception),
        )

    def test_product_baseline_must_be_supported_by_its_platform(self):
        with registry_fixture() as root:
            baseline_source = root / "baselines" / "test" / "baseline.conf"
            baseline_destination = root / "baselines" / "other" / "baseline.conf"
            baseline_destination.parent.mkdir(parents=True)
            baseline_destination.write_text(
                baseline_source.read_text(encoding="utf-8").replace(
                    "test", "other"
                ),
                encoding="utf-8",
            )
            product_path = root / "products" / "fixture-product" / "product.conf"
            product_path.write_text(
                product_path.read_text(encoding="utf-8").replace(
                    'PRODUCT_BASELINES="test"', 'PRODUCT_BASELINES="test other"'
                ),
                encoding="utf-8",
            )
            adapter_source = (
                root
                / "products"
                / "fixture-product"
                / "baselines"
                / "test.conf"
            )
            adapter_source.with_name("other.conf").write_text(
                adapter_source.read_text(encoding="utf-8").replace(
                    'PRODUCT_BASELINE_ID="test"',
                    'PRODUCT_BASELINE_ID="other"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "binds platform 'fixture-platform' to unsupported baseline 'other'",
            str(raised.exception),
        )

    def test_target_baseline_must_be_supported_by_its_platform(self):
        with registry_fixture() as root:
            baseline_source = root / "baselines" / "test" / "baseline.conf"
            baseline_destination = root / "baselines" / "other" / "baseline.conf"
            baseline_destination.parent.mkdir(parents=True)
            baseline_destination.write_text(
                baseline_source.read_text(encoding="utf-8").replace(
                    "test", "other"
                ),
                encoding="utf-8",
            )
            target_path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            target_path.write_text(
                target_path.read_text(encoding="utf-8").replace(
                    'TARGET_BASELINE="test"', 'TARGET_BASELINE="other"'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "binds platform 'fixture-platform' to unsupported baseline 'other'",
            str(raised.exception),
        )

    def test_target_support_level_is_from_the_supported_vocabulary(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_SUPPORT_LEVEL="Parse-Validated"',
                    'TARGET_SUPPORT_LEVEL="Works-On-My-Machine"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("Invalid TARGET_SUPPORT_LEVEL", str(raised.exception))

    def test_production_supported_target_requires_a_product(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_SUPPORT_LEVEL="Parse-Validated"',
                    'TARGET_SUPPORT_LEVEL="Production-Supported"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "cannot be Production-Supported without TARGET_PRODUCT",
            str(raised.exception),
        )

    def test_target_identifiers_reject_whitespace(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_MACHINE="fixture-machine"',
                    'TARGET_MACHINE="bad machine"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("TARGET_MACHINE has invalid identifier 'bad machine'", str(raised.exception))

    def test_target_default_image_cannot_be_empty(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "fixture-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_DEFAULT_IMAGE="core-image-minimal"',
                    'TARGET_DEFAULT_IMAGE=""',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("TARGET_DEFAULT_IMAGE is empty", str(raised.exception))

    def test_product_target_platform_matches_its_product(self):
        with registry_fixture() as root:
            other_platform = root / "platforms" / "other-platform"
            (other_platform / "baselines").mkdir(parents=True)
            (other_platform / "platform.conf").write_text(
                'PLATFORM_ID="other-platform"\nPLATFORM_BASELINES="test"\n',
                encoding="utf-8",
            )
            (other_platform / "baselines" / "test.conf").write_text(
                'PLATFORM_BASELINE_ID="test"\n'
                'PLATFORM_DISTRO="poky"\n'
                'PLATFORM_LAYERS=""\n',
                encoding="utf-8",
            )
            product_path = root / "products" / "fixture-product" / "product.conf"
            product_path.write_text(
                product_path.read_text(encoding="utf-8").replace(
                    'PRODUCT_PLATFORM="fixture-platform"',
                    'PRODUCT_PLATFORM="other-platform"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Product 'fixture-product' uses platform 'other-platform', "
            "target uses 'fixture-platform'",
            str(raised.exception),
        )

    def test_baseline_core_layers_stay_inside_the_profile(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "components/layers/baselines/test/poky/meta",
                    "components/layers/baselines/other/poky/meta",
                    1,
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("core layer", str(raised.exception))
        self.assertIn("outside its profile directory", str(raised.exception))

    def test_product_identifier_matches_owning_directory(self):
        with registry_fixture() as root:
            path = root / "products" / "fixture-product" / "product.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'PRODUCT_ID="fixture-product"', 'PRODUCT_ID="other-product"'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Product directory 'fixture-product' declares PRODUCT_ID 'other-product'",
            str(raised.exception),
        )

    def test_duplicate_product_identifiers_are_rejected(self):
        with registry_fixture() as root:
            source = root / "products" / "fixture-product" / "product.conf"
            destination = root / "products" / "other-product" / "product.conf"
            destination.parent.mkdir(parents=True)
            destination.write_text(
                source.read_text(encoding="utf-8"), encoding="utf-8"
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("Duplicate product 'fixture-product'", str(raised.exception))

    def test_product_adapter_baseline_matches_its_filename(self):
        with registry_fixture() as root:
            path = (
                root
                / "products"
                / "fixture-product"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'PRODUCT_BASELINE_ID="test"',
                    'PRODUCT_BASELINE_ID="other"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("adapter 'test.conf' declares 'other'", str(raised.exception))

    def test_duplicate_product_adapter_keys_are_rejected_before_overwrite(self):
        with registry_fixture() as root:
            source = (
                root
                / "products"
                / "fixture-product"
                / "baselines"
                / "test.conf"
            )
            duplicate = source.with_name("aaa.conf")
            duplicate.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Duplicate product adapter for 'fixture-product' and baseline 'test'",
            str(raised.exception),
        )
        self.assertIn("adapter 'aaa.conf' declares 'test'", str(raised.exception))

    def test_duplicate_baseline_identifiers_are_rejected(self):
        with registry_fixture() as root:
            source = root / "baselines" / "test" / "baseline.conf"
            destination = root / "baselines" / "other" / "baseline.conf"
            destination.parent.mkdir(parents=True)
            destination.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("Duplicate baseline 'test'", str(raised.exception))

    def test_product_rejects_undeclared_baseline_adapters(self):
        with registry_fixture() as root:
            baseline_source = root / "baselines" / "test" / "baseline.conf"
            baseline_destination = root / "baselines" / "other" / "baseline.conf"
            baseline_destination.parent.mkdir(parents=True)
            baseline_destination.write_text(
                baseline_source.read_text(encoding="utf-8").replace(
                    "test", "other"
                ),
                encoding="utf-8",
            )
            adapter = (
                root
                / "products"
                / "fixture-product"
                / "baselines"
                / "other.conf"
            )
            adapter.write_text(
                'PRODUCT_BASELINE_ID="other"\nPRODUCT_LAYERS=""\n',
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Product 'fixture-product' has unexpected baseline adapter 'other.conf'",
            str(raised.exception),
        )

    def test_platform_adapter_cannot_be_orphaned(self):
        with registry_fixture() as root:
            (root / "platforms" / "fixture-platform" / "platform.conf").unlink()

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "has no platform declaration",
            str(raised.exception),
        )

    def test_duplicate_platform_adapter_keys_are_rejected_before_overwrite(self):
        with registry_fixture() as root:
            source = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            duplicate = source.with_name("aaa.conf")
            duplicate.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Duplicate platform adapter for 'fixture-platform' and baseline 'test'",
            str(raised.exception),
        )
        self.assertIn("adapter 'aaa.conf' declares 'test'", str(raised.exception))

    def test_product_adapter_cannot_be_orphaned(self):
        with registry_fixture() as root:
            (root / "products" / "fixture-product" / "product.conf").unlink()

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("has no product declaration", str(raised.exception))

    def test_duplicate_target_identifiers_are_rejected(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "targets"
                / "second-target.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'TARGET_ID="second-target"', 'TARGET_ID="fixture-target"'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("Duplicate target 'fixture-target'", str(raised.exception))

    def test_product_adapter_local_fragment_must_exist(self):
        with registry_fixture() as root:
            fragment = (
                root
                / "products"
                / "fixture-product"
                / "conf"
                / "local.conf.fragment"
            )
            fragment.unlink()

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("local fragment", str(raised.exception))
        self.assertIn("is missing", str(raised.exception))

    def test_duplicate_platform_identifiers_are_rejected(self):
        with registry_fixture() as root:
            destination = root / "platforms" / "other-platform" / "platform.conf"
            destination.parent.mkdir(parents=True)
            destination.write_text(
                'PLATFORM_ID="fixture-platform"\nPLATFORM_BASELINES="test"\n',
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("Duplicate platform 'fixture-platform'", str(raised.exception))

    def test_platform_must_declare_at_least_one_baseline(self):
        with registry_fixture() as root:
            path = root / "platforms" / "fixture-platform" / "platform.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'PLATFORM_BASELINES="test"', 'PLATFORM_BASELINES=""'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("PLATFORM_BASELINES is empty", str(raised.exception))

    def test_platform_references_only_known_baselines(self):
        with registry_fixture() as root:
            platform_path = root / "platforms" / "fixture-platform" / "platform.conf"
            platform_path.write_text(
                platform_path.read_text(encoding="utf-8").replace(
                    'PLATFORM_BASELINES="test"', 'PLATFORM_BASELINES="other"'
                ),
                encoding="utf-8",
            )
            adapter = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            adapter_destination = adapter.with_name("other.conf")
            adapter_destination.write_text(
                adapter.read_text(encoding="utf-8").replace(
                    'PLATFORM_BASELINE_ID="test"',
                    'PLATFORM_BASELINE_ID="other"',
                ),
                encoding="utf-8",
            )
            adapter.unlink()

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "Platform 'fixture-platform' references unknown baseline 'other'",
            str(raised.exception),
        )

    def test_platform_adapter_distro_cannot_be_empty(self):
        with registry_fixture() as root:
            path = (
                root
                / "platforms"
                / "fixture-platform"
                / "baselines"
                / "test.conf"
            )
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'PLATFORM_DISTRO="poky"', 'PLATFORM_DISTRO=""'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("has no PLATFORM_DISTRO", str(raised.exception))

    def test_product_must_declare_at_least_one_baseline(self):
        with registry_fixture() as root:
            path = root / "products" / "fixture-product" / "product.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'PRODUCT_BASELINES="test"', 'PRODUCT_BASELINES=""'
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("PRODUCT_BASELINES is empty", str(raised.exception))

    def test_baseline_must_declare_core_layers(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            contents = path.read_text(encoding="utf-8")
            start = contents.index('BASELINE_LAYERS="')
            path.write_text(
                contents[:start] + 'BASELINE_LAYERS=""\n',
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn("BASELINE_LAYERS is empty", str(raised.exception))

    def test_baseline_series_is_a_valid_identifier(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    'BASELINE_SERIES="test-series"',
                    'BASELINE_SERIES="bad series"',
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "BASELINE_SERIES has invalid identifier 'bad series'",
            str(raised.exception),
        )

    def test_baseline_oeroot_must_be_canonical(self):
        with registry_fixture() as root:
            path = root / "baselines" / "test" / "baseline.conf"
            path.write_text(
                path.read_text(encoding="utf-8").replace(
                    "components/layers/baselines/test/poky",
                    "components/layers/baselines/test/./poky",
                    1,
                ),
                encoding="utf-8",
            )

            with self.assertRaises(RegistryError) as raised:
                BuildRegistry.compile(root)

        self.assertIn(
            "BASELINE_OEROOT must be a canonical repository-relative path",
            str(raised.exception),
        )

    def test_listing_preserves_the_public_registry_format_and_order(self):
        registry = BuildRegistry.compile(FIXTURE_ROOT)

        self.assertEqual(
            "Baseline Profiles:\n"
            "  test         series=test-series  \n"
            "\n"
            "Targets:\n"
            "  fixture-target             machine=fixture-machine              "
            "baseline=test        support=Parse-Validated\n"
            "  second-target              machine=second-machine               "
            "baseline=test        support=Declared\n"
            "  fixture-product-target     machine=fixture-product-machine      "
            "baseline=test        support=Parse-Validated\n",
            registry.render_listing(),
        )

    def test_canonical_resolution_composes_the_selected_records(self):
        registry = BuildRegistry.compile(FIXTURE_ROOT)

        selection = registry.resolve(
            "fixture-product-target", mode="canonical"
        )

        self.assertEqual("fixture-product-machine", selection.target.machine)
        self.assertEqual("test-series", selection.baseline.series)
        self.assertEqual("poky", selection.platform_adapter.distro)
        self.assertEqual("fixture-product", selection.product.identifier)
        self.assertEqual(
            (
                "components/layers/baselines/test/poky/meta",
                "components/layers/baselines/test/poky/meta-poky",
                "components/layers/baselines/test/meta-openembedded/meta-oe",
                "platforms/fixture-platform/meta-fixture",
                "products/fixture-product/meta-fixture-product",
            ),
            selection.layers,
        )

    def test_profile_argument_is_an_assertion(self):
        registry = BuildRegistry.compile(FIXTURE_ROOT)

        with self.assertRaises(ResolutionError) as raised:
            registry.resolve("fixture-target", mode="canonical", profile="other")

        self.assertEqual(
            "Target 'fixture-target' binds to baseline 'test', not 'other'.",
            str(raised.exception),
        )

    def test_selection_protocol_is_versioned_and_preserves_layer_order(self):
        registry = BuildRegistry.compile(FIXTURE_ROOT)
        selection = registry.resolve(
            "fixture-product-target", mode="canonical"
        )

        self.assertEqual(
            "PROTOCOL=1\n"
            "TARGET_ID=fixture-product-target\n"
            "TARGET_MACHINE=fixture-product-machine\n"
            "TARGET_BASELINE=test\n"
            "TARGET_PLATFORM=fixture-platform\n"
            "TARGET_PRODUCT=fixture-product\n"
            "TARGET_SUPPORT_LEVEL=Parse-Validated\n"
            "TARGET_DEFAULT_IMAGE=fixture-image\n"
            "BASELINE_SERIES=test-series\n"
            "BASELINE_OEROOT=components/layers/baselines/test/poky\n"
            "BASELINE_LAYER=components/layers/baselines/test/poky/meta\n"
            "BASELINE_LAYER=components/layers/baselines/test/poky/meta-poky\n"
            "BASELINE_LAYER=components/layers/baselines/test/meta-openembedded/meta-oe\n"
            "PLATFORM_DISTRO=poky\n"
            "PLATFORM_LAYER=platforms/fixture-platform/meta-fixture\n"
            "PLATFORM_LOCAL_CONF=platforms/fixture-platform/conf/local.conf.fragment\n"
            "PRODUCT_LAYER=products/fixture-product/meta-fixture-product\n"
            "PRODUCT_LOCAL_CONF=products/fixture-product/conf/local.conf.fragment\n",
            selection.render_protocol(),
        )

    def test_validate_command_reports_success(self):
        stdout = StringIO()
        stderr = StringIO()

        status = main(
            ["--root", str(FIXTURE_ROOT), "validate"],
            stdout=stdout,
            stderr=stderr,
        )

        self.assertEqual(0, status)
        self.assertEqual("Registry validation: ok\n", stdout.getvalue())
        self.assertEqual("", stderr.getvalue())

    def test_list_command_writes_the_registry_listing(self):
        stdout = StringIO()
        stderr = StringIO()

        status = main(
            ["--root", str(FIXTURE_ROOT), "list"],
            stdout=stdout,
            stderr=stderr,
        )

        self.assertEqual(0, status)
        self.assertEqual(
            BuildRegistry.compile(FIXTURE_ROOT).render_listing(),
            stdout.getvalue(),
        )
        self.assertEqual("", stderr.getvalue())

    def test_resolve_command_writes_only_the_selection_protocol(self):
        stdout = StringIO()
        stderr = StringIO()

        status = main(
            [
                "--root",
                str(FIXTURE_ROOT),
                "resolve",
                "--mode",
                "compat",
                "--selector",
                "fixture-machine",
                "--profile",
                "test",
            ],
            stdout=stdout,
            stderr=stderr,
        )

        self.assertEqual(0, status)
        expected = BuildRegistry.compile(FIXTURE_ROOT).resolve(
            "fixture-machine", mode="compat", profile="test"
        )
        self.assertEqual(expected.render_protocol(), stdout.getvalue())
        self.assertEqual("", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
