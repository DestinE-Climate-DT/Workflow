from __future__ import annotations

import json
from pathlib import Path

import pytest
from click.testing import CliRunner

from wftools.cli.main import cli
from wftools.domain.models import TestCase, TestResult
from wftools.results.store import ResultStore

FIXTURES = Path(__file__).resolve().parent.parent.parent / "fixtures"


@pytest.fixture()
def runner() -> CliRunner:
    return CliRunner()


@pytest.fixture()
def results_dir(tmp_path: Path) -> Path:
    d = tmp_path / "results"
    d.mkdir()
    return d


def _populate_results(results_dir: Path) -> None:
    """Write a couple of test results into results_dir for generate/metrics tests."""
    store = ResultStore(base_dir=results_dir)
    store.save(TestResult(name="smoke_check", passed=True))
    store.save(TestResult(name="deploy_check", passed=False, error="deploy failed"))
    store.save(
        TestCase(
            name="SIM [fc0_1]",
            passed=True,
            full_job_name="a006_19900101_fc0_1_SIM",
            classname="a006",
            status="COMPLETED",
        )
    )


class TestAdd:
    def test_add_pass(self, runner: CliRunner, tmp_path: Path) -> None:
        rd = str(tmp_path / "res")
        result = runner.invoke(
            cli, ["report", "add", "my_test", "pass", "--results-dir", rd]
        )
        assert result.exit_code == 0

        json_files = list(Path(rd).glob("*.json"))
        assert len(json_files) == 1

        data = json.loads(json_files[0].read_text())
        assert data["name"] == "my_test"
        assert data["passed"] is True

    def test_add_fail(self, runner: CliRunner, tmp_path: Path) -> None:
        rd = str(tmp_path / "res")
        result = runner.invoke(
            cli, ["report", "add", "my_test", "fail", "--results-dir", rd]
        )
        assert result.exit_code == 0

        json_files = list(Path(rd).glob("*.json"))
        assert len(json_files) == 1

        data = json.loads(json_files[0].read_text())
        assert data["name"] == "my_test"
        assert data["passed"] is False

    def test_add_fail_with_error_file(self, runner: CliRunner, tmp_path: Path) -> None:
        rd = str(tmp_path / "res")
        error_file = tmp_path / "err.log"
        error_file.write_text("RuntimeError: something went wrong\nstack trace here")

        result = runner.invoke(
            cli,
            [
                "report",
                "add",
                "my_test",
                "fail",
                str(error_file),
                "--results-dir",
                rd,
            ],
        )
        assert result.exit_code == 0

        json_files = list(Path(rd).glob("*.json"))
        assert len(json_files) == 1

        data = json.loads(json_files[0].read_text())
        assert data["passed"] is False
        assert "RuntimeError" in data["error"]

    def test_add_slashed_name(self, runner: CliRunner, tmp_path: Path) -> None:
        """The phase scripts report as `{type}/{phase}`; the store is flat."""
        rd = str(tmp_path / "res")
        result = runner.invoke(
            cli,
            [
                "report",
                "add",
                "ifs-nemo-lowres/resources",
                "pass",
                "--results-dir",
                rd,
                "--classname",
                "t0zz",
            ],
        )
        assert result.exit_code == 0, result.output

        json_files = list(Path(rd).glob("*.json"))
        assert len(json_files) == 1

        data = json.loads(json_files[0].read_text())
        assert data["name"] == "ifs-nemo-lowres/resources"
        assert data["classname"] == "t0zz"

    def test_add_invalid_status(self, runner: CliRunner, tmp_path: Path) -> None:
        rd = str(tmp_path / "res")
        result = runner.invoke(
            cli, ["report", "add", "my_test", "bogus", "--results-dir", rd]
        )
        assert result.exit_code != 0


