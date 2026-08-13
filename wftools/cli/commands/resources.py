from __future__ import annotations

from pathlib import Path

import click
from loguru import logger

from wftools.resources import store
from wftools.resources.history import job_records
from wftools.resources.writer import build_usage, to_json, to_metrics


@click.group()
def resources():
    """HPC resource-accounting commands for the tsuite CI."""


@resources.command("job-ids")
@click.argument("expid")
@click.option(
    "--db", "db_path", type=click.Path(), default=None, help="History DB path."
)
def job_ids(expid, db_path):
    """Print this experiment's job ids, comma-separated, for `sacct -j`.

    Login-node PIDs are listed alongside SLURM ids; only sacct's answer, checked
    against the job name, tells the two apart.
    """
    ids = {record.job_id for record in job_records(expid, db_path)}
    click.echo(",".join(sorted(ids)))


@resources.command()
@click.argument("expid")
@click.argument("sacct_file", type=click.Path(exists=True))
@click.option(
    "--json",
    "json_out",
    type=click.Path(),
    default="reports/resources.json",
    help="Path for the per-experiment resources JSON artifact.",
)
@click.option(
    "--metrics",
    "metrics_out",
    type=click.Path(),
    default="reports/metrics-resources.txt",
    help="Path for the GitLab custom-metrics file.",
)
@click.option("--pipeline-id", type=int, default=None, help="CI pipeline id.")
@click.option("--commit-sha", default=None, help="Commit the experiment ran from.")
@click.option("--mr-iid", type=int, default=None, help="Merge request iid, if any.")
@click.option("--type-name", default=None, help="Experiment type (e.g. ifs-nemo-e2e).")
@click.option("--hpc", default=None, help="HPC the experiment ran on.")
@click.option(
    "--history-db",
    type=click.Path(),
    default=None,
    help="Autosubmit history DB (default: resolved from autosubmitrc).",
)
@click.option(
    "--db",
    "db_path",
    type=click.Path(),
    default=None,
    help=(
        "SQLite store to record this run in "
        f"(default: $CI_RESOURCES_DB, else {store.DEFAULT_DB_PATH})."
    ),
)
@click.option(
    "--no-db",
    is_flag=True,
    help="Write the JSON/metrics artifacts only; skip the SQLite store.",
)
def report(
    expid,
    sacct_file,
    json_out,
    metrics_out,
    pipeline_id,
    commit_sha,
    mr_iid,
    type_name,
    hpc,
    history_db,
    db_path,
    no_db,
):
    """Parse sacct output into a resource-usage JSON and metrics file."""
    sacct_text = Path(sacct_file).read_text()
    usage = build_usage(
        expid,
        sacct_text,
        history=job_records(expid, history_db),
        pipeline_id=pipeline_id,
        commit_sha=commit_sha,
        mr_iid=mr_iid,
        type_name=type_name,
        hpc=hpc,
    )

    to_json(usage, Path(json_out))
    to_metrics(usage, Path(metrics_out))

    unscheduled = usage.unscheduled
    logger.info(
        "Resources for {}: {} jobs over {} run(s), {:.2f} core-h used / "
        "{:.2f} billed, {:.2f} node-h, {:.2f} gpu-h, {:.3f} kWh",
        expid,
        usage.job_count,
        len(usage.run_ids) or 1,
        usage.core_hours_used,
        usage.core_hours_billed,
        usage.node_hours,
        usage.gpu_hours,
        usage.energy_kwh,
    )
    logger.info(
        "  of which {} scheduled and {} on login nodes/VM "
        "({:.2f} core-h used, unbilled)",
        usage.slurm_job_count,
        unscheduled.job_count,
        unscheduled.core_hours_used,
    )
    logger.info("Wrote {} and {}", json_out, metrics_out)

    # Telemetry, not a gate: save() warns on failure.
    if not no_db:
        store.save(usage, db_path)


@resources.command()
@click.option("--expid", default=None, help="Restrict the listing to one experiment.")
@click.option("--limit", type=int, default=20, show_default=True)
@click.option(
    "--db",
    "db_path",
    type=click.Path(),
    default=None,
    help="SQLite store to read (default: $CI_RESOURCES_DB, else the deployed path).",
)
def history(expid, limit, db_path):
    """List previously recorded CI resource footprints, newest first."""
    rows = store.summarize(db_path, expid=expid)
    if not rows:
        click.echo("No records found.")
        return

    header = (
        f"{'expid':<6} {'type':<26} {'commit':<10} {'core-h used':>12} "
        f"{'billed':>10} {'gpu-h':>8}  created"
    )
    click.echo(header)
    click.echo("-" * len(header))
    for row in rows[:limit]:
        click.echo(
            f"{row['expid']:<6} "
            f"{(row['type_name'] or '-'):<26} "
            f"{(row['commit_sha'] or '-')[:10]:<10} "
            f"{row['core_hours_used']:>12.2f} "
            f"{row['core_hours_billed']:>10.2f} "
            f"{row['gpu_hours']:>8.2f}  "
            f"{row['created_at']}"
        )


@resources.command()
@click.option("--expid", default=None, help="Restrict the breakdown to one experiment.")
@click.option(
    "--db",
    "db_path",
    type=click.Path(),
    default=None,
    help="SQLite store to read (default: $CI_RESOURCES_DB, else the deployed path).",
)
def sections(expid, db_path):
    """Break recorded cost down by Autosubmit section, most expensive first."""
    _print_grouped("section", store.sections(db_path, expid=expid))


@resources.command()
@click.option("--expid", default=None, help="Restrict the breakdown to one experiment.")
@click.option(
    "--db",
    "db_path",
    type=click.Path(),
    default=None,
    help="SQLite store to read (default: $CI_RESOURCES_DB, else the deployed path).",
)
def executions(expid, db_path):
    """Break recorded cost down by where jobs ran: slurm, login or local."""
    _print_grouped("execution", store.executions(db_path, expid=expid))


def _print_grouped(label: str, rows: list) -> None:
    if not rows:
        click.echo("No records found.")
        return

    header = (
        f"{label:<24} {'jobs':>6} {'core-h used':>12} {'billed':>10} "
        f"{'gpu-h':>8} {'hours':>8}"
    )
    click.echo(header)
    click.echo("-" * len(header))
    for row in rows:
        click.echo(
            f"{row['name']:<24} "
            f"{row['job_count']:>6} "
            f"{row['core_hours_used']:>12.2f} "
            f"{row['core_hours_billed']:>10.2f} "
            f"{row['gpu_hours']:>8.2f} "
            f"{row['elapsed_s'] / 3600.0:>8.2f}"
        )
