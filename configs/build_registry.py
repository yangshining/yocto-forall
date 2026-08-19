"""Declarative Build Registry for the Yocto build framework."""

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import sys
from types import MappingProxyType
from typing import Dict, FrozenSet, Iterable, List, Mapping, Optional, TextIO, Tuple


_ASSIGNMENT = re.compile(r'^([A-Z][A-Z0-9_]*)="(.*)$')
_ASSIGNMENT_PREFIX = re.compile(r"^(?:export[ \t]+)?([A-Z][A-Z0-9_]*)=")
_CONTROL_CHARACTER = re.compile(r"[\x00-\x09\x0b\x0c\x0e-\x1f\x7f]")
_BASELINE_FIELDS = frozenset(
    {
        "BASELINE_DESCRIPTION",
        "BASELINE_ID",
        "BASELINE_LAYERS",
        "BASELINE_OEROOT",
        "BASELINE_SERIES",
    }
)
_BASELINE_REQUIRED_FIELDS = frozenset(
    {"BASELINE_ID", "BASELINE_LAYERS", "BASELINE_OEROOT", "BASELINE_SERIES"}
)
_PLATFORM_FIELDS = frozenset({"PLATFORM_BASELINES", "PLATFORM_ID"})
_PLATFORM_REQUIRED_FIELDS = _PLATFORM_FIELDS
_PLATFORM_ADAPTER_FIELDS = frozenset(
    {
        "PLATFORM_BASELINE_ID",
        "PLATFORM_DISTRO",
        "PLATFORM_LAYERS",
        "PLATFORM_LOCAL_CONF",
    }
)
_PLATFORM_ADAPTER_REQUIRED_FIELDS = frozenset(
    {"PLATFORM_BASELINE_ID", "PLATFORM_DISTRO"}
)
_PRODUCT_FIELDS = frozenset(
    {"PRODUCT_BASELINES", "PRODUCT_ID", "PRODUCT_PLATFORM"}
)
_PRODUCT_REQUIRED_FIELDS = _PRODUCT_FIELDS
_PRODUCT_ADAPTER_FIELDS = frozenset(
    {"PRODUCT_BASELINE_ID", "PRODUCT_LAYERS", "PRODUCT_LOCAL_CONF"}
)
_PRODUCT_ADAPTER_REQUIRED_FIELDS = frozenset({"PRODUCT_BASELINE_ID"})
_TARGET_FIELDS = frozenset(
    {
        "TARGET_ALIASES",
        "TARGET_BASELINE",
        "TARGET_DEFAULT_IMAGE",
        "TARGET_ID",
        "TARGET_MACHINE",
        "TARGET_PLATFORM",
        "TARGET_PRODUCT",
        "TARGET_SUPPORT_LEVEL",
    }
)
_TARGET_REQUIRED_FIELDS = frozenset(
    {
        "TARGET_BASELINE",
        "TARGET_DEFAULT_IMAGE",
        "TARGET_ID",
        "TARGET_MACHINE",
        "TARGET_PLATFORM",
        "TARGET_SUPPORT_LEVEL",
    }
)
_SUPPORT_LEVELS = frozenset(
    {
        "Declared",
        "Parse-Validated",
        "Build-Validated",
        "Boot-Validated",
        "Production-Supported",
    }
)


@dataclass(frozen=True)
class RegistryIssue:
    path: str
    field: Optional[str]
    code: str
    message: str


class RegistryError(Exception):
    def __init__(self, issues: Iterable[RegistryIssue]):
        self.issues = tuple(
            sorted(
                issues,
                key=lambda issue: (
                    issue.path,
                    issue.field or "",
                    issue.code,
                    issue.message,
                ),
            )
        )
        super().__init__(self._render())

    def _render(self) -> str:
        rendered = ["Build Registry validation failed:"]
        for issue in self.issues:
            location = issue.path
            if issue.field is not None:
                location += ":" + issue.field
            rendered.append("  {} [{}] {}".format(location, issue.code, issue.message))
        return "\n".join(rendered)


class ResolutionError(Exception):
    pass


@dataclass(frozen=True)
class Baseline:
    identifier: str
    series: str
    description: str
    oeroot: str
    layers: Tuple[str, ...]
    path: str


@dataclass(frozen=True)
class Platform:
    identifier: str
    baselines: Tuple[str, ...]
    path: str


@dataclass(frozen=True)
class PlatformAdapter:
    platform: str
    baseline: str
    distro: str
    layers: Tuple[str, ...]
    local_conf: Optional[str]
    path: str


@dataclass(frozen=True)
class Product:
    identifier: str
    platform: str
    baselines: Tuple[str, ...]
    path: str


@dataclass(frozen=True)
class ProductAdapter:
    product: str
    baseline: str
    layers: Tuple[str, ...]
    local_conf: Optional[str]
    path: str


@dataclass(frozen=True)
class Target:
    identifier: str
    machine: str
    aliases: Tuple[str, ...]
    platform: str
    product: Optional[str]
    baseline: str
    support_level: str
    default_image: str
    path: str


