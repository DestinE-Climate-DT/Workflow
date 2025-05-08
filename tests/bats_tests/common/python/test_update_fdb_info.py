from pathlib import Path
import tempfile

from runscripts.FDB.update_fdb_info import (
    load_yaml,
    update_dictionary,
    main,
)


def test_update_dictinoary_empty():
    data = {}
    updates = {"data.expver": "0001", "data.data_start_date": "2020-01-01"}
    hours = {"data.data_start_hour": "0000"}
    data = update_dictionary(data, updates, hours)
    assert data["data"]["expver"] == "0001"
    assert data["data"]["data_start_date"] == "2020-01-01T0000"
    assert set(data["data"]) == {"expver", "data_start_date"}
    assert set(data) == {"data"}


def test_update_dictionary_existing():
    data = {"data": {"data_start_date": "2020-01-01T0000", "expver": "0001"}}
    updates = {
        "data.expver": "0001",
        "data.data_start_date": "2020-01-03",
        "data.data_end_date": "2020-01-05",
    }
    hours = {"data.data_start_hour": "0000", "data.data_end_hour": "2300"}
    data = update_dictionary(data, updates, hours)
    assert data["data"]["expver"] == "0001"
    assert data["data"]["data_start_date"] == "2020-01-03T0000"
    assert data["data"]["data_end_date"] == "2020-01-05T2300"
    assert set(data["data"]) == {"expver", "data_start_date", "data_end_date"}
    assert set(data) == {"data"}


def test_main_create_file():
    tmp_dir = Path(tempfile.mkdtemp())
    argv = [
        "--create",
        "--file",
        str(tmp_dir / "test.yaml"),
        "--data_start_date",
        "2020-01-01",
    ]
    main(argv)
    assert (tmp_dir / "test.yaml").exists()


def test_main_update_file_all_keys():
    tmp_dir = Path(tempfile.mkdtemp())
    with open(str(tmp_dir / "test.yaml"), "w") as file:
        file.write("{}")
    argv = [
        "--file",
        str(tmp_dir / "test.yaml"),
        "--data_start_date",
        "2020-01-01",
        "--data_end_date",
        "2020-12-31",
        "--bridge_start_date",
        "2020-01-01",
        "--bridge_end_date",
        "2020-11-01",
        "--expver",
        "0001",
        "--bridge_expver",
        "0001",
    ]
    main(argv)
    data = load_yaml(str(tmp_dir / "test.yaml"))
    assert data["data"]["data_start_date"] == "2020-01-01T0000"
    assert data["data"]["data_end_date"] == "2020-12-31T2300"
    assert data["bridge"]["bridge_start_date"] == "2020-01-01T0000"
    assert data["bridge"]["bridge_end_date"] == "2020-11-01T2300"
    assert data["data"]["expver"] == "0001"
    assert data["bridge"]["expver"] == "0001"


def test_main_create_expver_data_start_date_from_remote_setup():
    tmp_dir = Path(tempfile.mkdtemp())
    argv = [
        "--create",
        "--file",
        str(tmp_dir / "test.yaml"),
        "--data_start_date",
        "2020-01-01",
        "--expver",
        "0001",
    ]
    main(argv)
    data = load_yaml(str(tmp_dir / "test.yaml"))
    assert data["data"]["data_start_date"] == "2020-01-01T0000"
    assert data["data"]["expver"] == "0001"


def test_main_update_data_end_date_from_dqc():
    tmp_dir = Path(tempfile.mkdtemp())

    # Simulate file created by REMOTE_SETUP with data_start_date and expver
    with open(tmp_dir / "test.yaml", "w") as file:
        file.write("data:\n  data_start_date: '2020-01-01T0000'\n  expver: '0001'\n")

    argv = [
        "--file",
        str(tmp_dir / "test.yaml"),
        "--data_end_date",
        "2020-01-05",
    ]
    main(argv)
    data = load_yaml(str(tmp_dir / "test.yaml"))
    assert data["data"]["data_start_date"] == "2020-01-01T0000"
    assert data["data"]["data_end_date"] == "2020-01-05T2300"
    assert data["data"]["expver"] == "0001"


def test_main_update_bridge_start_and_end_date_from_transfer():
    tmp_dir = Path(tempfile.mkdtemp())
    with open(tmp_dir / "test.yaml", "w") as file:
        file.write(
            "data:\n  data_start_date: '2020-01-01T0000'\n  data_end_date: '2020-01-05T2300'\n  expver: '0001'\n"
        )
    argv = [
        "--file",
        str(tmp_dir / "test.yaml"),
        "--bridge_start_date",
        "2020-01-01",
        "--bridge_end_date",
        "2020-01-03",
        "--bridge_expver",
        "0001",
    ]
    main(argv)
    data = load_yaml(str(tmp_dir / "test.yaml"))
    assert data["data"]["data_start_date"] == "2020-01-01T0000"
    assert data["data"]["data_end_date"] == "2020-01-05T2300"
    assert data["data"]["expver"] == "0001"
    assert data["bridge"]["bridge_start_date"] == "2020-01-01T0000"
    assert data["bridge"]["bridge_end_date"] == "2020-01-03T2300"
    assert data["bridge"]["expver"] == "0001"


def test_main_update_bridge_only_end_date_from_transfer():
    tmp_dir = Path(tempfile.mkdtemp())

    # Simulate file updated by TRANFER with all metadata
    with open(tmp_dir / "test.yaml", "w") as file:
        file.write(
            "data:\n  data_start_date: '2020-01-01T0000'\n  data_end_date: '2020-01-05T2300'\n  expver: '0001'\nbridge:\n  bridge_start_date: '2020-01-01T0000'\n  bridge_end_date: '2020-01-03T2300'\n  expver: '0001'\n"
        )

    argv = [
        "--file",
        str(tmp_dir / "test.yaml"),
        "--bridge_end_date",
        "2020-01-05",
        "--bridge_expver",
        "0001",
    ]
    main(argv)
    data = load_yaml(str(tmp_dir / "test.yaml"))
    assert data["data"]["data_start_date"] == "2020-01-01T0000"
    assert data["data"]["data_end_date"] == "2020-01-05T2300"
    assert data["data"]["expver"] == "0001"
    assert data["bridge"]["bridge_start_date"] == "2020-01-01T0000"
    assert data["bridge"]["bridge_end_date"] == "2020-01-05T2300"
    assert data["bridge"]["expver"] == "0001"


def test_main_update_data_start_date_only_from_wipe():
    tmp_dir = Path(tempfile.mkdtemp())

    # Simulate file updated by TRANFER with all metadata
    with open(tmp_dir / "test.yaml", "w") as file:
        file.write(
            "data:\n  data_start_date: '2020-01-01T0000'\n  data_end_date: '2020-01-05T2300'\n  expver: '0001'\nbridge:\n  bridge_start_date: '2020-01-01T0000'\n  bridge_end_date: '2020-01-05T2300'\n  expver: '0001'\n"
        )

    argv = [
        "--file",
        str(tmp_dir / "test.yaml"),
        "--data_start_date",
        "2020-01-04",
    ]
    main(argv)
    data = load_yaml(str(tmp_dir / "test.yaml"))
    assert data["data"]["data_start_date"] == "2020-01-04T0000"
    assert data["data"]["data_end_date"] == "2020-01-05T2300"
    assert data["data"]["expver"] == "0001"
    assert data["bridge"]["bridge_start_date"] == "2020-01-01T0000"
    assert data["bridge"]["bridge_end_date"] == "2020-01-05T2300"
    assert data["bridge"]["expver"] == "0001"
