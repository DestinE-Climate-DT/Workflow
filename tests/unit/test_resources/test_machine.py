"""Tests for the used-vs-billed core-hour model."""

from __future__ import annotations

from wftools.resources import machine


class TestSpecFor:
    def test_known_machines(self):
        assert machine.spec_for("lumi").cores_per_node == 128
        assert machine.spec_for("marenostrum5").cores_per_node == 112

    def test_matches_platform_variants(self):
        # Autosubmit platform names carry suffixes (lumi-login, lumi-transfer).
        assert machine.spec_for("LUMI-transfer") == machine.spec_for("lumi")
        assert machine.spec_for("mn5") == machine.spec_for("marenostrum5")

    def test_unknown_machine_falls_back(self):
        assert machine.spec_for("someday-hpc") == machine.UNKNOWN
        assert machine.spec_for(None) == machine.UNKNOWN


class TestCoresUsed:
    def test_strips_hyperthreading(self):
        assert machine.cores_used(256, machine.spec_for("lumi")) == 128

    def test_unknown_machine_keeps_raw_count(self):
        assert machine.cores_used(256, machine.UNKNOWN) == 256


class TestBilled:
    def test_sub_node_job_is_billed_as_used(self):
        spec = machine.spec_for("lumi")
        nodes, cores = machine.billed(cores=8, sacct_nodes=1, spec=spec)
        assert (nodes, cores) == (1, 8)

    def test_multi_node_job_is_billed_whole_nodes(self):
        """A job holding 130 cores occupies 2 nodes and is charged for 256."""
        spec = machine.spec_for("lumi")
        nodes, cores = machine.billed(cores=130, sacct_nodes=2, spec=spec)
        assert (nodes, cores) == (2, 256)

    def test_exactly_one_node_is_not_rounded_up(self):
        spec = machine.spec_for("lumi")
        assert machine.billed(cores=128, sacct_nodes=1, spec=spec) == (1, 128)

    def test_sacct_node_count_wins_when_larger(self):
        """A sparse allocation spans more nodes than the core count implies."""
        spec = machine.spec_for("lumi")
        nodes, cores = machine.billed(cores=200, sacct_nodes=4, spec=spec)
        assert (nodes, cores) == (4, 512)

    def test_marenostrum_node_size(self):
        spec = machine.spec_for("marenostrum5")
        assert machine.billed(cores=200, sacct_nodes=2, spec=spec) == (2, 224)

    def test_unknown_machine_bills_what_was_used(self):
        assert machine.billed(cores=200, sacct_nodes=2, spec=machine.UNKNOWN) == (
            2,
            200,
        )
