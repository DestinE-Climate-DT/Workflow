"""
Unit tests for resource_monitor.py module.

This module tests the ResourceMonitor class and helper functions that
orchestrate monitoring of SLURM jobs.

Test Coverage:
    - Helper functions (round_floats_2dp, save_json_gz, now_timestamp)
    - Shell command execution (_run_cmd)
    - SLURM job checking (job_is_active)
    - ResourceMonitor class initialization
    - Metadata collection (start/end)
    - sstat snapshot collection
    - pidstat snapshot collection
    - Main monitoring loop
"""

import gzip
import json
import os
import tempfile
from datetime import datetime
from pathlib import Path
from unittest.mock import MagicMock, Mock, patch

import pytest

from runscripts.CPMIP.resource_monitor import ResourceMonitor
from runscripts.CPMIP.monitor.utils.subprocess_helpers import job_is_active, execute_command
from runscripts.CPMIP.monitor.utils.timestamps import now_timestamp
from runscripts.CPMIP.monitor.utils.json_helpers import save_json_gz, round_floats_2dp


class TestHelperFunctions:
    """Test suite for helper functions."""

    def testround_floats_2dp_dict(self):
        """
        GIVEN nested dict with floats at various precisions
        WHEN round_floats_2dp is called
        THEN all floats rounded to 2 decimal places.
        """
        data = {
            "value": 3.14159,
            "nested": {"inner": 2.71828, "list": [1.414213, 2.236067]},
            "int": 42,
            "str": "hello",
        }
        result = round_floats_2dp(data)

        assert result["value"] == 3.14
        assert result["nested"]["inner"] == 2.72
        assert result["nested"]["list"] == [1.41, 2.24]
        assert result["int"] == 42
        assert result["str"] == "hello"

    def testround_floats_2dp_list(self):
        """
        GIVEN list with float values
        WHEN round_floats_2dp is called
        THEN all list elements rounded to 2 decimals.
        """
        data = [1.111, 2.222, 3.333]
        result = round_floats_2dp(data)
        assert result == [1.11, 2.22, 3.33]

    def testround_floats_2dp_preserves_types(self):
        """
        GIVEN dict with non-float types (bool, None, int)
        WHEN round_floats_2dp is called
        THEN non-float types preserved unchanged.
        """
        data = {"bool": True, "none": None, "int": 10}
        result = round_floats_2dp(data)
        assert result["bool"] is True
        assert result["none"] is None
        assert result["int"] == 10

    def testsave_json_gz(self):
        """
        GIVEN dict with float values
        WHEN save_json_gz is called
        THEN data saved to gzipped JSON with floats rounded.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "test.json.gz")
            data = {"test": 3.14159, "value": 42}

            save_json_gz(path, data)

            # Verify file exists
            assert os.path.exists(path)

            # Verify content (floats rounded to 2 decimals)
            with gzip.open(path, "rt", encoding="utf-8") as f:
                loaded = json.load(f)
            assert loaded["test"] == 3.14
            assert loaded["value"] == 42

    def testsave_json_gz_creates_directory(self):
        """
        GIVEN path with non-existent parent directories
        WHEN save_json_gz is called
        THEN parent directories created automatically.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "subdir", "nested", "test.json.gz")
            data = {"test": "value"}

            save_json_gz(path, data)

            assert os.path.exists(path)

    def testnow_timestamp(self):
        """
        GIVEN current system time
        WHEN now_timestamp is called
        THEN return epoch seconds and ISO formatted string.
        """
        epoch, iso = now_timestamp()

        # Verify types
        assert isinstance(epoch, int)
        assert isinstance(iso, str)

        # Verify epoch is reasonable (after 2020)
        assert epoch > 1577836800  # 2020-01-01

        # Verify ISO format
        datetime.fromisoformat(iso)  # Should not raise

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.subprocess.run")
    def test_execute_command_success(self, mock_run):
        """
        GIVEN command that succeeds with exit code 0
        WHEN execute_command is called
        THEN return (True, stdout, None).
        """
        mock_proc = Mock()
        mock_proc.returncode = 0
        mock_proc.stdout = "output"
        mock_proc.stderr = ""
        mock_run.return_value = mock_proc

        success, stdout, stderr = execute_command(["echo", "test"])

        assert success is True
        assert stdout == "output"
        assert stderr is None

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.subprocess.run")
    def test_execute_command_failure(self, mock_run):
        """
        GIVEN command that fails with exit code 1
        WHEN execute_command is called
        THEN return (False, stdout, stderr).
        """
        mock_proc = Mock()
        mock_proc.returncode = 1
        mock_proc.stdout = ""
        mock_proc.stderr = "error message"
        mock_run.return_value = mock_proc

        success, stdout, stderr = execute_command(["false"])

        assert success is False
        assert stderr == "error message"

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.subprocess.run")
    def testjob_is_active_true(self, mock_run):
        """
        GIVEN SLURM job in RUNNING state
        WHEN job_is_active is called
        THEN return True.
        """
        mock_proc = Mock()
        mock_proc.returncode = 0
        mock_proc.stdout = "12345  main  user  RUNNING"
        mock_run.return_value = mock_proc

        assert job_is_active("12345") is True

    @patch("runscripts.CPMIP.monitor.utils.subprocess_helpers.subprocess.run")
    def testjob_is_active_false(self, mock_run):
        """
        GIVEN SLURM job not found or completed
        WHEN job_is_active is called
        THEN return False.
        """
        mock_proc = Mock()
        mock_proc.returncode = 1
        mock_proc.stdout = ""
        mock_run.return_value = mock_proc

        assert job_is_active("12345") is False


