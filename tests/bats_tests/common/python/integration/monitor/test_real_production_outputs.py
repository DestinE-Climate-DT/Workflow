"""
Production-validated tests using real SLURM outputs.

These tests use actual outputs from production HPC systems to validate
parsers against real-world data formats and edge cases.
"""

import pytest
from runscripts.CPMIP.monitor.slurm.scontrol.parser import (
    parse_scontrol_output,
    parse_nodelist,
    parse_alloc_node,
)
from runscripts.CPMIP.monitor.system.parser import (
    parse_lscpu_output,
    parse_free_output,
    parse_uptime_output,
    get_total_node_memory_kb,
)
from runscripts.CPMIP.monitor.slurm.tres.parser import parse_tres_string
from runscripts.CPMIP.monitor.slurm.tres.normalizer import normalize_tres_keys_and_units


class TestRealScontrolOutput:
    """Tests using real scontrol output from production."""

    def test_parse_real_scontrol_job(self, real_scontrol_output):
        """
        GIVEN real scontrol job output
        WHEN parse_scontrol is called
        THEN extract job metadata correctly.
        """
        result = parse_scontrol_output(real_scontrol_output)

        # Verify job identification
        assert result["JobId"] == "32266924"
        assert result["JobName"] == "wrap"
        assert result["JobState"] == "RUNNING"

        # Verify user/group info
        assert "bsc071777" in result["UserId"]
        assert "bsc" in result["GroupId"]

    def test_parse_real_scontrol_resources(self, real_scontrol_output):
        """
        GIVEN real scontrol with resource info
        WHEN parse_scontrol is called
        THEN extract CPU/memory allocation.
        """
        result = parse_scontrol_output(real_scontrol_output)

        # Verify resource allocation
        assert result["NumNodes"] == "1"
        assert result["NumCPUs"] == "2"
        assert result["NumTasks"] == "1"
        assert result["NodeList"] == "glogin3"
        assert result["BatchHost"] == "glogin3"

    def test_parse_real_scontrol_tres(self, real_scontrol_output):
        """
        GIVEN real TRES allocation string
        WHEN parse_scontrol is called
        THEN extract TRES components.
        """
        result = parse_scontrol_output(real_scontrol_output)

        # ReqTRES vs AllocTRES
        assert "ReqTRES" in result
        assert "cpu=1" in result["ReqTRES"]
        assert "mem=2000M" in result["ReqTRES"]

        assert "AllocTRES" in result
        assert "cpu=2" in result["AllocTRES"]
        assert "mem=2000M" in result["AllocTRES"]

    def test_parse_real_scontrol_timestamps(self, real_scontrol_output):
        """
        GIVEN real job timestamps
        WHEN parse_scontrol is called
        THEN extract submit/start/end times.
        """
        result = parse_scontrol_output(real_scontrol_output)

        # Verify ISO-8601 timestamps
        assert result["SubmitTime"] == "2025-11-18T12:05:51"
        assert result["StartTime"] == "2025-11-18T12:06:04"
        assert result["EndTime"] == "2025-11-18T12:11:04"

        # Verify time limits
        assert result["RunTime"] == "00:02:02"
        assert result["TimeLimit"] == "00:05:00"

    def test_parse_real_scontrol_paths(self, real_scontrol_output):
        """
        GIVEN real file paths in output
        WHEN parse_scontrol is called
        THEN extract Command, WorkDir, StdOut, StdErr.
        """
        result = parse_scontrol_output(real_scontrol_output)

        # Verify working directory and output paths
        assert "WorkDir" in result
        assert "/gpfs/scratch/ehpc01/bsc071777/tools/sysstat" in result["WorkDir"]
        assert "StdOut" in result
        assert "slurm-32266924.out" in result["StdOut"]

    def test_parse_real_scontrol_alloc_node(self, real_scontrol_output):
        """
        GIVEN real AllocNode with Sid
        WHEN parse_alloc_node is called
        THEN extract node name correctly.
        """
        result = parse_scontrol_output(real_scontrol_output)
        alloc_node_str = result.get("AllocNode:Sid", "")

        parsed = parse_alloc_node(alloc_node_str)
        assert parsed["Node"] == "glogin4"
        assert parsed["Session_Id"] == "592379"  # Correct key name

    def test_parse_real_scontrol_partition(self, real_scontrol_output):
        """
        GIVEN real partition name
        WHEN parse_scontrol is called
        THEN extract partition field.
        """
        result = parse_scontrol_output(real_scontrol_output)

        assert result["Partition"] == "gpinteractive"
        assert result["QOS"] == "gp_interactive"
        assert result["Account"] == "ehpc01"


