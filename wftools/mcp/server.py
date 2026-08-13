from __future__ import annotations

try:
    from fastmcp import FastMCP
except ImportError:
    raise ImportError(
        "fastmcp is required for the MCP server. "
        "Install with: pip install 'climate-dt-workflow[mcp]'"
    )

from wftools.config import get_host, get_project
from wftools.gitlab.client import (
    get_mr_pipelines,
    get_pipeline_info,
    get_pipeline_test_report,
)

mcp = FastMCP("destine")

PASS_STATUSES = ("success",)
FAIL_STATUSES = ("failed", "error")
SKIP_STATUSES = ("skipped",)


def _resolve_project(project_path: str | None) -> str:
    """Return the given project path or fall back to the configured default."""
    if project_path is not None:
        return project_path
    return get_project()


def _group_test_cases_by_expid(test_report: dict) -> dict[str, list[dict]]:
    """Group test cases from a GitLab test report by classname (expid).

    The GitLab test report structure contains test_suites, each with
    test_cases that have a classname field corresponding to the expid.
    """
    groups: dict[str, list[dict]] = {}
    for suite in test_report.get("test_suites", []):
        for case in suite.get("test_cases", []):
            classname = case.get("classname", "unknown")
            groups.setdefault(classname, []).append(case)
    return groups


def _build_experiment_url(project_path: str, pipeline_id: int, expid: str) -> str:
    """Build the URL to the GitLab test report filtered to this experiment."""
    host = get_host()
    return (
        f"https://{host}/{project_path}/-/pipelines/"
        f"{pipeline_id}/test_report?job_name=report-{expid}"
    )


def _count_statuses(cases: list[dict]) -> tuple[int, int, int]:
    """Return (passed_count, failed_count, skipped_count) for a case list."""
    passed = sum(1 for c in cases if c.get("status") in PASS_STATUSES)
    failed = sum(1 for c in cases if c.get("status") in FAIL_STATUSES)
    skipped = sum(1 for c in cases if c.get("status") in SKIP_STATUSES)
    return passed, failed, skipped


def _summarize_experiment(
    expid: str,
    cases: list[dict],
    project_path: str,
    pipeline_meta: dict,
) -> dict:
    """Build a summary dict for an experiment from its test cases.

    Pass criterion: zero failures *and* at least one actually-passing case.
    All-skipped suites (e.g. AS workflow aborted before any job executed)
    are flagged as not-passed even though `failed_count == 0`.
    """
    pipeline_id = pipeline_meta["id"]
    total = len(cases)
    passed_count, failed_count, skipped_count = _count_statuses(cases)
    url = _build_experiment_url(project_path, pipeline_id, expid)
    return {
        "expid": expid,
        "passed": failed_count == 0 and passed_count > 0,
        "total": total,
        "passed_count": passed_count,
        "failed_count": failed_count,
        "skipped_count": skipped_count,
        # back-compat alias
        "failures": failed_count,
        "url": url,
        "pipeline_id": pipeline_id,
        "pipeline_url": pipeline_meta.get("web_url"),
        "sha": pipeline_meta.get("sha"),
        "ref": pipeline_meta.get("ref"),
    }


def _filter_status(summaries: list[dict], status_filter: str | None) -> list[dict]:
    """Filter summaries by status: 'passed', 'failed', 'skipped', or None."""
    if status_filter is None:
        return summaries
    sf = status_filter.lower()
    if sf == "passed":
        return [s for s in summaries if s["passed"]]
    if sf == "failed":
        return [s for s in summaries if s["failed_count"] > 0]
    if sf == "skipped":
        return [s for s in summaries if not s["passed"] and s["failed_count"] == 0]
    raise ValueError(
        f"Unknown status_filter {status_filter!r}; expected one of "
        "passed/failed/skipped or None."
    )


def _resolve_latest_pipeline_id(project: str, mr_iid: int) -> int | None:
    """Latest pipeline ID for an MR, or None if none exist."""
    pipelines = get_mr_pipelines(project, mr_iid)
    if not pipelines:
        return None
    return pipelines[0]["id"]


def _experiments_for_pipeline(
    project: str,
    pipeline_id: int,
    status_filter: str | None,
) -> list[dict]:
    """Build per-expid summaries for one pipeline, optionally filtered."""
    pipeline_meta = get_pipeline_info(project, pipeline_id)
    test_report = get_pipeline_test_report(project, pipeline_id)
    groups = _group_test_cases_by_expid(test_report)
    summaries = [
        _summarize_experiment(expid, cases, project, pipeline_meta)
        for expid, cases in sorted(groups.items())
    ]
    return _filter_status(summaries, status_filter)


@mcp.tool()
def list_experiments(
    mr_iid: int,
    project_path: str | None = None,
    status_filter: str | None = None,
) -> list[dict]:
    """List all experiments and their pass/fail status for an MR's latest pipeline.

    Each summary includes:

    - ``expid`` and a human ``passed`` boolean (true only when at least one
      case actually passed and zero failed; an all-skipped suite is *not*
      considered passing)
    - ``total``, ``passed_count``, ``failed_count``, ``skipped_count``
    - ``failures`` (back-compat alias for ``failed_count``)
    - ``url`` (deep-link to the GitLab test report for the experiment)
    - ``pipeline_id``, ``pipeline_url``, ``sha``, ``ref`` so callers can
      cross-reference glab / git without an extra round trip

    Pass ``status_filter`` ("passed" | "failed" | "skipped") to narrow the
    list.
    """
    project = _resolve_project(project_path)
    pipeline_id = _resolve_latest_pipeline_id(project, mr_iid)
    if pipeline_id is None:
        return []
    return _experiments_for_pipeline(project, pipeline_id, status_filter)


