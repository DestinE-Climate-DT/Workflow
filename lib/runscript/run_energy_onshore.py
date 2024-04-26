#!/usr/bin/env python3

# Load libraries
import argparse
import os

import numpy as np
import xarray as xr

# First step, create a parser:
parser = argparse.ArgumentParser(description="Runscript for Energy Onshore app.")

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
in_path = f"{hpcrootdir}/tmp"
out_path = f"{hpcrootdir}/tmp"

# Wind speed anomalies


def run_wind_speed_anomalies(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path, hpcprojdir
):
    from energy_onshore.core import wind_speed
    from energy_onshore import wind_speed_anomalies

    # Provide the data file name for all variables

    u100_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_100u_timestep_60_daily_mean.nc"
    v100_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_100v_timestep_60_daily_mean.nc"

    absolute_path_u100 = os.path.join(in_path, u100_file)
    absolute_path_v100 = os.path.join(in_path, v100_file)

    data_u100 = xr.open_dataset(absolute_path_u100)
    data_v100 = xr.open_dataset(absolute_path_v100)

    # Import processing script.

    u100 = data_u100["100u"][:, 0, 1:, :-1]
    v100 = data_v100["100v"][:, 0, 1:, :-1]

    num_points = len(u100.coords["lat"])
    new_latitude = np.linspace(27.0, 72.0, num=num_points)
    da_u100 = u100.assign_coords(lat=new_latitude)
    da_v100 = v100.assign_coords(lat=new_latitude)

    ws = wind_speed(da_u100, da_v100)

    path_clim = hpcprojdir + "applications/energy_onshore/ws_clim_1991_2020_eur.nc"
    ds_clim = xr.open_dataset(path_clim)
    ds_clim.close()
    clim_10m = ds_clim["sfcWind"]

    # Approximate 100m wind speed from 10m wind speed using power law as ERA5-Land does not provide 100m wind speed.
    clim_100m = clim_10m * (100 / 10) ** (0.143)

    ws_anom = wind_speed_anomalies(ws, clim_100m, scale="daily")

    output_file_path = os.path.join(out_path, f"ws100_anom_{ws['time'].values[0]}.nc")

    ws_anom.to_netcdf(path=output_file_path, mode="w")

    return


run_wind_speed_anomalies(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path, hpcprojdir
)

# Capacity factor (class I)


def run_capacity_factor_I(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
):
    from energy_onshore.core import wind_speed
    from energy_onshore import capacity_factor

    # Provide the data file name for all variables

    u100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100u_raw_data.nc"
    v100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100v_raw_data.nc"

    absolute_path_u100 = os.path.join(in_path, u100_file)
    absolute_path_v100 = os.path.join(in_path, v100_file)

    data_u100 = xr.open_dataset(absolute_path_u100)
    data_v100 = xr.open_dataset(absolute_path_v100)

    # Import processing script.

    u100 = data_u100["100u"]
    v100 = data_v100["100v"]

    ws = wind_speed(u100, v100)

    cf = capacity_factor(ws, iec_class="I")

    output_file_path = os.path.join(out_path, f"cf_I_{ws['time'].values[0]}.nc")

    cf.to_netcdf(path=output_file_path, mode="w")

    return


run_capacity_factor_I(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)

# Capacity factor (class II)


def run_capacity_factor_II(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
):
    from energy_onshore.core import wind_speed
    from energy_onshore import capacity_factor

    # Provide the data file name for all variables

    u100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100u_raw_data.nc"
    v100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100v_raw_data.nc"

    absolute_path_u100 = os.path.join(in_path, u100_file)
    absolute_path_v100 = os.path.join(in_path, v100_file)

    data_u100 = xr.open_dataset(absolute_path_u100)
    data_v100 = xr.open_dataset(absolute_path_v100)

    # Import processing script.

    u100 = data_u100["100u"]
    v100 = data_v100["100v"]

    ws = wind_speed(u100, v100)

    cf = capacity_factor(ws, iec_class="II")

    output_file_path = os.path.join(out_path, f"cf_II_{ws['time'].values[0]}.nc")

    cf.to_netcdf(path=output_file_path, mode="w")

    return


run_capacity_factor_II(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)

# Capacity factor (class III)


def run_capacity_factor_III(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
):
    from energy_onshore.core import wind_speed
    from energy_onshore import capacity_factor

    # Provide the data file name for all variables

    u100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100u_raw_data.nc"
    v100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100v_raw_data.nc"

    absolute_path_u100 = os.path.join(in_path, u100_file)
    absolute_path_v100 = os.path.join(in_path, v100_file)

    data_u100 = xr.open_dataset(absolute_path_u100)
    data_v100 = xr.open_dataset(absolute_path_v100)

    # Import processing script.

    u100 = data_u100["100u"]
    v100 = data_v100["100v"]

    ws = wind_speed(u100, v100)

    cf = capacity_factor(ws, iec_class="III")

    output_file_path = os.path.join(out_path, f"cf_III_{ws['time'].values[0]}.nc")

    cf.to_netcdf(path=output_file_path, mode="w")

    return


run_capacity_factor_III(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)

# Capacity factor (class S)


