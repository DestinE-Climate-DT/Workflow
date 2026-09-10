"""
Unit tests for subprocess execution helpers.

This module tests command execution wrappers for SLURM and system commands.
"""

import subprocess
from unittest.mock import MagicMock, patch


from runscripts.CPMIP.monitor.utils.subprocess_helpers import (
    execute_command,
    execute_srun,
)


class TestExecuteCommand:
    """
    Test suite for execute_command function.

    Tests command execution with success, failure, and error cases.
    """

    @patch("subprocess.run")
    def test_execute_command_success(self, mock_run):
        """
        GIVEN command succeeds with output
        WHEN execute_command is called
        THEN return (True, stdout, None).
        """
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "hello world\n"
        mock_result.stderr = ""
        mock_run.return_value = mock_result

        success, stdout, stderr = execute_command(["echo", "hello world"])

        assert success is True
        assert stdout == "hello world\n"
        assert stderr is None
        mock_run.assert_called_once_with(
            ["echo", "hello world"],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )

    @patch("subprocess.run")
    def test_execute_command_failure(self, mock_run):
        """
        GIVEN command fails with non-zero exit
        WHEN execute_command is called
        THEN return (False, stdout, stderr).
        """
        mock_result = MagicMock()
        mock_result.returncode = 1
        mock_result.stdout = ""
        mock_result.stderr = (
            "ls: cannot access '/nonexistent': No such file or directory\n"
        )
        mock_run.return_value = mock_result

        success, stdout, stderr = execute_command(["ls", "/nonexistent"])

        assert success is False
        assert stdout == ""
        assert stderr is not None
        assert "No such file" in stderr

    @patch("subprocess.run")
    def test_execute_command_timeout(self, mock_run):
        """
        GIVEN command times out
        WHEN execute_command is called
        THEN return (False, "", timeout_message).
        """
        mock_run.side_effect = subprocess.TimeoutExpired(
            cmd=["sleep", "100"], timeout=5
        )

        success, stdout, stderr = execute_command(["sleep", "100"], timeout=5)

        assert success is False
        assert stdout == ""
        assert stderr is not None
        assert "timed out after 5 seconds" in stderr

    @patch("subprocess.run")
    def test_execute_command_exception(self, mock_run):
        """
        GIVEN command raises exception (e.g., FileNotFoundError)
        WHEN execute_command is called
        THEN return (False, "", exception_message).
        """
        mock_run.side_effect = FileNotFoundError("Command not found")

        success, stdout, stderr = execute_command(["nonexistent_cmd"])

        assert success is False
        assert stdout == ""
        assert stderr is not None
        assert "Command not found" in stderr

    @patch("subprocess.run")
    def test_execute_command_with_custom_timeout(self, mock_run):
        """
        GIVEN custom timeout specified
        WHEN execute_command is called
        THEN use custom timeout value.
        """
        mock_result = MagicMock()
        mock_result.returncode = 0
        mock_result.stdout = "output"
        mock_result.stderr = ""
        mock_run.return_value = mock_result

        execute_command(["ls"], timeout=60)

        mock_run.assert_called_once_with(
            ["ls"], capture_output=True, text=True, timeout=60, check=False
        )


class TestExecuteSrun:
    """
    Test suite for execute_srun function.

    Tests srun command wrapper with --overlap.
    """

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.execute_command")
    def test_execute_srun_basic(self, mock_execute):
        """
        GIVEN basic srun command with jobid
        WHEN execute_srun is called
        THEN construct srun --jobid command.
        """
        mock_execute.return_value = (True, "node01\n", None)

        success, stdout, stderr = execute_srun(["hostname"], "12345", "node01")

        assert success is True
        assert stdout == "node01\n"
        mock_execute.assert_called_once_with(
            [
                "srun",
                "--overlap",
                "--exact",
                "--mpi=none",
                "--jobid",
                "12345",
                "--nodelist",
                "node01",
                "-n1",
                "-N1",
                "-c1",
                "hostname",
            ],
            30,
        )

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.execute_command")
    def test_execute_srun_with_account(self, mock_execute):
        """
        GIVEN account parameter provided
        WHEN execute_srun is called
        THEN add --account to srun command.
        """
        mock_execute.return_value = (True, "output\n", None)

        success, stdout, stderr = execute_srun(
            ["pidstat", "-h"], "12345", "node01", account="proj123"
        )

        assert success is True
        called_command = mock_execute.call_args[0][0]
        assert "--account" in called_command
        assert "proj123" in called_command

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.execute_command")
    def test_execute_srun_without_account(self, mock_execute):
        """
        GIVEN account is None
        WHEN execute_srun is called
        THEN omit --account from command.
        """
        mock_execute.return_value = (True, "output\n", None)

        execute_srun(["lscpu"], "12345", "node01", account=None)

        called_command = mock_execute.call_args[0][0]
        assert "--account" not in called_command

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.execute_command")
    def test_execute_srun_with_timeout(self, mock_execute):
        """
        GIVEN timeout parameter provided
        WHEN execute_srun is called
        THEN pass timeout to execute_command.
        """
        mock_execute.return_value = (True, "output\n", None)

        execute_srun(["free", "-k"], "12345", "node01", timeout=60)

        assert mock_execute.call_args[0][1] == 60

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.execute_command")
    def test_execute_srun_failure(self, mock_execute):
        """
        GIVEN srun command fails
        WHEN execute_srun is called
        THEN return failure status.
        """
        mock_execute.return_value = (False, "", "srun: error: Node not available")

        success, stdout, stderr = execute_srun(["bad_cmd"], "12345", "node01")

        assert success is False
        assert stdout == ""
        assert stderr is not None
        assert "Node not available" in stderr


class TestSubprocessHelpersIntegration:
    """
    Integration tests for subprocess helpers.

    Tests with real command execution (no mocking).
    """

    def test_execute_command_real_echo(self):
        """
        GIVEN real echo command without mocks
        WHEN execute_command is called
        THEN execute successfully.
        """
        success, stdout, stderr = execute_command(["echo", "test message"])

        assert success is True
        assert "test message" in stdout
        assert stderr is None

    def test_execute_command_real_failure(self):
        """
        GIVEN real invalid command
        WHEN execute_command is called
        THEN return failure status.
        """
        success, stdout, stderr = execute_command(
            ["ls", "/nonexistent_path_xyz_12345_abc"]
        )

        assert success is False
        assert stderr is not None
        assert "cannot access" in stderr.lower() or "no such file" in stderr.lower()
