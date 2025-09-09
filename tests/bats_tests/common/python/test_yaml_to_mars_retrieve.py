from io import BytesIO, StringIO
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace

import pyfdb
import yaml

from runscripts.FDB.yaml_to_mars_retrieve import (
    get_month_and_year_to_retrieve,
    update_request,
    retrieve_request,
    main,
)


# Monkeypatch pyfdb retrieve function to do nothing
def mockretrieve(request):
    print("Executing monkey pached retrieve")
    print(f"Retrieving request: {request}")
    return BytesIO(json.dumps(request).encode())


fdb = SimpleNamespace(retrieve=mockretrieve)


def mockfdb():
    return fdb


pyfdb.FDB = mockfdb


def test_update_request():
    request = {
        "expver": "default",
        "experiment": "default",
        "model": "default",
        "activity": "default",
        "realization": "default",
        "date": "default",
        "generation": "default",
    }
    args = SimpleNamespace(
        expid="0001",
        experiment="cont",
        activity="baseline",
        model="ifs-nemo",
        realization="1",
        startdate="20200101",
        generation="2",
        enddate="20200102",
    )
    updated_request = update_request(request, args)
    assert updated_request["expver"] == "0001"
    assert updated_request["experiment"] == "cont"
    assert updated_request["model"] == "ifs-nemo"
    assert updated_request["activity"] == "baseline"
    assert updated_request["realization"] == "1"
    assert updated_request["generation"] == "2"
    assert updated_request["date"] == "20200101/to/20200102"


def test_get_one_month():
    dates = [20200101, 20200102, 20200103]
    month, year = get_month_and_year_to_retrieve(dates)
    assert month == ["1"]
    assert year == ["2020"]


def test_get_no_month():
    dates = ["20200104", "20200105", "20200106"]
    month, year = get_month_and_year_to_retrieve(dates)
    assert not month
    assert not year


def test_get_two_months():
    dates = [f"202001{day:02d}" for day in range(1, 32)]
    dates.extend(["20200201", "20200202"])
    month, year = get_month_and_year_to_retrieve(dates)
    assert month == ["1", "2"]
    assert year == ["2020"]


def test_pyfdb_dummy():
    grib_file = tempfile.NamedTemporaryFile()
    retrieve_request({"class": "d1"}, grib_file.name)

    with open(grib_file.name, "rb") as f:
        data = json.load(f)

    assert data["class"] == "d1"


def test_main_update_clte():
    grib_file = tempfile.NamedTemporaryFile()
    profile_file = Path(__file__).parent / "sfc_hourly_healpix_high.yaml"
    argv = [
        "--file",
        str(profile_file),
        "--expid",
        "0001",
        "--experiment",
        "cont",
        "--activity",
        "baseline",
        "--model",
        "ifs-nemo",
        "--realization",
        "1",
        "--generation",
        "2",
        "--startdate",
        "20200101",
        "--enddate",
        "20200131",
        "--grib_file_name",
        grib_file.name,
    ]
    main(argv)

    with open(grib_file.name, "rb") as f:
        requested = json.load(f)

    with open(profile_file, "r") as f:
        profile = yaml.safe_load(f)

    original = profile["mars-keys"]

    assert requested["class"] == original["class"]
    assert requested["dataset"] == original["dataset"]
    assert requested["stream"] == original["stream"]
    assert requested["resolution"] == original["resolution"]
    assert requested["type"] == original["type"]
    # Not comparing times directly because requested are explicit
    # and origina implicit
    assert requested["time"] == [f"{i:02d}00" for i in range(24)]
    assert requested["levtype"] == original["levtype"]
    assert [str(param) for param in requested["param"]] == [
        str(param) for param in original["param"]
    ]
    assert requested["experiment"] == "cont"
    assert requested["activity"] == "baseline"
    assert requested["generation"] == "2"
    assert requested["model"] == "ifs-nemo"
    assert requested["expver"] == "0001"
    assert requested["realization"] == "1"
    assert requested["date"] == [f"202001{i:02d}" for i in range(1, 32)]
    assert "month" not in requested
    assert "year" not in requested


def test_main_update_clmn_first_date_included():
    grib_file = tempfile.NamedTemporaryFile()
    profile_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    argv = [
        "--file",
        str(profile_file),
        "--expid",
        "0001",
        "--experiment",
        "cont",
        "--activity",
        "baseline",
        "--model",
        "ifs-nemo",
        "--realization",
        "1",
        "--startdate",
        "20200101",
        "--enddate",
        "20200131",
        "--generation",
        "2",
        "--grib_file_name",
        grib_file.name,
    ]
    main(argv)

    with open(grib_file.name, "rb") as f:
        requested = json.load(f)

    with open(profile_file, "r") as f:
        profile = yaml.safe_load(f)

    original = profile["mars-keys"]

    assert requested["class"] == original["class"]
    assert requested["dataset"] == original["dataset"]
    assert requested["stream"] == original["stream"]
    assert requested["resolution"] == original["resolution"]
    assert requested["type"] == original["type"]
    assert requested["levtype"] == original["levtype"]
    assert [str(param) for param in requested["param"]] == [
        str(param) for param in original["param"]
    ]
    assert requested["experiment"] == "cont"
    assert requested["activity"] == "baseline"
    assert requested["model"] == "ifs-nemo"
    assert requested["expver"] == "0001"
    assert requested["realization"] == "1"
    assert requested["month"] == ["1"]
    assert requested["year"] == ["2020"]
    assert "date" not in requested
    assert "time" not in requested


