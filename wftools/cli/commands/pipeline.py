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


class PipelineProxyGroup(click.Group):
    """Click group for ``destine pipeline`` that forwards unknown subcommands to ``glab ci``."""

    def get_command(self, ctx, cmd_name):
        rv = super().get_command(ctx, cmd_name)
        if rv is not None:
            return rv
        return _make_pipeline_proxy(cmd_name)

    def resolve_command(self, ctx, args):
        cmd_name, cmd, cmd_args = super().resolve_command(ctx, args)
        return cmd_name, cmd, cmd_args


def _make_pipeline_proxy(cmd_name):
    @click.command(
        cmd_name,
        context_settings={"ignore_unknown_options": True, "allow_extra_args": True},
        add_help_option=False,
    )
    @click.argument("args", nargs=-1, type=click.UNPROCESSED)
    def proxy(args):
        result = subprocess.run(["glab", "ci", cmd_name] + list(args), env=os.environ)
        sys.exit(result.returncode)

    proxy.short_help = f"(proxied to glab ci {cmd_name})"
    return proxy


@click.group(cls=PipelineProxyGroup)
def pipeline():
    """Work with pipelines.

    Commands not handled natively are forwarded to ``glab ci``.
    """


@pipeline.command()
@click.argument("pipeline_id", type=int)
@click.argument("expid", required=False, default=None)
@click.option(
    "--open", "open_browser", is_flag=True, help="Open test report in browser."
)
@click.option(
    "--project", "project_path", default=None, help="GitLab project path override."
)
def exp(pipeline_id, expid, open_browser, project_path):
    """List or inspect experiments in a pipeline.

    \b
    destine pipeline exp <id>              List experiments.
    destine pipeline exp <id> <expid>      Show detail for a specific experiment.
    destine pipeline exp <id> <expid> --open  Open test report in browser.
    """
    from wftools.gitlab.client import get_pipeline_info, get_pipeline_test_report

    project = project_path or get_project()
    host = get_host()

    if open_browser and expid:
        report_url = (
            f"https://{host}/{project}/-/pipelines/"
            f"{pipeline_id}/test_report?job_name=report-{expid}"
        )
        click.launch(report_url)
        return

    logger.debug("Fetching pipeline #{}", pipeline_id)
    info = get_pipeline_info(project, pipeline_id)
    report = get_pipeline_test_report(project, pipeline_id)

    if expid:
        format_experiment_detail(expid, info, report, host, project)
    else:
        format_experiment_list(info, report, host, project)
