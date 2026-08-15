"""
Unit tests for SLURM sstat parser module.

This module tests the sstat parsing logic that transforms raw SLURM sstat output
into normalized, typed data structures with proper unit conversions.
"""

import pytest

from runscripts.CPMIP.monitor.slurm.sstat.steps.builder import build_step_stats

# Alias for backward compatibility in tests
parse_step_data = build_step_stats


class TestStepDataParsing:
    """
    Test suite for sstat step data parsing.

    Tests the main parse_step_data function that orchestrates all building
    functions to produce a complete ProcessedStepStats dictionary.
    """

    def test_parse_step_data_complete(self):
        """
        GIVEN sstat output has all fields
        WHEN parse_step_data is called
        THEN return dict with all step data.
        """
        raw_data = {
            "MaxRSS": "4096M",
            "MaxRSSNode": "nid001",
            "MaxRSSTask": "0",
            "AveRSS": "2048M",
            "MaxVMSize": "8192M",
            "MaxVMSizeNode": "nid001",
            "MaxVMSizeTask": "0",
            "AveVMSize": "4096M",
            "MaxDiskRead": "1024M",
            "MaxDiskReadNode": "nid001",
            "MaxDiskReadTask": "0",
            "AveDiskRead": "512M",
            "MaxDiskWrite": "2048M",
            "MaxDiskWriteNode": "nid001",
            "MaxDiskWriteTask": "0",
            "AveDiskWrite": "1024M",
            "MaxPages": "1000",
            "MaxPagesNode": "nid001",
            "MaxPagesTask": "0",
            "AvePages": "500",
            "ConsumedEnergy": "100.5",
            "NTasks": "10",
            "MinCPU": "00:05:00",
            "MinCPUNode": "nid001",
            "MinCPUTask": "0",
            "AveCPU": "00:10:00",
            "AveCPUFreq": "2000.0",
            "ReqCPUFreqMin": "Unknown",
            "ReqCPUFreqMax": "Unknown",
            "ReqCPUFreqGov": "Unknown",
            "TRESUsageInTot": "cpu=600,mem=4G",
            "TRESUsageOutTot": "cpu=1200,mem=8G",
            "TRESUsageInMax": "cpu=300,mem=2G",
            "TRESUsageInMaxNode": "nid001",
            "TRESUsageInMaxTask": "0",
            "TRESUsageOutMax": "cpu=600,mem=4G",
            "TRESUsageOutMaxNode": "nid001",
            "TRESUsageOutMaxTask": "0",
            "TRESUsageInMin": "cpu=150,mem=1G",
            "TRESUsageInMinNode": "nid001",
            "TRESUsageInMinTask": "0",
            "TRESUsageOutMin": "cpu=300,mem=2G",
            "TRESUsageOutMinNode": "nid001",
            "TRESUsageOutMinTask": "0",
            "TRESUsageInAve": "cpu=200,mem=1500M",
            "TRESUsageOutAve": "cpu=400,mem=3G",
        }

        result = parse_step_data("12345", "12345.0", raw_data)

        # Verify structure
        assert result["Job_Id"] == "12345"
        assert result["Step_Id"] == "12345.0"
        assert "Memory_Related" in result
        assert "CPU_Related" in result
        assert "Disk_IO" in result
        assert "TRES_Usage" in result

        # Verify memory parsing (4096M = 4096 * 1024 * 1024 bytes)
        assert (
            result["Memory_Related"]["Physical_Memory"]["Max_Bytes"]
            == 4096 * 1024 * 1024
        )
        assert (
            result["Memory_Related"]["Physical_Memory"]["Average_Bytes"]
            == 2048 * 1024 * 1024
        )
        assert result["Memory_Related"]["Physical_Memory"]["Max_Node"] == "nid001"

        # Verify CPU parsing (00:10:00 = 600 seconds)
        assert (
            result["CPU_Related"]["CPU_Time_Stats"]["Average_Cpu_Time_Seconds"] == 600.0
        )
        assert result["CPU_Related"]["CPU_Time_Stats"]["Total_Tasks_Count"] == 10

        # Verify disk I/O parsing
        assert result["Disk_IO"]["Read_Stats"]["Max_Bytes"] == 1024 * 1024 * 1024

    def test_parse_step_data_minimal(self):
        """
        GIVEN sstat output has minimal fields
        WHEN parse_step_data is called
        THEN handle missing optional fields.
        """
        raw_data = {}

        result = parse_step_data("12345", "12345.batch", raw_data)

        # Should not raise exceptions
        assert result["Job_Id"] == "12345"
        assert result["Step_Id"] == "12345.batch"

        # Should have default values
        assert result["Memory_Related"]["Physical_Memory"]["Max_Bytes"] == 0
        assert result["CPU_Related"]["CPU_Time_Stats"]["Total_Tasks_Count"] == 0

    def test_parse_step_data_zero_values(self):
        """
        GIVEN step has zero CPU/memory values
        WHEN parse_step_data is called
        THEN preserve zero values correctly.
        """
        raw_data = {
            "MaxRSS": "0",
            "AveRSS": "0",
            "MaxVMSize": "0",
            "AveVMSize": "0",
            "MaxDiskRead": "0",
            "AveDiskRead": "0",
            "MaxDiskWrite": "0",
            "AveDiskWrite": "0",
            "MaxPages": "0",
            "AvePages": "0",
            "ConsumedEnergy": "0",
            "NTasks": "0",
            "MinCPU": "00:00:00",
            "AveCPU": "00:00:00",
        }

        result = parse_step_data("12345", "12345.0", raw_data)

        # Zero values should be preserved
        assert result["Memory_Related"]["Physical_Memory"]["Max_Bytes"] == 0
        assert result["Disk_IO"]["Read_Stats"]["Max_Bytes"] == 0
        assert result["Page_Faults"]["Max_Count"] == 0
        assert result["Energy_Consumption"]["Total_Energy_Joules"] == 0.0

    @pytest.mark.parametrize(
        "job_id,step_id",
        [
            ("12345", "12345.0"),
            ("67890", "67890.batch"),
            ("11111", "11111.extern"),
            ("22222", "22222.1"),
        ],
        ids=["main_step", "batch_step", "extern_step", "numbered_step"],
    )
    def test_parse_step_data_preserves_ids(self, job_id: str, step_id: str):
        """
        GIVEN JobID, StepID, StepName present
        WHEN parse_step_data is called
        THEN extract identifiers correctly.
        """
        result = parse_step_data(job_id, step_id, {})

        assert result["Job_Id"] == job_id
        assert result["Step_Id"] == step_id