@dataclass(frozen=True)
class Selection:
    target: Target
    baseline: Baseline
    platform: Platform
    platform_adapter: PlatformAdapter
    product: Optional[Product]
    product_adapter: Optional[ProductAdapter]

    @property
    def layers(self) -> Tuple[str, ...]:
        product_layers = ()
        if self.product_adapter is not None:
            product_layers = self.product_adapter.layers
        return self.baseline.layers + self.platform_adapter.layers + product_layers

    def render_protocol(self) -> str:
        product_id = ""
        product_layers: Tuple[str, ...] = ()
        product_local_conf = ""
        if self.product is not None:
            product_id = self.product.identifier
        if self.product_adapter is not None:
            product_layers = self.product_adapter.layers
            product_local_conf = self.product_adapter.local_conf or ""

        lines = [
            "PROTOCOL=1",
            "TARGET_ID={}".format(self.target.identifier),
            "TARGET_MACHINE={}".format(self.target.machine),
            "TARGET_BASELINE={}".format(self.target.baseline),
            "TARGET_PLATFORM={}".format(self.target.platform),
            "TARGET_PRODUCT={}".format(product_id),
            "TARGET_SUPPORT_LEVEL={}".format(self.target.support_level),
            "TARGET_DEFAULT_IMAGE={}".format(self.target.default_image),
            "BASELINE_SERIES={}".format(self.baseline.series),
            "BASELINE_OEROOT={}".format(self.baseline.oeroot),
        ]
        lines.extend("BASELINE_LAYER={}".format(layer) for layer in self.baseline.layers)
        lines.append("PLATFORM_DISTRO={}".format(self.platform_adapter.distro))
        lines.extend(
            "PLATFORM_LAYER={}".format(layer)
            for layer in self.platform_adapter.layers
        )
        lines.append(
            "PLATFORM_LOCAL_CONF={}".format(
                self.platform_adapter.local_conf or ""
            )
        )
        lines.extend("PRODUCT_LAYER={}".format(layer) for layer in product_layers)
        lines.append("PRODUCT_LOCAL_CONF={}".format(product_local_conf))
        return "\n".join(lines) + "\n"


