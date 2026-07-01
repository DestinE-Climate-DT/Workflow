"""Tests for scontrol collector module."""

from unittest.mock import patch

from runscripts.CPMIP.monitor.slurm.scontrol.collector import collect_job_metadata


class TestCollectJobMetadata:
    """Tests for collect_job_metadata function."""

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_successful_metadata_collection(self, mock_execute):
        """
        GIVEN scontrol command succeeds with valid output
        WHEN collect_job_metadata is called
        THEN return complete job metadata dict.
        """
        mock_scontrol_output = """JobId=12345 JobName=test_job
   UserId=user123(1000) GroupId=group1(1000) MCS_label=N/A
   Priority=4294901757 Nice=0 Account=myaccount QOS=normal
   JobState=RUNNING Reason=None Dependency=(null)
   Requeue=1 Restarts=0 BatchFlag=1 Reboot=0 ExitCode=0:0
   RunTime=00:15:30 TimeLimit=01:00:00 TimeMin=N/A
   SubmitTime=2024-01-15T10:00:00 EligibleTime=2024-01-15T10:00:00
   AccrueTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00 EndTime=2024-01-15T11:05:00 Deadline=N/A
   SuspendTime=None SecsPreSuspend=0 LastSchedEval=2024-01-15T10:05:00 Scheduler=Main
   Partition=compute AllocNode:Sid=login01:12345
   ReqNodeList=(null) ExcNodeList=(null)
   NodeList=nid[001-004]
   BatchHost=nid001
   NumNodes=4 NumCPUs=128 NumTasks=64 CPUs/Task=2 ReqB:S:C:T=0:0:*:*
   TRES=cpu=128,mem=512G,node=4,billing=128
   AllocTRES=cpu=128,mem=512G,node=4
   Socks/Node=* NtasksPerN:B:S:C=0:0:*:* CoreSpec=*
   MinCPUsNode=1 MinMemoryCPU=4G MinTmpDiskNode=0
   Features=(null) DelayBoot=00:00:00
   OverSubscribe=OK Contiguous=0 Licenses=(null) Network=(null)
   Command=/home/user/script.sh
   WorkDir=/home/user/project
   StdErr=/home/user/project/job.err
   StdOut=/home/user/project/job.out
   Power=
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)

        result = collect_job_metadata("12345", threads_per_core=2)

        assert result["Job_Id"] == "12345"
        assert result["Job_Name"] == "test_job"
        assert result["Account"] == "myaccount"
        assert result["State"] == "RUNNING"
        assert result["Partition"] == "compute"
        assert result["User_Id"] == "user123(1000)"
        assert result["Quality_Of_Service"] == "normal"
        assert result["Allocated_Node_List"]["Count"] == 4
        assert "nid001" in result["Allocated_Node_List"]["Nodes"]
        assert result["Threads_Per_Core_Count"] == 2
        assert result["Resource_Info"]["Num_CPUs_Count"] == 64  # 128 / 2
        assert result["Files_Info"]["Command"] == "/home/user/script.sh"

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_scontrol_command_failure(self, mock_execute):
        """
        GIVEN scontrol command fails
        WHEN collect_job_metadata is called
        THEN return empty metadata with error note.
        """
        mock_execute.return_value = (False, "", "Command not found")

        result = collect_job_metadata("99999", threads_per_core=2)

        assert result["Job_Id"] == "99999"
        assert result["Job_Name"] == "N/A"
        assert "Notes" in result
        assert any("scontrol command failed" in note for note in result["Notes"])

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    @patch("runscripts.CPMIP.monitor.system.detector.detect_threads_per_core")
    def test_auto_detect_tpc(self, mock_detect, mock_execute):
        """
        GIVEN threads_per_core is None
        WHEN collect_job_metadata is called
        THEN auto-detect TPC using detect_threads_per_core.
        """
        mock_scontrol_output = """JobId=12345 JobName=test_job
   UserId=user123(1000) GroupId=group1(1000)
   Account=myaccount QOS=normal
   JobState=RUNNING
   NodeList=nid001
   NumCPUs=64 NumTasks=32 CPUs/Task=2 NumNodes=1
   AllocTRES=cpu=64,mem=256G,node=1
   Command=/home/user/script.sh
   WorkDir=/home/user
   SubmitTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00
   EndTime=2024-01-15T11:05:00
   RunTime=00:15:30
   AllocNode:Sid=login01:12345
   Partition=compute
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)
        mock_detect.return_value = (2, ["Auto-detected TPC=2"])

        result = collect_job_metadata("12345", threads_per_core=None)

        assert result["Threads_Per_Core_Count"] == 2
        mock_detect.assert_called_once()
        assert any("Auto-detected" in note for note in result.get("Notes", []))

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_completed_job_state(self, mock_execute):
        """
        GIVEN job is in COMPLETED state
        WHEN collect_job_metadata parses output
        THEN extract completion times correctly.
        """
        mock_scontrol_output = """JobId=12345 JobName=completed_job
   UserId=user123(1000)
   Account=myaccount QOS=normal
   JobState=COMPLETED ExitCode=0:0
   NodeList=nid001
   NumCPUs=32 NumTasks=16 CPUs/Task=2 NumNodes=1
   AllocTRES=cpu=32,mem=128G,node=1
   Command=/home/user/script.sh
   WorkDir=/home/user
   SubmitTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00
   EndTime=2024-01-15T10:30:00
   RunTime=00:25:00
   AllocNode:Sid=login01:12345
   Partition=compute
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)

        result = collect_job_metadata("12345", threads_per_core=1)

        assert result["State"] == "COMPLETED"
        assert result["Exit_Code"] == "0:0"
        assert result["Timing_Info"]["Actual_End_Time_ISO"] == "2024-01-15T10:30:00"
        assert result["Timing_Info"]["Estimated_End_Time_ISO"] == "N/A"

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_failed_job_state(self, mock_execute):
        """
        GIVEN job is in FAILED state
        WHEN collect_job_metadata parses output
        THEN extract failure information.
        """
        mock_scontrol_output = """JobId=12345 JobName=failed_job
   UserId=user123(1000)
   Account=myaccount QOS=normal
   JobState=FAILED ExitCode=1:0
   NodeList=nid001
   NumCPUs=32 NumTasks=16 CPUs/Task=2 NumNodes=1
   AllocTRES=cpu=32,mem=128G,node=1
   Command=/home/user/script.sh
   WorkDir=/home/user
   SubmitTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00
   EndTime=2024-01-15T10:15:00
   RunTime=00:10:00
   AllocNode:Sid=login01:12345
   Partition=compute
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)

        result = collect_job_metadata("12345", threads_per_core=1)

        assert result["State"] == "FAILED"
        assert result["Exit_Code"] == "1:0"

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_multi_node_job(self, mock_execute):
        """
        GIVEN job runs on multiple nodes
        WHEN collect_job_metadata parses NodeList
        THEN expand node ranges correctly.
        """
        mock_scontrol_output = """JobId=12345 JobName=multi_node
   UserId=user123(1000)
   Account=myaccount QOS=normal
   JobState=RUNNING
   NodeList=nid[001-008]
   NumCPUs=256 NumTasks=128 CPUs/Task=2 NumNodes=8
   AllocTRES=cpu=256,mem=1024G,node=8
   Command=/home/user/mpi_job.sh
   WorkDir=/home/user
   SubmitTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00
   EndTime=2024-01-15T12:05:00
   RunTime=00:30:00
   AllocNode:Sid=login01:12345
   Partition=compute
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)

        result = collect_job_metadata("12345", threads_per_core=2)

        assert result["Allocated_Node_List"]["Count"] == 8
        assert len(result["Allocated_Node_List"]["Nodes"]) == 8
        assert result["Resource_Info"]["Num_Nodes_Count"] == 8
        assert result["Resource_Info"]["Num_CPUs_Count"] == 128  # 256 / 2

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_missing_alloc_node(self, mock_execute):
        """
        GIVEN AllocNode field is missing
        WHEN collect_job_metadata parses output
        THEN default AllocNode to N/A.
        """
        mock_scontrol_output = """JobId=12345 JobName=test_job
   UserId=user123(1000)
   Account=myaccount QOS=normal
   JobState=RUNNING
   NodeList=nid001
   NumCPUs=32 NumTasks=16 CPUs/Task=2 NumNodes=1
   AllocTRES=cpu=32,mem=128G,node=1
   Command=/home/user/script.sh
   WorkDir=/home/user
   SubmitTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00
   EndTime=2024-01-15T11:05:00
   RunTime=00:15:30
   Partition=compute
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)

        result = collect_job_metadata("12345", threads_per_core=1)

        assert "Notes" in result
        assert any("AllocNode field is empty" in note for note in result["Notes"])

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_tres_allocated_parsing(self, mock_execute):
        """
        GIVEN TRES field contains complex allocation
        WHEN collect_job_metadata parses output
        THEN extract cpu, mem, node counts.
        """
        mock_scontrol_output = """JobId=12345 JobName=test_job
   UserId=user123(1000)
   Account=myaccount QOS=normal
   JobState=RUNNING
   NodeList=nid001
   NumCPUs=64 NumTasks=32 CPUs/Task=2 NumNodes=1
   AllocTRES=cpu=64,mem=512000M,node=1,billing=64
   Command=/home/user/script.sh
   WorkDir=/home/user
   SubmitTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00
   EndTime=2024-01-15T11:05:00
   RunTime=00:15:30
   AllocNode:Sid=login01:12345
   Partition=compute
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)

        result = collect_job_metadata("12345", threads_per_core=2)

        assert "Tres_Allocated" in result
        tres = result["Tres_Allocated"]
        assert tres.get("Cpu_Count") == 32
        assert tres.get("Mem_Bytes") == 536870912000
        assert tres.get("Node_Count") == 1

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_tpc_4_normalization(self, mock_execute):
        """
        GIVEN TPC=4 is specified
        WHEN collect_job_metadata normalizes CPUs
        THEN divide NumCPUs by 4.
        """
        mock_scontrol_output = """JobId=12345 JobName=test_job
   UserId=user123(1000)
   Account=myaccount QOS=normal
   JobState=RUNNING
   NodeList=nid001
   NumCPUs=256 NumTasks=64 CPUs/Task=4 NumNodes=1
   AllocTRES=cpu=256,mem=512G,node=1
   Command=/home/user/script.sh
   WorkDir=/home/user
   SubmitTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00
   EndTime=2024-01-15T11:05:00
   RunTime=00:15:30
   AllocNode:Sid=login01:12345
   Partition=compute
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)

        result = collect_job_metadata("12345", threads_per_core=4)

        assert result["Resource_Info"]["Num_CPUs_Count"] == 64  # 256 / 4
        assert result["Resource_Info"]["CPUs_Per_Task_Count"] == 1  # 4 / 4
        assert result["Tres_Allocated"].get("Cpu_Count") == 64  # 256 / 4

    @patch("runscripts.CPMIP.monitor.slurm.scontrol.collector.execute_command")
    def test_empty_account_field(self, mock_execute):
        """
        GIVEN Account field is empty or (null)
        WHEN collect_job_metadata parses output
        THEN handle null values gracefully.
        """
        mock_scontrol_output = """JobId=12345 JobName=test_job
   UserId=user123(1000)
   Account=
   QOS=normal
   JobState=RUNNING
   NodeList=nid001
   NumCPUs=32 NumTasks=16 CPUs/Task=2 NumNodes=1
   AllocTRES=cpu=32,mem=128G,node=1
   Command=/home/user/script.sh
   WorkDir=/home/user
   SubmitTime=2024-01-15T10:00:00
   StartTime=2024-01-15T10:05:00
   EndTime=2024-01-15T11:05:00
   RunTime=00:15:30
   AllocNode:Sid=login01:12345
   Partition=compute
"""
        mock_execute.return_value = (True, mock_scontrol_output, None)

        result = collect_job_metadata("12345", threads_per_core=1)

        assert result["Account"] == "N/A"
