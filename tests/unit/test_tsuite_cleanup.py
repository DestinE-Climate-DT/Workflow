"""Tests for the remote-cleanup resolvers and their remote-side guards.

The delete job reads back what Autosubmit *resolved* for an experiment and
deletes from that.  Two things make it easy to get wrong, and both are checked
here against parameter lists shaped like a real ``autosubmit report -all`` dump:

* the global ``FDB_HOME`` row is never substituted (``%CURRENT_*%`` is injected
  per job), and the per-job rows disagree -- a LUMI job inside an MN5
  experiment resolves to LUMI's *production* FDB root;
* an experiment has a per-expid root on every platform it touched, not just on
  the HPC that ``HPCROOTDIR`` names.

The remote-side guards are pulled out of the rendered script and executed, so
what is tested is what ships.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from wftools.tsuite_pipeline import generate

_LIB = (
    Path(__file__).resolve().parents[2]
    / "wftools"
    / "tsuite_pipeline"
    / "templates"
    / "cleanup_lib.sh"
)

# MN5 research experiment with TRANSFER and SYNC_LRA: roots on three machines,
# and FDB rows that resolve to a different store per platform.
_MN5_RESEARCH = """\
HPCROOTDIR=/gpfs/scratch/ehpc01/hpcuser/t4zz
AQUA.CENTRAL_LRA_OUTPUT_PATH=/appl/local/climatedt/data/AQUA/LRA/
AQUA.EXPERIMENT_NAME=t4zz
REQUEST.EXPVER=t4zz
REQUEST.FDB_HOME=%CURRENT_FDB_PROD%
PLATFORMS.LUMI.DATABRIDGE_FDB_HOME=/appl/local/destine/databridge
PLATFORMS.MARENOSTRUM5-TRANSFER.GATEWAY_FDB_HOME=/home/service/gateway
JOBS.LOCAL_SETUP.REQUEST.FDB_HOME=-
JOBS.LOCAL_SETUP.CURRENT_ROOTDIR=/appl/AS/AUTOSUBMIT_DATA/t4zz
JOBS.INI.REQUEST.FDB_HOME=/gpfs/projects/ehpc01/dte/fdb
JOBS.INI.CURRENT_ROOTDIR=/gpfs/scratch/ehpc01/hpcuser/t4zz
JOBS.SIM.HPCDATABRIDGE_FDB_HOME=-
JOBS.SIM.PLATFORMS.LUMI.DATABRIDGE_FDB_HOME=/appl/local/destine/databridge
JOBS.SIM.CURRENT_FDB_PROD=/gpfs/projects/ehpc01/dte/fdb
JOBS.SIM.REQUEST.FDB_HOME=/gpfs/projects/ehpc01/dte/fdb
JOBS.SIM.CURRENT_ROOTDIR=/gpfs/scratch/ehpc01/hpcuser/t4zz
JOBS.SYNC_LRA.REQUEST.FDB_HOME=/appl/local/destine/fdb
JOBS.SYNC_LRA.CURRENT_ROOTDIR=/scratch/project_465002727/lumiuser/t4zz
JOBS.TRANSFER.REQUEST.FDB_HOME=/home/service/gateway
JOBS.TRANSFER.CURRENT_ROOTDIR=/staging/ehpc01/datamover/t4zz
"""

# LUMI test experiment: per-expid FDB store, and local-platform rows that
# resolve against the VM's own AS data dir.
_LUMI_TEST = """\
HPCROOTDIR=/scratch/project_465002727/lumiuser/t4zy
REQUEST.EXPVER=t4zy
REQUEST.FDB_HOME=%CURRENT_SCRATCH_DIR%/%CURRENT_PROJECT%/experiments/t4zy/fdb
JOBS.LOCAL_SETUP.REQUEST.FDB_HOME=/appl/AS/AUTOSUBMIT_DATA/t4zy/tmp//experiments/t4zy/fdb
JOBS.LOCAL_SETUP.CURRENT_ROOTDIR=/appl/AS/AUTOSUBMIT_DATA/t4zy
JOBS.SYNCHRONIZE.REQUEST.FDB_HOME=/appl/AS/AUTOSUBMIT_DATA/t4zy/tmp//experiments/t4zy/fdb
JOBS.INI.REQUEST.FDB_HOME=/scratch/project_465002727/experiments/t4zy/fdb
JOBS.INI.CURRENT_ROOTDIR=/scratch/project_465002727/lumiuser/t4zy
JOBS.SIM.HPCDATABRIDGE_FDB_HOME=/appl/local/destine/databridge
JOBS.SIM.CURRENT_FDB_PROD=/appl/local/destine/fdb
JOBS.SIM.REQUEST.FDB_HOME=/scratch/project_465002727/experiments/t4zy/fdb
JOBS.SIM.CURRENT_ROOTDIR=/scratch/project_465002727/lumiuser/t4zy
"""


def _lib(snippet: str, **env: str) -> str:
    """Run `snippet` with cleanup_lib.sh sourced; return its stdout."""
    proc = subprocess.run(
        ["bash", "-c", f'source "{_LIB}"\n{snippet}'],
        capture_output=True,
        text=True,
        check=False,
        env={"PATH": "/usr/bin:/bin:/usr/local/bin", **env},
    )
    assert proc.returncode == 0, proc.stderr
    return proc.stdout


def _plist(tmp_path: Path, content: str) -> Path:
    path = tmp_path / "parameter_list.txt"
    path.write_text(content)
    return path


class TestResolveRoots:
    def test_every_platform_the_experiment_touched(self, tmp_path: Path) -> None:
        """The other HPC's root and the datamover's are roots too, and leak."""
        plist = _plist(tmp_path, _MN5_RESEARCH)
        out = _lib(f'resolve_roots "{plist}"').split()
        assert out == [
            "/gpfs/scratch/ehpc01/hpcuser/t4zz",
            "/scratch/project_465002727/lumiuser/t4zz",
            "/staging/ehpc01/datamover/t4zz",
        ]

    def test_the_vms_own_data_dir_is_never_a_root(self, tmp_path: Path) -> None:
        """Local-platform jobs resolve against the VM -- not ours to delete."""
        plist = _plist(tmp_path, _LUMI_TEST)
        out = _lib(f'resolve_roots "{plist}"').split()
        assert out == ["/scratch/project_465002727/lumiuser/t4zy"]


class TestResolveFdbStores:
    def test_only_the_sections_on_the_experiments_own_hpc_count(
        self, tmp_path: Path
    ) -> None:
        """SYNC_LRA resolves to the other HPC's production root, TRANSFER to the
        datamover's gateway; the experiment wrote to neither."""
        plist = _plist(tmp_path, _MN5_RESEARCH)
        root = "/gpfs/scratch/ehpc01/hpcuser/t4zz"
        out = _lib(f'resolve_fdb_stores "{plist}" {root}').split()
        assert out == ["/gpfs/projects/ehpc01/dte/fdb"]

    def test_per_expid_store_survives_and_the_vm_rows_do_not(
        self, tmp_path: Path
    ) -> None:
        plist = _plist(tmp_path, _LUMI_TEST)
        root = "/scratch/project_465002727/lumiuser/t4zy"
        out = _lib(f'resolve_fdb_stores "{plist}" {root}').split()
        assert out == ["/scratch/project_465002727/experiments/t4zy/fdb"]

    def test_the_unresolved_global_row_is_dropped(self, tmp_path: Path) -> None:
        """It is the row `head -1` used to take, and it never resolves."""
        for content, root in (
            (_MN5_RESEARCH, "/gpfs/scratch/ehpc01/hpcuser/t4zz"),
            (_LUMI_TEST, "/scratch/project_465002727/lumiuser/t4zy"),
        ):
            out = _lib(f'resolve_fdb_stores "{_plist(tmp_path, content)}" {root}')
            assert "%" not in out


