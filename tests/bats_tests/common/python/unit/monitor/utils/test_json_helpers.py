"""Unit tests for JSON helper utilities."""

import gzip
import json
import os
import tempfile

from runscripts.CPMIP.monitor.utils.json_helpers import (
    round_floats_2dp,
    save_json_gz,
)


class TestRoundFloats2dp:
    """Tests for round_floats_2dp function."""

    def test_round_simple_dict(self):
        """
        GIVEN dict with floats
        WHEN round_floats_2dp is called
        THEN round all floats to 2 decimals.
        """
        data = {"cpu": 45.6789, "mem": 1024}
        result = round_floats_2dp(data)

        assert result == {"cpu": 45.68, "mem": 1024}

    def test_round_nested_dict(self):
        """
        GIVEN nested dict with floats
        WHEN round_floats_2dp is called
        THEN recursively round all floats.
        """
        data = {
            "metrics": {"cpu": 12.34567, "memory": {"used": 98.7654, "total": 1024}}
        }
        result = round_floats_2dp(data)

        assert result["metrics"]["cpu"] == 12.35
        assert result["metrics"]["memory"]["used"] == 98.77
        assert result["metrics"]["memory"]["total"] == 1024

    def test_round_list_of_floats(self):
        """
        GIVEN list with floats
        WHEN round_floats_2dp is called
        THEN round all floats in list.
        """
        data = [1.234, 5.678, 9]
        result = round_floats_2dp(data)

        assert result == [1.23, 5.68, 9]

    def test_round_mixed_types(self):
        """
        GIVEN dict with mixed types (int, float, str, bool)
        WHEN round_floats_2dp is called
        THEN only round floats, preserve other types.
        """
        data = {
            "float": 3.14159,
            "int": 42,
            "string": "hello",
            "bool": True,
            "none": None,
        }
        result = round_floats_2dp(data)

        assert result["float"] == 3.14
        assert result["int"] == 42
        assert result["string"] == "hello"
        assert result["bool"] is True
        assert result["none"] is None

    def test_round_list_in_dict(self):
        """
        GIVEN dict containing lists with floats
        WHEN round_floats_2dp is called
        THEN round floats in nested lists.
        """
        data = {
            "values": [1.111, 2.222, 3.333],
            "nested": {"more_values": [4.444, 5.555]},
        }
        result = round_floats_2dp(data)

        assert result["values"] == [1.11, 2.22, 3.33]
        assert result["nested"]["more_values"] == [4.44, 5.55]

    def test_round_empty_structures(self):
        """
        GIVEN empty dict and list
        WHEN round_floats_2dp is called
        THEN return empty structures.
        """
        assert round_floats_2dp({}) == {}
        assert round_floats_2dp([]) == []

    def test_round_preserves_precision(self):
        """
        GIVEN floats with exactly 2 decimals
        WHEN round_floats_2dp is called
        THEN preserve exact values.
        """
        data = {"value": 3.14}
        result = round_floats_2dp(data)

        assert result["value"] == 3.14


class TestSaveJsonGz:
    """Tests for save_json_gz function."""

    def test_save_simple_dict(self):
        """
        GIVEN simple dict
        WHEN save_json_gz is called
        THEN create compressed JSON file with rounded floats.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "test.json.gz")
            data = {"cpu": 45.6789, "mem": 1024}

            save_json_gz(path, data)

            # Verify file exists
            assert os.path.exists(path)

            # Verify content
            with gzip.open(path, "rt", encoding="utf-8") as f:
                loaded = json.load(f)

            assert loaded["cpu"] == 45.68  # Rounded
            assert loaded["mem"] == 1024

    def test_save_creates_directory(self):
        """
        GIVEN path in non-existent directory
        WHEN save_json_gz is called
        THEN create directory structure.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "subdir", "nested", "test.json.gz")
            data = {"test": 123}

            save_json_gz(path, data)

            assert os.path.exists(path)
            assert os.path.exists(os.path.dirname(path))

    def test_save_overwrites_existing(self):
        """
        GIVEN existing file
        WHEN save_json_gz is called
        THEN overwrite existing content.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "test.json.gz")

            # Save first version
            save_json_gz(path, {"version": 1})

            # Overwrite with new version
            save_json_gz(path, {"version": 2})

            # Verify new content
            with gzip.open(path, "rt", encoding="utf-8") as f:
                loaded = json.load(f)

            assert loaded["version"] == 2

    def test_save_complex_structure(self):
        """
        GIVEN complex nested structure
        WHEN save_json_gz is called
        THEN save correctly with proper formatting.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "complex.json.gz")
            data = {
                "job_id": "12345",
                "metrics": {
                    "cpu": 45.6789,
                    "memory": [100.123, 200.456],
                    "active": True,
                },
            }

            save_json_gz(path, data)

            # Verify file is gzipped and JSON formatted
            with gzip.open(path, "rt", encoding="utf-8") as f:
                content = f.read()
                loaded = json.loads(content)

            assert loaded["job_id"] == "12345"
            assert loaded["metrics"]["cpu"] == 45.68
            assert loaded["metrics"]["memory"] == [100.12, 200.46]
            assert loaded["metrics"]["active"] is True

            # Verify it's indented (not minified)
            assert "\n" in content

    def test_save_preserves_booleans(self):
        """
        GIVEN data with boolean values
        WHEN save_json_gz is called
        THEN preserve booleans (not convert to 0/1).
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "bool.json.gz")
            data = {"active": True, "disabled": False}

            save_json_gz(path, data)

            with gzip.open(path, "rt", encoding="utf-8") as f:
                loaded = json.load(f)

            assert loaded["active"] is True
            assert loaded["disabled"] is False
            assert isinstance(loaded["active"], bool)
            assert isinstance(loaded["disabled"], bool)

    def test_save_handles_unicode(self):
        """
        GIVEN data with unicode characters
        WHEN save_json_gz is called
        THEN save with proper UTF-8 encoding.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            path = os.path.join(tmpdir, "unicode.json.gz")
            data = {"message": "Hëllö Wörld 你好 🚀"}

            save_json_gz(path, data)

            with gzip.open(path, "rt", encoding="utf-8") as f:
                loaded = json.load(f)

            assert loaded["message"] == "Hëllö Wörld 你好 🚀"
