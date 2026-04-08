"""Unit tests for system detector module.

Tests hardware topology detection, particularly Threads Per Core (TPC)
detection via lscpu command.
"""

from unittest.mock import patch

from runscripts.CPMIP.monitor.system.detector import detect_threads_per_core


class TestDetectThreadsPerCore:
    """Test suite for TPC detection from lscpu output."""

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_success_with_smt_enabled(self, mock_execute_srun):
        """
        GIVEN lscpu shows Thread(s) per core: 2
        WHEN detect_threads_per_core is called
        THEN return TPC=2.
        """
        # Mock lscpu output with Thread(s) per core: 2
        lscpu_output = """Architecture:        x86_64
CPU(s):              128
Thread(s) per core:  2
Core(s) per socket:  32
Socket(s):           2"""

        mock_execute_srun.return_value = (True, lscpu_output, "")

        tpc, notes = detect_threads_per_core(
            node_list=["node01"], jobid="12345", account="myaccount"
        )

        assert tpc == 2
        assert notes == []

        # Verify execute_srun was called correctly
        mock_execute_srun.assert_called_once()
        call_kwargs = mock_execute_srun.call_args[1]
        assert call_kwargs["command"] == ["lscpu"]
        assert call_kwargs["node"] == "node01"
        assert call_kwargs["jobid"] == "12345"
        assert call_kwargs["account"] == "myaccount"
        assert call_kwargs["timeout"] == 10

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_success_with_smt_disabled(self, mock_execute_srun):
        """
        GIVEN lscpu shows Thread(s) per core: 1
        WHEN detect_threads_per_core is called
        THEN return TPC=1.
        """
        lscpu_output = """Architecture:        x86_64
CPU(s):              64
Thread(s) per core:  1
Core(s) per socket:  32
Socket(s):           2"""

        mock_execute_srun.return_value = (True, lscpu_output, "")

        tpc, notes = detect_threads_per_core(node_list=["node01"])

        assert tpc == 1
        assert notes == []

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_with_four_threads_per_core(self, mock_execute_srun):
        """
        GIVEN lscpu shows Thread(s) per core: 4
        WHEN detect_threads_per_core is called
        THEN return TPC=4.
        """
        lscpu_output = """Architecture:        ppc64le
CPU(s):              256
Thread(s) per core:  4
Core(s) per socket:  16
Socket(s):           4"""

        mock_execute_srun.return_value = (True, lscpu_output, "")

        tpc, notes = detect_threads_per_core(node_list=["node01"])

        assert tpc == 4
        assert notes == []

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_empty_node_list(self, mock_execute_srun):
        """
        GIVEN node_list is empty
        WHEN detect_threads_per_core is called
        THEN return TPC=1 as default.
        """

        tpc, notes = detect_threads_per_core(node_list=[])

        assert tpc == 1
        assert len(notes) == 1
        assert "no nodes available" in notes[0]
        assert "fallback TPC=1" in notes[0]

        # Verify no srun command was executed
        mock_execute_srun.assert_not_called()

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_command_failure(self, mock_execute_srun):
        """
        GIVEN lscpu command fails
        WHEN detect_threads_per_core is called
        THEN return TPC=1 with error note.
        """
        # Mock failed command execution
        mock_execute_srun.return_value = (False, "", "lscpu: command not found")

        tpc, notes = detect_threads_per_core(node_list=["node01"], jobid="12345")

        assert tpc == 1
        assert len(notes) == 1
        assert "lscpu returned no valid data" in notes[0]
        assert "node01" in notes[0]

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_missing_thread_line(self, mock_execute_srun):
        """
        GIVEN lscpu output missing Thread(s) line
        WHEN detect_threads_per_core is called
        THEN return TPC=1 with warning.
        """
        # Mock incomplete lscpu output
        lscpu_output = """Architecture:        x86_64
CPU(s):              128
Core(s) per socket:  32
Socket(s):           2"""

        mock_execute_srun.return_value = (True, lscpu_output, "")

        tpc, notes = detect_threads_per_core(node_list=["node01"])

        assert tpc == 1
        assert len(notes) == 1
        assert "no valid data" in notes[0]

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_malformed_thread_value(self, mock_execute_srun):
        """
        GIVEN Thread(s) value is not a number
        WHEN detect_threads_per_core is called
        THEN return TPC=1 with error note.
        """
        lscpu_output = """Architecture:        x86_64
Thread(s) per core:  unknown
Core(s) per socket:  32"""

        mock_execute_srun.return_value = (True, lscpu_output, "")

        tpc, notes = detect_threads_per_core(node_list=["node01"])

        assert tpc == 1
        assert len(notes) == 1

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_zero_or_negative_value(self, mock_execute_srun):
        """
        GIVEN Thread(s) per core is 0 or negative
        WHEN detect_threads_per_core is called
        THEN return TPC=1 with error note.
        """
        lscpu_output = """Architecture:        x86_64
Thread(s) per core:  0
Core(s) per socket:  32"""

        mock_execute_srun.return_value = (True, lscpu_output, "")

        tpc, notes = detect_threads_per_core(node_list=["node01"])

        assert tpc == 1
        assert len(notes) == 1

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_exception_handling(self, mock_execute_srun):
        """
        GIVEN lscpu raises unexpected exception
        WHEN detect_threads_per_core is called
        THEN catch exception and return TPC=1.
        """
        # Mock execute_srun to raise exception
        mock_execute_srun.side_effect = RuntimeError("Connection timeout")

        tpc, notes = detect_threads_per_core(node_list=["node01"])

        assert tpc == 1
        assert len(notes) == 1
        assert "Connection timeout" in notes[0]
        assert "fallback TPC=1" in notes[0]

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_without_optional_params(self, mock_execute_srun):
        """
        GIVEN jobid and account are None
        WHEN detect_threads_per_core is called
        THEN execute lscpu without job context.
        """
        lscpu_output = """Thread(s) per core:  2"""
        mock_execute_srun.return_value = (True, lscpu_output, "")

        tpc, notes = detect_threads_per_core(node_list=["node01"])

        assert tpc == 2
        call_kwargs = mock_execute_srun.call_args[1]
        assert call_kwargs["jobid"] == ""
        assert call_kwargs["account"] is None

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_uses_first_node_only(self, mock_execute_srun):
        """
        GIVEN node_list has multiple nodes
        WHEN detect_threads_per_core is called
        THEN query only first node.
        """
        lscpu_output = """Thread(s) per core:  2"""
        mock_execute_srun.return_value = (True, lscpu_output, "")

        tpc, notes = detect_threads_per_core(node_list=["node01", "node02", "node03"])

        assert tpc == 2
        mock_execute_srun.assert_called_once()
        call_kwargs = mock_execute_srun.call_args[1]
        assert call_kwargs["node"] == "node01"

    @patch("runscripts.CPMIP.monitor.system.detector.execute_srun")
    def test_detect_tpc_with_real_lscpu_format(
        self, mock_execute_srun, real_lscpu_output
    ):
        """
        GIVEN real production lscpu output
        WHEN detect_threads_per_core parses it
        THEN extract TPC correctly.
        """
        mock_execute_srun.return_value = (True, real_lscpu_output, "")

        tpc, notes = detect_threads_per_core(node_list=["glogin4"])

        assert tpc == 2  # glogin4 has SMT enabled
        assert notes == []