@dataclass(frozen=True)
class BuildRegistry:
    baselines: Mapping[str, Baseline]
    platforms: Mapping[str, Platform]
    platform_adapters: Mapping[Tuple[str, str], PlatformAdapter]
    products: Mapping[str, Product]
    product_adapters: Mapping[Tuple[str, str], ProductAdapter]
    targets: Mapping[str, Target]
    selectors: Mapping[str, Target]

    def render_listing(self) -> str:
        lines = ["Baseline Profiles:"]
        for baseline in sorted(self.baselines.values(), key=lambda record: record.path):
            lines.append(
                "  {:<12} series={:<12} {}".format(
                    baseline.identifier, baseline.series, baseline.description
                )
            )
        lines.extend(("", "Targets:"))
        for target in sorted(self.targets.values(), key=lambda record: record.path):
            lines.append(
                "  {:<26} machine={:<28} baseline={:<11} support={}".format(
                    target.identifier,
                    target.machine,
                    target.baseline,
                    target.support_level,
                )
            )
        return "\n".join(lines) + "\n"

    def resolve(
        self, selector: str, mode: str, profile: Optional[str] = None
    ) -> Selection:
        if mode == "canonical":
            target = self.targets.get(selector)
        elif mode == "compat":
            target = self.selectors.get(selector)
        else:
            raise ValueError("unknown resolution mode: {}".format(mode))
        if target is None:
            raise ResolutionError(
                "Unknown target or machine '{}'. Use -l to list targets.".format(
                    selector
                )
            )
        if profile is not None and profile != target.baseline:
            raise ResolutionError(
                "Target '{}' binds to baseline '{}', not '{}'.".format(
                    target.identifier, target.baseline, profile
                )
            )

        baseline = self.baselines[target.baseline]
        platform = self.platforms[target.platform]
        platform_adapter = self.platform_adapters[
            (target.platform, target.baseline)
        ]
        product = None
        product_adapter = None
        if target.product is not None:
            product = self.products[target.product]
            product_adapter = self.product_adapters[
                (target.product, target.baseline)
            ]
        return Selection(
            target=target,
            baseline=baseline,
            platform=platform,
            platform_adapter=platform_adapter,
            product=product,
            product_adapter=product_adapter,
        )

    @classmethod
    def compile(cls, root: Path) -> "BuildRegistry":
        issues: List[RegistryIssue] = []
        baselines: Dict[str, Baseline] = {}
        baseline_paths = sorted(root.glob("baselines/*/baseline.conf"))
        discovered_baseline_ids = {path.parent.name for path in baseline_paths}
        for path in baseline_paths:
            values = _parse_record(
                root,
                path,
                _BASELINE_FIELDS,
                _BASELINE_REQUIRED_FIELDS,
                {"BASELINE_LAYERS"},
                issues,
            )
            if values is None:
                continue
            baseline = Baseline(
                identifier=values["BASELINE_ID"],
                series=values["BASELINE_SERIES"],
                description=values.get("BASELINE_DESCRIPTION", ""),
                oeroot=values["BASELINE_OEROOT"],
                layers=tuple(values["BASELINE_LAYERS"].split()),
                path=path.relative_to(root).as_posix(),
            )
            if baseline.identifier in baselines:
                issues.append(
                    RegistryIssue(
                        path=baseline.path,
                        field="BASELINE_ID",
                        code="duplicate-baseline",
                        message="Duplicate baseline '{}'".format(
                            baseline.identifier
                        ),
                    )
                )
                continue
            baselines[baseline.identifier] = baseline

        platforms: Dict[str, Platform] = {}
        platform_paths = sorted(root.glob("platforms/*/platform.conf"))
        discovered_platform_ids = {path.parent.name for path in platform_paths}
        for path in platform_paths:
            values = _parse_record(
                root,
                path,
                _PLATFORM_FIELDS,
                _PLATFORM_REQUIRED_FIELDS,
                {"PLATFORM_BASELINES"},
                issues,
            )
            if values is None:
                continue
            platform = Platform(
                identifier=values["PLATFORM_ID"],
                baselines=tuple(values["PLATFORM_BASELINES"].split()),
                path=path.relative_to(root).as_posix(),
            )
            if platform.identifier in platforms:
                issues.append(
                    RegistryIssue(
                        path=platform.path,
                        field="PLATFORM_ID",
                        code="duplicate-platform",
                        message="Duplicate platform '{}'".format(
                            platform.identifier
                        ),
                    )
                )
                continue
            platforms[platform.identifier] = platform

        platform_adapters: Dict[Tuple[str, str], PlatformAdapter] = {}
        for path in sorted(root.glob("platforms/*/baselines/*.conf")):
            values = _parse_record(
                root,
                path,
                _PLATFORM_ADAPTER_FIELDS,
                _PLATFORM_ADAPTER_REQUIRED_FIELDS,
                {"PLATFORM_LAYERS"},
                issues,
            )
            if values is None:
                continue
            adapter = PlatformAdapter(
                platform=path.parent.parent.name,
                baseline=values["PLATFORM_BASELINE_ID"],
                distro=values["PLATFORM_DISTRO"],
                layers=tuple(values.get("PLATFORM_LAYERS", "").split()),
                local_conf=values.get("PLATFORM_LOCAL_CONF") or None,
                path=path.relative_to(root).as_posix(),
            )
            adapter_key = (adapter.platform, adapter.baseline)
            if adapter_key in platform_adapters:
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PLATFORM_BASELINE_ID",
                        code="duplicate-platform-adapter",
                        message=(
                            "Duplicate platform adapter for '{}' and baseline "
                            "'{}'".format(adapter.platform, adapter.baseline)
                        ),
                    )
                )
                continue
            platform_adapters[adapter_key] = adapter

        products: Dict[str, Product] = {}
        product_paths = sorted(root.glob("products/*/product.conf"))
        discovered_product_ids = {path.parent.name for path in product_paths}
        for path in product_paths:
            values = _parse_record(
                root,
                path,
                _PRODUCT_FIELDS,
                _PRODUCT_REQUIRED_FIELDS,
                {"PRODUCT_BASELINES"},
                issues,
            )
            if values is None:
                continue
            product = Product(
                identifier=values["PRODUCT_ID"],
                platform=values["PRODUCT_PLATFORM"],
                baselines=tuple(values["PRODUCT_BASELINES"].split()),
                path=path.relative_to(root).as_posix(),
            )
            if product.identifier in products:
                issues.append(
                    RegistryIssue(
                        path=product.path,
                        field="PRODUCT_ID",
                        code="duplicate-product",
                        message="Duplicate product '{}'".format(
                            product.identifier
                        ),
                    )
                )
                continue
            products[product.identifier] = product

        product_adapters: Dict[Tuple[str, str], ProductAdapter] = {}
        for path in sorted(root.glob("products/*/baselines/*.conf")):
            values = _parse_record(
                root,
                path,
                _PRODUCT_ADAPTER_FIELDS,
                _PRODUCT_ADAPTER_REQUIRED_FIELDS,
                {"PRODUCT_LAYERS"},
                issues,
            )
            if values is None:
                continue
            adapter = ProductAdapter(
                product=path.parent.parent.name,
                baseline=values["PRODUCT_BASELINE_ID"],
                layers=tuple(values.get("PRODUCT_LAYERS", "").split()),
                local_conf=values.get("PRODUCT_LOCAL_CONF") or None,
                path=path.relative_to(root).as_posix(),
            )
            adapter_key = (adapter.product, adapter.baseline)
            if adapter_key in product_adapters:
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PRODUCT_BASELINE_ID",
                        code="duplicate-product-adapter",
                        message=(
                            "Duplicate product adapter for '{}' and baseline "
                            "'{}'".format(adapter.product, adapter.baseline)
                        ),
                    )
                )
                continue
            product_adapters[adapter_key] = adapter

        targets: Dict[str, Target] = {}
        target_paths = list(root.glob("platforms/*/targets/*.conf"))
        target_paths.extend(root.glob("products/*/targets/*.conf"))
        for path in sorted(target_paths):
            values = _parse_record(
                root,
                path,
                _TARGET_FIELDS,
                _TARGET_REQUIRED_FIELDS,
                {"TARGET_ALIASES"},
                issues,
            )
            if values is None:
                continue
            target = Target(
                identifier=values["TARGET_ID"],
                machine=values["TARGET_MACHINE"],
                aliases=tuple(values.get("TARGET_ALIASES", "").split()),
                platform=values["TARGET_PLATFORM"],
                product=values.get("TARGET_PRODUCT") or None,
                baseline=values["TARGET_BASELINE"],
                support_level=values["TARGET_SUPPORT_LEVEL"],
                default_image=values["TARGET_DEFAULT_IMAGE"],
                path=path.relative_to(root).as_posix(),
            )
            if target.identifier in targets:
                issues.append(
                    RegistryIssue(
                        path=target.path,
                        field="TARGET_ID",
                        code="duplicate-target",
                        message="Duplicate target '{}'".format(target.identifier),
                    )
                )
                continue
            targets[target.identifier] = target

        if not baseline_paths:
            issues.append(
                RegistryIssue(
                    path="baselines",
                    field=None,
                    code="no-baselines",
                    message="no Baseline Profiles found under baselines/",
                )
            )
        if not target_paths:
            issues.append(
                RegistryIssue(
                    path="platforms,products",
                    field=None,
                    code="no-targets",
                    message="no targets found under platforms/ or products/",
                )
            )
        for baseline in baselines.values():
            for field, value in (
                ("BASELINE_ID", baseline.identifier),
                ("BASELINE_SERIES", baseline.series),
            ):
                if not _is_identifier(value):
                    issues.append(
                        RegistryIssue(
                            path=baseline.path,
                            field=field,
                            code="invalid-identifier",
                            message="{} has invalid identifier '{}'".format(
                                field, value
                            ),
                        )
                    )
            expected = Path(baseline.path).parent.name
            if baseline.identifier != expected:
                issues.append(
                    RegistryIssue(
                        path=baseline.path,
                        field="BASELINE_ID",
                        code="owner-id-mismatch",
                        message=(
                            "Baseline directory '{}' declares BASELINE_ID '{}'".format(
                                expected, baseline.identifier
                            )
                        ),
                    )
                )
            expected_prefix = "components/layers/baselines/{}/".format(
                baseline.identifier
            )
            if not _is_canonical_relative_path(baseline.oeroot):
                issues.append(
                    RegistryIssue(
                        path=baseline.path,
                        field="BASELINE_OEROOT",
                        code="noncanonical-path",
                        message=(
                            "BASELINE_OEROOT must be a canonical "
                            "repository-relative path, got '{}'".format(
                                baseline.oeroot
                            )
                        ),
                    )
                )
            if not baseline.oeroot.startswith(expected_prefix):
                issues.append(
                    RegistryIssue(
                        path=baseline.path,
                        field="BASELINE_OEROOT",
                        code="baseline-oeroot-owner",
                        message=(
                            "Baseline '{}' OEROOT must live under {}".format(
                                baseline.identifier, expected_prefix
                            )
                        ),
                    )
                )
            if not baseline.layers:
                issues.append(
                    RegistryIssue(
                        path=baseline.path,
                        field="BASELINE_LAYERS",
                        code="empty-baseline-layers",
                        message="BASELINE_LAYERS is empty",
                    )
                )
            for layer in baseline.layers:
                if not _is_canonical_relative_path(layer):
                    issues.append(
                        RegistryIssue(
                            path=baseline.path,
                            field="BASELINE_LAYERS",
                            code="noncanonical-path",
                            message=(
                                "BASELINE_LAYERS must be a canonical "
                                "repository-relative path, got '{}'".format(layer)
                            ),
                        )
                    )
                    continue
                if not layer.startswith(expected_prefix):
                    issues.append(
                        RegistryIssue(
                            path=baseline.path,
                            field="BASELINE_LAYERS",
                            code="baseline-layer-owner",
                            message=(
                                "Baseline '{}' core layer '{}' is outside its "
                                "profile directory".format(
                                    baseline.identifier, layer
                                )
                            ),
                        )
                    )
        for adapter in platform_adapters.values():
            if not _is_identifier(adapter.baseline):
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PLATFORM_BASELINE_ID",
                        code="invalid-identifier",
                        message=(
                            "PLATFORM_BASELINE_ID has invalid identifier '{}'".format(
                                adapter.baseline
                            )
                        ),
                    )
                )
            if not adapter.distro:
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PLATFORM_DISTRO",
                        code="empty-platform-distro",
                        message=(
                            "Platform '{}' adapter '{}' has no PLATFORM_DISTRO".format(
                                adapter.platform, Path(adapter.path).name
                            )
                        ),
                    )
                )
            for layer in adapter.layers:
                if not _is_canonical_relative_path(layer):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PLATFORM_LAYERS",
                            code="noncanonical-path",
                            message=(
                                "PLATFORM_LAYERS must be a canonical "
                                "repository-relative path, got '{}'".format(layer)
                            ),
                        )
                    )
                    continue
                if layer.startswith("products/"):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PLATFORM_LAYERS",
                            code="platform-product-layer",
                            message=(
                                "Platform '{}' adapter '{}' must not reference "
                                "product layer '{}'".format(
                                    adapter.platform,
                                    Path(adapter.path).name,
                                    layer,
                                )
                            ),
                        )
                    )
                if layer.startswith("platforms/"):
                    layer_owner = layer.split("/", 2)[1]
                    if layer_owner != adapter.platform:
                        issues.append(
                            RegistryIssue(
                                path=adapter.path,
                                field="PLATFORM_LAYERS",
                                code="platform-layer-owner",
                                message=(
                                    "Platform '{}' adapter '{}' must not reference "
                                    "layer owned by platform '{}': '{}'".format(
                                        adapter.platform,
                                        Path(adapter.path).name,
                                        layer_owner,
                                        layer,
                                    )
                                ),
                            )
                        )
                if layer.startswith("components/layers/baselines/") and not layer.startswith(
                    "components/layers/baselines/{}/".format(adapter.baseline)
                ):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PLATFORM_LAYERS",
                            code="cross-baseline-layer",
                            message=(
                                "Platform '{}' adapter crosses from baseline '{}' "
                                "to layer '{}'".format(
                                    adapter.platform, adapter.baseline, layer
                                )
                            ),
                        )
                    )
            if adapter.local_conf is not None:
                if not _is_canonical_relative_path(adapter.local_conf):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PLATFORM_LOCAL_CONF",
                            code="noncanonical-path",
                            message=(
                                "PLATFORM_LOCAL_CONF must be a canonical "
                                "repository-relative path, got '{}'".format(
                                    adapter.local_conf
                                )
                            ),
                        )
                    )
                elif adapter.local_conf.startswith("products/"):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PLATFORM_LOCAL_CONF",
                            code="platform-product-fragment",
                            message=(
                                "Platform '{}' adapter '{}' must not reference "
                                "product fragment '{}'".format(
                                    adapter.platform,
                                    Path(adapter.path).name,
                                    adapter.local_conf,
                                )
                            ),
                        )
                    )
                elif adapter.local_conf.startswith("platforms/"):
                    fragment_owner = adapter.local_conf.split("/", 2)[1]
                    if fragment_owner != adapter.platform:
                        issues.append(
                            RegistryIssue(
                                path=adapter.path,
                                field="PLATFORM_LOCAL_CONF",
                                code="platform-fragment-owner",
                                message=(
                                    "Platform '{}' adapter '{}' must not reference "
                                    "fragment owned by platform '{}': '{}'".format(
                                        adapter.platform,
                                        Path(adapter.path).name,
                                        fragment_owner,
                                        adapter.local_conf,
                                    )
                                ),
                            )
                        )
                if _is_canonical_relative_path(adapter.local_conf) and not (
                    root / adapter.local_conf
                ).is_file():
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PLATFORM_LOCAL_CONF",
                            code="missing-platform-fragment",
                            message=(
                                "Platform '{}' local fragment '{}' is missing".format(
                                    adapter.platform, adapter.local_conf
                                )
                            ),
                        )
                    )
            platform = platforms.get(adapter.platform)
            if (
                platform is None
                and adapter.platform not in discovered_platform_ids
            ):
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field=None,
                        code="orphan-platform-adapter",
                        message=(
                            "Platform adapter '{}' has no platform declaration".format(
                                adapter.path
                            )
                        ),
                    )
                )
            filename_baseline = Path(adapter.path).stem
            if adapter.baseline != filename_baseline:
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PLATFORM_BASELINE_ID",
                        code="adapter-baseline-mismatch",
                        message=(
                            "Platform '{}' adapter '{}' declares '{}'".format(
                                adapter.platform,
                                Path(adapter.path).name,
                                adapter.baseline,
                            )
                        ),
                    )
                )
            if (
                platform is not None
                and platform.baselines
                and filename_baseline not in platform.baselines
            ):
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PLATFORM_BASELINE_ID",
                        code="unexpected-platform-adapter",
                        message=(
                            "Platform '{}' has unexpected baseline adapter "
                            "'{}'".format(
                                adapter.platform, Path(adapter.path).name
                            )
                        ),
                    )
                )
        for platform in platforms.values():
            for field, value in (("PLATFORM_ID", platform.identifier),) + tuple(
                ("PLATFORM_BASELINES", baseline_id)
                for baseline_id in platform.baselines
            ):
                if not _is_identifier(value):
                    issues.append(
                        RegistryIssue(
                            path=platform.path,
                            field=field,
                            code="invalid-identifier",
                            message="{} has invalid identifier '{}'".format(
                                field, value
                            ),
                        )
                    )
            owner = Path(platform.path).parent.name
            if platform.identifier != owner:
                issues.append(
                    RegistryIssue(
                        path=platform.path,
                        field="PLATFORM_ID",
                        code="owner-id-mismatch",
                        message=(
                            "Platform directory '{}' declares PLATFORM_ID '{}'".format(
                                owner, platform.identifier
                            )
                        ),
                    )
                )
                continue
            if not platform.baselines:
                issues.append(
                    RegistryIssue(
                        path=platform.path,
                        field="PLATFORM_BASELINES",
                        code="empty-platform-baselines",
                        message="PLATFORM_BASELINES is empty",
                    )
                )
                continue
            for baseline_id in platform.baselines:
                if (
                    baseline_id not in baselines
                    and baseline_id not in discovered_baseline_ids
                ):
                    issues.append(
                        RegistryIssue(
                            path=platform.path,
                            field="PLATFORM_BASELINES",
                            code="unknown-platform-baseline",
                            message=(
                                "Platform '{}' references unknown baseline '{}'".format(
                                    platform.identifier, baseline_id
                                )
                            ),
                        )
                    )
                has_adapter = any(
                    adapter.platform == platform.identifier
                    and Path(adapter.path).stem == baseline_id
                    for adapter in platform_adapters.values()
                )
                if not has_adapter:
                    issues.append(
                        RegistryIssue(
                            path=platform.path,
                            field="PLATFORM_BASELINES",
                            code="missing-platform-adapter",
                            message=(
                                "Platform '{}' is missing baseline adapter "
                                "'{}.conf'".format(
                                    platform.identifier, baseline_id
                                )
                            ),
                        )
                    )
        for adapter in product_adapters.values():
            expected_prefix = "products/{}/".format(adapter.product)
            if not _is_identifier(adapter.baseline):
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PRODUCT_BASELINE_ID",
                        code="invalid-identifier",
                        message=(
                            "PRODUCT_BASELINE_ID has invalid identifier '{}'".format(
                                adapter.baseline
                            )
                        ),
                    )
                )
            filename_baseline = Path(adapter.path).stem
            if adapter.baseline != filename_baseline:
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PRODUCT_BASELINE_ID",
                        code="adapter-baseline-mismatch",
                        message=(
                            "Product '{}' adapter '{}' declares '{}'".format(
                                adapter.product,
                                Path(adapter.path).name,
                                adapter.baseline,
                            )
                        ),
                    )
                )
            product = products.get(adapter.product)
            if product is None and adapter.product not in discovered_product_ids:
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field=None,
                        code="orphan-product-adapter",
                        message=(
                            "Product adapter '{}' has no product declaration".format(
                                adapter.path
                            )
                        ),
                    )
                )
            if (
                product is not None
                and product.baselines
                and filename_baseline not in product.baselines
            ):
                issues.append(
                    RegistryIssue(
                        path=adapter.path,
                        field="PRODUCT_BASELINE_ID",
                        code="unexpected-product-adapter",
                        message=(
                            "Product '{}' has unexpected baseline adapter '{}'".format(
                                adapter.product, Path(adapter.path).name
                            )
                        ),
                    )
                )
            for layer in adapter.layers:
                if not _is_canonical_relative_path(layer):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PRODUCT_LAYERS",
                            code="noncanonical-path",
                            message=(
                                "PRODUCT_LAYERS must be a canonical "
                                "repository-relative path, got '{}'".format(layer)
                            ),
                        )
                    )
                    continue
                if not layer.startswith(expected_prefix):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PRODUCT_LAYERS",
                            code="product-layer-owner",
                            message=(
                                "Product '{}' must own layer paths under {}, "
                                "got '{}'".format(
                                    adapter.product, expected_prefix, layer
                                )
                            ),
                        )
                    )
            if adapter.local_conf is not None:
                if not _is_canonical_relative_path(adapter.local_conf):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PRODUCT_LOCAL_CONF",
                            code="noncanonical-path",
                            message=(
                                "PRODUCT_LOCAL_CONF must be a canonical "
                                "repository-relative path, got '{}'".format(
                                    adapter.local_conf
                                )
                            ),
                        )
                    )
                elif not adapter.local_conf.startswith(expected_prefix):
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PRODUCT_LOCAL_CONF",
                            code="product-fragment-owner",
                            message=(
                                "Product '{}' must own its local fragment under "
                                "{}, got '{}'".format(
                                    adapter.product,
                                    expected_prefix,
                                    adapter.local_conf,
                                )
                            ),
                        )
                    )
                if _is_canonical_relative_path(adapter.local_conf) and not (
                    root / adapter.local_conf
                ).is_file():
                    issues.append(
                        RegistryIssue(
                            path=adapter.path,
                            field="PRODUCT_LOCAL_CONF",
                            code="missing-product-fragment",
                            message=(
                                "Product '{}' local fragment '{}' is missing".format(
                                    adapter.product, adapter.local_conf
                                )
                            ),
                        )
                    )
        for product in products.values():
            product_identifiers = (
                ("PRODUCT_ID", product.identifier),
                ("PRODUCT_PLATFORM", product.platform),
            ) + tuple(
                ("PRODUCT_BASELINES", baseline_id)
                for baseline_id in product.baselines
            )
            for field, value in product_identifiers:
                if not _is_identifier(value):
                    issues.append(
                        RegistryIssue(
                            path=product.path,
                            field=field,
                            code="invalid-identifier",
                            message="{} has invalid identifier '{}'".format(
                                field, value
                            ),
                        )
                    )
            owner = Path(product.path).parent.name
            if product.identifier != owner:
                issues.append(
                    RegistryIssue(
                        path=product.path,
                        field="PRODUCT_ID",
                        code="owner-id-mismatch",
                        message=(
                            "Product directory '{}' declares PRODUCT_ID '{}'".format(
                                owner, product.identifier
                            )
                        ),
                    )
                )
                continue
            if not product.baselines:
                issues.append(
                    RegistryIssue(
                        path=product.path,
                        field="PRODUCT_BASELINES",
                        code="empty-product-baselines",
                        message="PRODUCT_BASELINES is empty",
                    )
                )
                continue
            if (
                product.platform not in platforms
                and product.platform not in discovered_platform_ids
            ):
                issues.append(
                    RegistryIssue(
                        path=product.path,
                        field="PRODUCT_PLATFORM",
                        code="unknown-product-platform",
                        message=(
                            "Product '{}' references unknown platform '{}'".format(
                                product.identifier, product.platform
                            )
                        ),
                    )
                )
            platform = platforms.get(product.platform)
            for baseline_id in product.baselines:
                if (
                    platform is not None
                    and platform.baselines
                    and baseline_id not in platform.baselines
                ):
                    issues.append(
                        RegistryIssue(
                            path=product.path,
                            field="PRODUCT_BASELINES",
                            code="unsupported-product-baseline",
                            message=(
                                "Product '{}' binds platform '{}' to unsupported "
                                "baseline '{}'".format(
                                    product.identifier,
                                    product.platform,
                                    baseline_id,
                                )
                            ),
                        )
                    )
                has_adapter = any(
                    adapter.product == product.identifier
                    and Path(adapter.path).stem == baseline_id
                    for adapter in product_adapters.values()
                )
                if not has_adapter:
                    issues.append(
                        RegistryIssue(
                            path=product.path,
                            field="PRODUCT_BASELINES",
                            code="missing-product-adapter",
                            message=(
                                "Product '{}' is missing baseline adapter "
                                "'{}.conf'".format(
                                    product.identifier, baseline_id
                                )
                            ),
                        )
                    )
        for target in targets.values():
            path_parts = Path(target.path).parts
            identifier_fields = (
                ("TARGET_ID", target.identifier),
                ("TARGET_MACHINE", target.machine),
                ("TARGET_PLATFORM", target.platform),
                ("TARGET_BASELINE", target.baseline),
            )
            if target.product is not None:
                identifier_fields += (("TARGET_PRODUCT", target.product),)
            identifier_fields += tuple(
                ("TARGET_ALIASES", alias) for alias in target.aliases
            )
            for field, value in identifier_fields:
                if not _is_identifier(value):
                    issues.append(
                        RegistryIssue(
                            path=target.path,
                            field=field,
                            code="invalid-identifier",
                            message=(
                                "{} has invalid identifier '{}'".format(
                                    field, value
                                )
                            ),
                        )
                    )
            if not target.default_image:
                issues.append(
                    RegistryIssue(
                        path=target.path,
                        field="TARGET_DEFAULT_IMAGE",
                        code="empty-target-image",
                        message="TARGET_DEFAULT_IMAGE is empty",
                    )
                )
            filename_id = Path(target.path).stem
            if target.identifier != filename_id:
                issues.append(
                    RegistryIssue(
                        path=target.path,
                        field="TARGET_ID",
                        code="target-filename-mismatch",
                        message=(
                            "Target file '{}.conf' declares TARGET_ID '{}'".format(
                                filename_id, target.identifier
                            )
                        ),
                    )
                )
            if (
                target.baseline not in baselines
                and target.baseline not in discovered_baseline_ids
            ):
                issues.append(
                    RegistryIssue(
                        path=target.path,
                        field="TARGET_BASELINE",
                        code="unknown-target-baseline",
                        message=(
                            "Target '{}' references unknown baseline '{}'".format(
                                target.identifier, target.baseline
                            )
                        ),
                    )
                )
            target_platform = platforms.get(target.platform)
            if (
                target_platform is None
                and target.platform not in discovered_platform_ids
            ):
                issues.append(
                    RegistryIssue(
                        path=target.path,
                        field="TARGET_PLATFORM",
                        code="unknown-target-platform",
                        message=(
                            "Target '{}' references unknown platform '{}'".format(
                                target.identifier, target.platform
                            )
                        ),
                    )
                )
            if (
                target_platform is not None
                and target_platform.baselines
                and target.baseline in baselines
                and target.baseline not in target_platform.baselines
            ):
                issues.append(
                    RegistryIssue(
                        path=target.path,
                        field="TARGET_BASELINE",
                        code="unsupported-target-baseline",
                        message=(
                            "Target '{}' binds platform '{}' to unsupported "
                            "baseline '{}'".format(
                                target.identifier,
                                target.platform,
                                target.baseline,
                            )
                        ),
                    )
                )
            if target.support_level not in _SUPPORT_LEVELS:
                issues.append(
                    RegistryIssue(
                        path=target.path,
                        field="TARGET_SUPPORT_LEVEL",
                        code="invalid-support-level",
                        message=(
                            "Invalid TARGET_SUPPORT_LEVEL '{}'".format(
                                target.support_level
                            )
                        ),
                    )
                )
            if (
                target.support_level == "Production-Supported"
                and target.product is None
            ):
                issues.append(
                    RegistryIssue(
                        path=target.path,
                        field="TARGET_PRODUCT",
                        code="production-target-product",
                        message=(
                            "Target '{}' cannot be Production-Supported without "
                            "TARGET_PRODUCT".format(target.identifier)
                        ),
                    )
                )
            if target.product is not None:
                target_product = products.get(target.product)
                if (
                    target_product is None
                    and target.product not in discovered_product_ids
                ):
                    issues.append(
                        RegistryIssue(
                            path=target.path,
                            field="TARGET_PRODUCT",
                            code="unknown-target-product",
                            message=(
                                "Target '{}' references unknown product '{}'".format(
                                    target.identifier, target.product
                                )
                            ),
                        )
                    )
                elif target_product is not None:
                    if target_product.platform != target.platform:
                        issues.append(
                            RegistryIssue(
                                path=target.path,
                                field="TARGET_PLATFORM",
                                code="target-product-platform",
                                message=(
                                    "Product '{}' uses platform '{}', target uses "
                                    "'{}'".format(
                                        target.product,
                                        target_product.platform,
                                        target.platform,
                                    )
                                ),
                            )
                        )
                    if (
                        target.baseline in baselines
                        and target_product.baselines
                        and target.baseline not in target_product.baselines
                    ):
                        issues.append(
                            RegistryIssue(
                                path=target.path,
                                field="TARGET_BASELINE",
                                code="unsupported-target-product-baseline",
                                message=(
                                    "Product '{}' does not support baseline '{}'".format(
                                        target.product, target.baseline
                                    )
                                ),
                            )
                        )
            if path_parts[0] == "platforms":
                owner = path_parts[1]
                if target.platform != owner:
                    issues.append(
                        RegistryIssue(
                            path=target.path,
                            field="TARGET_PLATFORM",
                            code="target-platform-owner",
                            message=(
                                "Target '{}' is under platform '{}' but declares "
                                "TARGET_PLATFORM '{}'".format(
                                    target.identifier, owner, target.platform
                                )
                            ),
                        )
                    )
                if target.product is not None:
                    issues.append(
                        RegistryIssue(
                            path=target.path,
                            field="TARGET_PRODUCT",
                            code="platform-target-product",
                            message=(
                                "Platform target '{}' must not declare "
                                "TARGET_PRODUCT".format(target.identifier)
                            ),
                        )
                    )
            elif path_parts[0] == "products":
                owner = path_parts[1]
                if target.product is None:
                    issues.append(
                        RegistryIssue(
                            path=target.path,
                            field="TARGET_PRODUCT",
                            code="missing-target-product-owner",
                            message=(
                                "Product target '{}' under products/{}/ must "
                                "declare TARGET_PRODUCT".format(
                                    target.identifier, owner
                                )
                            ),
                        )
                    )
                elif target.product != owner:
                    issues.append(
                        RegistryIssue(
                            path=target.path,
                            field="TARGET_PRODUCT",
                            code="target-product-owner",
                            message=(
                                "Target '{}' is under product '{}' but declares "
                                "TARGET_PRODUCT '{}'".format(
                                    target.identifier, owner, target.product
                                )
                            ),
                        )
                    )
        selectors: Dict[str, Target] = {}
        for target in sorted(targets.values(), key=lambda record: record.path):
            target_selectors = set()
            for selector in (target.identifier, target.machine) + target.aliases:
                if selector in target_selectors:
                    continue
                target_selectors.add(selector)
                existing = selectors.get(selector)
                if existing is not None and existing.identifier != target.identifier:
                    issues.append(
                        RegistryIssue(
                            path=target.path,
                            field="TARGET_ALIASES",
                            code="duplicate-selector",
                            message=(
                                "Target selector '{}' is owned by more than one "
                                "target".format(selector)
                            ),
                        )
                    )
                    continue
                selectors[selector] = target
        gitlink_paths = _gitmodule_paths(root)
        integration_claims: Dict[str, Tuple[str, str]] = {}
        adapters_with_layers = []
        adapters_with_layers.extend(
            (adapter.path, adapter.baseline, adapter.layers)
            for adapter in platform_adapters.values()
        )
        adapters_with_layers.extend(
            (adapter.path, adapter.baseline, adapter.layers)
            for adapter in product_adapters.values()
        )
        for adapter_path, baseline_id, layers in sorted(adapters_with_layers):
            for layer in layers:
                if not _is_canonical_relative_path(layer):
                    continue
                integration_source = _integration_source(layer, gitlink_paths)
                existing = integration_claims.get(integration_source)
                if existing is None:
                    integration_claims[integration_source] = (baseline_id, layer)
                    continue
                existing_baseline, _ = existing
                if existing_baseline == baseline_id:
                    continue
                owners = sorted((baseline_id, existing_baseline))
                issues.append(
                    RegistryIssue(
                        path=adapter_path,
                        field=None,
                        code="integration-source-owner",
                        message=(
                            "Integration source '{}' (layer '{}') is claimed by "
                            "baselines '{}' and '{}'".format(
                                integration_source,
                                layer,
                                owners[0],
                                owners[1],
                            )
                        ),
                    )
                )
        if issues:
            raise RegistryError(issues)

        return cls(
            baselines=MappingProxyType(baselines),
            platforms=MappingProxyType(platforms),
            platform_adapters=MappingProxyType(platform_adapters),
            products=MappingProxyType(products),
            product_adapters=MappingProxyType(product_adapters),
            targets=MappingProxyType(targets),
            selectors=MappingProxyType(selectors),
        )


