"""Shared Rich formatters for experiment/pipeline output.

Used by both ``destine mr exp`` and ``destine pipeline exp`` so the two
commands render identical output.
"""

from __future__ import annotations

import sys

from rich.console import Console
from rich.text import Text


def format_experiment_list(
    pipeline_info: dict, test_report: dict, host: str, project: str
) -> None:
    """Print a Rich-formatted experiment list for a pipeline."""
    console = Console(file=sys.stdout, highlight=False)

    pipeline_id = pipeline_info["id"]
    pipeline_status = pipeline_info["status"]
    created_at = pipeline_info.get("created_at", "unknown")

    # Truncate timestamp to date+time
    if isinstance(created_at, str) and "T" in created_at:
        created_at = created_at.replace("T", " ")[:16]

    header = Text()
    header.append(f"Pipeline #{pipeline_id}", style="bold")
    header.append(
        f" ({pipeline_status})",
        style="green" if pipeline_status == "success" else "red",
    )
    header.append(f" -- {created_at}")
    console.print(header)

    suites = test_report.get("test_suites", [])
    if not suites:
        console.print("  No experiment results found.")
        return

    for suite in suites:
        name = suite.get("name", "unknown")
        total = suite.get("total_count", 0)
        failed = suite.get("failed_count", 0) + suite.get("error_count", 0)
        passed = total - failed
        status = "FAILED" if failed > 0 else "passed"

        line = Text("  ")
        line.append(f"{name:<8}", style="bold")
        if status == "passed":
            line.append(f"passed   ({total} tests)", style="green")
        else:
            line.append(
                f"FAILED   ({passed}/{total} passed, {failed} failure{'s' if failed != 1 else ''})",
                style="red",
            )

        console.print(line)


def format_experiment_detail(
    expid: str,
    pipeline_info: dict,
    test_report: dict,
    host: str,
    project: str,
) -> None:
    """Print Rich-formatted detail for a single experiment."""
    console = Console(file=sys.stdout, highlight=False)

    pipeline_id = pipeline_info["id"]

    suites = test_report.get("test_suites", [])
    suite = None
    for s in suites:
        if s.get("name") == expid:
            suite = s
            break

    if suite is None:
        console.print(
            f"[red]Experiment {expid} not found in pipeline #{pipeline_id}[/red]"
        )
        raise SystemExit(1)

    total = suite.get("total_count", 0)
    failed_count = suite.get("failed_count", 0) + suite.get("error_count", 0)
    passed_count = total - failed_count
    overall = "FAILED" if failed_count > 0 else "passed"

    report_url = (
        f"https://{host}/{project}/-/pipelines/"
        f"{pipeline_id}/test_report?job_name=report-{expid}"
    )

    header = Text()
    header.append(f"Experiment {expid}", style="bold")
    header.append(f" -- {overall}", style="green" if overall == "passed" else "red")
    console.print(header)
    console.print(f"Pipeline:  #{pipeline_id}")
    console.print(f"Report:    {report_url}")
    console.print()

    summary_parts = []
    if passed_count:
        summary_parts.append(f"{passed_count} passed")
    if failed_count:
        summary_parts.append(f"{failed_count} failed")
    console.print(f"Tests: {', '.join(summary_parts)}")
    console.print()

    test_cases = suite.get("test_cases", [])
    for tc in test_cases:
        tc_status = tc.get("status", "unknown")
        if tc_status in ("failed", "error"):
            tc_name = tc.get("name", "unknown")
            tc_classname = tc.get("classname", expid)
            tc_message = tc.get("system_output") or tc.get("message") or ""

            line = Text("  ")
            line.append("FAILED  ", style="bold red")
            line.append(f"{tc_classname} :: {tc_name}")
            console.print(line)

            if tc_message:
                for msg_line in tc_message.strip().splitlines():
                    console.print(f"    {msg_line}")
