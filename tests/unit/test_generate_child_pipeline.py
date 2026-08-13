"""Smoke test for the jinja-rendered child-pipeline generator.

``wftools.tsuite_pipeline`` renders each per-type job script from a
``wftools/tsuite_pipeline/templates/*.sh.j2`` template.  This guards that every
template renders (no missing file, no StrictUndefined variable) and that the
generated pipeline is valid YAML with the expected per-type job chain.
"""

from __future__ import annotations

import yaml

from wftools.tsuite_pipeline import generate

_TYPES = [
    {"type": "ifs-nemo-lowres", "hpc": "lumi", "detected": True},
    {"type": "nemo-standalone", "hpc": "marenostrum5", "detected": False},
]


def test_generate_renders_all_scripts_and_valid_yaml() -> None:
    pipeline = generate(_TYPES, parent_pipeline_id="42")

    # Every type gets the full chain plus a force-delete button.
    for phase in ("expid", "create", "run", "monitor", "resources", "delete"):
        assert f"{phase}-ifs-nemo-lowres" in pipeline
        assert f"{phase}-nemo-standalone" in pipeline
    assert "force-delete-ifs-nemo-lowres" in pipeline
    assert "force-delete-nemo-standalone" in pipeline

    # Every job's script rendered to a non-empty string (StrictUndefined would
    # have raised on a missing template variable).
    for name, job in pipeline.items():
        if isinstance(job, dict) and "script" in job:
            body = job["script"][0]
            assert isinstance(body, str) and body.strip(), name
            assert "{{" not in body, f"unrendered jinja in {name}"

    # The whole thing must serialise to valid YAML (what the CI consumes).
    assert yaml.safe_load(yaml.dump(pipeline)) is not None


def test_resources_is_serialised_between_run_and_monitor() -> None:
    """`needs` orders these jobs, not stage order.

    resources -> monitor keeps both off the same expid at once; delete reaches
    resources transitively, so it cannot reclaim HPCROOTDIR mid-collection.
    """
    pipeline = generate(_TYPES)
    for type_name in ("ifs-nemo-lowres", "nemo-standalone"):

        def needs_of(phase: str) -> set:
            return {n["job"] for n in pipeline[f"{phase}-{type_name}"]["needs"]}

        assert f"run-{type_name}" in needs_of("resources")
        assert f"resources-{type_name}" in needs_of("monitor")
        assert f"monitor-{type_name}" in needs_of("delete")


def test_delete_preserves_a_failed_run_and_force_delete_does_not() -> None:
    """A failed chain survives `delete` so it can be debugged, either class.

    `force-delete` is the manual override, and is the only job that reclaims
    it -- so it must NOT carry the preserve block.
    """
    pipeline = generate(_TYPES)
    for type_name in ("ifs-nemo-lowres", "nemo-standalone"):
        delete = pipeline[f"delete-{type_name}"]["script"][0]
        force_delete = pipeline[f"force-delete-{type_name}"]["script"][0]

        assert "ACTION REQUIRED" in delete
        assert "ACTION REQUIRED" not in force_delete
        # Both still carry the remote-cleanup block.
        assert "Remote HPC cleanup" in delete
        assert "Remote HPC cleanup" in force_delete


def test_delete_auto_runs_for_both_classes() -> None:
    """Optional chains clean up too -- their `expid` click is the only gate."""
    pipeline = generate(_TYPES)
    assert "when" not in pipeline["delete-nemo-standalone"]
    assert "when" not in pipeline["delete-ifs-nemo-lowres"]
    # The override is manual for every type.
    assert pipeline["force-delete-nemo-standalone"]["when"] == "manual"
    assert pipeline["force-delete-ifs-nemo-lowres"]["when"] == "manual"


def test_resources_reports_its_verdict_to_the_parent() -> None:
    """The accounting verdict has to survive the child pipeline.

    Its case name carries the `{type}/` prefix so `tsuite-required` can match
    the XML to the type, and the XML itself is forwarded under a phase-infixed
    name that keeps it clear of the monitor report.
    """
    pipeline = generate(_TYPES)
    for type_name in ("ifs-nemo-lowres", "nemo-standalone"):
        script = pipeline[f"resources-{type_name}"]["script"][0]

        assert f'destine report add "{type_name}/resources"' in script
        assert (
            'cp "reports/tsuite-resources.xml" '
            '"$SHARED_DIR/tsuite-report-$expid.resources.xml"' in script
        )
        # Broken accounting turns the job red; an empty-sacct SKIP does not.
        assert "accounting_failed=1" in script
        assert script.rstrip().endswith("exit 1\nfi")


def test_monitor_reuses_the_resources_phase_durations() -> None:
    """`resources` runs first and has sacct times AS has not recovered yet."""
    pipeline = generate(_TYPES)
    for type_name in ("ifs-nemo-lowres", "nemo-standalone"):
        script = pipeline[f"monitor-{type_name}"]["script"][0]
        assert '--durations "$SHARED_DIR/resources-$expid.json"' in script


def test_run_survives_a_failing_autosubmit_run() -> None:
    """A bare `autosubmit run | tee` is killed by errexit before it reports.

    Everything the run phase exists to produce on a failure -- the per-job
    logs and the JUnit -- sits after that pipeline, so it has to be guarded.
    """
    pipeline = generate(_TYPES)
    for type_name in ("ifs-nemo-lowres", "nemo-standalone"):
        script = pipeline[f"run-{type_name}"]["script"][0]

        assert 'if autosubmit run "$expid" 2>&1 | tee' in script
        assert "run_exit=${PIPESTATUS[0]}" in script
        # The failure path this guard exists to reach.
        assert 'tail -200 "$log"' in script
        assert "destine report generate reports/tsuite-run.xml" in script
