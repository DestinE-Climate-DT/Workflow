from __future__ import annotations

import json
import sys
from pathlib import Path

import click

import os

from wftools.tsuite import (
    DEFAULT_CONFIG_PATH,
    ChangedFiles,
    DetectionResult,
    Registry,
    check_required,
    load_registry,
    prepare_types,
    select_experiments,
)
from wftools.tsuite_collect import collect, receipt_path
from wftools.tsuite_pipeline import dump_pipeline, generate as generate_pipeline

_config_option = click.option(
    "--config",
    "config_path",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    default=str(DEFAULT_CONFIG_PATH),
    show_default=True,
    help="Path to the tsuite experiment-type registry YAML.",
)


@click.group()
def tsuite():
    """Experiment-type registry queries for the tsuite CI."""


@tsuite.command("select-type")
@_config_option
@click.argument("type_name")
def select_type(config_path, type_name):
    """Validate a single type name and emit ``[{"type": <name>}]`` on stdout.

    A typo fails with the list of valid names on stderr, so a mis-spelled
    manual override fails loudly instead of silently running nothing.
    """
    registry = load_registry(config_path)
    if type_name not in registry.names:
        click.echo(f"ERROR: '{type_name}' is not a known experiment type.", err=True)
        click.echo("Valid types: " + ", ".join(sorted(registry.names)), err=True)
        sys.exit(1)
    click.echo(json.dumps([{"type": type_name}]))


@tsuite.command("prepare-types")
@_config_option
@click.option(
    "--detected-json",
    default="[]",
    help='JSON array of detected types, e.g. [{"type":"ifs-nemo-lowres"}].',
)
@click.option(
    "--templates-dir",
    type=click.Path(path_type=Path),
    default="tests/tsuite_mains",
    show_default=True,
    help="Directory holding the tsuite-jacamar-{main,minimal}-<type>.yml pairs.",
)
@click.option(
    "--missing-file",
    type=click.Path(path_type=Path),
    default="missing_templates.txt",
    show_default=True,
    help="File to write the names of types lacking a template pair (one per line).",
)
def prepare_types_cmd(config_path, detected_json, templates_dir, missing_file):
    """Merge the detected types with the registry and template existence.

    Emits, on stdout, the CI JSON for every registry type that ships both
    templates (``[{"type","hpc","detected"}, ...]``), and writes the names of
    any types missing a template pair to ``--missing-file``.
    """
    registry = load_registry(config_path)
    detected_names = {entry["type"] for entry in json.loads(detected_json)}

    kept, missing = prepare_types(registry, detected_names, templates_dir)

    missing_file.write_text("".join(f"{name}\n" for name in missing))
    click.echo(json.dumps(kept))


def _read_source(
    registry: Registry, use_all: bool, file_path: Path | None
) -> DetectionResult:
    """Resolve --all / --file / stdin into a DetectionResult; exit 2 on error."""
    if use_all:
        return DetectionResult(
            experiments=list(registry.experiment_types), activated_tags={"ALL"}
        )
    if file_path:
        try:
            lines = file_path.read_text().strip().splitlines()
        except (OSError, PermissionError) as exc:
            click.echo(f"ERROR: cannot read file {file_path}: {exc}", err=True)
            sys.exit(2)
        return select_experiments(registry, ChangedFiles.from_lines(lines))
    if not sys.stdin.isatty():
        lines = sys.stdin.read().strip().splitlines()
        return select_experiments(registry, ChangedFiles.from_lines(lines))
    click.echo("ERROR: provide changed files via --file, stdin, or use --all", err=True)
    sys.exit(2)


def _log_verbose(result: DetectionResult, registry: Registry) -> None:
    click.echo("=== Matched Rules ===", err=True)
    for match in result.matches:
        click.echo(f"  {match.filepath}", err=True)
        click.echo(f"    pattern: {match.rule.pattern}", err=True)
        click.echo(f"    tags:    {', '.join(sorted(match.rule.tags))}", err=True)
    click.echo(f"=== Activated Tags ({len(result.activated_tags)}) ===", err=True)
    click.echo(f"  {', '.join(sorted(result.activated_tags))}", err=True)
    click.echo(
        f"=== Selected Experiment Types "
        f"({len(result.experiments)}/{len(registry.experiment_types)}) ===",
        err=True,
    )
    for experiment in result.experiments:
        matching = experiment.tags & result.activated_tags
        click.echo(
            f"  {experiment.name} ({experiment.hpc}): {experiment.description}",
            err=True,
        )
        click.echo(f"    matched on: {', '.join(sorted(matching))}", err=True)


