from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

import yaml
from loguru import logger

CONFIG_DIR = Path.home() / ".config" / "destine"
CONFIG_FILE = CONFIG_DIR / "config.yaml"

_SSH_REMOTE_RE = re.compile(r"git@(?P<host>[^:]+):(?P<path>.+?)(?:\.git)?$")
_HTTPS_REMOTE_RE = re.compile(r"https?://(?P<host>[^/]+)/(?P<path>.+?)(?:\.git)?$")


def _load_config() -> dict:
    """Load the YAML config file, returning an empty dict if absent or invalid."""
    if not CONFIG_FILE.is_file():
        return {}
    try:
        with CONFIG_FILE.open() as fh:
            data = yaml.safe_load(fh)
        return data if isinstance(data, dict) else {}
    except Exception:
        logger.warning("Failed to parse config file: {}", CONFIG_FILE)
        return {}


def _parse_git_remote() -> tuple[str | None, str | None]:
    """Extract host and project path from the git origin remote.

    Returns (host, project_path) or (None, None) on failure.
    """
    try:
        result = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return None, None

        url = result.stdout.strip()

        m = _SSH_REMOTE_RE.match(url)
        if m:
            return m.group("host"), m.group("path")

        m = _HTTPS_REMOTE_RE.match(url)
        if m:
            return m.group("host"), m.group("path")

        return None, None
    except (subprocess.TimeoutExpired, OSError):
        return None, None


def get_token() -> str | None:
    """Resolve GitLab token.

    Resolution order:
    1. ``GITLAB_TOKEN`` environment variable
    2. ``glab auth token`` subprocess call
    """
    token = os.environ.get("GITLAB_TOKEN")
    if token:
        return token

    # Read from glab's config file, matching the target host
    glab_config = Path.home() / ".config" / "glab-cli" / "config.yml"
    if glab_config.is_file():
        try:
            with glab_config.open() as fh:
                data = yaml.safe_load(fh)
            hosts = data.get("hosts", {}) if isinstance(data, dict) else {}
            target = get_host()
            for host_key, host_data in hosts.items():
                if not isinstance(host_data, dict) or not host_data.get("token"):
                    continue
                # Match: "gitlab.earth.bsc.es" in "gitlab.earth.bsc.es"
                # or "earth.bsc.es" in "gitlab.earth.bsc.es" (subpath style keys)
                if target in host_key or host_key in target:
                    return host_data["token"]
        except Exception:
            logger.debug("Failed to read glab config at {}", glab_config)

    return None


def get_host() -> str:
    """Resolve GitLab host.

    Resolution order:
    1. ``DESTINE_GITLAB_HOST`` environment variable
    2. ``~/.config/destine/config.yaml`` ``gitlab.host``
    3. Git remote URL of the current working directory
    """
    host = os.environ.get("DESTINE_GITLAB_HOST")
    if host:
        return host

    cfg = _load_config()
    cfg_host = cfg.get("gitlab", {}).get("host")
    if cfg_host:
        return str(cfg_host)

    remote_host, _ = _parse_git_remote()
    if remote_host:
        return remote_host

    return "gitlab.earth.bsc.es"


def get_project() -> str:
    """Resolve project path.

    Resolution order:
    1. ``DESTINE_PROJECT`` environment variable
    2. ``~/.config/destine/config.yaml`` ``defaults.project``
    3. Git remote URL of the current working directory
    """
    project = os.environ.get("DESTINE_PROJECT")
    if project:
        return project

    cfg = _load_config()
    cfg_project = cfg.get("defaults", {}).get("project")
    if cfg_project:
        return str(cfg_project)

    _, remote_path = _parse_git_remote()
    if remote_path:
        return remote_path

    return "digital-twins/de_340-2/workflow"


def get_project_id() -> int | None:
    """Resolve numeric GitLab project ID.

    Some GitLab instances have reverse proxies that decode ``%2F`` in URLs,
    breaking the ``/projects/namespace%2Fpath`` API.  A numeric ID always works.

    Resolution order:

    1. ``DESTINE_PROJECT_ID`` environment variable
    2. ``.glab-project-id`` file in the git repo root
    3. ``None`` (caller should fall back to string path)
    """
    env_id = os.environ.get("DESTINE_PROJECT_ID")
    if env_id:
        return int(env_id)

    try:
        git_root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if git_root.returncode == 0:
            cache = Path(git_root.stdout.strip()) / ".glab-project-id"
            if cache.is_file():
                return int(cache.read_text().strip())
    except (subprocess.TimeoutExpired, OSError, ValueError):
        pass

    return None
