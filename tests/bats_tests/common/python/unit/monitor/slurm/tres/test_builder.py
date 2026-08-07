"""Tests for TRES builder module."""

import pytest

from runscripts.CPMIP.monitor.slurm.tres.builder import (
    build_tres_allocated,
    build_tres_usage_section,
)


class TestBuildTresAllocated:
    """Tests for build_tres_allocated function."""

    @pytest.mark.parametrize(
        "tres_str,tpc,expected_cpu,expected_mem",
        [
            (
                "cpu=128,mem=256G,node=4",
                2,
                64,
                256 * 1024**3,
            ),  # Simple allocation TPC=2
            (
                "cpu=64,mem=128G,node=2",
                None,
                64,
                128 * 1024**3,
            ),  # TPC=None defaults to 1
            ("cpu=64,mem=128G,node=1", 1, 64, 128 * 1024**3),  # TPC=1 no conversion
            ("cpu=256,mem=512G,node=8", 4, 64, 512 * 1024**3),  # TPC=4
            (
                "cpu=128,mem=512000M,node=4",
                1,
                128,
                512000 * 1024**2,
            ),  # Large memory in M
            ("cpu=256,mem=2T,node=8", 2, 128, 2 * 1024**4),  # Terabyte memory
        ],
    )
    def test_build_allocation_tpc_variations(
        self, tres_str, tpc, expected_cpu, expected_mem
    ):
        """
        GIVEN AllocTRES string with various TPC values and memory units
        WHEN build_tres_allocated is called
        THEN return normalized TresAllocated dict with correct CPU and memory.
        """
        result = build_tres_allocated(tres_str, threads_per_core=tpc)
        assert result["Cpu_Count"] == expected_cpu
        assert result["Mem_Bytes"] == expected_mem

    def test_build_allocation_with_billing(self):
        """
        GIVEN AllocTRES with billing field and TPC=2
        WHEN build_tres_allocated is called
        THEN convert billing to PHYSICAL cores.
        """
        tres_str = "cpu=128,mem=256G,node=4,billing=128"
        result = build_tres_allocated(tres_str, threads_per_core=2)

        assert result["Billing_Count"] == 64  # 128 / 2

    @pytest.mark.parametrize("tres_str", ["", "N/A"])
    def test_build_allocation_empty_or_na(self, tres_str):
        """
        GIVEN empty string or 'N/A'
        WHEN build_tres_allocated is called
        THEN return empty dict.
        """
        result = build_tres_allocated(tres_str)
        assert result == {}


