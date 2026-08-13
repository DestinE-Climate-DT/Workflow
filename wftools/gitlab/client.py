from __future__ import annotations

from typing import TYPE_CHECKING

from loguru import logger

from wftools.config import get_host, get_project_id, get_token

if TYPE_CHECKING:
    import gitlab


def _import_gitlab():
    """Import python-gitlab lazily, with a helpful error if it is missing.

    Importing inside this helper keeps ``wftools.gitlab.client`` (and its
    functions) importable even when ``python-gitlab`` is not installed; the
    optional dependency is only required when a GitLab API call is made.
    """
    try:
        import gitlab
    except ImportError as exc:
        raise ImportError(
            "python-gitlab is required for GitLab API access.\n"
            "Install it with: pip install 'climate-dt-workflow[gitlab]'"
        ) from exc
    return gitlab


def get_client() -> gitlab.Gitlab:
    """Create an authenticated python-gitlab client.

    Uses :func:`wftools.config.get_token` and :func:`wftools.config.get_host`
    for credentials and server URL.
    """
    gitlab = _import_gitlab()
    token = get_token()
    host = get_host()
    url = f"https://{host}"

    if token:
        logger.debug("Authenticating to {} with private token", url)
        return gitlab.Gitlab(url=url, private_token=token)

    logger.warning("No GitLab token found; API calls may fail for private projects")
    return gitlab.Gitlab(url=url)


def _resolve_project(project_path: str):
    """Resolve a project, preferring numeric ID to avoid %2F proxy issues."""
    gl = get_client()
    project_id = get_project_id()
    if project_id:
        logger.debug("Using numeric project ID {}", project_id)
        return gl.projects.get(project_id)
    return gl.projects.get(project_path)


def get_mr_pipelines(project_path: str, mr_iid: int) -> list[dict]:
    """Get pipelines for a merge request, newest first.

    Parameters
    ----------
    project_path:
        Full GitLab project path (e.g. ``digital-twins/de_340-2/workflow``).
    mr_iid:
        Merge request internal ID.

    Returns
    -------
    list[dict]
        Pipeline dicts with keys like ``id``, ``status``, ``created_at``, ``web_url``.
    """
    project = _resolve_project(project_path)
    mr = project.mergerequests.get(mr_iid)
    pipelines = mr.pipelines.list(iterator=True)
    return [
        {
            "id": p.id,
            "status": p.status,
            "created_at": p.created_at,
            "web_url": p.web_url,
        }
        for p in pipelines
    ]


def get_pipeline_test_report(project_path: str, pipeline_id: int) -> dict:
    """Get the test report for a pipeline.

    Parameters
    ----------
    project_path:
        Full GitLab project path.
    pipeline_id:
        Pipeline ID.

    Returns
    -------
    dict
        The test report dict as returned by GitLab's API, containing
        ``total_time``, ``total_count``, ``success_count``, ``failed_count``,
        ``error_count``, ``test_suites``, etc.
    """
    project = _resolve_project(project_path)
    pipeline = project.pipelines.get(pipeline_id)
    return pipeline.test_report.get().asdict()


def get_pipeline_info(project_path: str, pipeline_id: int) -> dict:
    """Get pipeline metadata.

    Parameters
    ----------
    project_path:
        Full GitLab project path.
    pipeline_id:
        Pipeline ID.

    Returns
    -------
    dict
        Pipeline info with keys ``id``, ``status``, ``created_at``, ``web_url``,
        ``sha``, ``ref``.
    """
    project = _resolve_project(project_path)
    pipeline = project.pipelines.get(pipeline_id)
    return {
        "id": pipeline.id,
        "status": pipeline.status,
        "created_at": pipeline.created_at,
        "web_url": pipeline.web_url,
        "sha": getattr(pipeline, "sha", None),
        "ref": getattr(pipeline, "ref", None),
    }
