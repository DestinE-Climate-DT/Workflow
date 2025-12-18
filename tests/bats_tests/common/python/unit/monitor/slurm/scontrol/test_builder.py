"""Tests for scontrol builder module."""

from runscripts.CPMIP.monitor.slurm.scontrol.builder import (
    build_empty_metadata,
    build_files_info,
    build_resource_info,
    build_timing_info,
)


class TestBuildTimingInfo:
    """Tests for build_timing_info function."""

    def test_running_job_timing(self):
        """
        GIVEN job state is RUNNING
        WHEN build_timing_info is called
        THEN set Estimated_End_Time and N/A for Actual_End_Time.
        """
        flat = {
            "SubmitTime": "2024-01-01T10:00:00",
            "StartTime": "2024-01-01T10:05:00",
            "EndTime": "2024-01-01T11:00:00",
            "RunTime": "00:55:00",
            "JobState": "RUNNING",
        }
        notes = []

        result = build_timing_info(flat, notes)

        assert result["Submit_Time_ISO"] == "2024-01-01T10:00:00"
        assert result["Start_Time_ISO"] == "2024-01-01T10:05:00"
        assert result["Estimated_End_Time_ISO"] == "2024-01-01T11:00:00"
        assert result["Actual_End_Time_ISO"] == "N/A"
        assert result["Run_Time_Seconds"] == 3300  # 55 minutes
        assert result["Elapsed_Time_Seconds"] == 3300
        assert any("RUNNING" in note for note in notes)

    def test_completed_job_timing(self):
        """
        GIVEN job state is COMPLETED
        WHEN build_timing_info is called
        THEN set Actual_End_Time and N/A for Estimated_End_Time.
        """
        flat = {
            "SubmitTime": "2024-01-01T10:00:00",
            "StartTime": "2024-01-01T10:05:00",
            "EndTime": "2024-01-01T11:00:00",
            "RunTime": "00:55:00",
            "JobState": "COMPLETED",
        }
        notes = []

        result = build_timing_info(flat, notes)

        assert result["Estimated_End_Time_ISO"] == "N/A"
        assert result["Actual_End_Time_ISO"] == "2024-01-01T11:00:00"
        assert result["Run_Time_Seconds"] == 3300
        assert any("COMPLETED" in note for note in notes)

    def test_failed_job_timing(self):
        """
        GIVEN job state is FAILED
        WHEN build_timing_info is called
        THEN set Actual_End_Time to failure time.
        """
        flat = {
            "SubmitTime": "2024-01-01T10:00:00",
            "StartTime": "2024-01-01T10:05:00",
            "EndTime": "2024-01-01T10:30:00",
            "RunTime": "00:25:00",
            "JobState": "FAILED",
        }
        notes = []

        result = build_timing_info(flat, notes)

        assert result["Estimated_End_Time_ISO"] == "N/A"
        assert result["Actual_End_Time_ISO"] == "2024-01-01T10:30:00"
        assert result["Run_Time_Seconds"] == 1500  # 25 minutes
        assert any("FAILED" in note for note in notes)

    def test_unknown_job_state(self):
        """
        GIVEN job has unknown state like PENDING
        WHEN build_timing_info is called
        THEN set both times to same EndTime value.
        """
        flat = {
            "SubmitTime": "2024-01-01T10:00:00",
            "StartTime": "2024-01-01T10:05:00",
            "EndTime": "2024-01-01T11:00:00",
            "RunTime": "00:55:00",
            "JobState": "PENDING",
        }
        notes = []

        result = build_timing_info(flat, notes)

        # Both should have the same value for unknown states
        assert result["Estimated_End_Time_ISO"] == "2024-01-01T11:00:00"
        assert result["Actual_End_Time_ISO"] == "2024-01-01T11:00:00"
        assert any("PENDING" in note for note in notes)

    def test_missing_fields_defaults(self):
        """
        GIVEN timing fields are missing
        WHEN build_timing_info is called
        THEN default all timestamp fields to N/A.
        """
        flat = {}
        notes = []

        result = build_timing_info(flat, notes)

        assert result["Submit_Time_ISO"] == "N/A"
        assert result["Start_Time_ISO"] == "N/A"
        assert result["Estimated_End_Time_ISO"] == "N/A"
        assert result["Actual_End_Time_ISO"] == "N/A"
        assert result["Run_Time_Seconds"] == 0
        assert result["Elapsed_Time_Seconds"] == 0

    def test_runtime_conversion(self):
        """
        GIVEN RunTime is in HH:MM:SS format
        WHEN build_timing_info converts it
        THEN set Run_Time_Seconds and Elapsed_Time_Seconds.
        """
        test_cases = [
            ("00:05:00", 300),  # 5 minutes
            ("01:00:00", 3600),  # 1 hour
            ("1-00:00:00", 86400),  # 1 day
        ]

        for runtime_str, expected_seconds in test_cases:
            flat = {"RunTime": runtime_str, "JobState": "RUNNING"}
            notes = []
            result = build_timing_info(flat, notes)
            assert result["Run_Time_Seconds"] == expected_seconds


