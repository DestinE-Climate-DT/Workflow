from __future__ import annotations

import os
import subprocess
import sys

import click
from loguru import logger

from wftools.cli.commands._formatting import (
    format_experiment_detail,
    format_experiment_list,
)
from wftools.config import get_host, get_project


class MrProxyGroup(click.Group):
    """Click group for ``destine mr`` that forwards unknown subcommands to ``glab mr``."""

    def get_command(self, ctx, cmd_name):
        rv = super().get_command(ctx, cmd_name)
        if rv is not None:
            return rv
        return _make_mr_proxy(cmd_name)

    def resolve_command(self, ctx, args):
        cmd_name, cmd, cmd_args = super().resolve_command(ctx, args)
        return cmd_name, cmd, cmd_args


def _make_mr_proxy(cmd_name):
    @click.command(
        cmd_name,
        context_settings={"ignore_unknown_options": True, "allow_extra_args": True},
        add_help_option=False,
    )
    @click.argument("args", nargs=-1, type=click.UNPROCESSED)
    def proxy(args):
        result = subprocess.run(["glab", "mr", cmd_name] + list(args), env=os.environ)
        sys.exit(result.returncode)

    proxy.short_help = f"(proxied to glab mr {cmd_name})"
    return proxy


@click.group(cls=MrProxyGroup)
def mr():
    """Work with merge requests.

    Commands not handled natively are forwarded to ``glab mr``.
    """


def _get_pipeline_for_mr(
    project_path: str, mr_iid: int, pipeline_id: int | None = None
) -> int:
    """Resolve the pipeline ID for an MR.

    If *pipeline_id* is given, return it directly. Otherwise fetch the latest
    pipeline for the MR.
    """
    if pipeline_id is not None:
        return pipeline_id

    from wftools.gitlab.client import get_mr_pipelines

    pipelines = get_mr_pipelines(project_path, mr_iid)
    if not pipelines:
        click.echo(f"Error: No pipelines found for MR !{mr_iid}", err=True)
        raise SystemExit(1)

    return pipelines[0]["id"]


@mr.command()
@click.argument("iid", type=int)
@click.argument("expid", required=False, default=None)
@click.option(
    "--pipeline",
    "pipeline_id",
    type=int,
    default=None,
    help="Pipeline ID to use instead of latest.",
)
@click.option(
    "--open", "open_browser", is_flag=True, help="Open test report in browser."
)
@click.option(
    "--project", "project_path", default=None, help="GitLab project path override."
)
def exp(iid, expid, pipeline_id, open_browser, project_path):
    """List or inspect experiments in a merge request's pipeline.

    \b
    destine mr exp <iid>              List experiments in the latest pipeline.
    destine mr exp <iid> <expid>      Show detail for a specific experiment.
    destine mr exp <iid> <expid> --open  Open test report in browser.
    """
    from wftools.gitlab.client import get_pipeline_info, get_pipeline_test_report

    project = project_path or get_project()
    host = get_host()

    resolved_pipeline_id = _get_pipeline_for_mr(project, iid, pipeline_id)

    if open_browser and expid:
        report_url = (
            f"https://{host}/{project}/-/pipelines/"
            f"{resolved_pipeline_id}/test_report?job_name=report-{expid}"
        )
        click.launch(report_url)
        return

    logger.debug("Fetching pipeline #{} for MR !{}", resolved_pipeline_id, iid)
    info = get_pipeline_info(project, resolved_pipeline_id)
    report = get_pipeline_test_report(project, resolved_pipeline_id)

    if expid:
        format_experiment_detail(expid, info, report, host, project)
    else:
        format_experiment_list(info, report, host, project)
