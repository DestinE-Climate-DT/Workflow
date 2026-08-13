from __future__ import annotations

import os
import shutil
import subprocess
import sys

import click

from wftools._version import __version__
from wftools.cli.commands.mcp import mcp
from wftools.cli.commands.mr import mr
from wftools.cli.commands.pipeline import pipeline
from wftools.cli.commands.report import report
from wftools.cli.commands.resources import resources
from wftools.cli.commands.tsuite import tsuite


def _get_glab_commands():
    """Discover glab commands by parsing `glab --help`."""
    if shutil.which("glab") is None:
        return {}
    try:
        result = subprocess.run(
            ["glab", "--help"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        commands = {}
        in_commands = False
        for line in result.stdout.splitlines():
            stripped = line.strip()
            if stripped == "COMMANDS":
                in_commands = True
                continue
            if stripped == "FLAGS":
                break
            if not in_commands or not stripped:
                continue
            # Lines look like: "mr <command> [command] [--flags]   Description text."
            parts = stripped.split(None, 1)
            if not parts:
                continue
            cmd = parts[0]
            # Extract description: everything after the last repeated whitespace gap
            desc = ""
            if len(parts) > 1:
                # Find the description after the flags/args section
                rest = parts[1]
                # Split on 2+ spaces to separate args from description
                import re

                segments = re.split(r"\s{2,}", rest)
                if len(segments) > 1:
                    desc = segments[-1].rstrip(".")
                elif not any(c in rest for c in "<[-"):
                    desc = rest.rstrip(".")
            commands[cmd] = desc
        return commands
    except (subprocess.TimeoutExpired, OSError):
        return {}


class GlabProxyGroup(click.Group):
    """Click group that forwards unknown commands to glab."""

    def get_command(self, ctx, cmd_name):
        rv = super().get_command(ctx, cmd_name)
        if rv is not None:
            return rv
        return _make_glab_proxy(cmd_name)

    def resolve_command(self, ctx, args):
        cmd_name, cmd, cmd_args = super().resolve_command(ctx, args)
        return cmd_name, cmd, cmd_args

    def format_help(self, ctx, formatter):
        super().format_help(ctx, formatter)

        glab_cmds = _get_glab_commands()
        # Filter out commands we already handle natively
        native = set(self.commands)
        glab_only = {k: v for k, v in glab_cmds.items() if k not in native}

        if glab_only:
            formatter.write("\n")
            formatter.write_text("Proxied glab commands:")
            formatter.write("\n")
            with formatter.indentation():
                rows = [(name, desc) for name, desc in sorted(glab_only.items())]
                formatter.write_dl(rows)


def _make_glab_proxy(cmd_name):
    @click.command(
        cmd_name,
        context_settings={"ignore_unknown_options": True, "allow_extra_args": True},
        add_help_option=False,
    )
    @click.argument("args", nargs=-1, type=click.UNPROCESSED)
    def proxy(args):
        _check_glab()
        result = subprocess.run(["glab", cmd_name] + list(args), env=os.environ)
        sys.exit(result.returncode)

    proxy.short_help = f"(proxied to glab {cmd_name})"
    return proxy


def _check_glab():
    if shutil.which("glab") is None:
        click.echo(
            "Error: glab is not installed or not on PATH.\n"
            "Install it from https://gitlab.com/gitlab-org/cli",
            err=True,
        )
        sys.exit(1)


@click.group(cls=GlabProxyGroup)
@click.version_option(version=__version__, prog_name="destine")
def cli():
    """DestinE Climate DT workflow tools.

    Commands not listed below are forwarded to glab.
    """


cli.add_command(mcp)
cli.add_command(mr)
cli.add_command(pipeline)
cli.add_command(report)
cli.add_command(resources)
cli.add_command(tsuite)


def main():
    cli()


if __name__ == "__main__":
    main()
