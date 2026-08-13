from __future__ import annotations

import click


@click.group()
def mcp():
    """MCP (Model Context Protocol) server for experiment results."""


@mcp.command()
@click.option("--http", is_flag=True, help="Use HTTP/SSE transport instead of stdio.")
def serve(http):
    """Start the MCP server."""
    try:
        from wftools.mcp.server import mcp as mcp_server
    except ImportError as e:
        click.echo(str(e), err=True)
        raise SystemExit(1)

    if http:
        mcp_server.run(transport="sse")
    else:
        mcp_server.run()
