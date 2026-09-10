"""Tests for sstat aggregation builder module."""

import pytest

from runscripts.CPMIP.monitor.slurm.sstat.aggregation.builder import (
    build_aggregated_memory_block,
    build_aggregated_memory_efficiency,
    build_aggregated_storage_stats,
    build_aggregated_cpu_stats,
    build_aggregated_pagefaults,
    build_aggregated_energy,
    build_aggregated_io_efficiency,
    build_aggregated_cpu_frequency,
)


class TestBuildAggregatedMemoryBlock:
    """Tests for build_aggregated_memory_block function."""

    @pytest.mark.parametrize(
        "max_bytes,total_bytes,num_steps,expected_avg,expected_ratio",
        [
            (1000000, 1500000.0, 3, 500000, 2.0),  # Normal case
            (1000000, 0.0, 0, 0, 0.0),  # Zero steps
            (500000, 500000.0, 1, 500000, 1.0),  # Single step
            (1000000, 0.0, 1, 0, 0.0),  # Zero average
        ],
    )
    def test_build_memory_block_cases(
        self, max_bytes, total_bytes, num_steps, expected_avg, expected_ratio
    ):
        """
        GIVEN accumulated memory data from multiple steps
        WHEN build_aggregated_memory_block is called
        THEN return MemoryBlock with correct averages and ratios.
        """
        result = build_aggregated_memory_block(
            max_bytes=max_bytes,
            total_bytes=total_bytes,
            num_steps=num_steps,
            max_node="nid001",
            max_task=0,
        )

        assert result["Max_Bytes"] == max_bytes
        assert result["Average_Bytes"] == expected_avg
        assert result["Max_Node"] == "nid001"
        assert result["Max_Task"] == 0
        assert result["Total_Across_Steps_Bytes"] == total_bytes
        assert result["Peak_To_Average_Ratio"] == pytest.approx(expected_ratio)


class TestBuildAggregatedMemoryEfficiency:
    """Tests for build_aggregated_memory_efficiency function."""

    def test_build_memory_efficiency_normal_case(self):
        """
        GIVEN VM and RSS data from multiple steps
        WHEN build_aggregated_memory_efficiency is called
        THEN calculate efficiency ratios correctly.
        """
        result = build_aggregated_memory_efficiency(
            max_vm_bytes=2000000,
            max_rss_bytes=1500000,
            total_vm_bytes=6000000.0,
            total_rss_bytes=4500000.0,
            num_steps=3,
        )

        assert result["Physical_To_Virtual_Ratio"] == pytest.approx(0.75)
        assert result["Average_Memory_Utilization"] == pytest.approx(0.75)
        assert result["Memory_Waste_Percentage"] == pytest.approx(25.0)
        assert result["Memory_Consistency"] == pytest.approx(1.0)

    @pytest.mark.parametrize(
        "max_vm,max_rss,total_vm,total_rss,check_field,expected",
        [
            (0, 1000000, 0.0, 3000000.0, "Physical_To_Virtual_Ratio", 0.0),  # Zero VM
            (2000000, 0, 6000000.0, 0.0, "Memory_Consistency", 0.0),  # Zero RSS
            (
                1000000,
                1000000,
                3000000.0,
                3000000.0,
                "Memory_Waste_Percentage",
                0.0,
            ),  # Perfect utilization
        ],
    )
    def test_build_memory_efficiency_edge_cases(
        self, max_vm, max_rss, total_vm, total_rss, check_field, expected
    ):
        """
        GIVEN edge cases (zero VM, zero RSS, perfect utilization)
        WHEN build_aggregated_memory_efficiency is called
        THEN handle division by zero and return appropriate values.
        """
        result = build_aggregated_memory_efficiency(
            max_vm_bytes=max_vm,
            max_rss_bytes=max_rss,
            total_vm_bytes=total_vm,
            total_rss_bytes=total_rss,
            num_steps=3,
        )
        assert result[check_field] == pytest.approx(expected)


class TestBuildAggregatedStorageStats:
    """Tests for build_aggregated_storage_stats function."""

    @pytest.mark.parametrize(
        "max_bytes,total_bytes,num_steps,expected_avg",
        [
            (5000000, 12000000.0, 4, 3000000),  # Normal case
            (5000000, 0.0, 0, 0),  # Zero steps
        ],
    )
    def test_build_storage_stats_cases(
        self, max_bytes, total_bytes, num_steps, expected_avg
    ):
        """
        GIVEN storage I/O data from multiple steps
        WHEN build_aggregated_storage_stats is called
        THEN return StorageIOStats with correct aggregations.
        """
        result = build_aggregated_storage_stats(
            max_bytes=max_bytes,
            total_bytes=total_bytes,
            num_steps=num_steps,
            max_node="nid002",
            max_task=1,
        )

        assert result["Max_Bytes"] == max_bytes
        assert result["Average_Bytes"] == expected_avg
        assert result["Total_Across_Steps_Bytes"] == total_bytes
        assert result["Max_Node"] == "nid002"
        assert result["Max_Task"] == 1


