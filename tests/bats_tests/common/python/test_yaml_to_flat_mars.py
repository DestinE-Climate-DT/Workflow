from pathlib import Path
import tempfile

from runscripts.FDB.yaml_to_flat_request import main


def test_main_clte_profile():
    tmp_dir = Path(tempfile.mkdtemp())
    profile_file = Path(__file__).parent / "sfc_hourly_healpix_high.yaml"
    flat_request_filename = str(tmp_dir / "test_request.flat")
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
        "--request_name",
        flat_request_filename,
    ]
    main(argv)

    with open(flat_request_filename, "r") as f:
        flat_request_content = f.read()

    print(flat_request_content)
    assert flat_request_content == "class=d1,dataset=climate-dt,experiment=ssp3-7.0,activity=projections,generation=2,model=ifs-nemo,realization=1,expver=0001,stream=clte,date=20200101/20200102/20200103/20200104/20200105/20200106/20200107/20200108/20200109/20200110/20200111/20200112/20200113/20200114/20200115/20200116/20200117/20200118/20200119/20200120/20200121/20200122/20200123/20200124/20200125/20200126/20200127/20200128/20200129/20200130/20200131,resolution=high,type=fc,levtype=sfc,time=0000/0100/0200/0300/0400/0500/0600/0700/0800/0900/1000/1100/1200/1300/1400/1500/1600/1700/1800/1900/2000/2100/2200/2300,param=8/9/78/79/134/137/141/144/146/147/148/151/159/164/165/166/167/168/169/175/176/177/178/179/180/181/182/186/187/188/212/228/235/260048"


def test_main_clmn_profile():
    tmp_dir = Path(tempfile.mkdtemp())
    profile_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    flat_request_filename = str(tmp_dir / "test_request.flat")
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
        "--request_name",
        flat_request_filename,
    ]
    main(argv)

    with open(flat_request_filename, "r") as f:
        flat_request_content = f.read()

    print(flat_request_content)
    assert flat_request_content == "class=d1,dataset=climate-dt,experiment=ssp3-7.0,activity=projections,generation=2,model=ifs-nemo,realization=1,expver=0001,stream=clmn,resolution=high,type=fc,levtype=sfc,param=8/9/78/79/134/137/141/144/146/147/148/151/159/164/165/166/167/168/169/175/176/177/178/179/180/181/182/186/187/188/212/228/235/260048,month=1,year=2020"


def test_main_clte_profile_omit_for_check_messages():
    """
    Emulate the yaml_to_flat_mars script call with the arguments that would
    be passed from the WIPE template to generate the listing request
    for clte profiles, that checks everything is in the databridge
    before wiping.

    As this needs to check the full profile, only time and levelist
    needed to be omitted, as these are chunk independent and we want
    to check all times and levelist for the given profile.

    The resulting request should contain dates but not times.
    """
    tmp_dir = Path(tempfile.mkdtemp())
    profile_file = Path(__file__).parent / "sfc_hourly_healpix_high.yaml"
    flat_request_filename = str(tmp_dir / "test_request.flat")
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
        "--request_name",
        flat_request_filename,
        "--omit-keys",
        "time,levelist",
    ]
    main(argv)

    with open(flat_request_filename, "r") as f:
        flat_request_content = f.read()

    print(flat_request_content)
    assert flat_request_content == "class=d1,dataset=climate-dt,experiment=ssp3-7.0,activity=projections,generation=2,model=ifs-nemo,realization=1,expver=0001,stream=clte,date=20200101/20200102/20200103/20200104/20200105/20200106/20200107/20200108/20200109/20200110/20200111/20200112/20200113/20200114/20200115/20200116/20200117/20200118/20200119/20200120/20200121/20200122/20200123/20200124/20200125/20200126/20200127/20200128/20200129/20200130/20200131,resolution=high,type=fc,levtype=sfc,param=8/9/78/79/134/137/141/144/146/147/148/151/159/164/165/166/167/168/169/175/176/177/178/179/180/181/182/186/187/188/212/228/235/260048"


def test_main_clmn_profile_omit_check_messages():
    """
    Emulate the yaml_to_flat_mars script call with the arguments that would
    be passed from the WIPE template to generate the listing request
    for clmn profiles, that checks everything is in the databridge
    before wiping.

    As this needs to check the full profile, only time and levelist
    needed to be omitted, as these are chunk independent and we want
    to check all times and levelist for the given profile.

    Even if would not be present in the processed request for a clmn
    profile (as this would have been converted to month and key by the
    script), the tempalte uses the same call with the same argument, so
    the testing needs to take into account that. Omit of missing keys is
    a case handled by the script.

    The resulting request should contain both year and month, but neither
    date nor time.
    """
    tmp_dir = Path(tempfile.mkdtemp())
    profile_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    flat_request_filename = str(tmp_dir / "test_request.flat")
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
        "--request_name",
        flat_request_filename,
        "--omit-keys",
        "time,levelist",
    ]
    main(argv)

    with open(flat_request_filename, "r") as f:
        flat_request_content = f.read()

    print(flat_request_content)
    assert flat_request_content == "class=d1,dataset=climate-dt,experiment=ssp3-7.0,activity=projections,generation=2,model=ifs-nemo,realization=1,expver=0001,stream=clmn,resolution=high,type=fc,levtype=sfc,param=8/9/78/79/134/137/141/144/146/147/148/151/159/164/165/166/167/168/169/175/176/177/178/179/180/181/182/186/187/188/212/228/235/260048,month=1,year=2020"


