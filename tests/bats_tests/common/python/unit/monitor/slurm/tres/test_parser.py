"""Tests for TRES parser module."""

import pytest

from runscripts.CPMIP.monitor.slurm.tres.parser import parse_tres_string


class TestParseTresString:
    """Tests for parse_tres_string function."""

    def test_parse_simple_tres(self):
        """
        GIVEN a simple TRES string with cpu, mem, node
        WHEN parse_tres_string is called
        THEN return dict with all key-value pairs.
        """
        tres_str = "cpu=64,mem=187G,node=2"
        result = parse_tres_string(tres_str)
        assert result == {"cpu": "64", "mem": "187G", "node": "2"}

    def test_parse_complex_tres_with_billing(self):
        """
        GIVEN TRES string with billing and energy
        WHEN parse_tres_string is called
        THEN return dict with all fields.
        """
        tres_str = "cpu=128,mem=256G,node=4,billing=128,energy=12345"
        result = parse_tres_string(tres_str)

        assert result["cpu"] == "128"
        assert result["mem"] == "256G"
        assert result["node"] == "4"
        assert result["billing"] == "128"
        assert result["energy"] == "12345"

    @pytest.mark.parametrize("tres_str", ["", None, "N/A", "Unknown"])
    def test_parse_empty_or_invalid(self, tres_str):
        """
        GIVEN empty, None, N/A or Unknown string
        WHEN parse_tres_string is called
        THEN return empty dict.
        """
        result = parse_tres_string(tres_str)  # type: ignore
        assert result == {}

    def test_parse_tres_with_spaces(self):
        """
        GIVEN TRES string with spaces around equals and commas
        WHEN parse_tres_string is called
        THEN strip spaces and return clean dict.
        """
        tres_str = " cpu = 64 , mem = 187G , node = 2 "
        result = parse_tres_string(tres_str)
        assert result == {"cpu": "64", "mem": "187G", "node": "2"}

    def test_parse_tres_with_special_chars(self):
        """
        GIVEN TRES value containing special characters (colons)
        WHEN parse_tres_string is called
        THEN preserve special characters in value.
        """
        tres_str = "cpu=64,gres=gpu:a100:2,mem=256G"
        result = parse_tres_string(tres_str)

        assert result["cpu"] == "64"
        assert result["gres"] == "gpu:a100:2"
        assert result["mem"] == "256G"

    @pytest.mark.parametrize(
        "tres_str,expected_cpu",
        [
            ("cpu=64", "64"),  # Single item
            ("cpu=01:30:45,mem=10G", "01:30:45"),  # Time duration
        ],
    )
    def test_parse_special_formats(self, tres_str, expected_cpu):
        """
        GIVEN TRES string with single item or time duration format
        WHEN parse_tres_string is called
        THEN parse correctly and preserve format.
        """
        result = parse_tres_string(tres_str)
        assert result["cpu"] == expected_cpu

    def test_parse_malformed_item(self):
        """
        GIVEN TRES string with item missing equals sign
        WHEN parse_tres_string is called
        THEN skip malformed items.
        """
        tres_str = "cpu=64,invaliditem,mem=256G"
        result = parse_tres_string(tres_str)
        assert result == {"cpu": "64", "mem": "256G"}

    def test_parse_tres_with_empty_value(self):
        """
        GIVEN TRES string with key= (empty value)
        WHEN parse_tres_string is called
        THEN include key with empty string value.
        """
        tres_str = "cpu=64,mem=,node=2"
        result = parse_tres_string(tres_str)

        assert result["cpu"] == "64"
        assert result["mem"] == ""
        assert result["node"] == "2"