def run_capacity_factor_S(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
):
    from energy_onshore.core import wind_speed
    from energy_onshore import capacity_factor

    # Provide the data file name for all variables

    u100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100u_raw_data.nc"
    v100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100v_raw_data.nc"

    absolute_path_u100 = os.path.join(in_path, u100_file)
    absolute_path_v100 = os.path.join(in_path, v100_file)

    data_u100 = xr.open_dataset(absolute_path_u100)
    data_v100 = xr.open_dataset(absolute_path_v100)

    # Import processing script.

    u100 = data_u100["100u"]
    v100 = data_v100["100v"]

    ws = wind_speed(u100, v100)

    cf = capacity_factor(ws, iec_class="S")

    output_file_path = os.path.join(out_path, f"cf_S_{ws['time'].values[0]}.nc")

    cf.to_netcdf(path=output_file_path, mode="w")

    return


run_capacity_factor_S(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)

# Cooling degree days (CDD)


def run_cdd(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):
    from energy_onshore.core import convert_temperature
    from energy_onshore import cooling_degree_days

    # Provide the data file name for all variables

    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_mean.nc"
    tmax_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_max.nc"
    tmin_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_min.nc"

    absolute_path = os.path.join(in_path, t_file)
    absolute_path_max = os.path.join(in_path, tmax_file)
    absolute_path_min = os.path.join(in_path, tmin_file)

    data = xr.open_dataset(absolute_path)
    data_max = xr.open_dataset(absolute_path_max)
    data_min = xr.open_dataset(absolute_path_min)

    # Import processing script.

    data = data["2t"]
    data_max = data_max["2t"]
    data_min = data_min["2t"]
    tm = convert_temperature(data, unit="C")
    tx = convert_temperature(data_max, unit="C")
    tn = convert_temperature(data_min, unit="C")

    cdd, cdd_acc = cooling_degree_days(tm, tx, tn, base=22.0)

    output_file_path = os.path.join(out_path, f"cdd_{tm['time'].values[0]}.nc")

    cdd.to_netcdf(path=output_file_path, mode="w")

    return


run_cdd(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)

# Heating degree days (HDD)


def run_hdd(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path):
    from energy_onshore.core import convert_temperature
    from energy_onshore import heating_degree_days

    # Provide the data file name for all variables

    t_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_mean.nc"
    tmax_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_max.nc"
    tmin_file = f"{iniyear}_{inimonth}_{iniday}_to_{finyear}_{finmonth}_{finday}_2t_timestep_60_daily_min.nc"

    absolute_path = os.path.join(in_path, t_file)
    absolute_path_max = os.path.join(in_path, tmax_file)
    absolute_path_min = os.path.join(in_path, tmin_file)

    data = xr.open_dataset(absolute_path)
    data_max = xr.open_dataset(absolute_path_max)
    data_min = xr.open_dataset(absolute_path_min)

    # Import processing script.

    data = data["2t"]
    data_max = data_max["2t"]
    data_min = data_min["2t"]
    tm = convert_temperature(data, unit="C")
    tx = convert_temperature(data_max, unit="C")
    tn = convert_temperature(data_min, unit="C")

    hdd, hdd_acc = heating_degree_days(tm, tx, tn, base=15.5)

    output_file_path = os.path.join(out_path, f"hdd_{tm['time'].values[0]}.nc")

    hdd.to_netcdf(path=output_file_path, mode="w")

    return


run_hdd(iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path)

# High wind events


def run_high_wind_events(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
):
    from energy_onshore.core import wind_speed
    from energy_onshore import high_wind_events

    # Provide the data file name for all variables

    u100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100u_raw_data.nc"
    v100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100v_raw_data.nc"

    absolute_path_u100 = os.path.join(in_path, u100_file)
    absolute_path_v100 = os.path.join(in_path, v100_file)

    data_u100 = xr.open_dataset(absolute_path_u100)
    data_v100 = xr.open_dataset(absolute_path_v100)

    # Import processing script.

    u100 = data_u100["100u"]
    v100 = data_v100["100v"]

    ws = wind_speed(u100, v100)

    hwe = high_wind_events(ws, threshold=25.0)

    output_file_path = os.path.join(out_path, f"hwe_{ws['time'].values[0]}.nc")

    hwe.to_netcdf(path=output_file_path, mode="w")

    return


run_high_wind_events(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)

# Low wind events


def run_low_wind_events(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
):
    from energy_onshore.core import wind_speed
    from energy_onshore import low_wind_events

    # Provide the data file name for all variables

    u100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100u_raw_data.nc"
    v100_file = f"{iniyear}_{inimonth}_{iniday}_T00_00_to_{finyear}_{finmonth}_{finday}_T23_00_100v_raw_data.nc"

    absolute_path_u100 = os.path.join(in_path, u100_file)
    absolute_path_v100 = os.path.join(in_path, v100_file)

    data_u100 = xr.open_dataset(absolute_path_u100)
    data_v100 = xr.open_dataset(absolute_path_v100)

    # Import processing script.

    u100 = data_u100["100u"]
    v100 = data_v100["100v"]

    ws = wind_speed(u100, v100)

    lwe = low_wind_events(ws, threshold=3.0)

    output_file_path = os.path.join(out_path, f"lwe_{ws['time'].values[0]}.nc")

    lwe.to_netcdf(path=output_file_path, mode="w")

    return


run_low_wind_events(
    iniyear, inimonth, iniday, finyear, finmonth, finday, in_path, out_path
)
