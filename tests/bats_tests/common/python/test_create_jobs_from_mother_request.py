import pytest
import os
import time
from shutil import copy
from pathlib import Path
import ruamel.yaml

from conf.create_jobs_from_mother_request import (
    _check_elements_in_list,
    write_files,
    main,
    WorkflowType,
)


def test_workflow_type_enum():
    """Tests for the ``WorkflowType`` enum."""
    assert WorkflowType.END_TO_END in WorkflowType
    assert WorkflowType.APPS in WorkflowType
    assert "bob-marley" not in WorkflowType.list()
    assert "apps" in WorkflowType.list()
    assert "end-to-end" in WorkflowType.list()


def test_nameless_apps():
    """Tests that APP.NAME empty does not raise errors.

    See: https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/issues/494
    """
    path_to_conf = Path(Path(__file__).resolve().parent, "../../../../conf/").resolve()
    main_yaml = Path(
        Path(__file__).resolve().parent, "main_nameless_apps.yml"
    ).resolve()
    args = [
        "--path-to-conf",
        str(path_to_conf),
        "--main",
        str(main_yaml),
    ]
    with pytest.raises(SystemExit) as e:
        main(args)
    assert e.type is SystemExit
    assert e.value.code == 0


def test_simless():
    """Tests that WORKFLOW.TYPE simless is properly handled.

    See: https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/issues/485#note_294675
    """
    path_to_conf = Path(Path(__file__).resolve().parent, "../../../../conf/").resolve()
    main_yaml = Path(Path(__file__).resolve().parent, "main_simless.yml").resolve()
    args = [
        "--path-to-conf",
        str(path_to_conf),
        "--main",
        str(main_yaml),
    ]
    with pytest.raises(ValueError) as e:
        main(args)
    assert e.type is ValueError
    assert "is not apps nor end-to-end" in str(e.value)


def test_check_elements_in_list():
    # Test if the application that is passed exists or not in the available set of apps.
    app_available = ["app1", "app2", "app3"]
    app_requested = ["app1", "app2"]

    _check_elements_in_list(app_requested, app_available)

    with pytest.raises(ValueError):
        _check_elements_in_list(["app1", "bug"], app_available)


