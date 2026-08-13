"""Generate the dynamic child pipeline YAML for per-type Autosubmit CI jobs.

Each experiment type gets its own expid -> create -> run -> monitor -> delete
job chain, naming aligned with Autosubmit's CLI verbs.  The chain gives GitLab
full per-experiment visibility: separate logs, artifacts, JUnit reports, and
environment links.

The `delete` job auto-cleans an experiment only on an explicit clean-pass
verdict (RUN_FAILED=0).  A failed run -- or any upstream job (create/run) that
died before writing its verdict -- is preserved on the HPC for live debugging
(fail-safe default), and a manual `force-delete-{type}` job is provided to
clean it up afterwards.

Public API: ``generate(types, parent_pipeline_id="") -> dict``.
"""

from __future__ import annotations

import copy
import re
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined

from wftools.resources.sacct import SACCT_FORMAT


# ---------------------------------------------------------------------------
# YAML literal-block representer (forces ``|`` style for multi-line strings)
# ---------------------------------------------------------------------------
class _LiteralStr(str):
    """Marker class for strings that should be rendered as YAML literal blocks."""


def _literal_representer(dumper: yaml.Dumper, data: str) -> yaml.Node:
    return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")


yaml.add_representer(_LiteralStr, _literal_representer)


def _sanitize_env_name(type_name: str) -> str:
    """Convert type name to valid shell variable suffix: uppercase, hyphens to underscores."""
    return re.sub(r"[^A-Za-z0-9_]", "_", type_name).upper()


# ---------------------------------------------------------------------------
# Package data: skeleton + shell templates ship with wftools.
# ---------------------------------------------------------------------------
_PKG_DIR = Path(__file__).parent
_TEMPLATES_DIR = _PKG_DIR / "templates"
_SKELETON_PATH = _PKG_DIR / "skeleton.yml"

_JINJA = Environment(
    loader=FileSystemLoader(str(_TEMPLATES_DIR)),
    undefined=StrictUndefined,  # fail loudly on a missing context variable
    keep_trailing_newline=False,  # drop the file's final newline (scripts have none)
    autoescape=False,  # shell scripts, not HTML
)


def _render(template: str, **context) -> str:
    return _JINJA.get_template(template).render(**context)


# ---------------------------------------------------------------------------
# Shared before_script (module loading + helpers), loaded from disk so it
# gets shell syntax highlighting and can be edited without brace-doubling.
# ---------------------------------------------------------------------------
BEFORE_SCRIPT = _LiteralStr(
    (_TEMPLATES_DIR / "before_script.sh").read_text().rstrip("\n")
)


# ---------------------------------------------------------------------------
# Per-type job scripts
# ---------------------------------------------------------------------------
# Phase names that render from a template other than `{phase}.sh.j2`.
# `force_delete` reuses delete.sh.j2 -- the two only differ in `skip_on_fail`
# (always False here) and the report name (set at callsite).
_TEMPLATE_ALIASES = {"force_delete": "delete.sh.j2"}


# SSH host aliases, overridable at CI runtime like the smoke-stage
# connectivity checks.  Cleanup needs all three regardless of the job's own
# HPC: an experiment gets a per-expid root on every platform it touches.
_LUMI_ALIAS = "${LUMI_HOST:-lumi-cluster}"
_MN5_ALIAS = "${MN5_HOST:-mn5-cluster1}"
_TRANSFER_ALIAS = "${MN5_TRANSFER_HOST:-mn5-prod-client1}"


def _ssh_alias_for(hpc: str) -> str:
    """Map an Autosubmit HPC name to the runner's SSH host alias.

    Returns "" for unknown HPCs (the caller then skips SSH-based work).
    """
    hpc_l = hpc.lower()
    if hpc_l.startswith("lumi"):
        return _LUMI_ALIAS
    if hpc_l.startswith("marenostrum") or hpc_l.startswith("mn5"):
        return _MN5_ALIAS
    return ""


def _script(
    phase: str,
    type_name: str,
    hpc: str = "",
    *,
    skip_on_fail: bool = False,
    report: str | None = None,
) -> _LiteralStr:
    """Render the shell body for `phase` with the full per-type context.

    jinja2 with `StrictUndefined` errors only when a template *reads* an
    undefined variable -- passing extras is harmless, so every phase gets the
    same context bundle and each template picks what it needs.  Delete-family
    phases pull in `delete_preserve.sh.j2` + `remote_cleanup.sh.j2` via
    template-side `{% include %}` gated by `skip_on_fail`.
    """
    env_var = f"EXPID_{_sanitize_env_name(type_name)}"
    flag_var = f"RUN_FAILED_{_sanitize_env_name(type_name)}"
    template = _TEMPLATE_ALIASES.get(phase, f"{phase}.sh.j2")
    return _LiteralStr(
        _render(
            template,
            type_name=type_name,
            hpc=hpc,
            env_var=env_var,
            expid_ref=f"${{{env_var}}}",
            flag_var=flag_var,
            flag_ref=f"${{{flag_var}:-1}}",
            ssh_alias=_ssh_alias_for(hpc),
            lumi_alias=_LUMI_ALIAS,
            mn5_alias=_MN5_ALIAS,
            transfer_alias=_TRANSFER_ALIAS,
            skip_on_fail=skip_on_fail,
            sacct_format=SACCT_FORMAT,
            report=report or f"{type_name}_{phase}",
        )
    )


