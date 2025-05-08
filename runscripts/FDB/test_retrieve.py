from types import SimpleNamespace


from yaml_to_mars_retrieve import get_month_and_year_to_retrieve, update_request


def test_update_request():
    request = {
        "expver": "default",
        "experiment": "default",
        "model": "default",
        "activity": "default",
        "date": "default",
    }
    args = SimpleNamespace(
        expid="0001",
        experiment="cont",
        activity="baseline",
        model="ifs-nemo",
        startdate="20200101",
        enddate="20200102",
    )
    updated_request = update_request(request, args)
    assert updated_request["expver"] == "0001"
    assert updated_request["experiment"] == "cont"
    assert updated_request["model"] == "ifs-nemo"
    assert updated_request["activity"] == "baseline"
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
    def mockretrieve():
        pass

    pass