class TestRealSystemOutputs:
    """Tests using real system command outputs from production."""

    def test_parse_real_lscpu_intel_platinum(self, real_lscpu_output):
        """
        GIVEN real lscpu from Intel Platinum
        WHEN lscpu output is parsed
        THEN extract CPU architecture details.
        """
        result = parse_lscpu_output(real_lscpu_output)

        # Verify Intel Platinum topology
        assert result["Threads_Per_Core_Count"] == 2  # SMT enabled
        assert result["Cores_Per_Socket_Count"] == 56
        assert result["Sockets_Count"] == 2

        # Calculate total cores
        total_physical = result["Total_Physical_Cores_Count"]
        assert total_physical == 112  # 56 cores × 2 sockets

        # Verify model name
        assert "Intel(R) Xeon(R) Platinum 8480+" in result["Model"]

    def test_parse_real_free_high_usage(self, real_free_output):
        """
        GIVEN real free output with high memory usage
        WHEN parse free output
        THEN calculate memory metrics.
        """
        result = parse_free_output(real_free_output)

        # Verify total memory (~251 GB)
        total_kb = result["Total_Bytes"] // 1024
        assert total_kb == 263778264

        # Verify high usage (~63%)
        used_kb = result["Used_Bytes"] // 1024
        assert used_kb == 166428364

        # Verify available memory
        available_kb = result["Available_Bytes"] // 1024
        assert available_kb == 97349900

        # Calculate usage percentage
        usage_pct = (used_kb / total_kb) * 100
        assert 60 < usage_pct < 70  # ~63%

    def test_parse_real_free_minimal_swap(self, real_free_output):
        """
        GIVEN real free with minimal swap
        WHEN parse free output
        THEN handle low swap correctly.
        """
        # Function doesn't return swap, but should not fail
        result = parse_free_output(real_free_output)
        assert result is not None
        assert "Total_Bytes" in result

    def test_get_total_memory_from_real_output(self, real_free_output):
        """
        GIVEN real free output
        WHEN extract total memory
        THEN return memory in KB.
        """
        total = get_total_node_memory_kb(real_free_output)
        assert total == 263778264  # ~251 GB

    def test_parse_real_uptime_moderate_load(self, real_uptime_output):
        """
        GIVEN real uptime with load averages
        WHEN parse uptime output
        THEN extract 1/5/15 min load averages.
        """
        result = parse_uptime_output(real_uptime_output)
        assert result is not None

        # Verify load averages from production node (correct key names)
        assert result["Min_1"] == pytest.approx(6.23)
        assert result["Min_5"] == pytest.approx(6.53)
        assert result["Min_15"] == pytest.approx(7.93)

        # On 224-CPU system, load of 6-8 is light (~3% usage)


