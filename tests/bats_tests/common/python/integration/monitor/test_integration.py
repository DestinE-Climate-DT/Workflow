"""
Integration tests for SLURM monitor - End-to-End workflows.

These tests verify the complete pipeline from data collection to final output:
- collector → parser → builder → aggregator (for sstat)
- collector → parser → builder (for scontrol, pidstat)
- Full monitor workflow combining all commands

Focus: Integration between modules, not individual function logic.
"""

import pytest
from unittest.mock import patch, MagicMock

from runscripts.CPMIP.monitor.slurm.sstat.steps.collector import collect_sstat_steps
from runscripts.CPMIP.monitor.slurm.sstat.aggregation.aggregator import (
    aggregate_sstat_steps,
)
from runscripts.CPMIP.monitor.slurm.scontrol.collector import collect_job_metadata
from runscripts.CPMIP.monitor.pidstat.collector import collect_single_node
from runscripts.CPMIP.monitor.constants import SSTAT_FIELDS


class TestSstatEndToEnd:
    """End-to-end tests for sstat complete pipeline."""

    def test_sstat_full_pipeline_success(self, real_sstat_parseable_output):
        """
        GIVEN real sstat output from production
        WHEN full pipeline executes: collect → parse → build → aggregate
        THEN return valid aggregated statistics with all fields.
        """
        with patch(
            "runscripts.CPMIP.monitor.slurm.sstat.steps.collector.execute_command"
        ) as mock_cmd:
            mock_cmd.return_value = (True, real_sstat_parseable_output, "")

            job_id = "32635121"

            processed_steps = collect_sstat_steps(job_id)

            assert len(processed_steps) == 1
            assert f"{job_id}.16" in processed_steps

            aggregated = aggregate_sstat_steps(processed_steps, job_id)

            assert aggregated["Job_Id"] == job_id
            assert "Memory_Related" in aggregated
            assert "Cpu_Related" in aggregated
            assert "Storage_IO" in aggregated

            memory = aggregated["Memory_Related"]
            assert "Physical_Memory" in memory
            # MaxRSS = 81639443K = 83,598,789,632 bytes
            assert memory["Physical_Memory"]["Max_Bytes"] == 83598789632

            cpu = aggregated["Cpu_Related"]
            assert "Cpu_Time_Stats" in cpu
            # With the corrected fixture: NTasks=3, AveCPU=00:25:07 = 1507s, Total = 3 * 1507 = 4521s
            assert cpu["Cpu_Time_Stats"]["Total_Cpu_Time_Seconds"] == 4521.0

    def test_sstat_pipeline_with_single_step(self):
        """
        GIVEN job with only batch step (no parallel steps)
        WHEN pipeline executes
        THEN aggregate single step correctly.
        """
        with patch(
            "runscripts.CPMIP.monitor.slurm.sstat.steps.collector.execute_command"
        ) as mock_cmd:
            # Create properly formatted data with all 46 SSTAT_FIELDS + JobID
            # Fields: MaxVMSize, MaxVMSizeNode, MaxVMSizeTask, AveVMSize, MaxRSS, MaxRSSNode, MaxRSSTask, AveRSS,
            #         MaxDiskRead, MaxDiskReadNode, MaxDiskReadTask, AveDiskRead, MaxDiskWrite, MaxDiskWriteNode, MaxDiskWriteTask, AveDiskWrite,
            #         MaxPages, MaxPagesNode, MaxPagesTask, AvePages, ConsumedEnergy,
            #         NTasks, MinCPU, MinCPUNode, MinCPUTask, AveCPU, AveCPUFreq,
            #         ReqCPUFreqMin, ReqCPUFreqMax, ReqCPUFreqGov,
            #         TRESUsageInTot, TRESUsageOutTot,
            #         TRESUsageInMax, TRESUsageInMaxNode, TRESUsageInMaxTask,
            #         TRESUsageOutMax, TRESUsageOutMaxNode, TRESUsageOutMaxTask,
            #         TRESUsageInMin, TRESUsageInMinNode, TRESUsageInMinTask,
            #         TRESUsageOutMin, TRESUsageOutMinNode, TRESUsageOutMinTask,
            #         TRESUsageInAve, TRESUsageOutAve
            single_step = (
                "12345.batch|"
                "4G|node01|0|2G|"  # VM: Max, MaxNode, MaxTask, Ave
                "2G|node01|0|1G|"  # RSS: Max, MaxNode, MaxTask, Ave
                "500K|node01|0|250K|"  # DiskRead: Max, MaxNode, MaxTask, Ave
                "1M|node01|0|500K|"  # DiskWrite: Max, MaxNode, MaxTask, Ave
                "100|node01|0|50|"  # Pages: Max, MaxNode, MaxTask, Ave
                "1000|"  # ConsumedEnergy
                "16|00:30:00|node01|0|01:00:00|2.5M|"  # NTasks, MinCPU, MinCPUNode, MinCPUTask, AveCPU, AveCPUFreq
                "Unknown|Unknown|Unknown|"  # ReqCPUFreqMin, Max, Gov
                "cpu=16:00:00,mem=32G,energy=1000|cpu=2M,fs/disk=1M|"  # TRESUsageInTot, OutTot
                "cpu=01:30:00,mem=4G|cpu=node01,mem=node01|cpu=0,mem=0|"  # InMax, InMaxNode, InMaxTask
                "cpu=00:45:00,mem=2.5G|cpu=node01,mem=node01|cpu=0,mem=0|"  # OutMax, OutMaxNode, OutMaxTask
                "cpu=00:15:00,mem=1.5G|cpu=node01,mem=node01|cpu=0,mem=0|"  # InMin, InMinNode, InMinTask
                "cpu=00:50:00,mem=2.2G|cpu=node01,mem=node01|cpu=0,mem=0|"  # OutMin, OutMinNode, OutMinTask
                "cpu=01:00:00,mem=2G|cpu=00:40:00,mem=2G"  # InAve, OutAve
            )

            mock_cmd.return_value = (True, single_step, "")

            steps = collect_sstat_steps("12345")
            aggregated = aggregate_sstat_steps(steps, "12345")

            assert len(steps) == 1
            assert "12345.batch" in steps
            assert aggregated["Job_Id"] == "12345"
            assert "Memory_Related" in aggregated
            assert "Cpu_Related" in aggregated
            assert "Storage_IO" in aggregated

    def test_sstat_pipeline_handles_collection_failure(self):
        """
        GIVEN sstat command fails (job not found)
        WHEN pipeline executes
        THEN handle gracefully and return empty.
        """
        with patch(
            "runscripts.CPMIP.monitor.slurm.sstat.steps.collector.execute_command"
        ) as mock_cmd:
            mock_cmd.return_value = (
                False,
                "",
                "slurm_load_jobs error: Invalid job id specified",
            )

            steps = collect_sstat_steps("999999")
            assert steps == {}

            aggregated = aggregate_sstat_steps(steps, "999999")
            assert aggregated["Job_Id"] == "999999"
            assert "Memory_Related" in aggregated
            assert "Cpu_Related" in aggregated
            assert "Storage_IO" in aggregated


