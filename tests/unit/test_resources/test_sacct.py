from __future__ import annotations

import pytest

from wftools.resources.sacct import (
    extract_gpus,
    parse_elapsed,
    parse_mem,
    parse_sacct,
)


class TestParseElapsed:
    @pytest.mark.parametrize(
        "value,expected",
        [
            ("00:00:30", 30.0),
            ("01:00:00", 3600.0),
            ("02:03:04", 2 * 3600 + 3 * 60 + 4),
            ("1-00:00:00", 86400.0),
            ("2-01:00:00", 2 * 86400 + 3600),
            ("05:00", 300.0),  # MM:SS
            ("", 0.0),
            ("garbage", 0.0),
        ],
    )
    def test_parse(self, value: str, expected: float) -> None:
        assert parse_elapsed(value) == expected


class TestParseMem:
    @pytest.mark.parametrize(
        "value,expected",
        [
            ("1024K", 1024 * 1024),
            ("2M", 2 * 1024**2),
            ("1.5G", int(1.5 * 1024**3)),
            ("512", 512),
            ("", None),
            ("--", None),
        ],
    )
    def test_parse(self, value: str, expected) -> None:
        assert parse_mem(value) == expected


class TestParseSacct:
    def test_main_rows_aggregate(self) -> None:
        # Two allocation-level jobs, one with a .batch step carrying MaxRSS.
        text = (
            "1001|a006_SIM|COMPLETED|2|256|01:00:00|7200000|\n"
            "1001.batch|batch|COMPLETED|1|128|01:00:00|7200000|4G\n"
            "1002|a006_AQUA|COMPLETED|1|64|00:30:00|900000|\n"
        )
        jobs = parse_sacct(text)
        assert len(jobs) == 2  # step row folded in, not a separate job

        by_id = {j.job_id: j for j in jobs}
        sim = by_id["1001"]
        assert sim.nodes == 2
        assert sim.cpus == 256
        assert sim.elapsed_s == 3600.0
        assert sim.node_hours == 2.0
        # parse_sacct leaves billing alone; the writer resolves it per machine.
        assert sim.cores == 0 and sim.cores_billed == 0
        assert sim.energy_joules == 7200000.0
        # MaxRSS lifted from the .batch step.
        assert sim.max_rss_bytes == 4 * 1024**3

        aqua = by_id["1002"]
        assert aqua.node_hours == 0.5

    def test_missing_energy_is_none(self) -> None:
        jobs = parse_sacct("2001|x|COMPLETED|1|10|00:10:00||\n")
        assert jobs[0].energy_joules is None
        assert jobs[0].max_rss_bytes is None

    def test_empty_input(self) -> None:
        assert parse_sacct("") == []
        assert parse_sacct("\n\n") == []


class TestStepEnergy:
    """Only the step rows carry energy where SLURM makes no `extern` step."""

    def test_energy_lifted_from_batch_step(self) -> None:
        # LUMI shape: empty ConsumedEnergyRaw on the allocation row.
        text = (
            "20990120|a006_19900101_fc0_1_1_OPA_DATA|COMPLETED|1|256|00:01:18|||"
            "billing=256,cpu=256,mem=224G,node=1\n"
            "20990120.batch|batch|COMPLETED|1|256|00:01:18|21368|300804K|"
            "cpu=256,mem=224G,node=1\n"
        )
        job = parse_sacct(text)[0]
        assert job.energy_joules == 21368.0
        assert job.max_rss_bytes == 300804 * 1024

    def test_overlapping_steps_do_not_sum(self) -> None:
        """MN5 shape: `extern` spans the job, so the steps it contains repeat it."""
        text = (
            "42758309|a006_19900101_fc0_1_SIM|COMPLETED|5|1120|00:05:30|3265731||\n"
            "42758309.batch|batch|COMPLETED|1|224|00:05:30|208897|12935243K|\n"
            "42758309.extern|extern|COMPLETED|5|1120|00:05:30|3265731|403K|\n"
            "42758309.0|lscpu|COMPLETED|1|14|00:00:00|1405|3736K|\n"
            "42758309.1|orted|COMPLETED|4|1120|00:05:13|816744|19355762K|\n"
        )
        job = parse_sacct(text)[0]
        assert job.energy_joules == 3265731.0

    def test_allocation_row_wins_over_a_larger_step(self) -> None:
        """A populated allocation row is SLURM's own figure, even when a step exceeds it."""
        text = (
            "20990013|a006_SIM|COMPLETED|1|200|00:06:58|259781|\n"
            "20990013.batch|batch|COMPLETED|1|200|00:06:58|260288|18M\n"
            "20990013.0|bddcml_local|COMPLETED|1|200|00:06:57|259781|903264K\n"
        )
        assert parse_sacct(text)[0].energy_joules == 259781.0

    def test_batch_step_covers_the_srun_steps_inside_it(self) -> None:
        text = (
            "20990118|a006_SIM|CANCELLED|1|112|00:04:08||\n"
            "20990118.batch|batch|CANCELLED|1|112|00:04:10|139524|18512K\n"
            "20990118.0|run.sh|CANCELLED|1|112|00:04:06|136472|9089856K\n"
        )
        assert parse_sacct(text)[0].energy_joules == 139524.0

    def test_site_without_energy_accounting_stays_none(self) -> None:
        text = (
            "4001|a006_SIM|COMPLETED|1|128|01:00:00||\n"
            "4001.batch|batch|COMPLETED|1|128|01:00:00||1G\n"
        )
        assert parse_sacct(text)[0].energy_joules is None


class TestGpuAccounting:
    """AllocTRES is the only place sacct reports the GPU allocation."""

    def test_extracts_gpu_count(self):
        assert extract_gpus("billing=256,cpu=256,node=2,gres/gpu=8") == 8

    def test_no_gpu_is_zero(self):
        assert extract_gpus("billing=128,cpu=128,node=1") == 0
        assert extract_gpus("") == 0

    def test_gpu_hours_come_from_alloctres(self):
        line = (
            "77|SIM|COMPLETED|2|256|02:00:00|1000|"
            "|billing=256,cpu=256,node=2,gres/gpu=8"
        )
        job = parse_sacct(line)[0]
        assert job.gpus == 8
        assert job.gpu_hours == 16.0

    def test_rows_without_alloctres_still_parse(self):
        """Older captured sacct output predates the AllocTRES column."""
        job = parse_sacct("77|SIM|COMPLETED|2|256|02:00:00|1000|")[0]
        assert job.gpus == 0
        assert job.gpu_hours == 0.0