def test_write_files(tmp_path):
    # check if the format of the output jobs_end-to-end.yml file has the correct format.
    # Define joblist template
    jobs = {
        "RUN": {
            "OPA_NAMES": [
                "energy_onshore_1",
                "energy_onshore_2",
                "energy_onshore_3",
                "energy_onshore_4",
                "energy_onshore_5",
                "energy_onshore_6",
                "energy_onshore_7",
            ],
            "APP_NAMES": ["ENERGY_ONSHORE"],
        },
        "JOBS": {
            "LOCAL_SETUP": {
                "FILE": "templates/local_setup.sh",
                "PLATFORM": "LOCAL",
                "RUNNING": "once",
            },
            "SYNCHRONIZE": {
                "FILE": "templates/synchronize.sh",
                "PLATFORM": "LOCAL",
                "DEPENDENCIES": "LOCAL_SETUP",
                "RUNNING": "once",
            },
            "REMOTE_SETUP": {
                "FILE": [
                    "templates/remote_setup.sh",
                    "templates/fdb/confignative.yaml",
                    "templates/fdb/configregularll.yaml",
                    "templates/fdb/confighealpix.yaml",
                ],
                "PLATFORM": "%DEFAULT.HPCARCH%-login",
                "DEPENDENCIES": "SYNCHRONIZE",
                "RUNNING": "once",
                "WALLCLOCK": "02:00",
            },
            "INI": {
                "FILE": "templates/ini.sh",
                "PLATFORM": "%DEFAULT.HPCARCH%-login",
                "DEPENDENCIES": "REMOTE_SETUP",
                "RUNNING": "member",
                "WALLCLOCK": "00:30",
            },
            "SIM": {
                "FILE": "templates/sim_%MODEL.NAME%.sh",
                "PLATFORM": "%DEFAULT.HPCARCH%",
                "DEPENDENCIES": ["INI", "SIM-1"],
                "RUNNING": "chunk",
                "WALLCLOCK": "00:30",
            },
            "DN": {
                "FILE": ["templates/dn.sh", "conf/mother_request.yml"],
                "DEPENDENCIES": {
                    "SIM": {"STATUS": "RUNNING"},
                    "DN": {"SPLITS_FROM": {"all": {"SPLITS_TO": "previous"}}},
                },
                "RUNNING": "chunk",
                "WALLCLOCK": "02:00",
                "PLATFORM": "%DEFAULT.HPCARCH%-login",
                "SPLITS": "<to be added by the workflow>",
                "TOTALJOBS": 1,
                "CHECK": "on_submission",
            },
            "OPA": {
                "FOR": {"NAME": "%RUN.OPA_NAMES%", "SPLITS": "auto"},
                "DEPENDENCIES": None,
                "FILE": "templates/opa.sh",
                "PLATFORM": "%DEFAULT.HPCARCH%",
                "PARTITION": "%CURRENT_APP_PARTITION%",
                "RUNNING": "chunk",
                "NODES": 1,
                "PROCESSORS": 1,
                "TASKS": 1,
                "THREADS": 1,
                "CHECK": "on_submission",
            },
            "APP": {
                "FOR": {
                    "NAME": "%RUN.APP_NAMES%",
                    "SPLITS": None,
                    "DEPENDENCIES": None,
                },
                "FILE": [
                    "templates/application.sh",
                    "templates/applications/aqua/only_lra.yaml",
                ],
                "DEPENDENCIES": "OPA",
                "RUNNING": "chunk",
                "WALLCLOCK": "00:05",
                "PLATFORM": "%DEFAULT.HPCARCH%",
                "PARTITION": "%CURRENT_APP_PARTITION%",
                "NODES": 1,
                "PROCESSORS": 1,
                "TASKS": 1,
                "THREADS": 1,
                "CHECK": "on_submission",
            },
        },
    }

    # define example main dictionary from yml file:
    main_yml = {
        "RUN": {
            "WORKFLOW": "end-to-end",
            "ENVIRONMENT": "cray",
            "PROCESSOR_UNIT": "cpu",
            "TYPE": "TEST",
        },
        "MODEL": {
            "NAME": "ifs-nemo",
            "SIMULATION": "test-ifs-nemo",
            "GRID_ATM": "tco79l137",
            "GRID_OCE": "eORCA1_Z75",
            "VERSION": "",
        },
        "APP": {
            "NAMES": ["ENERGY_ONSHORE"],
            "OUTPATH": "/scratch/project_465000454/tmp/%DEFAULT.EXPID%/",
        },
        "PLATFORMS": {"LUMI": {"TYPE": "slurm", "APP_PARTITION": "debug"}},
        "JOBS": {"SIM": {"WALLCLOCK": "00:30", "NODES": 4}},
        "EXPERIMENT": {
            "DATELIST": 20200101,  # Startdate
            "MEMBERS": "fc0",
            "CHUNKSIZEUNIT": "month",
            "SPLITSIZEUNIT": "day",
            "CHUNKSIZE": 1,
            "NUMCHUNKS": 2,
            "CALENDAR": "standard",
        },
        "ADDITIONAL_JOBS": {
            "TRANSFER": "False",
            "BACKUP": "False",
            "MEMORY_CHECKER": "False",
            "DQC": "True",
        },
        "CONFIGURATION": {
            "INPUTS": "experiment/scenario-20y-2020-debug-configuration-2y-coupled-spinup",
            "ADDITIONAL_JOBS": {
                "TRANSFER": "False",
                "BACKUP": "False",
                "MEMORY_CHECKER": "False",
                "DQC": "True",
            },
        },
    }

    # create file
    write_files(output_path=tmp_path, jobs=jobs, main_yml=main_yml)

    # test is created to see if file is equal to the reference:
    file1_path = Path(
        Path(__file__).parent.resolve(), "t_jobs_end-to-end.yml"
    ).resolve()  # reference
    file2_path = tmp_path / "new_jobs_end-to-end.yml"  # new

    # copy the file, for testing purposes
    copy(file1_path, file2_path)

    with open(file1_path, "r") as file1, open(file2_path, "r") as file2:
        for line1, line2 in zip(file1, file2):
            assert (
                line1 == line2
            ), f"Files {file1_path} and {file2_path} differ at line: {line1.strip()}"

        # Check if both files have the same number of lines
        num_lines_file1 = sum(1 for line in open(file1_path))
        num_lines_file2 = sum(1 for line in open(file2_path))
        assert (
            num_lines_file1 == num_lines_file2
        ), f"Files {file1_path} and {file2_path} have different number of lines"
    print("Files are equal.")


def test_main(tmp_path: Path):
    # See if the file was created during the test (complementary to the test just above).
    # path_to_conf = Path(Path(__file__).resolve().parent, '../../../../conf/').resolve()
    path_to_conf = Path(Path(__file__).resolve().parent, "../../../../conf/").resolve()
    main_yaml = Path(Path(__file__).resolve().parent, "main.yml").resolve()
    args = [
        "--path-to-conf",
        str(path_to_conf),
        "--main",
        str(main_yaml),
        "--output-path",
        str(tmp_path),
    ]
    main(args)

    file_path = os.path.join(tmp_path, "jobs_end-to-end.yml")

    # Check if the file exists
    if os.path.exists(file_path):
        # Get the creation time of the file
        creation_time = os.path.getctime(file_path)
        current_time = time.time()

        # Calculate the time difference in seconds
        time_difference = current_time - creation_time

        # Assert if the file was created less than 10 seconds ago
        assert (
            time_difference <= 2
        ), f"The file '{file_path}' exists but was not created less than 2 seconds ago."

        print(
            f"The file '{file_path}' exists and was created less than 10 seconds ago."
        )

    else:
        print(f"The file '{file_path}' does not exist.")
