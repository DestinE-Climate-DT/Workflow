from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

pytest.importorskip("gitlab", reason="python-gitlab not installed")

import wftools.gitlab.client as _mod  # noqa: E402


class TestGetClient:
    def test_get_client_with_token(self):
        """Client is created with private_token when token is available."""
        mock_gitlab = MagicMock()
        with (
            patch.object(_mod, "get_token", return_value="test-token"),
            patch.object(_mod, "get_host", return_value="gitlab.example.com"),
            patch.object(_mod, "_import_gitlab", return_value=mock_gitlab),
        ):
            _mod.get_client()

            mock_gitlab.Gitlab.assert_called_once_with(
                url="https://gitlab.example.com",
                private_token="test-token",
            )

    def test_get_client_without_token(self):
        """Client is created without auth when no token is available."""
        mock_gitlab = MagicMock()
        with (
            patch.object(_mod, "get_token", return_value=None),
            patch.object(_mod, "get_host", return_value="gitlab.example.com"),
            patch.object(_mod, "_import_gitlab", return_value=mock_gitlab),
        ):
            _mod.get_client()

            mock_gitlab.Gitlab.assert_called_once_with(
                url="https://gitlab.example.com",
            )


class TestGetMrPipelines:
    def test_get_mr_pipelines(self):
        """Fetches pipelines for an MR and returns structured dicts."""
        mock_pipeline = MagicMock()
        mock_pipeline.id = 12345
        mock_pipeline.status = "success"
        mock_pipeline.created_at = "2025-04-14T09:31:00Z"
        mock_pipeline.web_url = "https://gitlab.example.com/project/-/pipelines/12345"

        mock_mr = MagicMock()
        mock_mr.pipelines.list.return_value = [mock_pipeline]

        mock_project = MagicMock()
        mock_project.mergerequests.get.return_value = mock_mr

        mock_gl = MagicMock()
        mock_gl.projects.get.return_value = mock_project

        with patch.object(_mod, "get_client", return_value=mock_gl):
            result = _mod.get_mr_pipelines("group/project", 42)

        assert len(result) == 1
        assert result[0]["id"] == 12345
        assert result[0]["status"] == "success"
        assert result[0]["created_at"] == "2025-04-14T09:31:00Z"
        assert "pipelines/12345" in result[0]["web_url"]


class TestGetPipelineTestReport:
    def test_get_pipeline_test_report(self):
        """Fetches test report for a pipeline."""
        expected_report = {
            "total_time": 42.5,
            "total_count": 12,
            "success_count": 11,
            "failed_count": 1,
            "error_count": 0,
            "test_suites": [
                {
                    "name": "a006",
                    "total_count": 12,
                    "failed_count": 0,
                    "error_count": 0,
                    "test_cases": [],
                }
            ],
        }

        mock_report = MagicMock()
        mock_report.asdict.return_value = expected_report

        mock_pipeline = MagicMock()
        mock_pipeline.test_report.get.return_value = mock_report

        mock_project = MagicMock()
        mock_project.pipelines.get.return_value = mock_pipeline

        mock_gl = MagicMock()
        mock_gl.projects.get.return_value = mock_project

        with patch.object(_mod, "get_client", return_value=mock_gl):
            result = _mod.get_pipeline_test_report("group/project", 12345)

        assert result == expected_report
        assert result["total_count"] == 12
        assert len(result["test_suites"]) == 1

    def test_get_pipeline_info(self):
        """Fetches pipeline metadata."""
        mock_pipeline = MagicMock()
        mock_pipeline.id = 12345
        mock_pipeline.status = "failed"
        mock_pipeline.created_at = "2025-04-14T09:31:00Z"
        mock_pipeline.web_url = "https://gitlab.example.com/project/-/pipelines/12345"

        mock_project = MagicMock()
        mock_project.pipelines.get.return_value = mock_pipeline

        mock_gl = MagicMock()
        mock_gl.projects.get.return_value = mock_project

        with patch.object(_mod, "get_client", return_value=mock_gl):
            result = _mod.get_pipeline_info("group/project", 12345)

        assert result["id"] == 12345
        assert result["status"] == "failed"
        assert result["created_at"] == "2025-04-14T09:31:00Z"
