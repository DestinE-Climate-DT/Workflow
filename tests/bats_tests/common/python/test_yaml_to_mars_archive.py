from pathlib import Path
import tempfile
from types import SimpleNamespace

from runscripts.FDB.yaml_to_mars_archive import (
    update_request,
    get_month_and_year_to_archive,
    write_archiving_mars_request,
    main,
)


def test_update_request():
    request = {
        "expver": "default",
        "experiment": "default",
        "model": "default",
        "activity": "default",
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
        enddate="20200102",
        grib_file_name="test.grib",
        generation="2",
        databridge_database="databridge"
    )
    updated_request = update_request(request, args)
    assert updated_request["expver"] == "0001"
    assert updated_request["experiment"] == "cont"
    assert updated_request["model"] == "ifs-nemo"
    assert updated_request["activity"] == "baseline"
    assert updated_request["generation"] == "2"
    assert updated_request["date"] == "20200101/to/20200102"
    assert updated_request["database"] == "databridge"
    assert updated_request["source"] == "test.grib"


def test_get_one_month():
    dates = [20200101, 20200102, 20200103]
    month, year = get_month_and_year_to_archive(dates)
    assert month == ["1"]
    assert year == ["2020"]


def test_get_no_month():
    dates = ["20200104", "20200105", "20200106"]
    month, year = get_month_and_year_to_archive(dates)
    assert not month
    assert not year


def test_get_two_months():
    dates = [f"202001{day:02d}" for day in range(1, 32)]
    dates.extend(["20200201", "20200202"])
    month, year = get_month_and_year_to_archive(dates)
    assert month == ["1", "2"]
    assert year == ["2020"]


def test_write_archiving_mars_request():
    request = {
        "class": "d1",
        "date": ["20200101", "20200102"],
        "database": "databridge-fdb",
        "source": "dummy.grib",
    }
    mars_file = tempfile.NamedTemporaryFile()
    write_archiving_mars_request(request, mars_file.name)

    # Check content of MARS request
    with open(mars_file.name, "r") as f:
        lines = f.readlines()
    assert lines[0] == "archive,\n"
    assert lines[1] == "\tclass=d1,\n"
    assert lines[2] == "\tdate=20200101/20200102,\n"
    assert lines[3] == "\tdatabase=databridge-fdb,\n"
    assert lines[4] == "\tsource=dummy.grib\n"


def test_main_update_clte():
    tmp_dir = Path(tempfile.mkdtemp())
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
        "--generation",
        "2",
        "--model",
        "ifs-nemo",
        "--startdate",
        "20200101",
        "--enddate",
        "20200131",
        "--grib_file_name",
        str(tmp_dir / "test.grb"),
        "--databridge_database",
        "databridge-fdb",
    ]
    main(argv)

    mars_request_filename = str(tmp_dir / "test.mars")

    with open(mars_request_filename, "r") as f:
        lines = f.readlines()

    # Check content of MARS request
    assert lines[0] == "archive,\n"
    assert lines[1] == "\tclass=d1,\n"
    assert lines[2] == "\tdataset=climate-dt,\n"
    assert lines[3] == "\texperiment=cont,\n"
    assert lines[4] == "\tactivity=baseline,\n"
    assert lines[5] == "\tgeneration=2,\n"
    assert lines[6] == "\tmodel=ifs-nemo,\n"
    assert lines[7] == "\trealization=1,\n"
    assert lines[8] == "\texpver=0001,\n"
    assert lines[9] == "\tstream=clte,\n"
    assert (
        lines[10] == f"\tdate={('/').join([f'202001{i:02}' for i in range(1, 32)])},\n"
    )
    assert lines[11] == "\tresolution=high,\n"
    assert lines[12] == "\ttype=fc,\n"
    assert lines[13] == "\tlevtype=sfc,\n"
    assert lines[14] == f"\ttime={('/').join([f'{i:02}00' for i in range(24)])},\n"
    assert (
        lines[15]
        == f"\tparam=8/9/78/79/134/137/141/144/146/147/148/151/159/164/165/166/167/168/169/175/176/177/178/179/180/181/182/186/187/188/212/228/235/260048,\n"
    )
    assert lines[16] == "\tdatabase=databridge-fdb,\n"
    assert lines[17] == f"\tsource={tmp_dir / 'test.grb'}\n"