class TestScontrolEndToEnd:
    """End-to-end tests for scontrol complete pipeline."""

    def test_scontrol_full_pipeline_success(self, real_scontrol_output):
        """
        GIVEN real scontrol output from production
        WHEN full pipeline executes: collect → parse → build
        THEN return valid job metadata with all fields.
        """
        with patch(
            "runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command"
        ) as mock_cmd:
            mock_cmd.return_value = (True, real_scontrol_output, "")

            with patch(
                "runscripts.CPMIP.monitor.system.detector.detect_threads_per_core"
            ) as mock_tpc:
                mock_tpc.return_value = (2, [])

                metadata = collect_job_metadata("32266924")

                assert metadata is not None
                assert isinstance(metadata, dict)

                assert metadata["Job_Id"] == "32266924"
                assert metadata["Job_Name"] == "wrap"
                assert metadata["State"] == "RUNNING"

                # NumCPUs=2 with TPC=2 gives 1 physical core (2 logical / 2 = 1 physical)
                assert metadata["Resource_Info"]["Num_CPUs_Count"] == 1
                assert metadata["Resource_Info"]["Num_Nodes_Count"] == 1

                assert metadata["Allocated_Node_List"]["Count"] == 1
                assert metadata["Allocated_Node_List"]["Nodes"] == ["glogin3"]

    def test_scontrol_pipeline_job_not_found(self):
        """
        GIVEN job ID doesn't exist
        WHEN scontrol pipeline executes
        THEN return empty metadata with error note.
        """
        with patch(
            "runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command"
        ) as mock_cmd:
            mock_cmd.return_value = (
                False,
                "",
                "slurm_load_jobs error: Invalid job id specified",
            )

            metadata = collect_job_metadata("invalid_job")

            assert metadata is not None
            assert metadata["Job_Id"] == "invalid_job"
            assert metadata["Job_Name"] == "N/A"
            if "Notes" in metadata:
                assert len(metadata["Notes"]) == 1
                assert "scontrol command failed" in metadata["Notes"][0]

    def test_scontrol_pipeline_with_array_job(self):
        """
        GIVEN array job ID (e.g., 12345_1)
        WHEN scontrol pipeline executes
        THEN handle array job format correctly.
        """
        with patch(
            "runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command"
        ) as mock_cmd:
            output = "JobId=12345_1 ArrayJobId=12345 ArrayTaskId=1 JobName=array_job State=RUNNING NodeList=node[01-02]"
            mock_cmd.return_value = (True, output, "")

            with patch(
                "runscripts.CPMIP.monitor.system.detector.detect_threads_per_core"
            ) as mock_tpc:
                mock_tpc.return_value = (2, [])

                metadata = collect_job_metadata("12345_1")

                assert metadata is not None
                assert metadata["Job_Id"] == "12345_1"
                assert metadata["Job_Name"] == "array_job"
                assert metadata["State"] == "RUNNING"


