from __future__ import annotations

import asyncio
from unittest.mock import MagicMock

import pytest

fastmcp = pytest.importorskip("fastmcp")


def _registered_tool_names() -> list[str]:
    """Return names of tools registered on the MCP server (async API)."""
    from wftools.mcp.server import mcp as _mcp

    return [t.name for t in asyncio.run(_mcp.list_tools())]


from wftools.mcp.server import (  # noqa: E402
    get_experiment,
    get_pipeline_experiments,
    list_experiments,
    list_failed_cases,
    mcp as mcp_server,
    open_test_report,
)


# ---------------------------------------------------------------------------
# Sample data
# ---------------------------------------------------------------------------

SAMPLE_TEST_REPORT = {
    "test_suites": [
        {
            "name": "tsuite",
            "test_cases": [
                {
                    "name": "LOCAL_SETUP",
                    "classname": "a006",
                    "status": "success",
                    "system_output": "",
                },
                {
                    "name": "SIM",
                    "classname": "a006",
                    "status": "success",
                    "system_output": "",
                },
                {
                    "name": "grib_set",
                    "classname": "a006",
                    "status": "failed",
                    "system_output": "grib_set: No messages found",
                },
                {
                    "name": "LOCAL_SETUP",
                    "classname": "b007",
                    "status": "success",
                    "system_output": "",
                },
                {
                    "name": "SIM",
                    "classname": "b007",
                    "status": "success",
                    "system_output": "",
                },
                # Experiment whose workflow aborted before any job ran:
                # everything skipped, zero failures.  Must NOT count as passed.
                {
                    "name": "LOCAL_SETUP",
                    "classname": "c008",
                    "status": "skipped",
                    "system_output": "",
                },
                {
                    "name": "SIM",
                    "classname": "c008",
                    "status": "skipped",
                    "system_output": "",
                },
            ],
        }
    ]
}

SAMPLE_PIPELINES = [
    {
        "id": 36919,
        "status": "success",
        "web_url": "https://gitlab.example.com/pipelines/36919",
    },
    {
        "id": 36900,
        "status": "failed",
        "web_url": "https://gitlab.example.com/pipelines/36900",
    },
]

SAMPLE_PIPELINE_INFO = {
    "id": 36919,
    "status": "success",
    "created_at": "2026-04-27T10:00:00Z",
    "web_url": "https://gitlab.example.com/pipelines/36919",
    "sha": "abc123def456",
    "ref": "feature/foo",
}

MOCK_PROJECT = "digital-twins/de_340-2/workflow"
MOCK_HOST = "gitlab.earth.bsc.es"


# ---------------------------------------------------------------------------
# Fixture: patch the server's imports before every test
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _mock_server_deps(monkeypatch):
    """Patch server-level references so no real GitLab calls are made."""
    monkeypatch.setattr(
        "wftools.mcp.server.get_mr_pipelines",
        MagicMock(return_value=SAMPLE_PIPELINES),
    )
    monkeypatch.setattr(
        "wftools.mcp.server.get_pipeline_test_report",
        MagicMock(return_value=SAMPLE_TEST_REPORT),
    )
    monkeypatch.setattr(
        "wftools.mcp.server.get_pipeline_info",
        MagicMock(return_value=SAMPLE_PIPELINE_INFO),
    )
    monkeypatch.setattr(
        "wftools.mcp.server.get_project",
        MagicMock(return_value=MOCK_PROJECT),
    )
    monkeypatch.setattr(
        "wftools.mcp.server.get_host",
        MagicMock(return_value=MOCK_HOST),
    )


# ---------------------------------------------------------------------------
# Tests: tool registration
# ---------------------------------------------------------------------------


class TestToolRegistration:
    def test_server_has_name(self):
        assert mcp_server.name == "destine"

    def test_list_experiments_registered(self):
        assert "list_experiments" in _registered_tool_names()

    def test_get_experiment_registered(self):
        assert "get_experiment" in _registered_tool_names()

    def test_get_pipeline_experiments_registered(self):
        assert "get_pipeline_experiments" in _registered_tool_names()

    def test_open_test_report_registered(self):
        assert "open_test_report" in _registered_tool_names()

    def test_list_failed_cases_registered(self):
        assert "list_failed_cases" in _registered_tool_names()

    def test_all_tools_count(self):
        assert len(_registered_tool_names()) == 5


# ---------------------------------------------------------------------------
# Tests: list_experiments
# ---------------------------------------------------------------------------