def test_main_update_clmn_first_date_included_two_months():
    grib_file = tempfile.NamedTemporaryFile()
    profile_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    argv = [
        "--file",
        str(profile_file),
        "--expid",
        "0001",
        "--experiment",
        "cont",
        "--activity",
        "baseline",
        "--model",
        "ifs-nemo",
        "--realization",
        "1",
        "--generation",
        "2",
        "--startdate",
        "20200131",
        "--enddate",
        "20200301",
        "--grib_file_name",
        grib_file.name,
    ]
    main(argv)

    with open(grib_file.name, "rb") as f:
        requested = json.load(f)

    with open(profile_file, "r") as f:
        profile = yaml.safe_load(f)

    original = profile["mars-keys"]

    assert requested["class"] == original["class"]
    assert requested["dataset"] == original["dataset"]
    assert requested["stream"] == original["stream"]
    assert requested["resolution"] == original["resolution"]
    assert requested["type"] == original["type"]
    assert requested["levtype"] == original["levtype"]
    assert [str(param) for param in requested["param"]] == [
        str(param) for param in original["param"]
    ]
    assert requested["experiment"] == "cont"
    assert requested["activity"] == "baseline"
    assert requested["generation"] == "2"
    assert requested["model"] == "ifs-nemo"
    assert requested["realization"] == "1"
    assert requested["expver"] == "0001"
    assert requested["month"] == ["2", "3"]
    assert requested["year"] == ["2020"]
    assert "date" not in requested
    assert "time" not in requested


def test_main_update_clmn_first_date_excluded():
    grib_file = tempfile.NamedTemporaryFile()
    profile_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    argv = [
        "--file",
        str(profile_file),
        "--expid",
        "0001",
        "--experiment",
        "cont",
        "--activity",
        "baseline",
        "--model",
        "ifs-nemo",
        "--realization",
        "1",
        "--generation",
        "2",
        "--startdate",
        "20200102",
        "--enddate",
        "20200131",
        "--grib_file_name",
        grib_file.name,
    ]
    main(argv)

    # Check that the created tempfile is empty, so no retrieve_data
    # has been called on it.
    assert Path(grib_file.name).stat().st_size == 0


def test_main_update_realization():
    grib_file = tempfile.NamedTemporaryFile()
    profile_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    argv = [
        "--file",
        str(profile_file),
        "--expid",
        "0001",
        "--experiment",
        "cont",
        "--activity",
        "baseline",
        "--model",
        "ifs-nemo",
        "--realization",
        "1",
        "--generation",
        "2",
        "--startdate",
        "20200102",
        "--enddate",
        "20200131",
        "--grib_file_name",
        grib_file.name,
    ]
    main(argv)

    # Check that the created tempfile is empty, so no retrieve_data
    # has been called on it.
    assert Path(grib_file.name).stat().st_size == 0


def test_main_update_realization():
    grib_file = tempfile.NamedTemporaryFile()
    profile_file = Path(__file__).parent / "sfc_hourly_healpix_high.yaml"
    argv = [
        "--file",
        str(profile_file),
        "--expid",
        "0001",
        "--experiment",
        "cont",
        "--activity",
        "baseline",
        "--model",
        "ifs-nemo",
        "--realization",
        "2",
        "--generation",
        "2",
        "--startdate",
        "20200101",
        "--enddate",
        "20200131",
        "--grib_file_name",
        grib_file.name,
    ]
    main(argv)

    with open(grib_file.name, "rb") as f:
        requested = json.load(f)

    with open(profile_file, "r") as f:
        profile = yaml.safe_load(f)

    original = profile["mars-keys"]

    assert requested["class"] == original["class"]
    assert requested["dataset"] == original["dataset"]
    assert requested["stream"] == original["stream"]
    assert requested["resolution"] == original["resolution"]
    assert requested["type"] == original["type"]
    # Not comparing times directly because requested are explicit
    # and origina implicit
    assert requested["time"] == [f"{i:02d}00" for i in range(24)]
    assert requested["levtype"] == original["levtype"]
    assert [str(param) for param in requested["param"]] == [
        str(param) for param in original["param"]
    ]
    assert requested["experiment"] == "cont"
    assert requested["activity"] == "baseline"
    assert requested["model"] == "ifs-nemo"
    assert requested["expver"] == "0001"
    assert requested["realization"] == "2"
    assert requested["generation"] == "2"
    assert requested["date"] == [f"202001{i:02d}" for i in range(1, 32)]
    assert "month" not in requested
    assert "year" not in requested