class TestPidstatEndToEnd:
    """End-to-end tests for pidstat complete pipeline."""

    def test_pidstat_full_pipeline_success(
        self,
        real_pidstat_output,
        real_lscpu_output,
        real_free_output,
        real_uptime_output,
    ):
        """
        GIVEN real pidstat output from production
        WHEN full pipeline executes: collect → parse → build
        THEN return valid process statistics.
        """
        with patch(
            "runscripts.CPMIP.monitor.pidstat.collector.execute_srun"
        ) as mock_srun:

            def srun_side_effect(command, jobid, node, account, timeout):
                if "uptime" in str(command):
                    combined = f"{real_uptime_output}\n__SPLIT__\n{real_lscpu_output}\n__SPLIT__\n{real_free_output}"
                    return (True, combined, "")
                elif "pidstat" in str(command):
                    return (True, real_pidstat_output, "")
                else:
                    return (False, "", "Unknown command")

            mock_srun.side_effect = srun_side_effect

            stats = collect_single_node(
                node_name="node01", pidstat_path="/usr/bin/pidstat", jobid="12345"
            )

            assert stats is not None
            assert isinstance(stats, dict)
            assert "Summary" in stats
            assert "Processes" in stats
            assert "Node_General_Info" in stats
            assert "Cpu_Info" in stats["Node_General_Info"]
            assert "Memory_Info" in stats["Node_General_Info"]

    def test_pidstat_pipeline_node_unreachable(self):
        """
        GIVEN node is unreachable
        WHEN pidstat pipeline executes
        THEN handle SSH/connection failure gracefully.
        """
        with patch(
            "runscripts.CPMIP.monitor.pidstat.collector.execute_srun"
        ) as mock_srun:
            mock_srun.return_value = (
                False,
                "",
                "ssh: connect to host node99 port 22: Connection refused",
            )

            with pytest.raises(RuntimeError) as exc_info:
                collect_single_node(
                    node_name="node99", pidstat_path="/usr/bin/pidstat", jobid="12345"
                )

            assert "srun failed on node node99" in str(exc_info.value)