class TestListExperiments:
    def test_returns_list(self):
        result = list_experiments(mr_iid=42)
        assert isinstance(result, list)

    def test_returns_three_experiments(self):
        result = list_experiments(mr_iid=42)
        assert len(result) == 3

    def test_experiment_keys(self):
        result = list_experiments(mr_iid=42)
        expected = {
            "expid",
            "passed",
            "total",
            "passed_count",
            "failed_count",
            "skipped_count",
            "failures",
            "url",
            "pipeline_id",
            "pipeline_url",
            "sha",
            "ref",
        }
        for exp in result:
            assert expected.issubset(exp.keys())

    def test_experiment_a006_has_failure(self):
        result = list_experiments(mr_iid=42)
        a006 = next(e for e in result if e["expid"] == "a006")
        assert a006["passed"] is False
        assert a006["total"] == 3
        assert a006["passed_count"] == 2
        assert a006["failed_count"] == 1
        assert a006["failures"] == 1
        assert a006["skipped_count"] == 0

    def test_experiment_b007_passes(self):
        result = list_experiments(mr_iid=42)
        b007 = next(e for e in result if e["expid"] == "b007")
        assert b007["passed"] is True
        assert b007["total"] == 2
        assert b007["passed_count"] == 2
        assert b007["failed_count"] == 0
        assert b007["skipped_count"] == 0

    def test_all_skipped_is_not_passing(self):
        """Workflow aborted before any job ran -> not a pass."""
        result = list_experiments(mr_iid=42)
        c008 = next(e for e in result if e["expid"] == "c008")
        assert c008["passed"] is False
        assert c008["total"] == 2
        assert c008["passed_count"] == 0
        assert c008["failed_count"] == 0
        assert c008["skipped_count"] == 2

    def test_pipeline_metadata_present(self):
        result = list_experiments(mr_iid=42)
        for exp in result:
            assert exp["pipeline_id"] == 36919
            assert exp["sha"] == "abc123def456"
            assert exp["ref"] == "feature/foo"
            assert exp["pipeline_url"].endswith("/36919")

    def test_status_filter_passed(self):
        result = list_experiments(mr_iid=42, status_filter="passed")
        assert [e["expid"] for e in result] == ["b007"]

    def test_status_filter_failed(self):
        result = list_experiments(mr_iid=42, status_filter="failed")
        assert [e["expid"] for e in result] == ["a006"]

    def test_status_filter_skipped(self):
        result = list_experiments(mr_iid=42, status_filter="skipped")
        assert [e["expid"] for e in result] == ["c008"]

    def test_status_filter_invalid_raises(self):
        with pytest.raises(ValueError):
            list_experiments(mr_iid=42, status_filter="bogus")

    def test_url_contains_pipeline_id(self):
        result = list_experiments(mr_iid=42)
        for exp in result:
            assert "36919" in exp["url"]

    def test_explicit_project_path(self):
        result = list_experiments(mr_iid=42, project_path="custom/project")
        for exp in result:
            assert "custom/project" in exp["url"]

    def test_empty_pipelines_returns_empty_list(self, monkeypatch):
        monkeypatch.setattr(
            "wftools.mcp.server.get_mr_pipelines",
            MagicMock(return_value=[]),
        )
        result = list_experiments(mr_iid=99)
        assert result == []


# ---------------------------------------------------------------------------
# Tests: get_experiment
# ---------------------------------------------------------------------------


class TestGetExperiment:
    def test_returns_dict(self):
        result = get_experiment(expid="a006", mr_iid=42)
        assert isinstance(result, dict)

    def test_experiment_keys(self):
        result = get_experiment(expid="a006", mr_iid=42)
        assert "expid" in result
        assert "passed" in result
        assert "url" in result
        assert "test_cases" in result
        assert "passed_count" in result
        assert "failed_count" in result
        assert "skipped_count" in result
        assert "pipeline_id" in result
        assert "sha" in result
        assert "ref" in result

    def test_a006_has_correct_test_count(self):
        result = get_experiment(expid="a006", mr_iid=42)
        assert len(result["test_cases"]) == 3

    def test_test_case_keys(self):
        result = get_experiment(expid="a006", mr_iid=42)
        for tc in result["test_cases"]:
            assert "name" in tc
            assert "status" in tc
        # Only the failing case carries a message field.
        failed = [tc for tc in result["test_cases"] if tc["status"] == "failed"]
        assert all("message" in tc for tc in failed)

    def test_failed_case_has_message(self):
        result = get_experiment(expid="a006", mr_iid=42)
        failed = [tc for tc in result["test_cases"] if tc["status"] == "failed"]
        assert len(failed) == 1
        assert "grib_set" in failed[0]["message"]

    def test_unknown_expid_returns_empty_cases(self):
        result = get_experiment(expid="zzzz", mr_iid=42)
        assert result["expid"] == "zzzz"
        assert result["test_cases"] == []
        # No cases at all: not passed (passed_count == 0).
        assert result["passed"] is False

    def test_all_skipped_expid_is_not_passing(self):
        result = get_experiment(expid="c008", mr_iid=42)
        assert result["passed"] is False
        assert result["skipped_count"] == 2
        assert result["passed_count"] == 0

    def test_accepts_pipeline_id_directly(self):
        result = get_experiment(expid="a006", pipeline_id=36919)
        assert result["expid"] == "a006"
        assert result["pipeline_id"] == 36919

    def test_requires_mr_or_pipeline(self):
        with pytest.raises(ValueError):
            get_experiment(expid="a006")

    def test_no_pipelines_returns_error(self, monkeypatch):
        monkeypatch.setattr(
            "wftools.mcp.server.get_mr_pipelines",
            MagicMock(return_value=[]),
        )
        result = get_experiment(expid="a006", mr_iid=99)
        assert "error" in result
        assert result["test_cases"] == []


