from pathlib import Path
import tempfile

import yaml

from runscripts.FDB.preprocess_requests import main

MARS_KEYS = [
    "class",
    "dataset",
    "experiment",
    "activity",
    "model",
    "realization",
    "generation",
    "type",
    "resolution",
    "stream",
    "expver",
    "param",
    "date",
]


def test_reading_file():
    root = Path(__file__).parents[4]
    example_request = (
        root / "conf" / "applications" / "request" / "request_ENERGY_INDICATORS.yml"
    )
    output_dir = Path(tempfile.mkdtemp())
    jobname = "TEST"
    main(
        argv=[
            "--file",
            str(example_request),
            "--output-dir",
            str(output_dir),
            "--omit-keys",
            "grid,method,area",
            "--jobname",
            jobname,
        ]
    )

    for file in output_dir.iterdir():
        assert file.suffix == ".yaml"
        with open(file, "r") as f:
            profile = yaml.safe_load(f)
            assert profile is not None

        assert "date-format" in profile
        assert "mars-keys" in profile

        for key in MARS_KEYS:
            assert (
                key in profile["mars-keys"]
            ), f"Key {key} not found in mars-keys of {file.name}"

        if profile["mars-keys"]["stream"] == "clte":
            assert (
                profile["date-format"] == "date"
            ), f"Expected date-format 'date' for stream 'clte' in {file.name}"
        else:
            assert (
                profile["date-format"] == "month"
            ), f"Expected date-format 'month' for stream '{profile['mars-keys']['stream']}' in {file.name}"

        for key in {"grid", "method", "area"}:
            assert (
                key not in profile["mars-keys"]
            ), f"Key {key} should be omitted from mars-keys in {file.name}"


def test_preprocess_request_derived_variables():
    example_request = Path(__file__).parent / "example_request_ENERGY_INDICATORS.yml"
    output_dir = Path(tempfile.mkdtemp())
    jobname = "TEST"
    main(
        argv=[
            "--file",
            str(example_request),
            "--output-dir",
            str(output_dir),
            "--omit-keys",
            "grid,method,area",
            "--jobname",
            jobname,
            "--process-derived-variables",
        ]
    )

    expected_variables = ["u", "v", "10si", "avg_sdswrf", "ws", "2t"]
    # Map from shortname to paramId, with derived variables already substituted.
    expected_params = {
        "u": [
            "131"
        ],  # GSV processed request always returns param as a list of strings.
        "v": ["132"],
        "10si": ["207"],
        "ws": ["131", "132"],
        "2t": ["167"],
        "avg_sdswrf": ["235035"],
    }

    file_list = {path.name for path in output_dir.iterdir()}
    expected_files = {f"{var}_{jobname}.yaml" for var in expected_variables}

    assert file_list == expected_files

    for file in output_dir.iterdir():
        assert file.suffix == ".yaml"
        with open(file, "r") as f:
            profile = yaml.safe_load(f)
            assert profile is not None

        # Assert presence of expected request keys
        assert "date-format" in profile
        assert "mars-keys" in profile

        for key in MARS_KEYS:
            assert (
                key in profile["mars-keys"]
            ), f"Key {key} not found in mars-keys of {file.name}"

        if profile["mars-keys"]["stream"] == "clte":
            assert (
                profile["date-format"] == "date"
            ), f"Expected date-format 'date' for stream 'clte' in {file.name}"
        else:
            assert (
                profile["date-format"] == "month"
            ), f"Expected date-format 'month' for stream '{profile['mars-keys']['stream']}' in {file.name}"

        # Assert absence of omitted keys.
        for key in {"grid", "method", "area"}:
            assert (
                key not in profile["mars-keys"]
            ), f"Key {key} should be omitted from mars-keys in {file.name}"

        # Check a file per variable was generated
        variable = file.name.removesuffix(
            f"_{jobname}.yaml"
        )  # Only valid for Python 3.9+
        assert variable in expected_params

        # Set in both sides to avoid issues with list ordering
        assert set(profile["mars-keys"]["param"]) == set(expected_params[variable])
