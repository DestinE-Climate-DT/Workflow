from __future__ import annotations

from pathlib import Path


from wftools.domain.models import SlurmMetadata, TestCase, TestResult
from wftools.results.store import ResultStore


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_test_result(**overrides) -> TestResult:
    defaults = {"name": "smoke_check", "passed": True}
    defaults.update(overrides)
    return TestResult(**defaults)


def _make_test_case(**overrides) -> TestCase:
    defaults = {
        "name": "SIM [fc0_1]",
        "passed": True,
        "full_job_name": "a006_19900101_fc0_1_SIM",
        "classname": "a006",
        "status": "COMPLETED",
        "slurm": SlurmMetadata(slurm_id="12345", platform="lumi", queue="standard"),
        "duration": 42.5,
    }
    defaults.update(overrides)
    return TestCase(**defaults)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_save_and_load_roundtrip(tmp_path: Path) -> None:
    """Save a TestResult, load_all, verify equality."""
    store = ResultStore(base_dir=tmp_path / "results")
    original = _make_test_result()

    store.save(original)
    loaded = store.load_all()

    assert len(loaded) == 1
    assert loaded[0].name == original.name
    assert loaded[0].passed == original.passed
    assert loaded[0].skipped == original.skipped
    assert loaded[0].timestamp == original.timestamp
    assert loaded[0].error == original.error


def test_save_testcase_roundtrip(tmp_path: Path) -> None:
    """Save a TestCase with slurm metadata, load_all, verify all fields preserved."""
    store = ResultStore(base_dir=tmp_path / "results")
    original = _make_test_case()

    store.save(original)
    loaded = store.load_all()

    assert len(loaded) == 1
    case = loaded[0]
    assert isinstance(case, TestCase)
    assert case.name == original.name
    assert case.passed == original.passed
    assert case.full_job_name == original.full_job_name
    assert case.classname == original.classname
    assert case.status == original.status
    assert case.duration == original.duration
    assert case.slurm.slurm_id == "12345"
    assert case.slurm.platform == "lumi"
    assert case.slurm.queue == "standard"


def test_load_all_skips_corrupt(tmp_path: Path) -> None:
    """Write a valid JSON + a corrupt file manually, load_all returns 1 result."""
    store = ResultStore(base_dir=tmp_path / "results")
    store.save(_make_test_result(name="good"))

    # Write a corrupt file directly
    corrupt_path = tmp_path / "results" / "corrupt.json"
    corrupt_path.write_text("{this is not valid json at all")

    loaded = store.load_all()
    assert len(loaded) == 1
    assert loaded[0].name == "good"


def test_load_all_empty_dir(tmp_path: Path) -> None:
    """Create empty dir, returns empty list."""
    results_dir = tmp_path / "results"
    results_dir.mkdir()

    store = ResultStore(base_dir=results_dir)
    loaded = store.load_all()

    assert loaded == []


def test_load_all_no_dir(tmp_path: Path) -> None:
    """Nonexistent dir, returns empty list."""
    store = ResultStore(base_dir=tmp_path / "nonexistent")
    loaded = store.load_all()

    assert loaded == []


def test_clean_removes_files(tmp_path: Path) -> None:
    """Save 3 results, clean, verify directory gone, returns 3."""
    store = ResultStore(base_dir=tmp_path / "results")
    store.save(_make_test_result(name="alpha"))
    store.save(_make_test_result(name="beta"))
    store.save(_make_test_result(name="gamma"))

    count = store.clean()

    assert count == 3
    assert not store.base_dir.exists()


def test_clean_empty(tmp_path: Path) -> None:
    """Clean on nonexistent dir returns 0."""
    store = ResultStore(base_dir=tmp_path / "nonexistent")
    count = store.clean()

    assert count == 0


def test_save_flattens_slashed_name(tmp_path: Path) -> None:
    """A `{type}/{phase}` name lands in a flat file the non-recursive glob sees."""
    store = ResultStore(base_dir=tmp_path / "results")

    path = store.save(_make_test_result(name="some-type/resources"))

    assert path == store.base_dir / "some-type_resources.json"
    loaded = store.load_all()
    assert len(loaded) == 1
    assert loaded[0].name == "some-type/resources"
    assert store.clean() == 1


def test_key_override(tmp_path: Path) -> None:
    """Save with explicit key, verify filename matches."""
    store = ResultStore(base_dir=tmp_path / "results")
    result = _make_test_result(name="original_name")

    path = store.save(result, key="custom_key")

    assert path.name == "custom_key.json"
    assert path.exists()
    # The content should still have the original name
    loaded = store.load_all()
    assert len(loaded) == 1
    assert loaded[0].name == "original_name"
