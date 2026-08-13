"""CLI tests for ``destine tsuite`` (select-type / prepare-types).

These two commands replace the inline Python heredocs in
``.gitlab/ci/jacamar-tsuite.yml`` (single-type validation and the
registry/template merge).
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from click.testing import CliRunner

from wftools.cli.main import cli

_REPO_ROOT = Path(__file__).resolve().parents[3]
_CONFIG = str(_REPO_ROOT / "tests" / "tsuite_config.yml")
_MAINS = str(_REPO_ROOT / "tests" / "tsuite_mains")


@pytest.fixture()
def runner() -> CliRunner:
    return CliRunner()


def _combined(result) -> str:
    """stdout + stderr, tolerant of click's version-dependent stream split."""
    text = result.output or ""
    try:
        text += result.stderr or ""
    except (ValueError, AttributeError):
        pass
    return text


class TestSelectType:
    def test_valid_type_emits_single_element_json(self, runner: CliRunner) -> None:
        result = runner.invoke(
            cli,
            ["tsuite", "select-type", "--config", _CONFIG, "ifs-fesom-storylines"],
        )
        assert result.exit_code == 0
        assert json.loads(result.output) == [{"type": "ifs-fesom-storylines"}]

    def test_invalid_type_fails_with_valid_list(self, runner: CliRunner) -> None:
        result = runner.invoke(
            cli, ["tsuite", "select-type", "--config", _CONFIG, "does-not-exist"]
        )
        assert result.exit_code == 1
        combined = _combined(result)
        assert "not a known experiment type" in combined
        assert "ifs-fesom-storylines" in combined  # the valid-types listing


class TestPrepareTypes:
    def test_merges_registry_with_detected_flag(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        missing = tmp_path / "missing.txt"
        result = runner.invoke(
            cli,
            [
                "tsuite",
                "prepare-types",
                "--config",
                _CONFIG,
                "--detected-json",
                '[{"type":"ifs-fesom-storylines"}]',
                "--templates-dir",
                _MAINS,
                "--missing-file",
                str(missing),
            ],
        )
        assert result.exit_code == 0
        kept = json.loads(result.output)
        assert len(kept) == 14
        assert all({"type", "hpc", "detected"} == set(e) for e in kept)
        detected = {e["type"] for e in kept if e["detected"]}
        assert detected == {"ifs-fesom-storylines"}
        # All real types ship templates -> empty missing file.
        assert missing.read_text() == ""

    def test_missing_templates_recorded(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        # A templates dir with no pairs -> every type is missing, kept == [].
        empty = tmp_path / "tpl"
        empty.mkdir()
        missing = tmp_path / "missing.txt"
        result = runner.invoke(
            cli,
            [
                "tsuite",
                "prepare-types",
                "--config",
                _CONFIG,
                "--detected-json",
                "[]",
                "--templates-dir",
                str(empty),
                "--missing-file",
                str(missing),
            ],
        )
        assert result.exit_code == 0
        assert result.output.strip() == "[]"
        assert len(missing.read_text().splitlines()) == 14


class TestCollect:
    """Exit codes here are load-bearing: tsuite-required `needs:` this job."""

    def _shared_with_results(self, tmp_path: Path, expid: str = "a006") -> Path:
        shared = tmp_path / "results" / "12345"
        shared.mkdir(parents=True)
        (shared / f"tsuite-report-{expid}.xml").write_text(
            f'<testsuite name="tsuite" tests="1" failures="0">'
            f'<testcase name="ifs-nemo-lowres/LOCAL_SETUP" classname="{expid}" />'
            f"</testsuite>"
        )
        (shared / f"metrics-{expid}.txt").write_text("total_jobs 12\n")
        (shared / "provenance.txt").write_text(
            f"expid={expid} type=ifs-nemo-lowres phase=monitor job=111 url=u at=t\n"
        )
        return shared

    def _invoke(self, runner: CliRunner, shared: Path, reports: Path, types="[]"):
        return runner.invoke(
            cli,
            [
                "tsuite",
                "collect",
                "--shared-dir",
                str(shared),
                "--reports-dir",
                str(reports),
                "--types-json",
                types,
            ],
        )

    def test_collects_and_names_its_sources(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        shared = self._shared_with_results(tmp_path)
        result = self._invoke(runner, shared, tmp_path / "reports")
        assert result.exit_code == 0
        assert "tsuite-report-a006.xml" in result.output
        assert "expid=a006" in result.output

    def test_nothing_to_collect_passes_so_the_gate_still_runs(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        result = self._invoke(
            runner,
            tmp_path / "results" / "12345",
            tmp_path / "reports",
            types='[{"type": "ifs-nemo-lowres", "detected": true}]',
        )
        assert result.exit_code == 0
        assert "1 required type(s) were detected" in result.output

    def test_no_detected_types_is_reported_as_benign(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        result = self._invoke(
            runner, tmp_path / "results" / "12345", tmp_path / "reports"
        )
        assert result.exit_code == 0
        assert "No types were detected" in result.output

    def test_retry_with_nothing_new_fails_instead_of_publishing_empty(
        self, runner: CliRunner, tmp_path: Path
    ) -> None:
        shared = self._shared_with_results(tmp_path)
        reports = tmp_path / "reports"
        assert self._invoke(runner, shared, reports).exit_code == 0

        result = self._invoke(runner, shared, reports)

        assert result.exit_code == 1
        assert "nothing new to collect" in result.output
        assert "expids=a006" in result.output

    def test_bad_types_json_exits_2(self, runner: CliRunner, tmp_path: Path) -> None:
        result = self._invoke(
            runner,
            tmp_path / "results" / "12345",
            tmp_path / "reports",
            types="not json",
        )
        assert result.exit_code == 2
        assert "invalid TSUITE_TYPES_JSON" in _combined(result)