# ---------------------------------------------------------------------------
# Tests: get_pipeline_experiments
# ---------------------------------------------------------------------------


class TestGetPipelineExperiments:
    def test_returns_list(self):
        result = get_pipeline_experiments(pipeline_id=36919)
        assert isinstance(result, list)

    def test_returns_three_experiments(self):
        result = get_pipeline_experiments(pipeline_id=36919)
        assert len(result) == 3

    def test_experiment_keys(self):
        result = get_pipeline_experiments(pipeline_id=36919)
        for exp in result:
            assert "expid" in exp
            assert "passed" in exp
            assert "total" in exp
            assert "failures" in exp
            assert "passed_count" in exp
            assert "failed_count" in exp
            assert "skipped_count" in exp
            assert "url" in exp

    def test_url_contains_pipeline_id(self):
        result = get_pipeline_experiments(pipeline_id=36919)
        for exp in result:
            assert "36919" in exp["url"]

    def test_status_filter(self):
        result = get_pipeline_experiments(pipeline_id=36919, status_filter="failed")
        assert [e["expid"] for e in result] == ["a006"]


# ---------------------------------------------------------------------------
# Tests: open_test_report
# ---------------------------------------------------------------------------


class TestOpenTestReport:
    def test_returns_string(self):
        result = open_test_report(expid="a006", mr_iid=42)
        assert isinstance(result, str)

    def test_url_contains_project_path(self):
        result = open_test_report(expid="a006", mr_iid=42)
        assert MOCK_PROJECT in result

    def test_url_contains_pipeline_id(self):
        result = open_test_report(expid="a006", mr_iid=42)
        assert "36919" in result

    def test_url_contains_expid(self):
        result = open_test_report(expid="a006", mr_iid=42)
        assert "report-a006" in result

    def test_accepts_pipeline_id(self):
        result = open_test_report(expid="a006", pipeline_id=36919)
        assert "36919" in result
        assert "report-a006" in result

    def test_requires_mr_or_pipeline(self):
        with pytest.raises(ValueError):
            open_test_report(expid="a006")

    def test_no_pipelines_returns_message(self, monkeypatch):
        monkeypatch.setattr(
            "wftools.mcp.server.get_mr_pipelines",
            MagicMock(return_value=[]),
        )
        result = open_test_report(expid="a006", mr_iid=99)
        assert "No pipelines found" in result

    def test_explicit_project_path(self):
        result = open_test_report(expid="a006", mr_iid=42, project_path="other/project")
        assert "other/project" in result


# ---------------------------------------------------------------------------
# Tests: list_failed_cases
# ---------------------------------------------------------------------------


class TestListFailedCases:
    def test_returns_list(self):
        result = list_failed_cases(mr_iid=42)
        assert isinstance(result, list)

    def test_returns_only_failed_cases(self):
        result = list_failed_cases(mr_iid=42)
        # Sample only has one failed case (grib_set on a006).
        assert len(result) == 1
        assert result[0]["status"] == "failed"
        assert result[0]["name"] == "grib_set"
        assert result[0]["expid"] == "a006"

    def test_entry_has_message_and_url(self):
        result = list_failed_cases(mr_iid=42)
        entry = result[0]
        assert "grib_set" in entry["message"]
        assert "report-a006" in entry["url"]

    def test_filter_by_expid(self):
        result = list_failed_cases(mr_iid=42, expid="b007")
        assert result == []

    def test_filter_by_expid_with_failure(self):
        result = list_failed_cases(mr_iid=42, expid="a006")
        assert len(result) == 1
        assert result[0]["expid"] == "a006"

    def test_accepts_pipeline_id(self):
        result = list_failed_cases(pipeline_id=36919)
        assert len(result) == 1
        assert result[0]["expid"] == "a006"

    def test_requires_mr_or_pipeline(self):
        with pytest.raises(ValueError):
            list_failed_cases()

    def test_no_pipelines_returns_empty(self, monkeypatch):
        monkeypatch.setattr(
            "wftools.mcp.server.get_mr_pipelines",
            MagicMock(return_value=[]),
        )
        assert list_failed_cases(mr_iid=99) == []
