from types import SimpleNamespace

import yaml

from runscripts.aqua.update_aqua_config import (
    update_grids,
    update_paths,
    update_realizations,
)


def _write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        yaml.dump(data, f, sort_keys=False)


def test_update_paths_redirects_grid_dirs(tmp_path):
    machine = tmp_path / "machine.yaml"
    _write(
        machine,
        {"MN5": {"paths": {"grids": "/old", "weights": "/old", "areas": "/old"}}},
    )

    rc = update_paths(
        SimpleNamespace(
            machine_yaml=str(machine), platform="MN5", data_dir="/data/aqua-data"
        )
    )
    assert rc == 0

    paths = yaml.safe_load(machine.read_text())["MN5"]["paths"]
    assert paths["grids"] == "/data/aqua-data/grids"
    assert paths["weights"] == "/data/aqua-data/weights"
    assert paths["areas"] == "/data/aqua-data/areas"


def test_update_paths_missing_platform_errors(tmp_path):
    machine = tmp_path / "machine.yaml"
    _write(machine, {"LUMI": {"paths": {"grids": "/old"}}})

    rc = update_paths(
        SimpleNamespace(machine_yaml=str(machine), platform="MN5", data_dir="/data")
    )
    assert rc == 1


def test_update_paths_missing_file_errors(tmp_path):
    rc = update_paths(
        SimpleNamespace(
            machine_yaml=str(tmp_path / "nope.yaml"), platform="MN5", data_dir="/data"
        )
    )
    assert rc == 1


def test_update_grids_sets_atm_and_ocean(tmp_path):
    grids = tmp_path / "matching_grids.yaml"
    _write(
        grids,
        {
            "atm_grid": {"ifs-fesom": {"lowres": "old"}},
            "ocean_grid": {"ifs-fesom": {"lowres": "old"}},
        },
    )

    rc = update_grids(
        SimpleNamespace(
            matching_grids_yaml=str(grids),
            model="ifs-fesom",
            profile="lowres",
            atm_grid="tco79",
            ocean_grid="CORE2",
        )
    )
    assert rc == 0

    data = yaml.safe_load(grids.read_text())
    assert data["atm_grid"]["ifs-fesom"]["lowres"] == "tco79"
    assert data["ocean_grid"]["ifs-fesom"]["lowres"] == "CORE2"


def test_update_grids_unknown_model_warns_but_succeeds(tmp_path):
    grids = tmp_path / "matching_grids.yaml"
    _write(grids, {"atm_grid": {"ifs-nemo": {}}, "ocean_grid": {"ifs-nemo": {}}})

    rc = update_grids(
        SimpleNamespace(
            matching_grids_yaml=str(grids),
            model="ifs-fesom",
            profile="lowres",
            atm_grid="tco79",
            ocean_grid="CORE2",
        )
    )
    # warn-only: missing model leaves the file unchanged but does not fail
    assert rc == 0
    data = yaml.safe_load(grids.read_text())
    assert "ifs-fesom" not in data["atm_grid"]


def _catalog_with_realization_block(allowed, default=1):
    return {
        "sources": {
            "hourly-sfc": {
                "args": {"request": {"realization": "{{ realization }}"}},
                "parameters": {
                    "realization": {
                        "allowed": list(allowed),
                        "type": "int",
                        "default": default,
                    }
                },
                "driver": "gsv",
            }
        }
    }


def test_update_realizations_replaces_allowed_with_identity_set(tmp_path):
    # MEMBERS: fc15 fc16 fc17 -> realizations 16 17 18 (catgen produced [1,2,3])
    cat = tmp_path / "t0ti.yaml"
    _write(cat, _catalog_with_realization_block([1, 2, 3]))

    rc = update_realizations(
        SimpleNamespace(catalog_file=str(cat), realizations="16 17 18")
    )
    assert rc == 0

    realization = yaml.safe_load(cat.read_text())["sources"]["hourly-sfc"][
        "parameters"
    ]["realization"]
    assert realization["allowed"] == [16, 17, 18]
    assert realization["default"] == 16


def test_update_realizations_fc0_experiment_unchanged(tmp_path):
    # backward compat: fc0 fc1 fc2 -> [1, 2, 3], unsorted input is normalised
    cat = tmp_path / "entry.yaml"
    _write(cat, _catalog_with_realization_block([1, 2, 3]))

    rc = update_realizations(
        SimpleNamespace(catalog_file=str(cat), realizations="3 1 2")
    )
    assert rc == 0

    realization = yaml.safe_load(cat.read_text())["sources"]["hourly-sfc"][
        "parameters"
    ]["realization"]
    assert realization["allowed"] == [1, 2, 3]
    assert realization["default"] == 1


def test_update_realizations_pins_single_member_request(tmp_path):
    # single member (count 1): catgen omits the block and hardcodes realization: 1
    cat = tmp_path / "single.yaml"
    _write(
        cat,
        {
            "sources": {
                "hourly-sfc": {
                    "args": {"request": {"realization": 1, "expver": "t0zz"}},
                    "driver": "gsv",
                }
            }
        },
    )

    rc = update_realizations(SimpleNamespace(catalog_file=str(cat), realizations="11"))
    assert rc == 0

    request = yaml.safe_load(cat.read_text())["sources"]["hourly-sfc"]["args"][
        "request"
    ]
    assert request["realization"] == 11


def test_update_realizations_emits_no_yaml_anchors(tmp_path):
    # two independent sources (as catgen writes them) must each get their own list,
    # so the dump carries no anchors/aliases
    cat = tmp_path / "two.yaml"
    data = _catalog_with_realization_block([1, 2, 3])
    data["sources"]["daily-sfc"] = _catalog_with_realization_block([1, 2, 3])[
        "sources"
    ]["hourly-sfc"]
    _write(cat, data)

    rc = update_realizations(
        SimpleNamespace(catalog_file=str(cat), realizations="16 17 18")
    )
    assert rc == 0

    text = cat.read_text()
    assert "*id" not in text and "&id" not in text
    sources = yaml.safe_load(text)["sources"]
    for name in ("hourly-sfc", "daily-sfc"):
        assert sources[name]["parameters"]["realization"]["allowed"] == [16, 17, 18]


def test_update_realizations_missing_file_errors(tmp_path):
    rc = update_realizations(
        SimpleNamespace(catalog_file=str(tmp_path / "nope.yaml"), realizations="1")
    )
    assert rc == 1