class TestBuildResourceInfo:
    """Tests for build_resource_info function."""

    def test_resource_info_with_tpc_2(self):
        """
        GIVEN TPC=2 (hyperthreading enabled)
        WHEN build_resource_info is called
        THEN normalize NumCPUs by dividing by 2.
        """
        flat = {
            "NumCPUs": "128",
            "NumTasks": "64",
            "CPUs/Task": "2",
            "NumNodes": "4",
        }

        result = build_resource_info(flat, threads_per_core=2)

        assert result["Num_CPUs_Count"] == 64  # 128 / 2
        assert result["Num_Tasks_Count"] == 64
        assert result["CPUs_Per_Task_Count"] == 1  # 2 / 2
        assert result["Num_Nodes_Count"] == 4

    def test_resource_info_with_tpc_1(self):
        """
        GIVEN TPC=1 (hyperthreading disabled)
        WHEN build_resource_info is called
        THEN NumCPUs remains unchanged.
        """
        flat = {
            "NumCPUs": "64",
            "NumTasks": "32",
            "CPUs/Task": "2",
            "NumNodes": "2",
        }

        result = build_resource_info(flat, threads_per_core=1)

        assert result["Num_CPUs_Count"] == 64
        assert result["Num_Tasks_Count"] == 32
        assert result["CPUs_Per_Task_Count"] == 2
        assert result["Num_Nodes_Count"] == 2

    def test_resource_info_with_tpc_4(self):
        """
        GIVEN TPC=4 (4 threads per core)
        WHEN build_resource_info is called
        THEN normalize NumCPUs by dividing by 4.
        """
        flat = {
            "NumCPUs": "256",
            "NumTasks": "128",
            "CPUs/Task": "4",
            "NumNodes": "8",
        }

        result = build_resource_info(flat, threads_per_core=4)

        assert result["Num_CPUs_Count"] == 64  # 256 / 4
        assert result["Num_Tasks_Count"] == 128
        assert result["CPUs_Per_Task_Count"] == 1  # 4 / 4
        assert result["Num_Nodes_Count"] == 8

    def test_resource_info_missing_fields(self):
        """
        GIVEN resource fields are missing
        WHEN build_resource_info is called
        THEN default numeric fields to 0.
        """
        flat = {}

        result = build_resource_info(flat, threads_per_core=2)

        # convert_to_physical_cores returns minimum 1, not 0
        assert result["Num_CPUs_Count"] == 1
        assert result["Num_Tasks_Count"] == 0
        assert result["CPUs_Per_Task_Count"] == 1
        assert result["Num_Nodes_Count"] == 0

    def test_resource_info_partial_data(self):
        """
        GIVEN only some resource fields present
        WHEN build_resource_info is called
        THEN extract available fields and default others.
        """
        flat = {
            "NumCPUs": "32",
            "NumNodes": "1",
        }

        result = build_resource_info(flat, threads_per_core=2)

        assert result["Num_CPUs_Count"] == 16  # 32 / 2
        assert result["Num_Tasks_Count"] == 0  # Missing
        assert result["CPUs_Per_Task_Count"] == 1  # Missing, minimum 1
        assert result["Num_Nodes_Count"] == 1


