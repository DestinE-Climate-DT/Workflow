from __future__ import annotations

import sys
from pathlib import Path

import click
from loguru import logger

from wftools.autosubmit.constants import ADD_ERROR_CAP, AS_DATA_ROOT
from wftools.autosubmit.parser import parse_experiment
from wftools.domain.models import TestCase, TestResult, TestSuite
from wftools.junit.writer import to_xml
from wftools.metrics.writer import to_metrics
from wftools.results.store import ResultStore
from wftools.util import strip_ansi


@click.group()
def report():
    """Test result reporting commands."""


@report.command()
@click.argument("testname")
@click.argument("status", type=click.Choice(["pass", "fail", "skip"]))
@click.argument(
    "error_file", required=False, default=None, type=click.Path(exists=True)
)
@click.option(
    "--results-dir",
    type=click.Path(),
    default="reports/tsuite_results",
    help="Directory for intermediate result JSON files.",
)
@click.option(
    "--classname",
    default=None,
    help=(
        "Optional 4-char expid to attach as JUnit classname.  When set, the "
        "case groups under that expid in destine MCP / GitLab test report; "
        "otherwise it lands in the unclassed parent bucket."
    ),
)
def add(testname, status, error_file, results_dir, classname):
    """Record a single coarse test result (pass/fail/skip)."""
    store = ResultStore(base_dir=Path(results_dir))

    error = None
    if error_file:
        content = strip_ansi(Path(error_file).read_text())
        error = content[:ADD_ERROR_CAP]

    common = dict(
        name=testname,
        passed=(status == "pass"),
        skipped=(status == "skip"),
        error=error,
    )
    if classname is not None:
        result = TestCase(classname=classname, **common)
    else:
        result = TestResult(**common)
    store.save(result)
    label = {"pass": "PASS", "fail": "FAIL", "skip": "SKIP"}[status]
    logger.info("{} {}", label, testname)


@report.command()
@click.argument("expid")
@click.argument("status_file", type=click.Path(exists=True))
@click.argument("run_log", required=False, default=None, type=click.Path(exists=True))
@click.option(
    "--results-dir",
    type=click.Path(),
    default="reports/tsuite_results",
    help="Directory for intermediate result JSON files.",
)
@click.option(
    "--data-root",
    type=click.Path(),
    default=str(AS_DATA_ROOT),
    help="Root of Autosubmit data directory.",
)
@click.option(
    "--name-prefix",
    default="",
    help=(
        "String prefixed to every test case display name (e.g. 'icon-r2b8/' "
        "so the GitLab Test Summary shows 'icon-r2b8/LOCAL_SETUP' rather "
        "than a context-free 'LOCAL_SETUP')."
    ),
)
@click.option(
    "--durations",
    type=click.Path(),
    default=None,
    help=(
        "Resource-accounting JSON ('destine resources report --json') to take "
        "job durations from where Autosubmit has not recovered a _STAT_ file "
        "yet.  Ignored if absent."
    ),
)
def parse(expid, status_file, run_log, results_dir, data_root, name_prefix, durations):
    """Parse Autosubmit status file and generate per-job results."""
    store = ResultStore(base_dir=Path(results_dir))

    run_log_path = Path(run_log) if run_log else None
    cases = parse_experiment(
        expid=expid,
        status_file=Path(status_file),
        run_log_file=run_log_path,
        data_root=Path(data_root),
        name_prefix=name_prefix,
        durations_file=Path(durations) if durations else None,
    )

    for case in cases:
        key = f"{expid}__{case.full_job_name or case.name}"
        store.save(case, key=key)

    logger.info("Parsed {} jobs for experiment {}", len(cases), expid)


@report.command()
@click.argument("output_file", type=click.Path())
@click.option(
    "--results-dir",
    type=click.Path(),
    default="reports/tsuite_results",
    help="Directory containing intermediate result JSON files.",
)
def generate(output_file, results_dir):
    """Generate JUnit XML from collected results."""
    store = ResultStore(base_dir=Path(results_dir))
    results = store.load_all()

    if not results:
        logger.error("No test results found in {}", results_dir)
        sys.exit(1)

    suite = TestSuite(cases=results)
    output = Path(output_file)
    output.parent.mkdir(parents=True, exist_ok=True)
    to_xml(suite, output)
    logger.info(
        "Generated JUnit XML: {} ({} tests, {} failures)",
        output,
        suite.total,
        suite.failures,
    )


@report.command()
@click.argument("output_file", type=click.Path())
@click.option(
    "--results-dir",
    type=click.Path(),
    default="reports/tsuite_results",
    help="Directory containing intermediate result JSON files.",
)
def metrics(output_file, results_dir):
    """Generate GitLab custom metrics file."""
    store = ResultStore(base_dir=Path(results_dir))
    results = store.load_all()

    if not results:
        logger.error("No test results found in {}", results_dir)
        sys.exit(1)

    suite = TestSuite(cases=results)
    output = Path(output_file)
    output.parent.mkdir(parents=True, exist_ok=True)
    to_metrics(suite, output)
    logger.info("Generated metrics: {}", output)


@report.command()
@click.option(
    "--results-dir",
    type=click.Path(),
    default="reports/tsuite_results",
    help="Directory containing intermediate result JSON files.",
)
def clean(results_dir):
    """Remove intermediate result files."""
    store = ResultStore(base_dir=Path(results_dir))
    count = store.clean()
    logger.info("Cleaned {} result files", count)
