from pathlib import Path

from runscripts.FDB.count_expected_messages import main


def test_main_clte(capsys):
    profile_file = Path(__file__).parent / "sfc_hourly_healpix_high.yaml"
    argv = [
        "--file",
        str(profile_file),
        "--expver",
        "0001",
        "--experiment",
        "ssp3-7.0",
        "--activity",
        "projections",
        "--model",
        "ifs-nemo",
        "--generation",
        "2",
        "--realization",
        "1",
        "--startdate",
        "20200101",
        "--enddate",
        "20200131",
        "--chunk",
        "1",
    ]
    main(argv)
    captured = capsys.readouterr()
    assert captured.out == "25296\n"


def test_main_clmn(capsys):
    profile_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    argv = [
        "--file",
        str(profile_file),
        "--expver",
        "0001",
        "--experiment",
        "ssp3-7.0",
        "--activity",
        "projections",
        "--model",
        "ifs-nemo",
        "--generation",
        "2",
        "--realization",
        "1",
        "--startdate",
        "20200101",
        "--enddate",
        "20200131",
        "--chunk",
        "1",
    ]
    main(argv)
    captured = capsys.readouterr()
    assert captured.out == "34\n"
