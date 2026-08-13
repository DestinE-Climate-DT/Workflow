"""Tests for the shared Autosubmit job-name grammar."""

from __future__ import annotations

import pytest

from wftools.autosubmit.job_names import split_job_name


class TestSection:
    @pytest.mark.parametrize(
        "job_name,expected",
        [
            ("a006_19900101_fc0_1_SIM", "SIM"),
            ("a006_19900101_fc0_1_DQC_FULL", "DQC_FULL"),
            ("a006_19900101_fc0_1_9_TRANSFER", "TRANSFER"),
            ("a006_LOCAL_SETUP", "LOCAL_SETUP"),
            ("a006_SYNCHRONIZE", "SYNCHRONIZE"),
            ("a006_19900101_REMOTE_SETUP", "REMOTE_SETUP"),
        ],
    )
    def test_extracts_section(self, job_name, expected):
        assert split_job_name("a006", job_name).section == expected

    def test_missing_name_has_no_section(self):
        assert split_job_name("a006", None).section is None
        assert split_job_name("a006", "").section is None

    def test_name_that_is_all_coordinates_has_no_section(self):
        assert split_job_name("a006", "a006_19900101_fc0_1").section is None

    def test_name_without_the_expid_prefix_still_parses(self):
        assert split_job_name("zzzz", "19900101_fc0_1_SIM").section == "SIM"


class TestCoordinates:
    def test_member_and_chunk(self):
        parts = split_job_name("a006", "a006_19900101_fc0_1_SIM")
        assert (parts.date, parts.member, parts.split) == ("19900101", "fc0_1", None)
        assert parts.context == "fc0_1"

    def test_split_is_captured(self):
        parts = split_job_name("a006", "a006_19900101_fc0_1_9_TRANSFER")
        assert parts.split == "9"
        assert parts.context == "fc0_1_9"

    def test_no_coordinates(self):
        parts = split_job_name("a006", "a006_LOCAL_SETUP")
        assert parts.context is None