class TestBuildAggregatedCpuTimeStats:
    """Tests for build_aggregated_cpu_stats function."""

    @pytest.mark.parametrize(
        "total_tasks,min_cpu,total_cpu,expected_avg,expected_min",
        [
            (10, 3000.0, 36000.0, 3600.0, 3000.0),  # Normal case
            (0, 0.0, 0.0, 0.0, 0.0),  # Zero tasks
            (5, float("inf"), 15000.0, 3000.0, 0.0),  # Min CPU inf
        ],
    )
    def test_build_cpu_time_stats_cases(
        self, total_tasks, min_cpu, total_cpu, expected_avg, expected_min
    ):
        """
        GIVEN CPU time data from multiple steps
        WHEN build_aggregated_cpu_stats is called
        THEN return total and average CPU times with edge case handling.
        """
        result = build_aggregated_cpu_stats(
            total_tasks=total_tasks,
            min_cpu_seconds=min_cpu,
            min_cpu_node="nid001",
            min_cpu_task=0,
            total_cpu_seconds=total_cpu,
        )

        assert result["Total_Cpu_Time_Seconds"] == total_cpu
        assert result["Total_Tasks_Count"] == total_tasks
        assert result["Average_Cpu_Time_Seconds"] == expected_avg
        assert result["Min_Cpu_Time_Seconds"] == expected_min


class TestBuildAggregatedPageFaults:
    """Tests for build_aggregated_pagefaults function."""

    def test_build_page_faults_normal_case(self):
        """
        GIVEN page fault data from multiple steps
        WHEN build_aggregated_pagefaults is called
        THEN return aggregated page fault stats.
        """
        result = build_aggregated_pagefaults(
            max_count=10000,
            max_node="nid003",
            max_task=2,
            total_count=25000.0,
            num_steps=5,
        )

        assert result["Max_Count"] == 10000
        assert result["Average_Count"] == 5000  # 25000 / 5
        assert result["Total_Across_Steps_Count"] == 25000
        assert result["Max_Pages_Node"] == "nid003"
        assert result["Max_Pages_Task"] == 2


class TestBuildAggregatedEnergy:
    """Tests for build_aggregated_energy function."""

    def test_build_energy_normal_case(self):
        """
        GIVEN energy consumption data
        WHEN build_aggregated_energy is called
        THEN return total energy.
        """
        result = build_aggregated_energy(
            total_energy_joules=100000.0,
        )

        assert result["Total_Energy_Joules"] == 100000.0

    def test_build_energy_zero(self):
        """
        GIVEN zero energy
        WHEN build_aggregated_energy is called
        THEN Total_Energy_Joules is 0.
        """
        result = build_aggregated_energy(
            total_energy_joules=0.0,
        )

        assert result["Total_Energy_Joules"] == 0.0


class TestBuildAggregatedIoEfficiency:
    """Tests for build_aggregated_io_efficiency function."""

    def test_build_io_efficiency_normal_case(self):
        """
        GIVEN read and write I/O totals
        WHEN build_aggregated_io_efficiency is called
        THEN calculate read/write ratio.
        """
        result = build_aggregated_io_efficiency(
            max_read_bytes=10000000,
            max_write_bytes=3000000,
            total_read_bytes=8000000.0,
            total_write_bytes=2000000.0,
            num_steps=4,
        )

        assert result["Total_Io_Bytes"] == 13000000  # 10000000 + 3000000
        assert result["Read_Write_Ratio"] == pytest.approx(
            3.333, rel=0.01
        )  # 10000000 / 3000000

    def test_build_io_efficiency_zero_write(self):
        """
        GIVEN max_write_bytes=0
        WHEN build_aggregated_io_efficiency is called
        THEN Read_Write_Ratio is inf.
        """
        result = build_aggregated_io_efficiency(
            max_read_bytes=5000000,
            max_write_bytes=0,
            total_read_bytes=5000000.0,
            total_write_bytes=0.0,
            num_steps=1,
        )

        assert result["Read_Write_Ratio"] == float("inf")

    def test_build_io_efficiency_equal_io(self):
        """
        GIVEN equal max read and write bytes
        WHEN build_aggregated_io_efficiency is called
        THEN ratio is 1.0.
        """
        result = build_aggregated_io_efficiency(
            max_read_bytes=3000000,
            max_write_bytes=3000000,
            total_read_bytes=3000000.0,
            total_write_bytes=3000000.0,
            num_steps=1,
        )

        assert result["Read_Write_Ratio"] == pytest.approx(1.0)


class TestBuildAggregatedCpuFrequency:
    """Tests for build_aggregated_cpu_frequency function."""

    def test_build_cpu_frequency_normal_case(self):
        """
        GIVEN CPU frequency data from multiple steps
        WHEN build_aggregated_cpu_frequency is called
        THEN calculate average frequency.
        """
        result = build_aggregated_cpu_frequency(
            total_freq_khz=12000000.0,  # 12 GHz in KHz
            freq_count=4,
            req_min_freq="1000000",
            req_max_freq="3000000",
            freq_governor="performance",
        )

        assert result["Average_Frequency_KHz"] == 3000000.0  # 12000000 / 4

    def test_build_cpu_frequency_zero_count(self):
        """
        GIVEN freq_count=0
        WHEN build_aggregated_cpu_frequency is called
        THEN average is 0.
        """
        result = build_aggregated_cpu_frequency(
            total_freq_khz=0.0,
            freq_count=0,
            req_min_freq="Unknown",
            req_max_freq="Unknown",
            freq_governor="Unknown",
        )

        assert result["Average_Frequency_KHz"] == 0.0

    def test_build_cpu_frequency_single_step(self):
        """
        GIVEN single step with frequency
        WHEN build_aggregated_cpu_frequency is called
        THEN average equals that frequency.
        """
        result = build_aggregated_cpu_frequency(
            total_freq_khz=2500000.0,
            freq_count=1,
            req_min_freq="800000",
            req_max_freq="2500000",
            freq_governor="ondemand",
        )

        assert result["Average_Frequency_KHz"] == 2500000.0
        assert result["Frequency_Governor"] == "ondemand"