class TestRealTRESParsing:
    """Tests using real TRES strings from production."""

    def test_parse_real_tres_with_energy(self, real_sstat_parseable_output):
        """
        GIVEN real sstat with energy consumption
        WHEN parse TRES data
        THEN extract energy values.
        """
        # Extract one TRES string from the output
        lines = real_sstat_parseable_output.strip().split("\n")
        first_line = lines[0]

        # TRESUsageInTot is after many fields - extract manually
        # Format: cpu=01:15:23,energy=89564,fs/disk=49430961202,mem=142462354K,pages=101,vmem=542192528K
        assert "energy=89564" in first_line
        assert "fs/disk=49430961202" in first_line

        # Parse a TRES string
        tres_str = (
            "cpu=01:15:23,energy=89564,fs/disk=49430961202,mem=142462354K,pages=101,vmem=542192528K"
        )
        result = parse_tres_string(tres_str)

        assert result["cpu"] == "01:15:23"
        assert result["energy"] == "89564"
        assert result["fs/disk"] == "49430961202"
        assert result["mem"] == "142462354K"

    def test_normalize_real_tres_units(self, real_sstat_parseable_output):
        """
        GIVEN real TRES with various units
        WHEN unit normalization applied
        THEN convert K/M/G/T to bytes.
        """
        tres_str = (
            "cpu=01:15:23,energy=89564,fs/disk=49430961202,mem=142462354K,pages=101,vmem=542192528K"
        )
        parsed = parse_tres_string(tres_str)
        normalized = normalize_tres_keys_and_units(parsed)

        # Verify energy in Joules
        assert normalized.get("Energy_Joules") == 89564.0

        # Verify fs/disk in bytes
        assert normalized.get("Fs/Disk_Bytes") == 49430961202.0

        # Verify memory conversions (K suffix = 1024 bytes)
        assert normalized.get("Mem_Bytes") == 142462354 * 1024  # 142462354K
        assert normalized.get("Vmem_Bytes") == 542192528 * 1024  # 542192528K

    def test_parse_real_tres_batch_vs_extern(self, real_sstat_parseable_output):
        """
        GIVEN real sstat output
        WHEN parse step data
        THEN handle single or multiple steps correctly.
        """
        lines = real_sstat_parseable_output.strip().split("\n")

        # Verify we have at least one line
        assert len(lines) >= 1
        
        # First line should contain job step data
        assert "32635121.16" in lines[0]
        
        # Verify it contains TRES data with energy and fs/disk
        assert "energy=" in lines[0]
        assert "fs/disk=" in lines[0]

    def test_real_tres_with_hostname_nodes(self, real_sstat_parseable_output):
        """
        GIVEN real sstat with node hostnames
        WHEN parse NodeList field
        THEN extract node names.
        """
        # Some TRES max nodes show hostname: "cpu=gs02r1b21,energy=gs02r1b21,..."
        assert "cpu=gs02r1b21" in real_sstat_parseable_output
        assert "energy=gs02r1b21" in real_sstat_parseable_output

        # Parser should handle these as string values
        tres_str = "cpu=gs02r1b21,energy=gs02r1b21,fs/disk=gs02r1b21"
        result = parse_tres_string(tres_str)

        assert result["cpu"] == "gs02r1b21"
        assert result["energy"] == "gs02r1b21"


class TestRealProductionEdgeCases:
    """Edge cases discovered from real production data."""

    def test_scontrol_single_node_job(self, real_scontrol_output):
        """
        GIVEN real scontrol for single-node job
        WHEN parse NodeList
        THEN return single node.
        """
        result = parse_scontrol_output(real_scontrol_output)
        nodelist_str = result["NodeList"]

        # Single node: no brackets
        assert nodelist_str == "glogin3"

        # parse_nodelist should return dict with single node
        nodes = parse_nodelist(nodelist_str)
        assert nodes["Count"] == 1
        assert "glogin3" in nodes["Nodes"]

    def test_scontrol_null_values_common(self, real_scontrol_output):
        """
        GIVEN real scontrol with null/(null) values
        WHEN parse scontrol
        THEN handle SLURM null values.
        """
        result = parse_scontrol_output(real_scontrol_output)

        # Many fields have (null)
        assert result["Dependency"] == "(null)"
        assert result["ReqNodeList"] == "(null)"
        assert result["ExcNodeList"] == "(null)"
        assert result["Features"] == "(null)"
        assert result["Licenses"] == "(null)"
        assert result["Network"] == "(null)"
        assert result["Command"] == "(null)"

    def test_scontrol_none_vs_null(self, real_scontrol_output):
        """
        GIVEN scontrol output None vs null
        WHEN parse values
        THEN distinguish between None string and actual null.
        """
        result = parse_scontrol_output(real_scontrol_output)

        # SuspendTime uses "None" not "(null)"
        assert result["SuspendTime"] == "None"
        # But Reason uses "None" too
        assert result["Reason"] == "None"

    def test_tres_zero_cpu_time(self, real_sstat_parseable_output):
        """
        GIVEN sstat step with CPU time
        WHEN parse TRES
        THEN handle time values correctly.
        """
        # Real output contains CPU times like 01:15:23
        assert "cpu=01:15:23" in real_sstat_parseable_output or "cpu=00:00:00" in real_sstat_parseable_output

        # Test parsing zero CPU time
        tres_str = "cpu=00:00:00,mem=100M"
        parsed = parse_tres_string(tres_str)
        normalized = normalize_tres_keys_and_units(parsed)

        # Should convert to 0 seconds
        assert normalized.get("Cpu_Time_Seconds") == 0.0

    def test_free_buff_cache_not_returned(self, real_free_output):
        """
        GIVEN real free output
        WHEN parse memory data
        THEN exclude buff/cache from calculations.
        """
        # Real output has buff/cache column
        assert "buff/cache" in real_free_output.lower()

        result = parse_free_output(real_free_output)

        # But function only returns total, used, free, available
        assert "Total_Bytes" in result
        assert "Used_Bytes" in result
        assert "Free_Bytes" in result
        assert "Available_Bytes" in result
        # No buff/cache key
        assert "Buff_Cache_Bytes" not in result

    def test_lscpu_stepping_field_present(self, real_lscpu_output):
        """
        GIVEN real lscpu with Stepping field
        WHEN parse lscpu
        THEN handle optional fields.
        """
        assert "Stepping:" in real_lscpu_output

        result = parse_lscpu_output(real_lscpu_output)

        # Function only extracts specific fields
        assert "Threads_Per_Core_Count" in result
        assert "Model" in result
        # But not Stepping
        assert "Stepping" not in result

    def test_memory_in_kb_format(self, real_sstat_parseable_output):
        """
        GIVEN sstat memory values in KB
        WHEN parse and convert
        THEN handle K suffix correctly.
        """
        # Real SLURM uses K for kilobytes
        assert "142462354K" in real_sstat_parseable_output
        assert "mem=142462354K" in real_sstat_parseable_output

        # Parse a TRES string with memory
        tres_str = "mem=142462354K,vmem=542192528K"
        parsed = parse_tres_string(tres_str)

        assert parsed["mem"] == "142462354K"
        assert parsed["vmem"] == "542192528K"


