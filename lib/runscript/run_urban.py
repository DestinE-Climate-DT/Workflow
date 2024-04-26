#!/usr/bin/env python3

# Load libraries
import argparse
import os
import numpy as np
import xarray as xr

# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for Urban app.")

# Second step, add positional arguments. THESE ARGUMENTS CHANGE DYNAMICALLY WITH THE WORKFLOW
# https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
parser.add_argument(
    "-iniyear", required=True, help="Input year for the urban app", default=1
)
parser.add_argument(
    "-inimonth", required=True, help="Input month for the urban app", default=2
)
parser.add_argument(
    "-iniday", required=True, help="Input day for the urban app", default=3
)
parser.add_argument(
    "-hpcrootdir", required=True, help="ROOT directory of the experiment", default=4
)
parser.add_argument(
    "-finyear", required=True, help="Input year for the urban app", default=5
)
parser.add_argument(
    "-finmonth", required=True, help="Input month for the urban app", default=6
)
parser.add_argument(
    "-finday", required=True, help="Input day for the urban app", default=7
)
parser.add_argument(
    "-hpcprojdir", required=True, help="PROJECT directory of the HPC", default=8
)

# Third step, parse arguments.
# The default args list is taken from sys.args
args = parser.parse_args()

# hour = args.hour
iniyear = args.iniyear
inimonth = args.inimonth
iniday = args.iniday
hpcrootdir = args.hpcrootdir
finyear = args.finyear
finmonth = args.finmonth
finday = args.finday
hpcprojdir = args.hpcprojdir
# Provide the input and output DIR path
in_path = f"{hpcrootdir}/"
out_path = f"{hpcrootdir}/"

# Tropical nights (TR20)


def run_tropical_nights(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
):
    from urban_heat.core import convert_temperature
    from urban_heat import tropical_nights

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_min.nc"

    absolute_path = os.path.join(in_path, t_file)

    data = xr.open_dataset(absolute_path)

    # Import processing script.

    data = data["2t"]
    tn = convert_temperature(data, unit="C")

    tr = tropical_nights(tn, threshold=20.0)

    output_file_path = os.path.join(out_path, f"tr20_{tn['time'].values[0]}.nc")

    tr.to_netcdf(path=output_file_path, mode="w")

    return


run_tropical_nights(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)

# Summer days (SU25)


def run_summer_days(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
):
    from urban_heat.core import convert_temperature
    from urban_heat import summer_days

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_max.nc"

    absolute_path = os.path.join(in_path, t_file)

    data = xr.open_dataset(absolute_path)

    # Import processing script.

    data = data["2t"]
    tx = convert_temperature(data, unit="C")

    su = summer_days(tx, threshold=25.0)

    output_file_path = os.path.join(out_path, f"su25_{tx['time'].values[0]}.nc")

    su.to_netcdf(path=output_file_path, mode="w")

    return


run_summer_days(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)

# Warm nights (TN90p)


def run_warm_nights(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path, hpcprojdir
):
    from urban_heat.core import convert_temperature
    from urban_heat import warm_nights

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_min.nc"

    absolute_path = os.path.join(in_path, t_file)

    data = xr.open_dataset(absolute_path)

    # Import processing script.

    data = data["2t"][:, 1:, :-1]
    num_points = len(data.coords["lat"])
    new_latitude = np.linspace(27.0, 72.0, num=num_points)
    da = data.assign_coords(lat=new_latitude)

    tn = convert_temperature(da, unit="C")

    path_clim = hpcprojdir + "/applications/urban/tasmin_p90_clim_1981_2010_eur.nc"
    ds_clim = xr.open_dataset(path_clim)
    ds_clim.close()
    clim = convert_temperature(ds_clim["tasmin"], unit="C")

    tn90p = warm_nights(tn, clim)

    output_file_path = os.path.join(out_path, f"tn90p_{tn['time'].values[0]}.nc")

    tn90p.to_netcdf(path=output_file_path, mode="w")

    return