class TestStepDataTypes:
    """
    Test suite for type correctness of parsed step data.

    Verifies that parsed data conforms to the expected TypedDict schemas
    defined in types/sstat.py.
    """

    def test_memory_related_types(self):
        """
        GIVEN memory fields parsed
        WHEN parse_step_data is called
        THEN convert to correct integer types.
        """
        raw_data = {
            "MaxRSS": "4096M",
            "AveRSS": "2048M",
            "MaxVMSize": "8192M",
            "AveVMSize": "4096M",
            "MaxPages": "1000",
            "AvePages": "500",
        }

        result = parse_step_data("12345", "12345.0", raw_data)
        mem = result["Memory_Related"]

        # Check types
        assert isinstance(mem["Physical_Memory"]["Max_Bytes"], int)
        assert isinstance(mem["Physical_Memory"]["Average_Bytes"], int)
        assert isinstance(mem["Virtual_Memory"]["Max_Bytes"], int)
        assert isinstance(mem["Memory_Efficiency"]["Physical_To_Virtual_Ratio"], float)

    def test_cpu_related_types(self):
        """
        GIVEN CPU time fields parsed
        WHEN parse_step_data is called
        THEN preserve as strings for later conversion.
        """
        raw_data = {
            "NTasks": "10",
            "MinCPU": "00:05:00",
            "AveCPU": "00:10:00",
            "AveCPUFreq": "2000.0",
            "ReqCPUFreqMin": "1000",
            "ReqCPUFreqMax": "3000",
            "ReqCPUFreqGov": "performance",
        }

        result = parse_step_data("12345", "12345.0", raw_data)
        cpu = result["CPU_Related"]

        # Check types
        assert isinstance(cpu["CPU_Time_Stats"]["Total_Tasks_Count"], int)
        assert isinstance(cpu["CPU_Time_Stats"]["Average_Cpu_Time_Seconds"], float)
        assert isinstance(cpu["CPU_Time_Stats"]["Cpu_Time_Variation"], float)
        assert isinstance(cpu["CPU_Frequency"]["Average_Frequency_KHz"], float)
        assert isinstance(cpu["CPU_Frequency"]["Requested_Min_Frequency_KHz"], str)

    def test_disk_io_types(self):
        """
        GIVEN disk I/O fields parsed
        WHEN parse_step_data is called
        THEN convert to bytes correctly.
        """
        raw_data = {
            "MaxDiskRead": "1024M",
            "AveDiskRead": "512M",
            "MaxDiskWrite": "2048M",
            "AveDiskWrite": "1024M",
        }

        result = parse_step_data("12345", "12345.0", raw_data)
        io = result["Disk_IO"]

        # Check types
        assert isinstance(io["Read_Stats"]["Max_Bytes"], int)
        assert isinstance(io["Write_Stats"]["Max_Bytes"], int)
        assert isinstance(io["IO_Efficiency"]["Read_Write_Ratio"], float)
