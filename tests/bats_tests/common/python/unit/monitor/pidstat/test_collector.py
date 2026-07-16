"""
Unit tests for the pidstat collector module.

Covers the per-node sampler script builder (including the optional rocm-smi GPU
section) and the rocm-smi --json parser.
"""

from runscripts.CPMIP.monitor.pidstat.collector import (
    build_sampler_script,
    parse_rocm_smi_json,
)


class TestBuildSamplerScript:
    """Test suite for build_sampler_script."""

    def test_no_rocm_smi_by_default(self):
        """
        GIVEN no rocm_smi_path
        WHEN build_sampler_script is called
        THEN no rocm-smi section is emitted (3 __SPLIT__ sections per sample).
        """
        script = build_sampler_script(pidstat_path="pidstat", frequency_seconds=10)
        assert "rocm-smi" not in script
        # uptime|free|pidstat => exactly 2 __SPLIT__ separators in one block.
        assert script.count("__SPLIT__") == 2

    def test_rocm_smi_section_added(self):
        """
        GIVEN rocm_smi_path is set
        WHEN build_sampler_script is called
        THEN a rocm-smi --showuse --showpower --json section is appended.
        """
        script = build_sampler_script(
            pidstat_path="pidstat", frequency_seconds=10, rocm_smi_path="rocm-smi"
        )
        assert (
            "rocm-smi --showuse --showmemuse --showmeminfo vram "
            "--showpower --showbw --json" in script
        )
        # Now uptime|free|pidstat|rocm => 3 __SPLIT__ separators.
        assert script.count("__SPLIT__") == 3
        # rocm-smi must run on the host, not via singularity exec.
        assert "singularity exec --no-home --cleanenv  rocm-smi" not in script
        # Graceful fallback on non-GPU nodes keeps the loop alive.
        assert "ROCM_SMI_ERROR" in script

    def test_pidstat_in_container_unaffected_by_rocm(self):
        """
        GIVEN a container_sif and rocm_smi_path
        WHEN build_sampler_script is called
        THEN pidstat runs in the container but rocm-smi runs on the host.
        """
        script = build_sampler_script(
            pidstat_path="/usr/local/bin/pidstat",
            frequency_seconds=5,
            container_sif="/x/perf.sif",
            rocm_smi_path="rocm-smi",
        )
        assert "singularity exec --no-home --cleanenv /x/perf.sif" in script
        assert (
            "rocm-smi --showuse --showmemuse --showmeminfo vram "
            "--showpower --showbw --json" in script
        )


class TestParseRocmSmiJson:
    """Test suite for parse_rocm_smi_json."""

    def test_parses_per_card_and_coerces_numbers(self):
        """
        GIVEN valid rocm-smi --json output
        WHEN parse_rocm_smi_json is called
        THEN it returns {card: {metric: value}} with numeric values as floats.
        """
        raw = (
            '{"card0": {"GPU use (%)": "42", '
            '"Average Graphics Package Power (W)": "310.0"}, '
            '"card1": {"GPU use (%)": "0"}}'
        )
        result = parse_rocm_smi_json(raw)
        assert result["card0"]["GPU use (%)"] == 42.0
        assert result["card0"]["Average Graphics Package Power (W)"] == 310.0
        assert result["card1"]["GPU use (%)"] == 0.0

    def test_keeps_non_numeric_values(self):
        """
        GIVEN a metric value like 'N/A'
        WHEN parse_rocm_smi_json is called
        THEN the original string is preserved (not coerced).
        """
        result = parse_rocm_smi_json('{"card0": {"GPU use (%)": "N/A"}}')
        assert result["card0"]["GPU use (%)"] == "N/A"

    def test_error_marker_returns_empty(self):
        """
        GIVEN the ROCM_SMI_ERROR fallback marker (non-GPU node)
        WHEN parse_rocm_smi_json is called
        THEN it returns {} rather than raising.
        """
        assert parse_rocm_smi_json("ROCM_SMI_ERROR") == {}

    def test_empty_or_invalid_returns_empty(self):
        """
        GIVEN empty / whitespace / non-dict JSON
        WHEN parse_rocm_smi_json is called
        THEN it returns {}.
        """
        assert parse_rocm_smi_json("") == {}
        assert parse_rocm_smi_json("   ") == {}
        assert parse_rocm_smi_json("[1, 2, 3]") == {}