run_warm_nights(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path, hpcprojdir
)

# Warm days (TX90p)


def run_warm_days(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path, hpcprojdir
):
    from urban_heat.core import convert_temperature
    from urban_heat import warm_days

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_max.nc"

    absolute_path = os.path.join(in_path, t_file)

    data = xr.open_dataset(absolute_path)

    # Import processing script.

    data = data["2t"][:, 1:, :-1]
    num_points = len(data.coords["lat"])
    new_latitude = np.linspace(27.0, 72.0, num=num_points)
    da = data.assign_coords(lat=new_latitude)

    tx = convert_temperature(da, unit="C")

    path_clim = hpcprojdir + "/applications/urban/tasmax_p90_clim_1981_2010_eur.nc"
    ds_clim = xr.open_dataset(path_clim)
    ds_clim.close()
    clim = convert_temperature(ds_clim["tasmax"], unit="C")

    tx90p = warm_days(tx, clim)

    output_file_path = os.path.join(out_path, f"tx90p_{tx['time'].values[0]}.nc")

    tx90p.to_netcdf(path=output_file_path, mode="w")

    return


run_warm_days(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path, hpcprojdir
)

# Excess Heat Factor (EHF)


def run_ehf(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path, hpcprojdir
):
    from urban_heat.core import convert_temperature
    from urban_heat import excess_heat_factor

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_mean.nc"

    absolute_path = os.path.join(in_path, t_file)

    data = xr.open_dataset(absolute_path)

    # Import processing script.

    data = data["2t"][:, 1:, :-1]
    num_points = len(data.coords["lat"])
    new_latitude = np.linspace(27.0, 72.0, num=num_points)
    da = data.assign_coords(lat=new_latitude)

    tm = convert_temperature(da, unit="C")

    path_clim = hpcprojdir + "/applications/urban/tas_p95_clim_1981_2010_eur.nc"
    ds_clim = xr.open_dataset(path_clim)
    ds_clim.close()
    clim = convert_temperature(ds_clim["tas"], unit="C")

    ehf = excess_heat_factor(tm, clim)

    output_file_path = os.path.join(out_path, f"ehf_{tm['time'].values[0]}.nc")

    ehf.to_netcdf(path=output_file_path, mode="w")

    return


# run_ehf(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path, hpcprojdir)

# TXx


def run_max_tx(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):
    from urban_heat.core import convert_temperature
    from urban_heat import max_tx

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_max.nc"

    absolute_path = os.path.join(in_path, t_file)

    data = xr.open_dataset(absolute_path)

    # Import processing script.

    data = data["2t"]
    tx = convert_temperature(data, unit="C")

    txx = max_tx(tx)

    output_file_path = os.path.join(out_path, f"txx_{tx['time'].values[0]}.nc")

    txx.to_netcdf(path=output_file_path, mode="w")

    return


run_max_tx(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)

# TNx


def run_max_tn(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):
    from urban_heat.core import convert_temperature
    from urban_heat import max_tn

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_min.nc"

    absolute_path = os.path.join(in_path, t_file)

    data = xr.open_dataset(absolute_path)

    # Import processing script.

    data = data["2t"]
    tn = convert_temperature(data, unit="C")

    tnx = max_tn(tn)

    output_file_path = os.path.join(out_path, f"tnx_{tn['time'].values[0]}.nc")

    tnx.to_netcdf(path=output_file_path, mode="w")

    return


# Heat Index (HI)


def run_hi(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):
    from urban_heat.core import convert_temperature
    from urban_heat import heat_index

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_2t_raw_data.nc"
    d_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_2d_raw_data.nc"

    absolute_path_t = os.path.join(in_path, t_file)
    absolute_path_d = os.path.join(in_path, d_file)

    data_t = xr.open_dataset(absolute_path_t)
    data_d = xr.open_dataset(absolute_path_d)

    # Import processing script.

    data_t = data_t["2t"]
    data_d = data_d["2d"]
    t = convert_temperature(data_t, unit="C")
    d = convert_temperature(data_d, unit="C")

    hi = heat_index(t2c=t, rh=None, d2c=d, method="adjusted")

    output_file_path = os.path.join(out_path, f"hi_adjusted_{t['time'].values[0]}.nc")

    hi.to_netcdf(path=output_file_path, mode="w")

    return