class TestResourceMonitorInit:
    """Test suite for ResourceMonitor initialization."""

    def test_init_basic(self):
        """
        GIVEN valid ResourceMonitor parameters
        WHEN ResourceMonitor is instantiated
        THEN initialize with correct attributes.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=10,
                slurm_frequency_seconds=60,
                output_dir=tmpdir,
                pidstat_path="/usr/bin/pidstat",
            )

            assert monitor.job_id == "12345"
            assert monitor.frequency_seconds == 10
            assert monitor.slurm_frequency_seconds == 60
            assert monitor.pidstat_path == "/usr/bin/pidstat"
            assert monitor.container_sif is None

    def test_init_with_container(self):
        """
        GIVEN container_sif path provided
        WHEN ResourceMonitor is instantiated
        THEN store container_sif attribute.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=10,
                slurm_frequency_seconds=60,
                output_dir=tmpdir,
                pidstat_path="/usr/bin/pidstat",
                container_sif="/path/to/container.sif",
            )

            assert monitor.container_sif == "/path/to/container.sif"

    def test_init_enforces_minimum_frequencies(self):
        """
        GIVEN frequencies below minimum thresholds
        WHEN ResourceMonitor is instantiated
        THEN enforce minimum values (5s, 60s).
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=1,  # Too low, should become 5
                slurm_frequency_seconds=30,  # Too low, should become 60
                output_dir=tmpdir,
                pidstat_path="/usr/bin/pidstat",
            )

            assert monitor.frequency_seconds == 5
            assert monitor.slurm_frequency_seconds == 60


class TestResourceMonitorMetadata:
    """Test suite for metadata collection."""

    @patch("runscripts.CPMIP.resource_monitor.collect_job_metadata")
    def test_write_metadata_start(self, mock_collect):
        """
        GIVEN job metadata available via scontrol
        WHEN _write_metadata_start is called
        THEN collect metadata and save to start.json.gz.
        """
        mock_collect.return_value = {
            "Job_Id": "12345",
            "Job_Name": "test_job",
            "Allocated_Node_List": {"Nodes": ["nid001", "nid002"], "Count": 2},
            "Threads_Per_Core_Count": 2,
            "Account": "myaccount",
            "Tres_Allocated": {"Mem_Bytes": 8589934592},  # 8GB
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=10,
                slurm_frequency_seconds=60,
                output_dir=tmpdir,
                pidstat_path="/usr/bin/pidstat",
            )

            monitor._write_metadata_start()

            # Verify metadata was collected
            assert monitor.node_list == ["nid001", "nid002"]
            assert monitor.threads_per_core == 2
            assert monitor.account == "myaccount"
            assert monitor.job_mem_limit_bytes == 8589934592

            # Verify file was created
            metadata_file = os.path.join(tmpdir, "metadata", "start.json.gz")
            assert os.path.exists(metadata_file)

            # Verify content
            with gzip.open(metadata_file, "rt") as f:
                data = json.load(f)
            assert data["Job_Metadata"]["Job_Id"] == "12345"
            assert "Timestamp_Epoch" in data
            assert "Timestamp_ISO_Local" in data

    @patch("runscripts.CPMIP.resource_monitor.collect_job_metadata")
    def test_write_metadata_end(self, mock_collect):
        """
        GIVEN job completed or ending
        WHEN _write_metadata_end is called
        THEN collect final metadata and save to end.json.gz.
        """
        mock_collect.return_value = {
            "Job_Id": "12345",
            "Job_State": "COMPLETED",
            "Allocated_Node_List": {"Nodes": ["nid001"], "Count": 1},
            "Threads_Per_Core_Count": 2,
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=10,
                slurm_frequency_seconds=60,
                output_dir=tmpdir,
                pidstat_path="/usr/bin/pidstat",
            )
            monitor.threads_per_core = 2

            monitor._write_metadata_end()

            # Verify file was created
            metadata_file = os.path.join(tmpdir, "metadata", "end.json.gz")
            assert os.path.exists(metadata_file)


class TestResourceMonitorSstat:
    """Test suite for sstat snapshot collection."""

    @patch("runscripts.CPMIP.resource_monitor.aggregate_sstat_steps")
    @patch("runscripts.CPMIP.resource_monitor.collect_sstat_steps")
    def test_write_sstat_snapshot_success(self, mock_collect, mock_aggregate):
        """
        GIVEN sstat data available for job steps
        WHEN _write_sstat_snapshot is called
        THEN collect, aggregate, and save snapshot.
        """
        mock_collect.return_value = {
            "12345.0": {"MaxRSS": "4096M", "AveRSS": "2048M"},
            "12345.batch": {"MaxRSS": "2048M", "AveRSS": "1024M"},
        }
        mock_aggregate.return_value = {
            "Memory_Related": {"Peak_RSS_Bytes": 4294967296}
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=10,
                slurm_frequency_seconds=60,
                output_dir=tmpdir,
                pidstat_path="/usr/bin/pidstat",
            )
            monitor.threads_per_core = 2

            monitor._write_sstat_snapshot()

            # Verify aggregated file was created
            agg_files = list(Path(tmpdir).glob("sstat/aggregated/*.json.gz"))
            assert len(agg_files) == 1

    @patch("runscripts.CPMIP.resource_monitor.collect_sstat_steps")
    def test_write_sstat_snapshot_no_data(self, mock_collect):
        """
        GIVEN sstat returns no data (empty dict)
        WHEN _write_sstat_snapshot is called
        THEN skip writing snapshot files.
        """
        mock_collect.return_value = {}

        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=10,
                slurm_frequency_seconds=60,
                output_dir=tmpdir,
                pidstat_path="/usr/bin/pidstat",
            )

            monitor._write_sstat_snapshot()

            # Verify no files created
            agg_dir = Path(tmpdir) / "sstat" / "aggregated"
            if agg_dir.exists():
                assert len(list(agg_dir.glob("*.json.gz"))) == 0


class TestResourceMonitorPidstat:
    """Test suite for pidstat snapshot collection."""

    @patch("runscripts.CPMIP.resource_monitor.collect_node_stats")
    def test_write_pidstat_snapshots_success(self, mock_collect):
        """
        GIVEN pidstat data available for nodes
        WHEN _write_pidstat_snapshots is called
        THEN collect and save per-node snapshots.
        """
        mock_collect.return_value = {
            "nid001": {
                "Summary": {"Counts": {"Process_Count": 5}},
                "Processes": [],
                "Node_General_Info": {"Status": "success"},
            }
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=10,
                slurm_frequency_seconds=60,
                output_dir=tmpdir,
                pidstat_path="/usr/bin/pidstat",
            )
            monitor.node_list = ["nid001"]
            monitor.threads_per_core = 2
            monitor.account = "myaccount"
            monitor.job_mem_limit_bytes = 8589934592

            monitor._write_pidstat_snapshots()

            # Verify node directory and file created
            node_files = list(Path(tmpdir).glob("pidstat/nodes/nid001/*.json.gz"))
            assert len(node_files) == 1

            # Verify content
            with gzip.open(node_files[0], "rt") as f:
                data = json.load(f)
            assert data["Job_Id"] == "12345"
            assert data["Node"] == "nid001"
            assert data["Threads_Per_Core_Count"] == 2

    def test_write_pidstat_snapshots_no_pidstat_path(self):
        """
        GIVEN pidstat_path is empty or None
        WHEN _write_pidstat_snapshots is called
        THEN skip pidstat collection.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            monitor = ResourceMonitor(
                job_id="12345",
                frequency_seconds=10,
                slurm_frequency_seconds=60,
                output_dir=tmpdir,
                pidstat_path="",  # Empty path
            )
            monitor.node_list = ["nid001"]

            monitor._write_pidstat_snapshots()

            # Verify no files created
            pidstat_dir = Path(tmpdir) / "pidstat"
            assert not pidstat_dir.exists() or len(list(pidstat_dir.rglob("*.json.gz"))) == 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