def _parse_record(
    root: Path,
    path: Path,
    allowed_fields: Iterable[str],
    required_fields: Iterable[str],
    multiline_fields: Iterable[str],
    issues: List[RegistryIssue],
) -> Optional[Dict[str, str]]:
    display_path = path.relative_to(root).as_posix()
    try:
        values, declared_fields, parser_issues = _parse_assignments(
            path, display_path, allowed_fields, multiline_fields
        )
        issues.extend(parser_issues)
        missing = frozenset(required_fields).difference(declared_fields)
        if missing:
            issues.extend(
                RegistryIssue(
                    path=display_path,
                    field=field,
                    code="missing-field",
                    message="missing required field {}".format(field),
                )
                for field in missing
            )
        if parser_issues or missing:
            return None
    except RegistryError as error:
        issues.extend(error.issues)
        return None
    except (OSError, UnicodeError):
        issues.append(
            RegistryIssue(
                path=display_path,
                field=None,
                code="record-read-error",
                message="could not read declarative record as UTF-8",
            )
        )
        return None
    return values


def _parse_assignments(
    path: Path,
    display_path: str,
    allowed_fields: Iterable[str],
    multiline_fields: Iterable[str],
) -> Tuple[Dict[str, str], FrozenSet[str], Tuple[RegistryIssue, ...]]:
    allowed = frozenset(allowed_fields)
    multiline = frozenset(multiline_fields)
    lines = path.read_text(encoding="utf-8").splitlines()
    values: Dict[str, str] = {}
    seen_fields = set()
    issues: List[RegistryIssue] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        index += 1
        if not stripped or stripped.startswith("#"):
            continue

        match = _ASSIGNMENT.fullmatch(line)
        if match is None:
            prefix_match = _ASSIGNMENT_PREFIX.match(line)
            if prefix_match is not None and prefix_match.group(1) in allowed:
                seen_fields.add(prefix_match.group(1))
            issues.append(
                RegistryIssue(
                    path=display_path,
                    field=None,
                    code="invalid-syntax",
                    message="expected a quoted field assignment",
                )
            )
            continue

        field, remainder = match.groups()
        field_is_valid = True
        if field not in allowed:
            issues.append(
                RegistryIssue(
                    path=display_path,
                    field=field,
                    code="unknown-field",
                    message="unknown field {}".format(field),
                )
            )
            field_is_valid = False
        elif field in seen_fields:
            issues.append(
                RegistryIssue(
                    path=display_path,
                    field=field,
                    code="duplicate-field",
                    message="duplicate field {}".format(field),
                )
            )
            field_is_valid = False
        seen_fields.add(field)

        value_lines = []
        if '"' in remainder and (
            not remainder.endswith('"') or remainder.count('"') != 1
        ):
            issues.append(
                RegistryIssue(
                    path=display_path,
                    field=field,
                    code="trailing-tokens",
                    message="trailing tokens are not allowed after a quoted value",
                )
            )
            continue
        if not remainder.endswith('"') and field not in multiline:
            issues.append(
                RegistryIssue(
                    path=display_path,
                    field=field,
                    code="unterminated-value",
                    message="unterminated quoted value",
                )
            )
            continue
        value_complete = True
        while not remainder.endswith('"'):
            value_lines.append(remainder)
            if index >= len(lines):
                issues.append(
                    RegistryIssue(
                        path=display_path,
                        field=field,
                        code="unterminated-value",
                        message="unterminated quoted value",
                    )
                )
                value_complete = False
                break
            remainder = lines[index]
            index += 1
            if '"' in remainder and (
                not remainder.endswith('"') or remainder.count('"') != 1
            ):
                issues.append(
                    RegistryIssue(
                        path=display_path,
                        field=field,
                        code="trailing-tokens",
                        message=(
                            "trailing tokens are not allowed after a quoted value"
                        ),
                    )
                )
                value_complete = False
                break
        if not value_complete:
            continue
        value_lines.append(remainder[:-1])
        value = "\n".join(value_lines)
        if "$" in value or "`" in value:
            issues.append(
                RegistryIssue(
                    path=display_path,
                    field=field,
                    code="substitution-not-allowed",
                    message="substitution is not allowed in declarative records",
                )
            )
            continue
        if _CONTROL_CHARACTER.search(value) is not None:
            issues.append(
                RegistryIssue(
                    path=display_path,
                    field=field,
                    code="control-character",
                    message="control characters are not allowed in values",
                )
            )
            continue
        if field_is_valid:
            values[field] = value
    return values, frozenset(seen_fields), tuple(issues)