# ---------------------------------------------------------------------------
# Pipeline generation
# ---------------------------------------------------------------------------
# Job shapes (stage, needs, artifacts, ...) live in the sibling skeleton.yml
# for readability -- edit shapes there, edit behaviour (rules, script wiring,
# conditional `when:`) here.  [NOTE] PG: revisit once provenance-yaml is ready
# -- skeleton file is the natural place to attach which-template-made-which-job
# links.
with open(_SKELETON_PATH) as _fh:
    _SKELETON = yaml.safe_load(_fh)

# Required types render in the left columns of the child pipeline graph,
# optional ("extras") in the right columns.
PHASES = tuple(_SKELETON["defaults"]["phases"])
_STAGE_CLASSES = tuple(_SKELETON["defaults"]["stage_classes"])
CHILD_STAGES = [
    f"{stage_class}-{phase}" for stage_class in _STAGE_CLASSES for phase in PHASES
]


def _format_tree(node, ctx: dict):
    if isinstance(node, str):
        return node.format(**ctx) if ("{" in node and "}" in node) else node
    if isinstance(node, dict):
        return {k: _format_tree(v, ctx) for k, v in node.items()}
    if isinstance(node, list):
        return [_format_tree(v, ctx) for v in node]
    return node


# GitLab is order-agnostic, but a stable field order keeps generator output
# diffable across refactors.  Fields not in this list are appended in insertion
# order.
_JOB_KEY_ORDER = (
    "extends",
    "stage",
    "rules",
    "allow_failure",
    "timeout",
    "needs",
    "environment",
    "when",
    "script",
    "artifacts",
)


def _order_job(job: dict) -> dict:
    ordered = {k: job[k] for k in _JOB_KEY_ORDER if k in job}
    for k, v in job.items():
        if k not in ordered:
            ordered[k] = v
    return ordered


def _job(phase: str, ctx: dict) -> dict:
    """Deep-copy + str.format the skeleton entry for `phase`, add `extends`."""
    spec = _format_tree(copy.deepcopy(_SKELETON["jobs"][phase]), ctx)
    spec["extends"] = ".child-defaults"
    return spec


def _expid_rules(detected: bool) -> list:
    """Build the expid job's `rules:` list.

    Auto-start policy is chosen at child-pipeline runtime via `$TSUITE_AUTO`
    forwarded from tsuite-trigger:

      ALL      -> every chain auto-starts (on_success)
      REQUIRED -> required chains auto-start; optional stay manual
      NONE     -> every chain waits for a manual click  (default)
    """
    rules: list = [{"if": '$TSUITE_AUTO == "ALL"', "when": "on_success"}]
    if detected:
        rules.append({"if": '$TSUITE_AUTO == "REQUIRED"', "when": "on_success"})
    rules.append({"when": "manual"})
    return rules


def generate(types: list[dict], parent_pipeline_id: str = "") -> dict:
    """Generate child pipeline config for a list of experiment types.

    Each ``types`` entry: ``{type: str, hpc: str, detected: bool}``.

    Every job carries `allow_failure: true` (see the skeleton for the full
    rationale).  `detected=True` types go into `required-*` stages and
    `detected=False` ("extras") into `optional-*`; both get the same chain,
    whose `expid` job is `when: manual` (no auto HPC) and the rest of which runs
    on success, so an un-clicked chain is skipped entirely.  Both classes get a
    manual `force-delete-{type}`, the only way to reclaim what `delete` kept.
    """
    variables: dict[str, str] = {"AUTOSUBMIT_VERSION": ""}
    if parent_pipeline_id:
        variables["PARENT_PIPELINE_ID"] = parent_pipeline_id

    child_defaults = copy.deepcopy(_SKELETON["defaults"]["child_defaults"])
    # Runtime-only fields (Python object for before_script; per-invocation vars).
    child_defaults["variables"] = variables
    child_defaults["before_script"] = [BEFORE_SCRIPT]

    pipeline: dict = {
        "stages": list(CHILD_STAGES),
        # Child pipeline gets its own workflow:rules so the parent's
        # `merge_request_event` filter doesn't reject the trigger-spawned
        # pipeline (CI_PIPELINE_SOURCE = 'parent_pipeline' here).
        "workflow": copy.deepcopy(_SKELETON["defaults"]["workflow"]),
        ".child-defaults": child_defaults,
    }

    for entry in types:
        type_name = entry["type"]
        hpc = entry["hpc"]
        # back-compat: missing flag treated as detected so older overrides
        # still produce required chains.
        detected = entry.get("detected", True)
        stage_class = "required" if detected else "optional"
        ctx = {
            "stage_class": stage_class,
            "type_name": type_name,
        }

        # Build the main chain (expid -> create -> run -> monitor -> delete).
        for phase in PHASES:
            job = _job(phase, ctx)
            if phase == "delete":
                # Preserve on FAIL so a failed chain can be investigated live.
                job["script"] = [_script(phase, type_name, hpc, skip_on_fail=True)]
            else:
                job["script"] = [_script(phase, type_name, hpc)]
            if phase == "expid":
                job["rules"] = _expid_rules(detected)
            pipeline[f"{phase}-{type_name}"] = job

        force_job = _job("force_delete", ctx)
        force_job["script"] = [_script("force_delete", type_name, hpc)]
        pipeline[f"force-delete-{type_name}"] = force_job

    # Stable field order for diffability -- top-level non-job keys pass through.
    non_job_keys = {"stages", "workflow", ".child-defaults"}
    return {k: (v if k in non_job_keys else _order_job(v)) for k, v in pipeline.items()}


def dump_pipeline(pipeline: dict) -> str:
    """YAML-dump a pipeline dict with the settings the CI consumes."""
    return yaml.dump(pipeline, default_flow_style=False, sort_keys=False)
