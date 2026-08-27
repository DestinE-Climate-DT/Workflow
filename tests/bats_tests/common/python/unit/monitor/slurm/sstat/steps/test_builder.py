"""
Unit tests for SLURM sstat builder module.

This module tests the builder functions that construct structured
data blocks from raw SLURM sstat strings.
"""

import pytest

from runscripts.CPMIP.monitor.slurm.sstat.steps.builder import (
    build_cpu_stats,
    build_io_efficiency,
    build_memory_block,
    build_memory_efficiency,
    build_storage_stats,
)


class TestBuildMemoryBlock:
    """
    Test suite for memory block building.

    Tests conversion of raw SLURM memory strings (with K/M/G suffixes)
    into structured MemoryBlock with bytes and metadata.
    """

    def test_build_rss_memory_block(self):
        """
        Test building RSS (physical memory) block.

        RSS = Resident Set Size = actual physical memory used.

        Verifies:
            - MaxRSS parsed correctly to bytes
            - AveRSS parsed correctly to bytes
            - Node and task metadata preserved
            - Peak-to-average ratio calculated

        Example:
            >>> raw = {"MaxRSS": "4G", "AveRSS": "2G", "MaxRSSNode": "nid001", "MaxRSSTask": "5"}
            >>> block = build_memory_block(raw, "RSS")
            >>> assert block["Max_Bytes"] == 4 * 1024**3
        """
        raw_stats = {
            "MaxRSS": "4G",
            "AveRSS": "2G",
            "MaxRSSNode": "nid001",
            "MaxRSSTask": "5",
        }

        block = build_memory_block(raw_stats, "RSS")

        assert block["Max_Bytes"] == 4 * 1024**3
        assert block["Average_Bytes"] == 2 * 1024**3
        assert block["Max_Node"] == "nid001"
        assert block["Max_Task"] == 5
        assert block["Peak_To_Average_Ratio"] == pytest.approx(2.0)

    def test_build_vm_memory_block(self):
        """
        Test building VM (virtual memory) block.

        VM = Virtual Memory = memory address space allocated (includes unused).

        Verifies:
            - MaxVMSize parsed correctly
            - AveVMSize parsed correctly
            - Metadata for VM different from RSS

        Example:
            >>> raw = {"MaxVMSize": "8G", "AveVMSize": "4G", "MaxVMSizeNode": "nid002"}
            >>> block = build_memory_block(raw, "VM")
            >>> assert block["Max_Bytes"] == 8 * 1024**3
        """
        raw_stats = {
            "MaxVMSize": "8G",
            "AveVMSize": "4G",
            "MaxVMSizeNode": "nid002",
            "MaxVMSizeTask": "3",
        }

        block = build_memory_block(raw_stats, "VM")

        assert block["Max_Bytes"] == 8 * 1024**3
        assert block["Average_Bytes"] == 4 * 1024**3
        assert block["Max_Node"] == "nid002"
        assert block["Max_Task"] == 3

    def test_build_memory_block_with_zero_average(self):
        """
        Test memory block when average is zero.

        Should handle division by zero gracefully in ratio calculation.

        Verifies:
            - No exception raised
            - Ratio is 0.0 when average is zero

        Example:
            >>> raw = {"MaxRSS": "4G", "AveRSS": "0"}
            >>> block = build_memory_block(raw, "RSS")
            >>> assert block["Peak_To_Average_Ratio"] == 0.0
        """
        raw_stats = {
            "MaxRSS": "4G",
            "AveRSS": "0",
        }

        block = build_memory_block(raw_stats, "RSS")

        assert block["Peak_To_Average_Ratio"] == 0.0

    def test_build_memory_block_missing_fields(self):
        """
        Test memory block with missing optional fields.

        Should use default values when fields absent.

        Verifies:
            - Missing memory values default to 0
            - Missing node defaults to empty string
            - Missing task defaults to 0

        Example:
            >>> raw = {}  # Empty dict
            >>> block = build_memory_block(raw, "RSS")
            >>> assert block["Max_Bytes"] == 0
        """
        raw_stats = {}

        block = build_memory_block(raw_stats, "RSS")

        assert block["Max_Bytes"] == 0
        assert block["Average_Bytes"] == 0
        assert block["Max_Node"] == ""
        assert block["Max_Task"] == 0


