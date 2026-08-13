from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import yaml

from wftools.config import get_host, get_project, get_token


class TestGetToken:
    def test_get_token_from_env(self, monkeypatch):
        """GITLAB_TOKEN env var takes precedence."""
        monkeypatch.setenv("GITLAB_TOKEN", "env-token-123")
        assert get_token() == "env-token-123"

    def test_get_token_from_glab_config(self, monkeypatch, tmp_path):
        """Falls back to glab config file when env var is absent."""
        monkeypatch.delenv("GITLAB_TOKEN", raising=False)
        monkeypatch.setenv("DESTINE_GITLAB_HOST", "gitlab.example.com")

        config = tmp_path / "config.yml"
        config.write_text("hosts:\n  gitlab.example.com:\n    token: glab-token-456\n")
        monkeypatch.setattr("wftools.config.Path.home", lambda: tmp_path)
        # glab config lives at ~/.config/glab-cli/config.yml
        glab_dir = tmp_path / ".config" / "glab-cli"
        glab_dir.mkdir(parents=True)
        (glab_dir / "config.yml").write_text(config.read_text())

        token = get_token()
        assert token == "glab-token-456"

    def test_get_token_returns_none_when_unavailable(self, monkeypatch, tmp_path):
        """Returns None when neither env nor glab config can provide a token."""
        monkeypatch.delenv("GITLAB_TOKEN", raising=False)
        monkeypatch.setenv("DESTINE_GITLAB_HOST", "gitlab.example.com")
        # Point home to empty tmp dir (no glab config)
        monkeypatch.setattr("wftools.config.Path.home", lambda: tmp_path)
        assert get_token() is None

    def test_get_token_env_takes_precedence_over_glab(self, monkeypatch):
        """Env var wins even if glab would also return a token."""
        monkeypatch.setenv("GITLAB_TOKEN", "env-token")

        with patch("wftools.config.subprocess.run") as mock_run:
            token = get_token()

        assert token == "env-token"
        mock_run.assert_not_called()


class TestGetHost:
    def test_get_host_from_env(self, monkeypatch):
        """DESTINE_GITLAB_HOST env var takes precedence."""
        monkeypatch.setenv("DESTINE_GITLAB_HOST", "custom.gitlab.example.com")
        assert get_host() == "custom.gitlab.example.com"

    def test_get_host_from_config(self, monkeypatch, tmp_path):
        """Falls back to config file when env var is absent."""
        monkeypatch.delenv("DESTINE_GITLAB_HOST", raising=False)

        config_file = tmp_path / "config.yaml"
        config_data = {"gitlab": {"host": "config.gitlab.example.com"}}
        config_file.write_text(yaml.dump(config_data))

        with patch("wftools.config.CONFIG_FILE", config_file):
            assert get_host() == "config.gitlab.example.com"

    def test_get_host_from_git_remote(self, monkeypatch):
        """Falls back to git remote when env var and config are absent."""
        monkeypatch.delenv("DESTINE_GITLAB_HOST", raising=False)

        with (
            patch("wftools.config.CONFIG_FILE", Path("/nonexistent/config.yaml")),
            patch("wftools.config.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = (
                "git@remote.gitlab.example.com:group/project.git\n"
            )
            assert get_host() == "remote.gitlab.example.com"

    def test_get_host_defaults_when_all_fail(self, monkeypatch):
        """Returns default host when all resolution methods fail."""
        monkeypatch.delenv("DESTINE_GITLAB_HOST", raising=False)

        with (
            patch("wftools.config.CONFIG_FILE", Path("/nonexistent/config.yaml")),
            patch("wftools.config.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 1
            mock_run.return_value.stdout = ""
            assert get_host() == "gitlab.earth.bsc.es"

    def test_get_host_https_remote(self, monkeypatch):
        """Parses HTTPS remote URL correctly."""
        monkeypatch.delenv("DESTINE_GITLAB_HOST", raising=False)

        with (
            patch("wftools.config.CONFIG_FILE", Path("/nonexistent/config.yaml")),
            patch("wftools.config.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = (
                "https://https-host.example.com/group/subgroup/repo.git\n"
            )
            assert get_host() == "https-host.example.com"


class TestGetProject:
    def test_get_project_from_env(self, monkeypatch):
        """DESTINE_PROJECT env var takes precedence."""
        monkeypatch.setenv("DESTINE_PROJECT", "my-group/my-project")
        assert get_project() == "my-group/my-project"

    def test_get_project_from_config(self, monkeypatch, tmp_path):
        """Falls back to config file when env var is absent."""
        monkeypatch.delenv("DESTINE_PROJECT", raising=False)

        config_file = tmp_path / "config.yaml"
        config_data = {"defaults": {"project": "config-group/config-project"}}
        config_file.write_text(yaml.dump(config_data))

        with patch("wftools.config.CONFIG_FILE", config_file):
            assert get_project() == "config-group/config-project"

    def test_get_project_from_git_remote_ssh(self, monkeypatch):
        """Falls back to git remote (SSH) when env var and config are absent."""
        monkeypatch.delenv("DESTINE_PROJECT", raising=False)

        with (
            patch("wftools.config.CONFIG_FILE", Path("/nonexistent/config.yaml")),
            patch("wftools.config.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = (
                "git@gitlab.example.com:digital-twins/de_340-2/workflow.git\n"
            )
            assert get_project() == "digital-twins/de_340-2/workflow"

    def test_get_project_from_git_remote_https(self, monkeypatch):
        """Falls back to git remote (HTTPS) when env var and config are absent."""
        monkeypatch.delenv("DESTINE_PROJECT", raising=False)

        with (
            patch("wftools.config.CONFIG_FILE", Path("/nonexistent/config.yaml")),
            patch("wftools.config.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = (
                "https://gitlab.example.com/digital-twins/de_340-2/workflow.git\n"
            )
            assert get_project() == "digital-twins/de_340-2/workflow"

    def test_get_project_defaults_when_all_fail(self, monkeypatch):
        """Returns default project when all resolution methods fail."""
        monkeypatch.delenv("DESTINE_PROJECT", raising=False)

        with (
            patch("wftools.config.CONFIG_FILE", Path("/nonexistent/config.yaml")),
            patch("wftools.config.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 1
            mock_run.return_value.stdout = ""
            assert get_project() == "digital-twins/de_340-2/workflow"

    def test_get_project_ssh_without_git_suffix(self, monkeypatch):
        """SSH remote without .git suffix is parsed correctly."""
        monkeypatch.delenv("DESTINE_PROJECT", raising=False)

        with (
            patch("wftools.config.CONFIG_FILE", Path("/nonexistent/config.yaml")),
            patch("wftools.config.subprocess.run") as mock_run,
        ):
            mock_run.return_value.returncode = 0
            mock_run.return_value.stdout = "git@gitlab.example.com:group/project\n"
            assert get_project() == "group/project"
