from __future__ import annotations

from unittest.mock import patch

import pytest
from click.testing import CliRunner

pytest.importorskip("gitlab", reason="python-gitlab not installed")
import wftools.gitlab.client  # noqa: F401, E402 — ensure module is loaded for patching

from wftools.cli.main import cli  # noqa: E402


@pytest.fixture()
def runner() -> CliRunner:
    return CliRunner()


SAMPLE_PIPELINE_INFO = {
    "id": 36919,
    "status": "success",
    "created_at": "2025-04-14T09:31:00Z",
    "web_url": "https://gitlab.earth.bsc.es/digital-twins/de_340-2/workflow/-/pipelines/36919",
}

SAMPLE_TEST_REPORT = {
    "total_time": 120.5,
    "total_count": 24,
    "success_count": 23,
    "failed_count": 1,
    "error_count": 0,
    "test_suites": [
        {
            "name": "a006",
            "total_count": 12,
            "failed_count": 0,
            "error_count": 0,
            "test_cases": [
                {"name": "grib_set", "classname": "a006", "status": "success"},
                {
                    "name": "interpolation",
                    "classname": "a006",
                    "status": "success",
                },
            ],
        },
        {
            "name": "b007",
            "total_count": 12,
            "failed_count": 1,
            "error_count": 0,
            "test_cases": [
                {
                    "name": "grib_set",
                    "classname": "b007",
                    "status": "failed",
                    "system_output": "grib_set: No messages found",
                },
                {
                    "name": "interpolation",
                    "classname": "b007",
                    "status": "success",
                },
            ],
        },
    ],
}

SAMPLE_MR_PIPELINES = [
    {
        "id": 36919,
        "status": "success",
        "created_at": "2025-04-14T09:31:00Z",
        "web_url": "https://gitlab.earth.bsc.es/digital-twins/de_340-2/workflow/-/pipelines/36919",
    },
]


class TestMrHelp:
    def test_mr_help(self, runner):
        """``destine mr --help`` exits 0 and shows help text."""
        result = runner.invoke(cli, ["mr", "--help"])
        assert result.exit_code == 0
        assert "merge request" in result.output.lower() or "mr" in result.output.lower()

    def test_mr_exp_help(self, runner):
        """``destine mr exp --help`` exits 0 and shows help text."""
        result = runner.invoke(cli, ["mr", "exp", "--help"])
        assert result.exit_code == 0
        assert "experiment" in result.output.lower() or "exp" in result.output.lower()


class TestMrExpList:
    def test_mr_exp_lists_experiments(self, runner, monkeypatch):
        """``destine mr exp <iid>`` lists experiments with status."""
        monkeypatch.setenv("DESTINE_GITLAB_HOST", "gitlab.earth.bsc.es")
        monkeypatch.setenv("DESTINE_PROJECT", "digital-twins/de_340-2/workflow")

        with (
            patch(
                "wftools.gitlab.client.get_mr_pipelines",
                return_value=SAMPLE_MR_PIPELINES,
            ),
            patch(
                "wftools.gitlab.client.get_pipeline_info",
                return_value=SAMPLE_PIPELINE_INFO,
            ),
            patch(
                "wftools.gitlab.client.get_pipeline_test_report",
                return_value=SAMPLE_TEST_REPORT,
            ),
        ):
            result = runner.invoke(cli, ["mr", "exp", "42"])

        assert result.exit_code == 0
        assert "36919" in result.output
        assert "a006" in result.output
        assert "b007" in result.output


class TestMrExpDetail:
    def test_mr_exp_shows_detail(self, runner, monkeypatch):
        """``destine mr exp <iid> <expid>`` shows experiment detail."""
        monkeypatch.setenv("DESTINE_GITLAB_HOST", "gitlab.earth.bsc.es")
        monkeypatch.setenv("DESTINE_PROJECT", "digital-twins/de_340-2/workflow")

        with (
            patch(
                "wftools.gitlab.client.get_mr_pipelines",
                return_value=SAMPLE_MR_PIPELINES,
            ),
            patch(
                "wftools.gitlab.client.get_pipeline_info",
                return_value=SAMPLE_PIPELINE_INFO,
            ),
            patch(
                "wftools.gitlab.client.get_pipeline_test_report",
                return_value=SAMPLE_TEST_REPORT,
            ),
        ):
            result = runner.invoke(cli, ["mr", "exp", "42", "b007"])

        assert result.exit_code == 0
        assert "b007" in result.output
        assert "FAILED" in result.output
        assert "grib_set" in result.output

    def test_mr_exp_detail_not_found(self, runner, monkeypatch):
        """Shows error when experiment is not found in the pipeline."""
        monkeypatch.setenv("DESTINE_GITLAB_HOST", "gitlab.earth.bsc.es")
        monkeypatch.setenv("DESTINE_PROJECT", "digital-twins/de_340-2/workflow")

        with (
            patch(
                "wftools.gitlab.client.get_mr_pipelines",
                return_value=SAMPLE_MR_PIPELINES,
            ),
            patch(
                "wftools.gitlab.client.get_pipeline_info",
                return_value=SAMPLE_PIPELINE_INFO,
            ),
            patch(
                "wftools.gitlab.client.get_pipeline_test_report",
                return_value=SAMPLE_TEST_REPORT,
            ),
        ):
            result = runner.invoke(cli, ["mr", "exp", "42", "z999"])

        assert result.exit_code != 0

    def test_mr_exp_with_pipeline_override(self, runner, monkeypatch):
        """``--pipeline`` flag overrides the latest pipeline lookup."""
        monkeypatch.setenv("DESTINE_GITLAB_HOST", "gitlab.earth.bsc.es")
        monkeypatch.setenv("DESTINE_PROJECT", "digital-twins/de_340-2/workflow")

        with (
            patch(
                "wftools.gitlab.client.get_pipeline_info",
                return_value=SAMPLE_PIPELINE_INFO,
            ) as mock_info,
            patch(
                "wftools.gitlab.client.get_pipeline_test_report",
                return_value=SAMPLE_TEST_REPORT,
            ),
        ):
            result = runner.invoke(cli, ["mr", "exp", "42", "--pipeline", "36919"])

        assert result.exit_code == 0
        mock_info.assert_called_once_with("digital-twins/de_340-2/workflow", 36919)