@mcp.tool()
def get_pipeline_experiments(
    pipeline_id: int,
    project_path: str | None = None,
    status_filter: str | None = None,
) -> list[dict]:
    """List all experiments in a specific pipeline by ID.

    Same shape as :func:`list_experiments` but addressed by pipeline ID
    directly rather than via a merge request.  Useful for branch pipelines
    that have no associated MR.
    """
    project = _resolve_project(project_path)
    return _experiments_for_pipeline(project, pipeline_id, status_filter)


def _case_summary(case: dict, max_msg: int = 500) -> dict:
    """Compact view of a single test case, with truncated failure message."""
    status = case.get("status", "unknown")
    summary: dict = {"name": case.get("name", ""), "status": status}
    if status in FAIL_STATUSES:
        msg = case.get("system_output", "") or case.get("message", "") or ""
        if len(msg) > max_msg:
            msg = msg[:max_msg] + "... [truncated]"
        summary["message"] = msg
    return summary


@mcp.tool()
def get_experiment(
    expid: str,
    mr_iid: int | None = None,
    pipeline_id: int | None = None,
    project_path: str | None = None,
) -> dict:
    """Get detailed test results for a specific experiment.

    Provide *either* ``mr_iid`` (uses latest pipeline on the MR) *or*
    ``pipeline_id`` (direct).  At least one must be set.

    Returns the experiment ID, pass/fail status, URL to the test report,
    pipeline metadata, status counts, and a list of individual test cases.
    Failure cases include a truncated message excerpt.
    """
    if mr_iid is None and pipeline_id is None:
        raise ValueError("get_experiment requires either mr_iid or pipeline_id")

    project = _resolve_project(project_path)

    if pipeline_id is None:
        resolved = _resolve_latest_pipeline_id(project, mr_iid)  # type: ignore[arg-type]
        if resolved is None:
            return {
                "expid": expid,
                "passed": False,
                "url": "",
                "test_cases": [],
                "error": "No pipelines found for this MR.",
            }
        pipeline_id = resolved

    pipeline_meta = get_pipeline_info(project, pipeline_id)
    test_report = get_pipeline_test_report(project, pipeline_id)
    groups = _group_test_cases_by_expid(test_report)
    cases = groups.get(expid, [])
    summary = _summarize_experiment(expid, cases, project, pipeline_meta)
    summary["test_cases"] = [_case_summary(c) for c in cases]
    return summary


@mcp.tool()
def list_failed_cases(
    mr_iid: int | None = None,
    pipeline_id: int | None = None,
    expid: str | None = None,
    project_path: str | None = None,
) -> list[dict]:
    """Flat list of failing test cases across experiments.

    Use to triage failures without paging through every experiment.

    Provide either ``mr_iid`` (uses latest pipeline) or ``pipeline_id``.
    Optionally restrict to a single ``expid``.

    Each entry contains ``expid``, case ``name``, ``status``, truncated
    ``message``, and the experiment-scoped ``url``.
    """
    if mr_iid is None and pipeline_id is None:
        raise ValueError("list_failed_cases requires either mr_iid or pipeline_id")

    project = _resolve_project(project_path)

    if pipeline_id is None:
        resolved = _resolve_latest_pipeline_id(project, mr_iid)  # type: ignore[arg-type]
        if resolved is None:
            return []
        pipeline_id = resolved

    test_report = get_pipeline_test_report(project, pipeline_id)
    groups = _group_test_cases_by_expid(test_report)

    out: list[dict] = []
    for cur_expid, cases in sorted(groups.items()):
        if expid is not None and cur_expid != expid:
            continue
        url = _build_experiment_url(project, pipeline_id, cur_expid)
        for case in cases:
            if case.get("status") not in FAIL_STATUSES:
                continue
            entry = _case_summary(case, max_msg=200)
            entry["expid"] = cur_expid
            entry["url"] = url
            out.append(entry)
    return out


@mcp.tool()
def open_test_report(
    expid: str,
    mr_iid: int | None = None,
    pipeline_id: int | None = None,
    project_path: str | None = None,
) -> str:
    """Return the direct URL to the GitLab test report for an experiment.

    Provide either ``mr_iid`` or ``pipeline_id``.  Use to share a link or
    open the report in a browser.
    """
    if mr_iid is None and pipeline_id is None:
        raise ValueError("open_test_report requires either mr_iid or pipeline_id")

    project = _resolve_project(project_path)

    if pipeline_id is None:
        resolved = _resolve_latest_pipeline_id(project, mr_iid)  # type: ignore[arg-type]
        if resolved is None:
            return f"No pipelines found for MR !{mr_iid} in {project}."
        pipeline_id = resolved

    return _build_experiment_url(project, pipeline_id, expid)