class TestBuildMemoryEfficiency:
    """
    Test suite for memory efficiency calculations.

    Tests various efficiency metrics comparing physical (RSS) vs
    virtual (VM) memory usage.
    """

    def test_build_memory_efficiency_normal_case(self):
        """
        Test memory efficiency with typical values.

        Typical scenario: VM > RSS (some allocated memory unused).

        Verifies:
            - Physical to virtual ratio calculated correctly
            - Memory waste percentage calculated
            - Memory consistency (ave vs max) calculated

        Example:
            >>> raw = {"MaxVMSize": "8G", "MaxRSS": "4G", "AveVMSize": "6G", "AveRSS": "3G"}
            >>> eff = build_memory_efficiency(raw)
            >>> assert eff["Physical_To_Virtual_Ratio"] == 0.5
        """
        raw_stats = {
            "MaxVMSize": "8G",
            "MaxRSS": "4G",
            "AveVMSize": "6G",
            "AveRSS": "3G",
        }

        eff = build_memory_efficiency(raw_stats)

        assert eff["Physical_To_Virtual_Ratio"] == pytest.approx(0.5)
        assert eff["Average_Memory_Utilization"] == pytest.approx(0.5)
        assert eff["Memory_Waste_Percentage"] == pytest.approx(50.0)
        assert eff["Memory_Consistency"] == pytest.approx(0.75)

    def test_build_memory_efficiency_zero_vm(self):
        """
        Test memory efficiency when VM is zero.

        Should handle division by zero gracefully.

        Verifies:
            - No exception raised
            - Ratios default to 0.0

        Example:
            >>> raw = {"MaxVMSize": "0", "MaxRSS": "0"}
            >>> eff = build_memory_efficiency(raw)
            >>> assert eff["Physical_To_Virtual_Ratio"] == 0.0
        """
        raw_stats = {
            "MaxVMSize": "0",
            "MaxRSS": "0",
            "AveVMSize": "0",
            "AveRSS": "0",
        }

        eff = build_memory_efficiency(raw_stats)

        assert eff["Physical_To_Virtual_Ratio"] == 0.0
        assert eff["Memory_Waste_Percentage"] == 0.0


class TestBuildCpuStats:
    """
    Test suite for CPU stats building.

    Tests conversion of CPU time strings and task counts into
    structured CPU statistics.
    """

    def test_build_cpu_stats_normal_case(self):
        """
        Test CPU stats with typical values.

        Verifies:
            - Task count parsed correctly
            - Time strings converted to seconds
            - Node metadata preserved

        Example:
            >>> raw = {"NTasks": "64", "MinCPU": "00:30:00", "AveCPU": "01:00:00"}
            >>> stats = build_cpu_stats(raw)
            >>> assert stats["Number_Of_Tasks"] == 64
            >>> assert stats["Average_Cpu_Time_Seconds"] == 3600.0
        """
        raw_stats = {
            "NTasks": "64",
            "MinCPU": "00:30:00",
            "AveCPU": "01:00:00",
            "MinCPUNode": "nid001",
            "MinCPUTask": "10",
        }

        stats = build_cpu_stats(raw_stats)

        assert stats["Total_Tasks_Count"] == 64
        assert stats["Min_Cpu_Time_Seconds"] == pytest.approx(1800.0)
        assert stats["Average_Cpu_Time_Seconds"] == pytest.approx(3600.0)
        assert stats["Min_Cpu_Node"] == "nid001"
        assert stats["Min_Cpu_Task"] == 10

    def test_build_cpu_stats_with_days(self):
        """
        Test CPU stats with durations including days.

        SLURM can report times like "2-12:30:45" (2 days, 12h, 30m, 45s).

        Verifies:
            - Multi-day durations parsed correctly
            - Total seconds calculated accurately

        Example:
            >>> raw = {"AveCPU": "2-12:30:45"}
            >>> stats = build_cpu_stats(raw)
            >>> # 2*86400 + 12*3600 + 30*60 + 45 = 217845
            >>> assert stats["Average_Cpu_Time_Seconds"] == 217845.0
        """
        raw_stats = {
            "NTasks": "1",
            "AveCPU": "2-12:30:45",
        }

        stats = build_cpu_stats(raw_stats)

        expected_seconds = 2 * 86400 + 12 * 3600 + 30 * 60 + 45
        assert stats["Average_Cpu_Time_Seconds"] == pytest.approx(expected_seconds)


