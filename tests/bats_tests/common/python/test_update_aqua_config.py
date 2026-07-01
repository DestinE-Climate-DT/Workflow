from types import SimpleNamespace

import yaml

from runscripts.aqua.update_aqua_config import update_grids, update_paths


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