def _is_canonical_relative_path(value: str) -> bool:
    if not value or value.startswith("/") or value.endswith("/"):
        return False
    if any(character.isspace() for character in value):
        return False
    return all(part not in {"", ".", ".."} for part in value.split("/"))


def _is_identifier(value: str) -> bool:
    return re.fullmatch(r"[A-Za-z0-9._+-]+", value) is not None


def _gitmodule_paths(root: Path) -> Tuple[str, ...]:
    path = root / ".gitmodules"
    if not path.is_file():
        return ()
    gitlinks = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\s*path\s*=\s*(\S+)\s*$", line)
        if match is not None:
            gitlinks.append(match.group(1))
    return tuple(sorted(gitlinks))


def _integration_source(layer: str, gitlink_paths: Iterable[str]) -> str:
    matches = [
        path
        for path in gitlink_paths
        if layer == path or layer.startswith(path + "/")
    ]
    if not matches:
        return layer
    return max(matches, key=len)


def main(
    argv: Optional[Iterable[str]] = None,
    stdout: Optional[TextIO] = None,
    stderr: Optional[TextIO] = None,
) -> int:
    output = stdout if stdout is not None else sys.stdout
    errors = stderr if stderr is not None else sys.stderr
    parser = argparse.ArgumentParser(prog="build_registry.py")
    parser.add_argument("--root", type=Path, default=Path.cwd())
    subparsers = parser.add_subparsers(dest="command")
    subparsers.required = True
    subparsers.add_parser("validate")
    subparsers.add_parser("list")
    resolve_parser = subparsers.add_parser("resolve")
    resolve_parser.add_argument(
        "--mode", choices=("canonical", "compat"), required=True
    )
    resolve_parser.add_argument("--selector", required=True)
    resolve_parser.add_argument("--profile")
    arguments = parser.parse_args(list(argv) if argv is not None else None)

    try:
        registry = BuildRegistry.compile(arguments.root)
    except RegistryError as error:
        print(str(error), file=errors)
        return 1

    if arguments.command == "validate":
        print("Registry validation: ok", file=output)
        return 0
    if arguments.command == "list":
        output.write(registry.render_listing())
        return 0
    if arguments.command == "resolve":
        try:
            selection = registry.resolve(
                arguments.selector,
                mode=arguments.mode,
                profile=arguments.profile,
            )
        except ResolutionError as error:
            print(str(error), file=errors)
            return 1
        output.write(selection.render_protocol())
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