class TestRealDataIntegration:
    """Integration tests combining multiple real outputs."""

    def test_job_cpu_vs_node_cpu(self, real_scontrol_output, real_lscpu_output):
        """
        GIVEN job CPUs vs total node CPUs
        WHEN compare allocations
        THEN validate job fits within node capacity.
        """
        job_info = parse_scontrol_output(real_scontrol_output)
        cpu_info = parse_lscpu_output(real_lscpu_output)

        # Job allocated 2 CPUs
        job_cpus = int(job_info["NumCPUs"])
        assert job_cpus == 2

        # Node has 112 physical cores (224 logical with TPC=2)
        node_physical = cpu_info["Total_Physical_Cores_Count"]
        assert node_physical == 112

        # Job uses 2/224 = 0.89% of node's logical cores
        tpc = cpu_info["Threads_Per_Core_Count"]
        node_logical = node_physical * tpc
        usage_pct = (job_cpus / node_logical) * 100
        assert usage_pct < 1.0  # Less than 1% of node

    def test_job_memory_vs_node_memory(self, real_scontrol_output, real_free_output):
        """
        GIVEN job memory vs total node memory
        WHEN compare allocations
        THEN validate memory allocation.
        """
        job_info = parse_scontrol_output(real_scontrol_output)
        mem_info = parse_free_output(real_free_output)

        # Job allocated 2000M = 2 GB
        assert "mem=2000M" in job_info["AllocTRES"]
        job_mem_mb = 2000

        # Node has ~251 GB total
        node_mem_kb = mem_info["Total_Bytes"] // 1024
        node_mem_mb = node_mem_kb // 1024

        # Job uses 2/251000 = 0.0008% of node memory
        usage_pct = (job_mem_mb / node_mem_mb) * 100
        assert usage_pct < 1.0  # Less than 1% of node memory

    def test_load_average_vs_cpu_count(self, real_uptime_output, real_lscpu_output):
        """
        GIVEN load average vs CPU count
        WHEN compare metrics
        THEN validate load is reasonable for CPU count.
        """
        uptime = parse_uptime_output(real_uptime_output)
        assert uptime is not None
        cpu_info = parse_lscpu_output(real_lscpu_output)

        # Load of 6.23 on 224-CPU system
        load_1min = uptime["Min_1"]  # Correct key name
        tpc = cpu_info["Threads_Per_Core_Count"]
        logical_cpus = cpu_info["Total_Physical_Cores_Count"] * tpc

        # Load per CPU
        load_per_cpu = load_1min / logical_cpus
        assert load_per_cpu < 0.05  # < 5% average load per CPU
