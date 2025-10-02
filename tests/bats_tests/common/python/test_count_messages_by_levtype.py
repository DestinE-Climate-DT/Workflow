from pathlib import Path
import typing as T

import pytest

from runscripts.FDB.count_messages_by_levtype import (
    main,
    count_messages_in_file,
    get_levtype,
    get_frequency,
    group_by_levtype
)


class Namepsace:
    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)


def test_count_messages_in_file_clte():
    test_file = Path(__file__).parent / "sfc_hourly_healpix_high.yaml"
    args = Namepsace(
        expver="0001",
        experiment="hist",
        activity="baseline",
        model="ifs-nemo",
        generation="2",
        realization="1",
        startdate="19900101",
        enddate="19900131",        
    )
    assert count_messages_in_file(str(test_file), args) == 25296  # 34 vars * 744 timesteps


def test_count_messages_in_file_clmn():
    test_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    args = Namepsace(
        expver="0001",
        experiment="hist",
        activity="baseline",
        model="ifs-nemo",
        generation="2",
        realization="1",
        startdate="19900101",
        enddate="19900131",        
    )
    assert count_messages_in_file(str(test_file), args) == 34


def test_count_messages_in_file_clmn_submonthly():
    test_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    args = Namepsace(
        expver="0001",
        experiment="hist",
        activity="baseline",
        model="ifs-nemo",
        generation="2",
        realization="1",
        startdate="19900102",
        enddate="19900131",        
    )
    with pytest.raises(ValueError):  # TODO, does this makes sense?
        count_messages_in_file(str(test_file), args) == 34


def test_get_levtype():
    profiles = ["sfc_hourly_healpix_high.yaml", "pl_6-hourly_healpix_standard.yaml", "o3d_2_daiy_healpix_high.yaml", "hl_monthly_healpix_standard.yaml"]
    results = ["sfc", "pl", "o3d", "hl"]
    for profile, result in zip(profiles, results):
        assert get_levtype(profile) == result


def test_get_frequency():
    profiles = ["sfc_hourly_healpix_high.yaml", "pl_6-hourly_healpix_standard.yaml", "o3d_2_daily_healpix_high.yaml", "hl_monthly_healpix_standard.yaml"]
    results = ["hourly", "6-hourly", "daily", "monthly"]
    for profile, result in zip(profiles, results):
        assert get_frequency(profile) == result


def test_is_monthly():
    profiles = ["sfc_hourly_healpix_high.yaml", "pl_6-hourly_healpix_standard.yaml", "o3d_2_daily_healpix_high.yaml", "hl_monthly_healpix_standard.yaml"]
    results = [False, False, False, True]
    for profile, result in zip(profiles, results):
        assert (get_frequency(profile) == "monthly") == result


def group_by_levtype_full():
    profiles = [
        "sfc_hourly_healpix_high.yaml",
        "sfc_hourly_healpix_standard.yaml",
        "sfc_daily_healpix_high.yaml",
        "sfc_daily_healpix_standard.yaml",
        "sfc_monthly_healpix_high.yaml",
        "sfc_monthly_healpix_standard.yaml",
        "pl_hourly_healpix_high.yaml",
        "pl_hourly_healpix_standard.yaml",
        "pl_monthly_healpix_standard.yaml",
        "o2d_daily_healpix_high.yaml",
        "o2d_daily_healpix_standard.yaml",
        "o2d_monthly_healpix_high.yaml",
        "o2d_monthly_healpix_standard.yaml",
        "o3d_daily_healpix_high.yaml",
        "o3d_daily_healpix_standard.yaml",
        "o3d_2_daily_healpix_high.yaml",
        "o3d_2_daily_healpix_standard.yaml",
        "o3d_monthly_healpix_high.yaml",
        "o3d_monthly_healpix_standard.yaml",
        "o3d_2_monthly_healpix_standard.yaml",
        "o3d_3_monthly_healpix_standard.yaml",
        "hl_hourly_healpix_high.yaml"
        "hl_hourly_healpix_standard.yaml",
        "hl_monthly_healpix_standard.yaml",
        "sol_hourly_healpix_high.yaml",
        "sol_hourly_healpix_standard.yaml",
        "sol_2_hourly_healpix_high.yaml",
        "sol_2_hourly_healpix_standard.yaml",
        "sol_monthly_healpix_high.yaml",
        "sol_monthly_healpix_standard.yaml",
        "sol_2_monthly_healpix_high.yaml",
        "sol_2_monthly_healpix_standard.yaml",
    ]
    profiles_by_levtype = group_by_levtype(profiles)
    assert set(profiles_by_levtype.keys()) == set(["sfc", "pl", "o2d", "o3d", "hl", "sol"])
    assert len(profiles_by_levtype["sfc"]) == 6
    assert len(profiles_by_levtype["pl"]) == 3
    assert len(profiles_by_levtype["o2d"]) == 4
    assert len(profiles_by_levtype["o3d"]) == 8
    assert len(profiles_by_levtype["hl"]) == 3
    assert len(profiles_by_levtype["sol"]) == 8
