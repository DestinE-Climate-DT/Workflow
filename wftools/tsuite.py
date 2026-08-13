"""tsuite experiment-type registry + change-driven detection.

Single home for the experiment-type registry (``EXPERIMENT_TYPES``) and the
change-driven detection used by the ``destine tsuite`` CLI.  Loaded from
``tests/tsuite_config.yml``.
"""

from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

import yaml

# Default location of the registry YAML, relative to the working directory.
# The CI jobs run from the repo root, so this resolves to the checked-out copy.
DEFAULT_CONFIG_PATH = Path("tests/tsuite_config.yml")


@dataclass(frozen=True)
class ExperimentType:
    name: str
    description: str
    hpc: str
    tags: frozenset[str]

    def as_ci_record(self) -> dict:
        return {"type": self.name, "hpc": self.hpc}

    def as_record(self) -> dict:
        return {"type": self.name, "hpc": self.hpc, "description": self.description}


@dataclass(frozen=True)
class PathRule:
    pattern: str
    tags: frozenset[str]


@dataclass(frozen=True)
class Registry:
    experiment_types: tuple[ExperimentType, ...]
    path_rules: tuple[PathRule, ...]

    @property
    def names(self) -> frozenset[str]:
        return frozenset(et.name for et in self.experiment_types)


def load_registry(config_path: Path | str = DEFAULT_CONFIG_PATH) -> Registry:
    """Load experiment types and path rules from the registry YAML."""
    with open(config_path) as fh:
        raw = yaml.safe_load(fh)

    experiment_types = tuple(
        ExperimentType(
            name=entry["type"],
            description=entry["description"],
            hpc=entry["hpc"],
            tags=frozenset(entry["tags"]),
        )
        for entry in raw["experiment_types"]
    )
    path_rules = tuple(
        PathRule(pattern=rule["pattern"], tags=frozenset(rule["tags"]))
        for rule in raw["path_rules"]
    )
    return Registry(experiment_types=experiment_types, path_rules=path_rules)


@dataclass(frozen=True)
class RuleMatch:
    filepath: Path
    rule: PathRule


@dataclass(frozen=True)
class ChangedFiles:
    paths: tuple[Path, ...]

    @classmethod
    def from_lines(cls, lines: list[str]) -> "ChangedFiles":
        return cls(tuple(Path(line.strip()) for line in lines if line.strip()))


@dataclass
class DetectionResult:
    experiments: list[ExperimentType] = field(default_factory=list)
    activated_tags: set[str] = field(default_factory=set)
    matches: list[RuleMatch] = field(default_factory=list)

    def as_json(self) -> str:
        return json.dumps(
            [experiment.as_ci_record() for experiment in self.experiments],
            separators=(",", ":"),
        )


def select_experiments(
    registry: Registry, changed_files: ChangedFiles
) -> DetectionResult:
    """Given changed file paths, return experiment types to run."""
    activated_tags: set[str] = set()
    matches: list[RuleMatch] = []

    for filepath in changed_files.paths:
        for rule in registry.path_rules:
            if re.search(rule.pattern, str(filepath)):
                activated_tags.update(rule.tags)
                matches.append(RuleMatch(filepath, rule))

    if "ALL" in activated_tags:
        return DetectionResult(list(registry.experiment_types), activated_tags, matches)

    experiments = [et for et in registry.experiment_types if et.tags & activated_tags]
    return DetectionResult(experiments, activated_tags, matches)


def is_primary_report(report: Path) -> bool:
    """True for a monitor report (``tsuite-report-<expid>.xml``).

    Per-phase reports carry a ``.<phase>`` infix.  Only the monitor one proves
    the chain ran, so it alone answers "did this type run at all?".
    """
    return "." not in report.stem


def xml_files_for_type(reports_dir: Path, type_name: str) -> list[Path]:
    """Return tsuite-report-*.xml files whose contents reference the type.

    Case names are prefixed with ``{type}/`` -- by `destine report parse
    --name-prefix` for the per-job cases, and by the phase scripts for their
    own -- so we can match XMLs to types without needing to know the expid.
    """
    matches: list[Path] = []
    for path in sorted(reports_dir.glob("tsuite-report-*.xml")):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        for tc in root.iter("testcase"):
            name = tc.get("name", "")
            if name.startswith(f"{type_name}/"):
                matches.append(path)
                break
    return matches


def has_junit_failures(xml_path: Path) -> bool:
    """True iff any <testcase> in `xml_path` carries <failure> or <error>."""
    root = ET.parse(xml_path).getroot()
    for tc in root.iter("testcase"):
        if tc.find("failure") is not None or tc.find("error") is not None:
            return True
    return False


def check_required(
    detected_types: list[dict], reports_dir: Path
) -> tuple[list[str], list[tuple[str, str]]]:
    """Gate check for detected types.  Returns ``(passed, failed)``.

    ``failed`` entries are ``(type_name, reason)`` tuples.  A type fails if
    its monitor XML is missing (= required expid-{type} job was not clicked)
    OR if any of its XMLs contain ``<failure>`` / ``<error>`` cases.  A
    per-phase report alone never stands in for the monitor one, which would
    turn a chain that died before monitor into a pass.
    """
    passed: list[str] = []
    failed: list[tuple[str, str]] = []
    for entry in detected_types:
        type_name = entry["type"]
        xml_files = xml_files_for_type(reports_dir, type_name)
        if not any(is_primary_report(p) for p in xml_files):
            failed.append(
                (
                    type_name,
                    f"did not run -- no tsuite-report-<expid>.xml found "
                    f"(was the required expid-{type_name} job clicked?)",
                )
            )
            continue
        bad = [p for p in xml_files if has_junit_failures(p)]
        if bad:
            files = ", ".join(str(p.name) for p in bad)
            failed.append((type_name, f"JUnit reports failures in: {files}"))
        else:
            passed.append(type_name)
    return passed, failed


def prepare_types(
    registry: Registry, detected_names: set[str], templates_dir: Path
) -> tuple[list[dict], list[str]]:
    """Keep every registry type that ships both templates; tag with ``detected``.

    Returns ``(kept, missing)`` where ``kept`` is a list of CI records
    (``{"type", "hpc", "detected"}``) and ``missing`` is the names of types
    lacking a main+minimal template pair.
    """
    kept: list[dict] = []
    missing: list[str] = []
    for et in registry.experiment_types:
        main_tpl = templates_dir / f"tsuite-jacamar-main-{et.name}.yml"
        minimal_tpl = templates_dir / f"tsuite-jacamar-minimal-{et.name}.yml"
        if main_tpl.exists() and minimal_tpl.exists():
            kept.append(
                {"type": et.name, "hpc": et.hpc, "detected": et.name in detected_names}
            )
        else:
            missing.append(et.name)
    return kept, missing
