from __future__ import annotations

from pathlib import Path

import pytest

from wftools.autosubmit.parser import (
    extract_job_errors,
    extract_job_type,
    parse_experiment,
    parse_status_tree,
    read_accounted_durations,
)
from wftools.domain.models import SlurmMetadata
from wftools.resources.models import JobUsage, ResourceUsage

FIXTURES = Path(__file__).resolve().parent.parent.parent / "fixtures"


@pytest.fixture()
def sample_tree() -> str:
    return (FIXTURES / "status_tree_sample.txt").read_text()


class TestParseStatusTree:
    def test_basic(self, sample_tree: str) -> None:
        """Parsing the sample tree should produce 6 TestCase objects."""
        cases = parse_status_tree("a006", sample_tree)
        assert len(cases) == 6

    def test_statuses(self, sample_tree: str) -> None:
        """Verify correct passed/skipped/failed counts."""
        cases = parse_status_tree("a006", sample_tree)
        passed = sum(1 for c in cases if c.passed)
        skipped = sum(1 for c in cases if c.skipped)
        failed = sum(1 for c in cases if not c.passed and not c.skipped)

        assert passed == 4  # LOCAL_SETUP, SYNCHRONIZE, fc0_2_SIM, fc0_2_DQC_BASIC
        assert skipped == 1  # fc0_1_DQC_BASIC (WAITING)
        assert failed == 1  # fc0_1_SIM (FAILED)

    def test_empty(self) -> None:
        """Empty text returns empty list."""
        assert parse_status_tree("a006", "") == []

    def test_header_only(self) -> None:
        """Only header line returns empty list."""
        text = "## String representation of Job List [0]  ##\n"
        assert parse_status_tree("a006", text) == []

    def test_slurm_metadata_passthrough(self, sample_tree: str) -> None:
        """Slurm metadata is attached when provided."""
        meta = {
            "a006_19900101_fc0_1_SIM": SlurmMetadata(
                slurm_id="12345", platform="lumi", queue="gpu"
            )
        }
        cases = parse_status_tree("a006", sample_tree, slurm_metadata=meta)
        sim_case = next(
            c for c in cases if c.full_job_name == "a006_19900101_fc0_1_SIM"
        )
        assert sim_case.slurm.slurm_id == "12345"
        assert sim_case.slurm.platform == "lumi"
        assert sim_case.slurm.queue == "gpu"

    def test_err_finder_called_for_failed(self, sample_tree: str) -> None:
        """err_finder is called for FAILED jobs."""
        calls: list[str] = []

        def fake_err_finder(job_name: str) -> str | None:
            calls.append(job_name)
            return "some error output"

        cases = parse_status_tree("a006", sample_tree, err_finder=fake_err_finder)
        assert "a006_19900101_fc0_1_SIM" in calls

        sim_case = next(
            c for c in cases if c.full_job_name == "a006_19900101_fc0_1_SIM"
        )
        assert sim_case.error == "some error output"

    def test_duration_finder_called(self, sample_tree: str) -> None:
        """duration_finder is called for every job."""

        def fake_duration(job_name: str) -> float | None:
            if "SIM" in job_name:
                return 120.5
            return None

        cases = parse_status_tree("a006", sample_tree, duration_finder=fake_duration)
        sim_cases = [c for c in cases if "SIM" in (c.full_job_name or "")]
        for c in sim_cases:
            assert c.duration == 120.5


class TestExtractJobType:
    def test_local_setup(self) -> None:
        assert extract_job_type("a006", "a006_LOCAL_SETUP") == "LOCAL_SETUP"

    def test_sim_with_member(self) -> None:
        assert extract_job_type("a006", "a006_19900101_fc0_1_SIM") == "SIM [fc0_1]"

    def test_multipart(self) -> None:
        result = extract_job_type("a006", "a006_19900101_fc0_2_FIX_CONSTANT_VARIABLES")
        assert result == "FIX_CONSTANT_VARIABLES [fc0_2]"

    def test_date_only_no_member(self) -> None:
        result = extract_job_type("a006", "a006_19900101_REMOTE_SETUP")
        assert result == "REMOTE_SETUP"

    def test_bare_expid(self) -> None:
        """Edge case: job name is exactly the expid."""
        assert extract_job_type("a006", "a006") == "a006"