class TestBuildTresUsageSection:
    """Tests for build_tres_usage_section function."""

    def test_build_usage_in_section_complete(self):
        """
        GIVEN raw sstat dict with TRESUsageIn fields
        WHEN build_tres_usage_section is called with direction='In'
        THEN return normalized usage section with Ave/Max/Min/Tot.
        """
        raw_stats = {
            "TRESUsageInAve": "cpu=01:00:00,mem=10G",
            "TRESUsageInMax": "cpu=02:00:00,mem=20G",
            "TRESUsageInMin": "cpu=00:30:00,mem=5G",
            "TRESUsageInTot": "cpu=10:00:00,mem=100G",
        }
        result = build_tres_usage_section(raw_stats, "In")

        assert result["Average"]["Cpu_Time_Seconds"] == 3600.0
        assert result["Average"]["Mem_Bytes"] == 10 * 1024 * 1024 * 1024
        assert result["Maximum"]["Cpu_Time_Seconds"] == 7200.0
        assert result["Minimum"]["Cpu_Time_Seconds"] == 1800.0
        assert result["Total"]["Cpu_Time_Seconds"] == 36000.0

    def test_build_usage_out_section_complete(self):
        """
        GIVEN raw sstat dict with TRESUsageOut fields
        WHEN build_tres_usage_section is called with direction='Out'
        THEN return normalized output usage section.
        """
        raw_stats = {
            "TRESUsageOutAve": "cpu=00:45:00,mem=8G",
            "TRESUsageOutMax": "cpu=01:30:00,mem=15G",
            "TRESUsageOutMin": "cpu=00:20:00,mem=3G",
            "TRESUsageOutTot": "cpu=05:00:00,mem=50G",
        }
        result = build_tres_usage_section(raw_stats, "Out")

        assert result["Average"]["Cpu_Time_Seconds"] == 2700.0  # 45 min
        assert result["Maximum"]["Cpu_Time_Seconds"] == 5400.0  # 90 min
        assert result["Minimum"]["Cpu_Time_Seconds"] == 1200.0  # 20 min
        assert result["Total"]["Cpu_Time_Seconds"] == 18000.0  # 5 hours

    def test_build_usage_section_with_energy(self):
        """
        GIVEN raw sstat with energy in TRES usage
        WHEN build_tres_usage_section is called
        THEN include Energy_Joules in result.
        """
        raw_stats = {
            "TRESUsageInAve": "cpu=01:00:00,energy=1000",
            "TRESUsageInMax": "cpu=02:00:00,energy=2500",
            "TRESUsageInMin": "cpu=00:30:00,energy=500",
            "TRESUsageInTot": "cpu=10:00:00,energy=10000",
        }
        result = build_tres_usage_section(raw_stats, "In")

        assert result["Average"]["Energy_Joules"] == 1000.0
        assert result["Maximum"]["Energy_Joules"] == 2500.0
        assert result["Minimum"]["Energy_Joules"] == 500.0
        assert result["Total"]["Energy_Joules"] == 10000.0

    def test_build_usage_section_missing_fields(self):
        """
        GIVEN raw sstat dict missing some TRES fields
        WHEN build_tres_usage_section is called
        THEN return empty dicts for missing subsections.
        """
        raw_stats = {
            "TRESUsageInAve": "cpu=01:00:00",
            # Missing Max, Min, Tot
        }
        result = build_tres_usage_section(raw_stats, "In")

        assert result["Average"]["Cpu_Time_Seconds"] == 3600.0
        assert result["Maximum"] == {}
        assert result["Minimum"] == {}
        assert result["Total"] == {}

    def test_build_usage_section_all_empty(self):
        """
        GIVEN raw sstat dict without any TRES usage fields
        WHEN build_tres_usage_section is called
        THEN return structure with empty subsections.
        """
        raw_stats = {}
        result = build_tres_usage_section(raw_stats, "In")

        assert result["Average"] == {}
        assert result["Maximum"] == {}
        assert result["Minimum"] == {}
        assert result["Total"] == {}

    def test_build_usage_section_with_na_values(self):
        """
        GIVEN raw sstat with 'N/A' TRES values
        WHEN build_tres_usage_section is called
        THEN return empty dicts for N/A values.
        """
        raw_stats = {
            "TRESUsageInAve": "N/A",
            "TRESUsageInMax": "cpu=01:00:00",
            "TRESUsageInMin": "N/A",
            "TRESUsageInTot": "N/A",
        }
        result = build_tres_usage_section(raw_stats, "In")

        assert result["Average"] == {}
        assert result["Maximum"]["Cpu_Time_Seconds"] == 3600.0
        assert result["Minimum"] == {}
        assert result["Total"] == {}

    def test_build_usage_section_zero_values(self):
        """
        GIVEN TRES usage with zero CPU time
        WHEN build_tres_usage_section is called
        THEN preserve zero values.
        """
        raw_stats = {
            "TRESUsageInAve": "cpu=00:00:00,mem=0",
            "TRESUsageInMax": "cpu=00:00:00,mem=0",
            "TRESUsageInMin": "cpu=00:00:00,mem=0",
            "TRESUsageInTot": "cpu=00:00:00,mem=0",
        }
        result = build_tres_usage_section(raw_stats, "In")

        assert result["Average"]["Cpu_Time_Seconds"] == 0.0
        assert result["Average"]["Mem_Bytes"] == 0

    def test_build_usage_section_direction_case_sensitive(self):
        """
        GIVEN raw sstat dict and direction='Out'
        WHEN build_tres_usage_section constructs field names
        THEN use exact case for TRESUsageOut prefix.
        """
        raw_stats = {
            "TRESUsageOutAve": "cpu=01:00:00",
            "TRESUsageOutMax": "cpu=02:00:00",
            "TRESUsageOutMin": "cpu=00:30:00",
            "TRESUsageOutTot": "cpu=05:00:00",
        }
        result = build_tres_usage_section(raw_stats, "Out")

        assert "Average" in result
        assert "Maximum" in result
        assert "Minimum" in result
        assert "Total" in result

    def test_build_usage_section_mixed_units(self):
        """
        GIVEN TRES usage with mixed memory units (K, M, G)
        WHEN build_tres_usage_section is called
        THEN normalize all to bytes.
        """
        raw_stats = {
            "TRESUsageInAve": "mem=1024K",
            "TRESUsageInMax": "mem=100M",
            "TRESUsageInMin": "mem=512K",
            "TRESUsageInTot": "mem=10G",
        }
        result = build_tres_usage_section(raw_stats, "In")

        assert result["Average"]["Mem_Bytes"] == 1024 * 1024
        assert result["Maximum"]["Mem_Bytes"] == 100 * 1024 * 1024
        assert result["Minimum"]["Mem_Bytes"] == 512 * 1024
        assert result["Total"]["Mem_Bytes"] == 10 * 1024 * 1024 * 1024

    def test_build_usage_section_with_days_duration(self):
        """
        GIVEN TRES usage with days in duration
        WHEN build_tres_usage_section is called
        THEN convert full duration including days.
        """
        raw_stats = {
            "TRESUsageInTot": "cpu=2-05:30:00",
        }
        result = build_tres_usage_section(raw_stats, "In")

        expected = 2 * 86400 + 5 * 3600 + 30 * 60  # 192600 seconds
        assert result["Total"]["Cpu_Time_Seconds"] == expected