def test_main_clte_profile_omit_for_exec_wipe():
    """
    Emulate the yaml_to_flat_mars script call with the arguments that would
    be passed from the WIPE template to generate wiping request that will
    wipe the data for the clte data.

    This commands gets called once for all the clte data (unlike the
    listing call which gets called once per profile), so the request
    should not cotain profile-specific keys.

    In special, the time, levelist, param, levtype and resolution keys
    need to be omitted.

    The resulting request should contain dates, but not times. Also, it
    should not contain neither param, levtype nor resolution.
    """
    tmp_dir = Path(tempfile.mkdtemp())
    general_request = Path(__file__).parents[4] / "runscripts/FDB/general_request_clte.yaml"
    flat_request_filename = str(tmp_dir / "test_request.flat")
    argv = [
        "--file",
        str(general_request),
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
        "--request_name",
        flat_request_filename,
        "--omit-keys",
        "time,levelist,param,levtype,resolution",
    ]
    main(argv)

    with open(flat_request_filename, "r") as f:
        flat_request_content = f.read()

    print(flat_request_content)
    assert flat_request_content == "class=d1,dataset=climate-dt,activity=projections,experiment=ssp3-7.0,generation=2,model=ifs-nemo,realization=1,expver=0001,stream=clte,date=20200101/20200102/20200103/20200104/20200105/20200106/20200107/20200108/20200109/20200110/20200111/20200112/20200113/20200114/20200115/20200116/20200117/20200118/20200119/20200120/20200121/20200122/20200123/20200124/20200125/20200126/20200127/20200128/20200129/20200130/20200131,type=fc"


def test_main_clmn_profile_omit_for_exec_wipe():
    """
    Emulate the yaml_to_flat_mars script call with the arguments that would
    be passed from the WIPE template to generate wiping request that will
    wipe the data for the clmn data.

    This commands gets called once for all the clmn data (unlike the
    listing call which gets called once per profile), so the request
    should not cotain profile-specific keys.

    In special, the time, levelist, param, levtype and resolution keys
    need to be omitted.

    The resulting request should contain year and month, but neither date
    nor time. Also, it should not contain neither param, levtype
    nor resolution.
    """
    tmp_dir = Path(tempfile.mkdtemp())
    general_request = Path(__file__).parents[4] / "runscripts/FDB/general_request_clmn.yaml"
    flat_request_filename = str(tmp_dir / "test_request.flat")
    argv = [
        "--file",
        str(general_request),
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
        "--request_name",
        flat_request_filename,
        "--omit-keys",
        "time,levelist,param,levtype,resolution",
    ]
    main(argv)

    with open(flat_request_filename, "r") as f:
        flat_request_content = f.read()

    print(flat_request_content)
    assert flat_request_content == "class=d1,dataset=climate-dt,activity=projections,experiment=ssp3-7.0,generation=2,model=ifs-nemo,realization=1,expver=0001,stream=clmn,type=fc,month=1,year=2020"

def test_main_clte_profile_omit_for_purge():
    """
    Run the yaml_to_flat_mars script with the arguments that would
    be passed from the purge command for a clte profile.
    
    As only top-tier MARS keys are accepted by purge, time, levelist,
    param, levtype, type and resolution must be omitted.

    The resulting request should not contain any second or third tier
    keys like resolution,type, levtype, time, levelist, nor param.
    """
    tmp_dir = Path(tempfile.mkdtemp())
    profile_file = Path(__file__).parent / "sfc_hourly_healpix_high.yaml"
    flat_request_filename = str(tmp_dir / "test_request.flat")
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
        "--request_name",
        flat_request_filename,
        "--omit-keys",
        "time,levelist,param,levtype,type,resolution"
    ]
    main(argv)

    with open(flat_request_filename, "r") as f:
        flat_request_content = f.read()

    print(flat_request_content)
    assert flat_request_content == "class=d1,dataset=climate-dt,experiment=ssp3-7.0,activity=projections,generation=2,model=ifs-nemo,realization=1,expver=0001,stream=clte,date=20200101/20200102/20200103/20200104/20200105/20200106/20200107/20200108/20200109/20200110/20200111/20200112/20200113/20200114/20200115/20200116/20200117/20200118/20200119/20200120/20200121/20200122/20200123/20200124/20200125/20200126/20200127/20200128/20200129/20200130/20200131"

def test_main_clmn_profile_omit_for_purge():
    """
    Run the yaml_to_flat_mars script with the arguments that would
    be passed from the purge command for a clmn profile.
    
    As only top-tier MARS keys are accepted by purge, time, levelist,
    param, levtype, type, resolution amd month must be omitted.

    The resulting request should not contain any second or third tier
    keys like resolution,type, levtype, time, levelist, nor param.
    """
    tmp_dir = Path(tempfile.mkdtemp())
    profile_file = Path(__file__).parent / "sfc_monthly_healpix_high.yaml"
    flat_request_filename = str(tmp_dir / "test_request.flat")
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
        "--request_name",
        flat_request_filename,
        "--omit-keys",
        "time,levelist,param,levtype,type,resolution,month"
    ]
    main(argv)

    with open(flat_request_filename, "r") as f:
        flat_request_content = f.read()

    print(flat_request_content)
    assert flat_request_content == "class=d1,dataset=climate-dt,experiment=ssp3-7.0,activity=projections,generation=2,model=ifs-nemo,realization=1,expver=0001,stream=clmn,year=2020"