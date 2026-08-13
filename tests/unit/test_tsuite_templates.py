"""Integrity checks tying the tsuite experiment-type registry to its templates.

Every experiment type declared in ``tests/tsuite_config.yml`` must ship the two
Autosubmit template files that ``destine tsuite generate-pipeline``
(``wftools.tsuite_pipeline``) copies into each ephemeral experiment:

    tests/tsuite_mains/tsuite-jacamar-main-{type}.yml
    tests/tsuite_mains/tsuite-jacamar-minimal-{type}.yml

Without them the child pipeline fails at runtime with "Template not found", so
these tests fail fast at MR time instead.
"""

from __future__ import annotations

from pathlib import Path

import pytest
import yaml

_REPO_ROOT = Path(__file__).resolve().parents[2]
_CONFIG = _REPO_ROOT / "tests" / "tsuite_config.yml"
_MAINS = _REPO_ROOT / "tests" / "tsuite_mains"


def _load_type_names() -> list[str]:
    with open(_CONFIG) as fh:
        raw = yaml.safe_load(fh)
    return [entry["type"] for entry in raw["experiment_types"]]


_TYPE_NAMES = _load_type_names()


def test_experiment_types_are_unique():
    duplicates = sorted({name for name in _TYPE_NAMES if _TYPE_NAMES.count(name) > 1})
    assert not duplicates, (
        f"Duplicate experiment 'type' names in {_CONFIG.relative_to(_REPO_ROOT)}: "
        f"{duplicates}"
    )


@pytest.mark.parametrize("kind", ["main", "minimal"])
@pytest.mark.parametrize("type_name", _TYPE_NAMES)
def test_tsuite_template_exists(type_name: str, kind: str):
    template = _MAINS / f"tsuite-jacamar-{kind}-{type_name}.yml"
    assert template.is_file(), (
        f"Missing {kind} template for experiment type '{type_name}': "
        f"expected {template.relative_to(_REPO_ROOT)} "
        f"(declared in {_CONFIG.relative_to(_REPO_ROOT)})"
    )


def test_no_orphan_tsuite_templates():
    expected = set()
    for name in _TYPE_NAMES:
        expected.add(f"tsuite-jacamar-main-{name}.yml")
        expected.add(f"tsuite-jacamar-minimal-{name}.yml")
    actual = {path.name for path in _MAINS.glob("tsuite-jacamar-*.yml")}
    orphans = sorted(actual - expected)
    assert not orphans, (
        "Orphan tsuite templates in tests/tsuite_mains/ with no matching experiment "
        f"type in {_CONFIG.relative_to(_REPO_ROOT)}: {orphans}"
    )