class TestResolveParam:
    @pytest.mark.parametrize(
        ("key", "expected"),
        [
            ("HPCROOTDIR", "/gpfs/scratch/ehpc01/hpcuser/t4zz"),
            ("REQUEST.EXPVER", "t4zz"),
            ("AQUA.CENTRAL_LRA_OUTPUT_PATH", "/appl/local/climatedt/data/AQUA/LRA/"),
        ],
    )
    def test_global_rows(self, tmp_path: Path, key: str, expected: str) -> None:
        plist = _plist(tmp_path, _MN5_RESEARCH)
        assert _lib(f'resolve_param "{plist}" {key}').strip() == expected

    def test_absent_key_is_empty(self, tmp_path: Path) -> None:
        """No central-LRA row means the experiment ran no LRA jobs."""
        plist = _plist(tmp_path, _LUMI_TEST)
        assert _lib(f'resolve_param "{plist}" AQUA.CENTRAL_LRA_OUTPUT_PATH') == ""


class TestExpidGuard:
    @pytest.mark.parametrize("expid", ["t400", "t4zz", "t5a0", "t7zz"])
    def test_accepts_the_ci_namespace(self, expid: str) -> None:
        assert _lib(f"is_ci_expid {expid} && echo yes").strip() == "yes"

    @pytest.mark.parametrize("expid", ["t0zz", "a006", "t8zz", "t4z", "t4zzz", ""])
    def test_refuses_everything_else(self, expid: str) -> None:
        assert _lib(f'is_ci_expid "{expid}" || echo no').strip() == "no"