@tsuite.command("detect")
@_config_option
@click.option(
    "--file",
    "-f",
    "file_path",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="Read changed files from this file (one per line).",
)
@click.option(
    "--all",
    "use_all",
    is_flag=True,
    help="Force all experiment types (bypasses detection).",
)
@click.option(
    "--dotenv",
    type=click.Path(path_type=Path),
    help="Write TSUITE_TYPES_JSON=<result> to this dotenv file.",
)
@click.option(
    "--verbose",
    "-v",
    is_flag=True,
    help="Emit matching details on stderr.",
)
@click.option(
    "--json",
    "as_full_record",
    is_flag=True,
    help="Emit the full detection record (types + activated tags + counts) instead of the compact CI JSON.",
)
def detect_cmd(config_path, file_path, use_all, dotenv, verbose, as_full_record):
    """Detect which tsuite experiment types to run based on MR changed files.

    Reads a list of changed file paths (one per line on stdin or from
    ``--file``) and emits the CI JSON on stdout.  Stdout is always valid
    JSON, even ``[]`` on no-match, so downstream consumers can parse
    unconditionally.  No-match is a valid outcome (e.g. an MR touching only
    docs); CI has the same fallback -- it writes ``[]`` when the
    changed-files list is empty.
    """
    if use_all and file_path:
        raise click.UsageError("--all and --file are mutually exclusive.")

    registry = load_registry(config_path)
    result = _read_source(registry, use_all, file_path)

    if verbose:
        _log_verbose(result, registry)

    if as_full_record:
        click.echo(
            json.dumps(
                {
                    "types": [et.as_record() for et in result.experiments],
                    "activated_tags": sorted(result.activated_tags),
                    "count": len(result.experiments),
                    "total": len(registry.experiment_types),
                },
                indent=2,
            )
        )
    else:
        click.echo(result.as_json())
        if not result.experiments:
            click.echo(
                "WARNING: no experiment types matched the changed files.",
                err=True,
            )

    if dotenv:
        # Always write when --dotenv is set, so downstream jobs never have
        # to check for a missing file.
        dotenv.write_text(f"TSUITE_TYPES_JSON={result.as_json()}\n")
        click.echo(f"Wrote {dotenv}: {len(result.experiments)} types", err=True)


@tsuite.command("collect")
@click.option(
    "--shared-dir",
    required=True,
    type=click.Path(path_type=Path),
    help="Directory the child pipeline's monitor/resources jobs wrote results to.",
)
@click.option(
    "--reports-dir",
    type=click.Path(path_type=Path),
    default=Path("reports"),
    show_default=True,
    help="Directory to publish the collected reports into.",
)
@click.option(
    "--types-json",
    default="[]",
    help="TSUITE_TYPES_JSON value; used only to explain an empty collection.",
)
@click.option("--job-url", default="", help="URL of this collect job, for the receipt.")
def collect_cmd(shared_dir, reports_dir, types_json, job_url):
    """Publish the child pipeline's JUnit + metrics into the parent's reports.

    GitLab does not surface a child pipeline's JUnit in the parent MR widget,
    so this re-uploads it.  It runs once -- the bridge it waits on resolves
    when the child first reaches a terminal state, and a later retry of a child
    chain cannot re-open the parent's report stage.  Everything published is
    therefore stamped with the source expid and producing child job id, and a
    receipt is left behind so the next attempt can see it was superseded.

    Exit code: 0 collected (or nothing to collect), 1 retried with no new
    results, 2 bad JSON input.
    """
    result = collect(shared_dir, reports_dir, job_url=job_url)

    if result.status == "stale":
        click.echo(f"ERROR: nothing new to collect in {shared_dir}.")
        click.echo(
            f"\nThis pipeline's results were already collected:\n{result.prior_receipt}"
        )
        click.echo(
            "Re-running this job cannot recover them -- the shared directory was\n"
            "emptied by the first collection.  Re-run the whole parent pipeline, or\n"
            "re-run the child chain first and then retry this job."
        )
        sys.exit(1)

    if result.status == "empty":
        try:
            detected = sum(1 for t in json.loads(types_json) if t.get("detected"))
        except (json.JSONDecodeError, AttributeError) as exc:
            click.echo(f"ERROR: invalid TSUITE_TYPES_JSON: {exc}", err=True)
            sys.exit(2)
        click.echo(f"No results directory: {shared_dir}")
        if detected:
            # Exit 0 regardless so tsuite-required still runs and produces the
            # authoritative per-type gate result.
            click.echo(
                f"{detected} required type(s) were detected for this MR but nothing was\n"
                "collected.  The tsuite-required gate will fail for the missing types."
            )
        else:
            click.echo("No types were detected for this MR -- nothing to collect.")
        return

    if result.prior_receipt:
        click.echo(
            "NOTE: this supersedes an earlier collection of the same pipeline:\n"
            f"{result.prior_receipt}"
        )

    click.echo(f"Collected {len(result.reports)} report(s) from {shared_dir}:")
    for report in result.reports:
        click.echo(f"  {report.name}")
    click.echo("\nSources:")
    for source in result.sources:
        click.echo(f"  {source.as_line()}")
    click.echo("\nMetrics:")
    for key, value in result.metrics.items():
        click.echo(f"  {key} {value}")
    click.echo(f"\nReceipt: {receipt_path(shared_dir)}")