class TestBuildStorageStats:
    """
    Test suite for storage I/O stats building.

    Tests parsing of disk read/write statistics.
    """

    def test_build_storage_stats_read(self):
        """
        Test building read I/O statistics.

        Verifies:
            - MaxDiskRead parsed to bytes
            - AveDiskRead parsed to bytes
            - Node metadata preserved

        Example:
            >>> raw = {"MaxDiskRead": "1G", "AveDiskRead": "512M", "MaxDiskReadNode": "nid001"}
            >>> stats = build_storage_stats(raw, "read")
            >>> assert stats["Max_Bytes"] == 1 * 1024**3
        """
        raw_stats = {
            "MaxDiskRead": "1G",
            "AveDiskRead": "512M",
            "MaxDiskReadNode": "nid001",
            "MaxDiskReadTask": "2",
        }

        stats = build_storage_stats(raw_stats, "Read")

        assert stats["Max_Bytes"] == 1 * 1024**3
        assert stats["Average_Bytes"] == 512 * 1024**2
        assert stats["Max_Node"] == "nid001"
        assert stats["Max_Task"] == 2

    def test_build_storage_stats_write(self):
        """
        Test building write I/O statistics.

        Verifies:
            - MaxDiskWrite parsed to bytes
            - AveDiskWrite parsed to bytes

        Example:
            >>> raw = {"MaxDiskWrite": "2G", "AveDiskWrite": "1G"}
            >>> stats = build_storage_stats(raw, "Write")
            >>> assert stats["Max_Bytes"] == 2 * 1024**3
        """
        raw_stats = {
            "MaxDiskWrite": "2G",
            "AveDiskWrite": "1G",
            "MaxDiskWriteNode": "nid002",
            "MaxDiskWriteTask": "5",
        }

        stats = build_storage_stats(raw_stats, "Write")

        assert stats["Max_Bytes"] == 2 * 1024**3
        assert stats["Average_Bytes"] == 1 * 1024**3
        assert stats["Max_Node"] == "nid002"


class TestBuildIoEfficiency:
    """
    Test suite for I/O efficiency calculations.

    Tests read vs write ratios and consistency metrics.
    """

    def test_build_io_efficiency_normal_case(self):
        """
        Test I/O efficiency with typical read/write values.

        Verifies:
            - Read to write ratio calculated
            - Peak to average ratios calculated for both

        Example:
            >>> raw = {"MaxDiskRead": "1G", "AveDiskRead": "512M", "MaxDiskWrite": "2G", "AveDiskWrite": "1G"}
            >>> eff = build_io_efficiency(raw)
            >>> assert eff["Read_To_Write_Ratio"] == 0.5
        """
        raw_stats = {
            "MaxDiskRead": "1G",
            "AveDiskRead": "512M",
            "MaxDiskWrite": "2G",
            "AveDiskWrite": "1G",
        }

        eff = build_io_efficiency(raw_stats)

        # Read (1G) / Write (2G) = 0.5
        assert eff["Read_Write_Ratio"] == pytest.approx(0.5)

        # Read: Ave 512M / Max 1G = 0.5
        assert eff["Io_Consistency_Read"] == pytest.approx(0.5)

        # Write: Ave 1G / Max 2G = 0.5
        assert eff["Io_Consistency_Write"] == pytest.approx(0.5)

    def test_build_io_efficiency_zero_write(self):
        """
        Test I/O efficiency when write is zero (read-only workload).

        Should handle division by zero gracefully.

        Verifies:
            - No exception raised
            - Ratio is inf when write is zero (as per TypedDict doc)

        Example:
            >>> raw = {"MaxDiskRead": "1G", "MaxDiskWrite": "0"}
            >>> eff = build_io_efficiency(raw)
            >>> assert eff["Read_Write_Ratio"] == float('inf')
        """
        raw_stats = {
            "MaxDiskRead": "1G",
            "AveDiskRead": "512M",
            "MaxDiskWrite": "0",
            "AveDiskWrite": "0",
        }

        eff = build_io_efficiency(raw_stats)

        # According to TypedDict: "inf if write==0"
        assert eff["Read_Write_Ratio"] == float("inf")