class TestGenerate:
    def test_generate_with_results(self, runner: CliRunner, tmp_path: Path) -> None:
        rd = tmp_path / "res"
        _populate_results(rd)

        out = str(tmp_path / "output" / "report.xml")
        result = runner.invoke(
            cli, ["report", "generate", out, "--results-dir", str(rd)]
        )
        assert result.exit_code == 0

        output_path = Path(out)
        assert output_path.exists()
        content = output_path.read_text()
        assert "<testsuite" in content
        assert 'name="tsuite"' in content

    def test_generate_no_results(self, runner: CliRunner, tmp_path: Path) -> None:
        rd = tmp_path / "empty_res"
        rd.mkdir()

        out = str(tmp_path / "output" / "report.xml")
        result = runner.invoke(
            cli, ["report", "generate", out, "--results-dir", str(rd)]
        )
        assert result.exit_code != 0


class TestMetrics:
    def test_metrics_basic(self, runner: CliRunner, tmp_path: Path) -> None:
        rd = tmp_path / "res"
        _populate_results(rd)

        out = str(tmp_path / "output" / "metrics.txt")
        result = runner.invoke(
            cli, ["report", "metrics", out, "--results-dir", str(rd)]
        )
        assert result.exit_code == 0

        output_path = Path(out)
        assert output_path.exists()
        content = output_path.read_text()
        # Only the one real job counts; the two coarse `add` results do not.
        assert "completed_jobs 1" in content
        assert "failed_jobs 0" in content
        assert "total_jobs 1" in content


class TestClean:
    def test_clean(self, runner: CliRunner, tmp_path: Path) -> None:
        rd = tmp_path / "res"
        _populate_results(rd)

        # Verify files exist before clean
        assert len(list(rd.glob("*.json"))) == 3

        result = runner.invoke(cli, ["report", "clean", "--results-dir", str(rd)])
        assert result.exit_code == 0

        # Directory should be removed (or at least emptied)
        assert not rd.exists() or len(list(rd.glob("*.json"))) == 0


class TestParse:
    def test_parse_with_fixture(
        self, runner: CliRunner, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        """Parse the sample status tree with monkeypatched filesystem functions.

        The real HPC filesystem is not available locally, so we monkeypatch
        the three filesystem functions to return None/empty results.  The
        parse command should still produce TestCase JSON files -- just
        without error content or slurm metadata.
        """
        rd = str(tmp_path / "res")
        status_file = str(FIXTURES / "status_tree_sample.txt")

        # Use a temp data_root so the filesystem functions see empty directories
        # and return None / empty dicts naturally (no HPC paths needed).
        fake_data_root = str(tmp_path / "fake_as_data")

        # Monkeypatch the filesystem functions to gracefully handle missing paths
        monkeypatch.setattr(
            "wftools.autosubmit.filesystem.find_job_err",
            lambda log_dir, job_name: None,
        )
        monkeypatch.setattr(
            "wftools.autosubmit.filesystem.get_job_duration",
            lambda log_dir, job_name: None,
        )
        monkeypatch.setattr(
            "wftools.autosubmit.filesystem.parse_jobs_status_log",
            lambda aslogs_dir, expid: {},
        )

        result = runner.invoke(
            cli,
            [
                "report",
                "parse",
                "a006",
                status_file,
                "--results-dir",
                rd,
                "--data-root",
                fake_data_root,
            ],
        )
        assert result.exit_code == 0, f"CLI failed: {result.output}"

        json_files = list(Path(rd).glob("*.json"))
        # The sample tree has 6 jobs
        assert len(json_files) == 6

        # Verify one of the parsed results has the right structure
        names = set()
        for f in json_files:
            data = json.loads(f.read_text())
            names.add(data["name"])
            assert "classname" in data
            assert data["classname"] == "a006"

        # Check that known job types are present
        assert "LOCAL_SETUP" in names
        assert "SYNCHRONIZE" in names


class TestHelpAndVersion:
    def test_cli_help(self, runner: CliRunner) -> None:
        result = runner.invoke(cli, ["--help"])
        assert result.exit_code == 0
        assert "DestinE" in result.output

    def test_report_help(self, runner: CliRunner) -> None:
        result = runner.invoke(cli, ["report", "--help"])
        assert result.exit_code == 0
        assert "report" in result.output.lower()

    def test_version(self, runner: CliRunner) -> None:
        result = runner.invoke(cli, ["--version"])
        assert result.exit_code == 0
        assert "destine" in result.output.lower()