@tsuite.command("required")
@click.option(
    "--types-json",
    required=True,
    help="TSUITE_TYPES_JSON value (JSON array with detected:bool per entry).",
)
@click.option(
    "--reports-dir",
    type=click.Path(path_type=Path),
    default=Path("reports"),
    show_default=True,
    help="Directory containing the collected tsuite-report-*.xml files.",
)
def required_cmd(types_json, reports_dir):
    """MR-blocking gate: every detected type must have run and passed.

    For every entry in TSUITE_TYPES_JSON flagged ``detected: true``:

    * find the matching ``tsuite-report-*.xml`` (aggregated by tsuite-collect
      from the child pipeline's ``monitor-{type}`` job);
    * fail iff the file is missing (= the required ``expid-{type}`` job was
      not clicked) or contains any ``<failure>`` / ``<error>`` cases.

    Optional types (``detected: false``) are ignored -- they never gate.

    Exit code: 0 all-pass, 1 any-fail, 2 bad JSON input.
    """
    try:
        types = json.loads(types_json)
    except json.JSONDecodeError as exc:
        click.echo(f"ERROR: invalid TSUITE_TYPES_JSON: {exc}", err=True)
        click.echo(f"Input: {types_json!r}", err=True)
        sys.exit(2)

    detected = [t for t in types if t.get("detected")]
    click.echo(f"Required (detected) types: {[t['type'] for t in detected]}")

    if not detected:
        click.echo("\nNo detected types in this MR -- gate trivially passes.")
        sys.exit(0)

    passed, failed = check_required(detected, reports_dir)

    click.echo("")
    for name, reason in failed:
        click.echo(f"FAIL: required type {name!r}: {reason}")
    for name in passed:
        click.echo(f"PASS: required type {name!r}")

    click.echo(
        f"\nSummary: {len(failed)} required type(s) failing, {len(passed)} passing."
    )
    sys.exit(1 if failed else 0)


@tsuite.command("generate-pipeline")
@click.option(
    "--types-json",
    help="JSON array of type objects (overrides --from-env).",
)
@click.option(
    "--from-env",
    is_flag=True,
    help="Read the JSON array from $TSUITE_TYPES_JSON.",
)
@click.option(
    "--parent-pipeline-id",
    default="",
    help="Parent pipeline ID (embedded in the child's PARENT_PIPELINE_ID var).",
)
def generate_pipeline_cmd(types_json, from_env, parent_pipeline_id):
    """Emit the child-pipeline YAML for a list of experiment types on stdout.

    Reads the type list from ``--types-json`` or, with ``--from-env``, from
    the ``TSUITE_TYPES_JSON`` environment variable.  Each type produces the
    expid -> create -> run -> monitor -> delete job chain (plus a manual
    force-delete for every type).
    """
    if from_env:
        raw = os.environ.get("TSUITE_TYPES_JSON", "")
        if not raw:
            click.echo("ERROR: $TSUITE_TYPES_JSON is empty.", err=True)
            sys.exit(1)
        types = json.loads(raw)
    elif types_json:
        types = json.loads(types_json)
    else:
        click.echo("ERROR: provide --types-json or --from-env.", err=True)
        sys.exit(1)

    if not types:
        click.echo("ERROR: no experiment types provided.", err=True)
        sys.exit(1)

    pipeline = generate_pipeline(types, parent_pipeline_id=parent_pipeline_id)
    click.echo(dump_pipeline(pipeline), nl=False)