class TestExtractJobErrors:
    def test_basic(self) -> None:
        run_log = (
            "some context before "
            "Job a006_19900101_fc0_1_SIM is FAILED "
            "some context after the failure message "
            "more log lines here"
        )
        errors = extract_job_errors("a006", run_log)
        assert "a006_19900101_fc0_1_SIM" in errors
        assert "FAILED" in errors["a006_19900101_fc0_1_SIM"]

    def test_multiple_failures(self) -> None:
        run_log = "Job a006_JOB_A is FAILED blah\nJob a006_JOB_B is ABORTED blah\n"
        errors = extract_job_errors("a006", run_log)
        assert len(errors) == 2
        assert "a006_JOB_A" in errors
        assert "a006_JOB_B" in errors

    def test_no_failures(self) -> None:
        run_log = "Everything completed successfully\n"
        errors = extract_job_errors("a006", run_log)
        assert errors == {}


class TestReadAccountedDurations:
    """The resources phase's sacct times, reused for jobs AS has no _STAT_ for."""

    def _usage_json(self, tmp_path: Path, jobs: list[JobUsage]) -> Path:
        path = tmp_path / "resources-a006.json"
        path.write_text(ResourceUsage(expid="a006", jobs=jobs).model_dump_json())
        return path

    def test_reads_elapsed_per_job_name(self, tmp_path: Path) -> None:
        path = self._usage_json(
            tmp_path,
            [
                JobUsage(
                    job_id="1", job_name="a006_19900101_fc0_1_SIM", elapsed_s=47.0
                ),
                JobUsage(job_id="2", job_name="a006_LOCAL_SETUP", elapsed_s=1.0),
            ],
        )
        assert read_accounted_durations(path) == {
            "a006_19900101_fc0_1_SIM": 47.0,
            "a006_LOCAL_SETUP": 1.0,
        }

    def test_unfinished_and_unnamed_jobs_are_dropped(self, tmp_path: Path) -> None:
        """A 0 s job never ran to completion; a nameless one cannot be matched."""
        path = self._usage_json(
            tmp_path,
            [
                JobUsage(job_id="1", job_name="a006_SIM", elapsed_s=0.0),
                JobUsage(job_id="2", job_name=None, elapsed_s=12.0),
            ],
        )
        assert read_accounted_durations(path) == {}

    @pytest.mark.parametrize("content", ["", "not json", '{"expid": 3}'])
    def test_an_unusable_file_is_ignored_not_raised(
        self, tmp_path: Path, content: str
    ) -> None:
        """Durations are a nicety; the report must survive without them."""
        path = tmp_path / "resources.json"
        path.write_text(content)
        assert read_accounted_durations(path) == {}

    def test_no_file_at_all(self, tmp_path: Path) -> None:
        assert read_accounted_durations(None) == {}
        assert read_accounted_durations(tmp_path / "absent.json") == {}


class TestParseExperimentDurations:
    def _run(self, tmp_path: Path, durations_file: Path | None) -> dict[str, float]:
        cases = parse_experiment(
            expid="a006",
            status_file=FIXTURES / "status_tree_sample.txt",
            data_root=tmp_path / "empty_as_data",
            durations_file=durations_file,
        )
        return {c.full_job_name: c.duration for c in cases}

    def test_accounted_times_fill_the_gaps(self, tmp_path: Path) -> None:
        """No _STAT_ files here -- exactly the case that left `time=` empty."""
        path = tmp_path / "resources-a006.json"
        path.write_text(
            ResourceUsage(
                expid="a006",
                jobs=[
                    JobUsage(
                        job_id="1", job_name="a006_19900101_fc0_1_SIM", elapsed_s=47.0
                    )
                ],
            ).model_dump_json()
        )

        durations = self._run(tmp_path, path)

        assert durations["a006_19900101_fc0_1_SIM"] == 47.0
        assert durations["a006_LOCAL_SETUP"] is None
        assert self._run(tmp_path, None)["a006_19900101_fc0_1_SIM"] is None