class TestAliasForRoot:
    @pytest.mark.parametrize(
        ("root", "expected"),
        [
            ("/scratch/project_465002727/lumiuser/t4zz", "lumi"),
            ("/gpfs/scratch/ehpc01/hpcuser/t4zz", "mn5"),
            ("/staging/ehpc01/datamover/t4zz", "transfer"),
            ("/appl/local/destine/fdb", ""),
        ],
    )
    def test_each_root_reaches_its_own_machine(self, root: str, expected: str) -> None:
        out = _lib(
            f'alias_for_root "{root}"',
            LUMI_ALIAS="lumi",
            MN5_ALIAS="mn5",
            TRANSFER_ALIAS="transfer",
        )
        assert out.strip() == expected


# ---------------------------------------------------------------------------
# Remote-side guards, extracted from the rendered script and executed.
# ---------------------------------------------------------------------------
def _delete_script() -> str:
    pipeline = generate([{"type": "ifs-fesom-tco79", "hpc": "marenostrum5"}])
    return pipeline["delete-ifs-fesom-tco79"]["script"][0]


def _remote_guard(func: str, tmp_path: Path) -> Path:
    """Write the heredoc `func` sends to the HPC out as a runnable script."""
    body = _delete_script().split(f"{func}() {{", 1)[1]
    body = body.split("<<'REMOTE_EOF'\n", 1)[1].split("\nREMOTE_EOF", 1)[0]
    path = tmp_path / f"{func}.sh"
    path.write_text(body)
    return path


def _run(script: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["bash", str(script), *args], capture_output=True, text=True, check=False
    )


# The guards on the shared stores take the expid pattern as an argument, so the
# one definition in the lib is what they are tested against.
_CI_PATTERN = _lib('printf %s "$CI_EXPID_PATTERN"')


# A select root as it really looks: per-grid `<grid>/etc/fdb/config.yaml`, each
# routing by MARS key.  Only the climate-dt block that pins no expver can hold a
# CI run's data -- a pinned block is production's, an archive:False root is a
# read-only mount.
_SELECT_CONFIG = """\
---
type: select
fdbs:
- select: class=d1,dataset=^climate-dt$,generation=2,expver=(0001|o[0-9a-z]{{3}})
  type: local
  engine: toc
  spaces:
  - roots:
    - path: {prod}
- select: class=d1,dataset=^climate-dt$
  excludes: ['class=d1,dataset=^climate-dt$,generation=2,expver=(0001|o[0-9a-z]{{3}})']
  type: local
  engine: toc
  spaces:
  - roots:
    - path: {ours}
    - path: {readonly}
      archive: False
- select: class=d1,dataset=^on-demand-extremes-dt$|^extremes-dt$
  type: local
  engine: toc
  spaces:
  - roots:
    - path: {extremes}
"""

_ENTRY = "d1:climate-dt:CMIP6:hist:1:IFS-NEMO:1:{expver}:clte:20200101"


def _select_root(tmp_path: Path) -> tuple[Path, dict[str, Path]]:
    """Build a select root plus the four data roots its config routes to."""
    data = {
        name: tmp_path / name / "fdb" / "native"
        for name in ("ours", "prod", "readonly", "extremes")
    }
    for root in data.values():
        for expver in ("t4zz", "0001"):
            (root / _ENTRY.format(expver=expver)).mkdir(parents=True)

    store = tmp_path / "select"
    config = store / "native" / "etc" / "fdb"
    config.mkdir(parents=True)
    (config / "config.yaml").write_text(
        _SELECT_CONFIG.format(**{k: v for k, v in data.items()})
    )
    return store, data


