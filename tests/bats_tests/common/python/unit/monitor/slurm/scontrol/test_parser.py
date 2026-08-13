"""Unit tests for scontrol parser module - edge cases and error handling.

Tests parsing of scontrol show job output with focus on edge cases,
malformed data, and error conditions.
"""

import pytest

from runscripts.CPMIP.monitor.slurm.scontrol.parser import (
    parse_scontrol_output,
    parse_alloc_node,
    parse_nodelist,
)


class TestParseScontrolOutputEdgeCases:
    """Test edge cases and error handling for scontrol output parsing."""

    @pytest.mark.parametrize(
        "output",
        [
            "",  # Empty string
            None,  # None
            "   \n  \t  ",  # Whitespace only
        ],
    )
    def test_parse_empty_or_invalid_output(self, output):
        """
        GIVEN scontrol output is empty, None, or whitespace
        WHEN parse_scontrol is called
        THEN return empty dict.
        """
        result = parse_scontrol_output(output)
        assert result == {}

    @pytest.mark.parametrize(
        "output, expected",
        [
            ("JobId=12345", {"JobId": "12345"}),
            (
                "JobId=12345 JobName=test Partition=main",
                {"JobId": "12345", "JobName": "test", "Partition": "main"},
            ),
        ],
    )
    def test_parse_basic_key_values(self, output, expected):
        """
        GIVEN simple Key=Value pairs
        WHEN parse_scontrol is called
        THEN return dict with entries.
        """
        result = parse_scontrol_output(output)
        assert result == expected

    def test_parse_multiline_output(self):
        """
        GIVEN Key=Value pairs span multiple lines
        WHEN parse_scontrol is called
        THEN combine all into single dict.
        """
        output = """JobId=12345 JobName=test
Partition=main UserId=user1
State=RUNNING"""
        result = parse_scontrol_output(output)
        assert result["JobId"] == "12345"
        assert result["JobName"] == "test"
        assert result["Partition"] == "main"
        assert result["UserId"] == "user1"
        assert result["State"] == "RUNNING"

    @pytest.mark.parametrize(
        "output",
        [
            'WorkDir="/path/to/work dir" Command="/usr/bin/script.sh"',
            "WorkDir='/path/to/work' Command='/usr/bin/script'",
            'Comment="This is a comment" JobName="my job"',
        ],
    )
    def test_parse_quoted_values(self, output):
        """
        GIVEN values wrapped in quotes (single or double)
        WHEN parse_scontrol is called
        THEN strip quotes from values.
        """
        result = parse_scontrol_output(output)
        assert "WorkDir" in result or "Comment" in result
        # Verify quotes were stripped
        for value in result.values():
            assert not value.startswith('"')
            assert not value.startswith("'")

    def test_parse_real_scontrol_output(self, real_scontrol_output):
        """
        GIVEN real production scontrol output
        WHEN parse_scontrol is called
        THEN extract all job fields correctly.
        """
        result = parse_scontrol_output(real_scontrol_output)

        # Verify key fields were parsed
        assert "JobId" in result
        assert "JobName" in result
        assert "UserId" in result
        assert "JobState" in result or "State" in result

        # Verify at least 10 fields parsed (real output has many fields)
        assert len(result) >= 10


class TestParseAllocNodeEdgeCases:
    """Test edge cases for AllocNode parsing."""

    @pytest.mark.parametrize(
        "alloc_node,expected_node,expected_sid",
        [
            ("Sid=glogin3:12345", "glogin3", "12345"),
            ("glogin3:12345", "glogin3", "12345"),
            ("glogin3", "glogin3", ""),
            ("", "", ""),
            (None, "", ""),
        ],
    )
    def test_parse_alloc_node_formats(self, alloc_node, expected_node, expected_sid):
        """
        GIVEN AllocNode with various formats (with/without Sid prefix, empty, None)
        WHEN parse_alloc_node is called
        THEN extract node name and session ID correctly.
        """
        result = parse_alloc_node(alloc_node)  # type: ignore
        assert result["Node"] == expected_node
        assert result["Session_Id"] == expected_sid


class TestParseNodeListEdgeCases:
    """Test edge cases for NodeList parsing."""

    @pytest.mark.parametrize(
        "nodelist,expected_nodes,expected_count",
        [
            ("node01", ["node01"], 1),
            ("node01,node02,node03", ["node01", "node02", "node03"], 3),
            ("nid[001-004]", ["nid001", "nid002", "nid003", "nid004"], 4),
            ("nid[001-002,005-006]", ["nid001", "nid002", "nid005", "nid006"], 4),
            ("nid[001,003,005]", ["nid001", "nid003", "nid005"], 3),
            ("", [], 0),
            (None, [], 0),
        ],
    )
    def test_parse_node_list_formats(self, nodelist, expected_nodes, expected_count):
        """
        GIVEN NodeList in various formats (single, comma-separated, ranges, empty, None)
        WHEN parse_nodelist is called
        THEN expand ranges and return list of all nodes.
        """
        result = parse_nodelist(nodelist)  # type: ignore
        assert result["Nodes"] == expected_nodes
        assert result["Count"] == expected_count

    def test_parse_node_list_large_range(self):
        """
        GIVEN NodeList with large range (100 nodes)
        WHEN parse_nodelist is called
        THEN expand without performance issues.
        """
        result = parse_nodelist("nid[001-100]")
        assert result["Count"] == 100
        assert result["Nodes"][0] == "nid001"
        assert result["Nodes"][-1] == "nid100"

    def test_parse_node_list_mixed_notation(self):
        """
        GIVEN NodeList mixing ranges and individual nodes
        WHEN parse_nodelist is called
        THEN parse all notation types correctly.
        """
        result = parse_nodelist("nid[001-002],nid005")
        assert "nid001" in result["Nodes"]
        assert "nid002" in result["Nodes"]
        assert "nid005" in result["Nodes"]
        assert result["Count"] == 3