run_hi(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)

# Apparent Temperature (AT)


def run_at(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):
    from urban_heat.core import convert_temperature
    from urban_heat.core import wind_speed
    from urban_heat import apparent_temperature

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_2t_raw_data.nc"
    u10_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_10u_raw_data.nc"
    v10_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_10v_raw_data.nc"

    absolute_path_t = os.path.join(in_path, t_file)
    absolute_path_u10 = os.path.join(in_path, u10_file)
    absolute_path_v10 = os.path.join(in_path, v10_file)

    data_t = xr.open_dataset(absolute_path_t)
    data_u10 = xr.open_dataset(absolute_path_u10)
    data_v10 = xr.open_dataset(absolute_path_v10)

    # Import processing script.

    data_t = data_t["2t"]
    t = convert_temperature(data_t, unit="C")

    data_u10 = data_u10["10u"]
    data_v10 = data_v10["10v"]

    ws10 = wind_speed(data_u10, data_v10)

    at = apparent_temperature(t2c=t, ws10=ws10, rad=None)

    output_file_path = os.path.join(out_path, f"at_{t['time'].values[0]}.nc")

    at.to_netcdf(path=output_file_path, mode="w")

    return


run_at(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)

# Wet Bulb Temperature (WBT)


def run_wbt(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):
    from urban_heat import wet_bulb_temperature
    from urban_heat.core import convert_temperature

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_2t_raw_data.nc"
    d_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_2d_raw_data.nc"

    absolute_path_t = os.path.join(in_path, t_file)
    absolute_path_d = os.path.join(in_path, d_file)

    data_t = xr.open_dataset(absolute_path_t)
    data_d = xr.open_dataset(absolute_path_d)

    # Import processing script.

    data_t = data_t["2t"]
    data_d = data_d["2d"]

    t = convert_temperature(data_t, unit="C")
    d = convert_temperature(data_d, unit="C")

    wbt = wet_bulb_temperature(t2c=t, rh=None, d2c=d)

    output_file_path = os.path.join(out_path, f"wbt_{t['time'].values[0]}.nc")

    wbt.to_netcdf(path=output_file_path, mode="w")

    return


run_wbt(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)

# Normal Effective Temperature (NET)


def run_net(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):
    from urban_heat import normal_effective_temperature
    from urban_heat.core import convert_temperature
    from urban_heat.core import wind_speed

    # Provide the data file name for all variables
    t_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_2t_raw_data.nc"
    d_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_2d_raw_data.nc"
    u10_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_10u_raw_data.nc"
    v10_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_10v_raw_data.nc"

    absolute_path_t = os.path.join(in_path, t_file)
    absolute_path_d = os.path.join(in_path, d_file)
    absolute_path_u10 = os.path.join(in_path, u10_file)
    absolute_path_v10 = os.path.join(in_path, v10_file)

    data_t = xr.open_dataset(absolute_path_t)
    data_d = xr.open_dataset(absolute_path_d)
    data_u10 = xr.open_dataset(absolute_path_u10)
    data_v10 = xr.open_dataset(absolute_path_v10)

    # Import processing script.

    data_t = data_t["2t"]
    data_d = data_d["2d"]

    t = convert_temperature(data_t, unit="C")
    d = convert_temperature(data_d, unit="C")

    data_u10 = data_u10["10u"]
    data_v10 = data_v10["10v"]

    ws10 = wind_speed(data_u10, data_v10)

    net = normal_effective_temperature(t2c=t, ws10=ws10, rh=None, d2c=d)

    output_file_path = os.path.join(out_path, f"net_{t['time'].values[0]}.nc")

    net.to_netcdf(path=output_file_path, mode="w")

    return


run_net(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)