class TestRemoteFdbRm:
    def test_only_our_expids_entries_under_the_routed_root_are_removed(
        self, tmp_path: Path
    ) -> None:
        """The config says where the data is; the :expid: anchor says which of it."""
        store, data = _select_root(tmp_path)

        proc = _run(
            _remote_guard("remote_fdb_rm", tmp_path), str(store), "t4zz", _CI_PATTERN
        )

        assert proc.returncode == 0, proc.stdout
        ours = data["ours"]
        assert not (ours / _ENTRY.format(expver="t4zz")).exists()
        # Another experiment's data in the same shared root is untouched.
        assert (ours / _ENTRY.format(expver="0001")).exists()

    @pytest.mark.parametrize("kind", ["prod", "readonly", "extremes"])
    def test_roots_this_expver_cannot_route_to_are_left_alone(
        self, kind: str, tmp_path: Path
    ) -> None:
        """Pinned-expver, archive:False and other-dataset roots are not ours."""
        store, data = _select_root(tmp_path)

        _run(_remote_guard("remote_fdb_rm", tmp_path), str(store), "t4zz", _CI_PATTERN)

        assert (data[kind] / _ENTRY.format(expver="t4zz")).exists()

    def test_a_store_declaring_nothing_is_reported_not_guessed_at(
        self, tmp_path: Path
    ) -> None:
        proc = _run(
            _remote_guard("remote_fdb_rm", tmp_path),
            str(tmp_path / "empty"),
            "t4zz",
            _CI_PATTERN,
        )
        assert proc.returncode == 3
        assert "NOCONFIG" in proc.stdout

    def test_a_non_ci_expid_is_refused(self, tmp_path: Path) -> None:
        store, _ = _select_root(tmp_path)
        proc = _run(
            _remote_guard("remote_fdb_rm", tmp_path), str(store), "t0zz", _CI_PATTERN
        )
        assert proc.returncode == 2
        assert "not a CI expid" in proc.stdout


class TestRemoteGuardedRm:
    def test_the_datamover_root_is_now_allowed(self, tmp_path: Path) -> None:
        """Its /staging prefix used to fail the allowlist."""
        proc = _run(
            _remote_guard("remote_guarded_rm", tmp_path),
            "/staging/ehpc01/datamover/t4zz",
            "t4zz",
            "dir",
        )
        assert proc.returncode == 0
        assert "already absent" in proc.stdout

    @pytest.mark.parametrize(
        ("target", "expected"),
        [
            ("/appl/AS/AUTOSUBMIT_DATA/t4zz", "unsafe prefix"),
            ("/scratch/project_465002727/lumiuser/other", "does not end in"),
        ],
    )
    def test_refusals(self, target: str, expected: str, tmp_path: Path) -> None:
        proc = _run(_remote_guard("remote_guarded_rm", tmp_path), target, "t4zz", "dir")
        assert proc.returncode == 2
        assert expected in proc.stdout


class TestRemoteLraRm:
    def test_only_the_ci_expids_copy_is_removed(self, tmp_path: Path) -> None:
        """The central LRA is a shared store: the expid guard is all there is."""
        central = tmp_path / "LRA"
        ours = central / "mn5-phase2" / "IFS-NEMO-hr" / "t4zz"
        theirs = central / "mn5-phase2" / "IFS-NEMO-hr" / "t0zz"
        for path in (ours, theirs):
            path.mkdir(parents=True)
            (path / "lra.nc").write_text("data")

        proc = _run(
            _remote_guard("remote_lra_rm", tmp_path), f"{central}/", "t4zz", _CI_PATTERN
        )

        assert proc.returncode == 0, proc.stdout
        assert not ours.exists()
        assert theirs.exists()

    def test_a_non_ci_expid_is_refused(self, tmp_path: Path) -> None:
        proc = _run(
            _remote_guard("remote_lra_rm", tmp_path),
            "/appl/local/LRA",
            "t0zz",
            _CI_PATTERN,
        )
        assert proc.returncode == 2
        assert "not a CI expid" in proc.stdout


def test_the_delete_script_carries_the_resolvers_and_no_global_grep() -> None:
    """The lib is included into the job script, not shipped alongside it."""
    script = _delete_script()
    for func in ("is_ci_expid", "resolve_roots", "resolve_fdb_stores", "rm_root"):
        assert f"{func}(" in script
    # The row that never resolves must no longer be what cleanup reads.
    assert "'(^|\\.)FDB_HOME='" not in script