class TestFullMonitorWorkflow:
    """Integration test for complete monitor workflow with all commands."""

    def test_complete_monitoring_workflow(
        self,
        real_scontrol_output,
        real_sstat_parseable_output,
        real_lscpu_output,
        real_free_output,
    ):
        """
        GIVEN all SLURM/system commands available
        WHEN complete monitor workflow executes
        THEN collect all metrics without errors.
        """
        job_id = "32635121"  # Updated to match the new fixture data

        with patch("subprocess.run") as mock_run:

            def side_effect(*args, **kwargs):
                cmd = args[0] if args else kwargs.get("args", [])
                cmd_str = " ".join(cmd) if isinstance(cmd, list) else str(cmd)

                if "scontrol" in cmd_str:
                    return MagicMock(
                        stdout=real_scontrol_output, returncode=0, stderr=""
                    )
                elif "sstat" in cmd_str:
                    return MagicMock(
                        stdout=real_sstat_parseable_output, returncode=0, stderr=""
                    )
                elif "lscpu" in cmd_str:
                    return MagicMock(stdout=real_lscpu_output, returncode=0, stderr="")
                elif "free" in cmd_str:
                    return MagicMock(stdout=real_free_output, returncode=0, stderr="")
                else:
                    return MagicMock(stdout="", returncode=0, stderr="")

            mock_run.side_effect = side_effect

            metadata = collect_job_metadata(job_id)
            assert metadata is not None
            # The collector uses the job_id passed as parameter
            assert metadata["Job_Id"] == job_id
            # But the scontrol fixture has job name from a different job
            assert metadata["Job_Name"] == "wrap"

            steps = collect_sstat_steps(job_id)
            assert len(steps) == 1  # Updated: new fixture has only 1 step (.16)
            assert f"{job_id}.16" in steps  # The real fixture has step .16, not .extern or .batch

            aggregated = aggregate_sstat_steps(steps, job_id)
            assert aggregated["Job_Id"] == job_id
            assert "Memory_Related" in aggregated
            assert "Cpu_Related" in aggregated
            assert "Storage_IO" in aggregated

    def test_workflow_partial_failure(self):
        """
        GIVEN some commands succeed, some fail
        WHEN monitor workflow executes
        THEN continue with available data.
        """
        job_id = "12345"

        with patch("subprocess.run") as mock_run:

            def side_effect(*args, **kwargs):
                cmd = args[0] if args else kwargs.get("args", [])
                cmd_str = " ".join(cmd) if isinstance(cmd, list) else str(cmd)

                if "scontrol" in cmd_str:
                    return MagicMock(
                        stdout="JobId=12345 State=RUNNING", returncode=0, stderr=""
                    )
                elif "sstat" in cmd_str:
                    return MagicMock(
                        stdout="", returncode=1, stderr="Job has not started yet"
                    )
                else:
                    return MagicMock(stdout="", returncode=0, stderr="")

            mock_run.side_effect = side_effect

            metadata = collect_job_metadata(job_id)
            assert metadata is not None
            assert metadata["Job_Id"] == job_id

            steps = collect_sstat_steps(job_id)
            assert steps == {}

            aggregated = aggregate_sstat_steps(steps, job_id)
            assert aggregated["Job_Id"] == job_id
            assert "Memory_Related" in aggregated
            assert "Cpu_Related" in aggregated
            assert "Storage_IO" in aggregated