def test_main_update_clmn_first_date_included():
    tmp_dir = Path(tempfile.mkdtemp())
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
        "--generation",
        "2",
        "--model",
        "ifs-nemo",
        "--startdate",
        "20200101",
        "--enddate",
        "20200131",
        "--grib_file_name",
        str(tmp_dir / "test.grb"),
        "--databridge_database",
        "databridge-fdb",
    ]
    main(argv)

    mars_request_filename = str(tmp_dir / "test.mars")

    with open(mars_request_filename, "r") as f:
        lines = f.readlines()

    # Check content of MARS request
    assert lines[0] == "archive,\n"
    assert lines[1] == "\tclass=d1,\n"
    assert lines[2] == "\tdataset=climate-dt,\n"
    assert lines[3] == "\texperiment=cont,\n"
    assert lines[4] == "\tactivity=baseline,\n"
    assert lines[5] == "\tgeneration=2,\n"
    assert lines[6] == "\tmodel=ifs-nemo,\n"
    assert lines[7] == "\trealization=1,\n"
    assert lines[8] == "\texpver=0001,\n"
    assert lines[9] == "\tstream=clmn,\n"
    assert lines[10] == "\tresolution=high,\n"
    assert lines[11] == "\ttype=fc,\n"
    assert lines[12] == "\tlevtype=sfc,\n"
    assert (
        lines[13]
        == f"\tparam=8/9/78/79/134/137/141/144/146/147/148/151/159/164/165/166/167/168/169/175/176/177/178/179/180/181/182/186/187/188/212/228/235/260048,\n"
    )
    assert lines[14] == "\tdatabase=databridge-fdb,\n"
    assert lines[15] == f"\tsource={tmp_dir / 'test.grb'},\n"
    assert lines[16] == "\tmonth=1,\n"
    assert lines[17] == "\tyear=2020\n"


def test_main_update_clmn_first_date_included_two_months():
    tmp_dir = Path(tempfile.mkdtemp())
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
        "--generation",
        "2",
        "--model",
        "ifs-nemo",
        "--startdate",
        "20200131",
        "--enddate",
        "20200301",
        "--grib_file_name",
        str(tmp_dir / "test.grb"),
        "--databridge_database",
        "databridge-fdb",
    ]
    main(argv)

    mars_request_filename = str(tmp_dir / "test.mars")

    with open(mars_request_filename, "r") as f:
        lines = f.readlines()

    # Check content of MARS request
    assert lines[0] == "archive,\n"
    assert lines[1] == "\tclass=d1,\n"
    assert lines[2] == "\tdataset=climate-dt,\n"
    assert lines[3] == "\texperiment=cont,\n"
    assert lines[4] == "\tactivity=baseline,\n"
    assert lines[5] == "\tgeneration=2,\n"
    assert lines[6] == "\tmodel=ifs-nemo,\n"
    assert lines[7] == "\trealization=1,\n"
    assert lines[8] == "\texpver=0001,\n"
    assert lines[9] == "\tstream=clmn,\n"
    assert lines[10] == "\tresolution=high,\n"
    assert lines[11] == "\ttype=fc,\n"
    assert lines[12] == "\tlevtype=sfc,\n"
    assert (
        lines[13]
        == f"\tparam=8/9/78/79/134/137/141/144/146/147/148/151/159/164/165/166/167/168/169/175/176/177/178/179/180/181/182/186/187/188/212/228/235/260048,\n"
    )
    assert lines[14] == "\tdatabase=databridge-fdb,\n"
    assert lines[15] == f"\tsource={tmp_dir / 'test.grb'},\n"
    assert lines[16] == "\tmonth=2/3,\n"
    assert lines[17] == "\tyear=2020\n"


def test_main_update_clmn_first_date_excluded():
    tmp_dir = Path(tempfile.mkdtemp())
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
        "--generation",
        "2",
        "--startdate",
        "20200102",
        "--enddate",
        "20200103",
        "--grib_file_name",
        str(tmp_dir / "test.grb"),
        "--databridge_database",
        "databridge-fdb",
    ]
    main(argv)

    mars_request_filename = tmp_dir / "test.mars"

    assert not mars_request_filename.exists()


def test_main_update_realization():
    tmp_dir = Path(tempfile.mkdtemp())
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
        str(tmp_dir / "test.grb"),
        "--databridge_database",
        "databridge-fdb",
    ]
    main(argv)

    mars_request_filename = str(tmp_dir / "test.mars")

    with open(mars_request_filename, "r") as f:
        lines = f.readlines()

    # Check content of MARS request
    assert lines[0] == "archive,\n"
    assert lines[1] == "\tclass=d1,\n"
    assert lines[2] == "\tdataset=climate-dt,\n"
    assert lines[3] == "\texperiment=cont,\n"
    assert lines[4] == "\tactivity=baseline,\n"
    assert lines[5] == "\tgeneration=2,\n"
    assert lines[6] == "\tmodel=ifs-nemo,\n"
    assert lines[7] == "\trealization=2,\n"
    assert lines[8] == "\texpver=0001,\n"
    assert lines[9] == "\tstream=clte,\n"
    assert (
        lines[10] == f"\tdate={('/').join([f'202001{i:02}' for i in range(1, 32)])},\n"
    )
    assert lines[11] == "\tresolution=high,\n"
    assert lines[12] == "\ttype=fc,\n"
    assert lines[13] == "\tlevtype=sfc,\n"
    assert lines[14] == f"\ttime={('/').join([f'{i:02}00' for i in range(24)])},\n"
    assert (
        lines[15]
        == f"\tparam=8/9/78/79/134/137/141/144/146/147/148/151/159/164/165/166/167/168/169/175/176/177/178/179/180/181/182/186/187/188/212/228/235/260048,\n"
    )
    assert lines[16] == "\tdatabase=databridge-fdb,\n"
    assert lines[17] == f"\tsource={tmp_dir / 'test.grb'}\n"