# ---------------------------------------------------------------------------
# The cleanup block itself, run against a fake parameter list with `ssh` and
# `autosubmit` stubbed.  Only the block is taken: the rest of the delete job
# reclaims the experiment's dir on the VM this test may be running on.
# ---------------------------------------------------------------------------
def _cleanup_run(tmp_path: Path, expid: str, plist: str) -> list[tuple[str, list[str]]]:
    """Run the cleanup for `expid`; return (alias, remote args) per ssh made."""
    script = _delete_script()
    body = script[
        script.index("# --- Remote HPC cleanup") : script.index(
            'expdir="/appl/AS/AUTOSUBMIT_DATA/'
        )
    ]
    (tmp_path / "reports").mkdir()
    (tmp_path / "params.txt").write_text(plist)
    (tmp_path / "cleanup.sh").write_text(body)
    (tmp_path / "harness.sh").write_text(
        "start_section() { :; }\nend_section() { :; }\n"
        f"RED=''\nGREEN=''\nNC=''\nexpid={expid}\nsource cleanup.sh\n"
    )
    stubs = tmp_path / "bin"
    stubs.mkdir()
    (stubs / "ssh").write_text(
        '#!/bin/bash\nprintf "%s\\n" "$*" >> "$SSH_LOG"\ncat > /dev/null\n'
    )
    # `autosubmit report <expid> -all -fp <dir>` is the only call made.
    (stubs / "autosubmit").write_text(
        '#!/bin/bash\ncp "$PWD/params.txt" "$5/$2_parameter_list_1.txt"\n'
    )
    for stub in stubs.iterdir():
        stub.chmod(0o755)

    ssh_log = tmp_path / "ssh.log"
    ssh_log.touch()
    proc = subprocess.run(
        ["bash", "harness.sh"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        env={
            "PATH": f"{stubs}:/usr/bin:/bin",
            "SSH_LOG": str(ssh_log),
        },
    )
    assert proc.returncode == 0, proc.stderr
    calls = []
    for line in ssh_log.read_text().splitlines():
        head, remote_args = line.split(" bash -s -- ")
        calls.append((head.split()[-1], remote_args.split()))
    return calls, proc.stdout


class TestCleanupBlock:
    def test_every_platforms_root_is_cleaned_on_its_own_machine(
        self, tmp_path: Path
    ) -> None:
        calls, _ = _cleanup_run(tmp_path, "t4zz", _MN5_RESEARCH)
        targets = {args[0]: alias for alias, args in calls if args[-1] == "dir"}
        assert targets == {
            "/gpfs/scratch/ehpc01/hpcuser/t4zz": "mn5-cluster1",
            "/scratch/project_465002727/lumiuser/t4zz": "lumi-cluster",
            "/staging/ehpc01/datamover/t4zz": "mn5-prod-client1",
        }

    def test_only_the_own_hpc_fdb_store_is_touched(self, tmp_path: Path) -> None:
        """The other HPC's production root and the gateway are never reached."""
        calls, _ = _cleanup_run(tmp_path, "t4zz", _MN5_RESEARCH)
        targeted = [args[0] for _, args in calls]
        assert "/gpfs/projects/ehpc01/dte/fdb" in targeted
        for other_platform in ("/appl/local/destine/fdb", "/home/service/gateway"):
            assert other_platform not in targeted

    def test_the_central_lra_copy_is_cleaned_on_lumi(self, tmp_path: Path) -> None:
        calls, _ = _cleanup_run(tmp_path, "t4zz", _MN5_RESEARCH)
        assert any(
            alias == "lumi-cluster"
            and args[0] == "/appl/local/climatedt/data/AQUA/LRA/"
            for alias, args in calls
        )

    def test_the_per_expid_fdb_dir_is_cleaned(self, tmp_path: Path) -> None:
        """The `TYPE: test` case: what the unresolved global row used to break."""
        calls, _ = _cleanup_run(tmp_path, "t4zy", _LUMI_TEST)
        assert (
            "lumi-cluster",
            ["/scratch/project_465002727/experiments/t4zy", "t4zy", "expdir"],
        ) in calls

    def test_an_expid_keyed_expver_sends_its_store_to_the_fdb_cleanup(
        self, tmp_path: Path
    ) -> None:
        """expver == expid, so this run's entries really are in the shared store."""
        calls, out = _cleanup_run(tmp_path, "t4zz", _MN5_RESEARCH)
        assert (
            "mn5-cluster1",
            ["/gpfs/projects/ehpc01/dte/fdb", "t4zz", _CI_PATTERN],
        ) in calls
        assert "REMOTE CLEANUP INCOMPLETE" not in out

    def test_a_fixed_expver_leaves_nothing_and_says_so_quietly(
        self, tmp_path: Path
    ) -> None:
        """Nothing in the shared store is keyed to this expid, so nothing is owed."""
        plist = _MN5_RESEARCH.replace("REQUEST.EXPVER=t4zz", "REQUEST.EXPVER=0001")
        calls, out = _cleanup_run(tmp_path, "t4zz", plist)
        assert "keys entries by expver 0001; nothing of t4zz there" in out
        assert "/gpfs/projects/ehpc01/dte/fdb" not in [args[0] for _, args in calls]
        assert "REMOTE CLEANUP INCOMPLETE" not in out

    def test_a_non_ci_expid_reaches_no_machine_at_all(self, tmp_path: Path) -> None:
        calls, out = _cleanup_run(tmp_path, "t0zz", _MN5_RESEARCH)
        assert calls == []
        assert "REMOTE CLEANUP INCOMPLETE" in out