class TestBuildFilesInfo:
    """Tests for build_files_info function."""

    def test_files_info_complete(self):
        """
        GIVEN all file paths are present
        WHEN build_files_info is called
        THEN extract Command, WorkDir, StdOut, StdErr.
        """
        flat = {
            "Command": "/path/to/script.sh",
            "WorkDir": "/home/user/project",
            "StdErr": "/path/to/error.log",
            "StdOut": "/path/to/output.log",
            "BatchHost": "node01",
        }

        result = build_files_info(flat)

        assert result["Command"] == "/path/to/script.sh"
        assert result["Working_Directory"] == "/home/user/project"
        assert result["Std_Error_Path"] == "/path/to/error.log"
        assert result["Std_Output_Path"] == "/path/to/output.log"
        assert result["Batch_Host"] == "node01"

    def test_files_info_missing_fields(self):
        """
        GIVEN file path fields are missing
        WHEN build_files_info is called
        THEN default missing paths to N/A.
        """
        flat = {}

        result = build_files_info(flat)

        assert result["Command"] == "N/A"
        assert result["Working_Directory"] == "N/A"
        assert result["Std_Error_Path"] == "N/A"
        assert result["Std_Output_Path"] == "N/A"
        assert result["Batch_Host"] == "N/A"

    def test_files_info_partial_data(self):
        """
        GIVEN only some file paths present
        WHEN build_files_info is called
        THEN extract available paths and default others.
        """
        flat = {
            "Command": "python my_script.py",
            "WorkDir": "/tmp",
        }

        result = build_files_info(flat)

        assert result["Command"] == "python my_script.py"
        assert result["Working_Directory"] == "/tmp"
        assert result["Std_Error_Path"] == "N/A"
        assert result["Std_Output_Path"] == "N/A"
        assert result["Batch_Host"] == "N/A"


class TestBuildEmptyMetadata:
    """Tests for build_empty_metadata function."""

    def test_empty_metadata_creation(self):
        """
        GIVEN scontrol command fails
        WHEN create_empty_metadata is called
        THEN return metadata dict with error note.
        """
        result = build_empty_metadata("12345", "scontrol command failed")

        assert result["Job_Id"] == "12345"
        assert result["Job_Name"] == "N/A"
        assert result["Partition"] == "N/A"
        assert result["Account"] == "N/A"
        assert result["User_Id"] == "N/A"
        assert result["Quality_Of_Service"] == "N/A"
        assert result["State"] == "N/A"
        assert result["Exit_Code"] == "N/A"
        assert result["Allocated_Node_List"]["Nodes"] == []
        assert result["Allocated_Node_List"]["Count"] == 0
        assert result["Timing_Info"]["Run_Time_Seconds"] == 0
        assert result["Resource_Info"]["Num_CPUs_Count"] == 0
        assert result["Threads_Per_Core_Count"] == 1
        assert "scontrol command failed" in result["Notes"]

    def test_empty_metadata_different_error(self):
        """
        GIVEN error message is provided
        WHEN create_empty_metadata is called
        THEN include error message in Notes.
        """
        result = build_empty_metadata("99999", "Job not found")

        assert result["Job_Id"] == "99999"
        assert "Job not found" in result["Notes"]

    def test_empty_metadata_structure_validity(self):
        """
        GIVEN empty metadata is created
        WHEN create_empty_metadata returns dict
        THEN have all required keys with N/A or 0 values.
        """
        result = build_empty_metadata("54321", "Test error")

        # Verify all required keys exist
        required_keys = [
            "Job_Id",
            "Job_Name",
            "Partition",
            "Account",
            "User_Id",
            "Quality_Of_Service",
            "State",
            "Exit_Code",
            "Allocated_Node_List",
            "Alloc_Node",
            "Timing_Info",
            "Resource_Info",
            "Tres_Allocated",
            "Files_Info",
            "Threads_Per_Core_Count",
            "Notes",
        ]

        for key in required_keys:
            assert key in result, f"Missing key: {key}"
