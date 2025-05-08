import argparse
from datetime import datetime, timezone

import numpy as np
import pandas as pd
import xarray as xr


def pet_calculator(tavg, lat, time, stat_freq, l_heat=2.26, w_density=977):
    """
    calculation of Potential Evapotranspiration (PET)
    according to Oudin (2005).

    Parameters
    ----------

    t_avg : numpy.ndarray, optional
        average temperature data set in °C.
    lat : numpy.ndarray
        latitude for the data set in radians.
    time : datetime.datatime
        timestamp for the data.
    stat_freq: string
        'daily' or 'hourly' data requency.
    l_heat: float, optional
        latent heat of water vaporization in MJ/kg.
        default is 2.26.
    w_density: float, optional
        water density in kg/m3.
        default is 977.


    Returns
    -------
    numpy.ndarray
        Potential Evapotranspiration (PET) data in mm/stat_freq.
    """
    e_rad = e_rad_calculator(time, lat)
    pet = (e_rad / (l_heat * w_density)) * ((tavg + 5) / 100)
    pet = pet * 1000
    pet[tavg < -5] = 0
    if stat_freq == "daily":
        return pet
    else:
        return pet / 24


def e_rad_calculator(time, lat):
    """
    calculation of Potential Evapotranspiration (PET)
    according to John A. Duffie (Deceased) and William A. Beckman (2013).

    Parameters
    ----------
    time : datetime.datatime
        timestamp for the data.
    lat : numpy.ndarray
        latitude for the data set in radians.

    Returns
    -------
    numpy.ndarray
        Extraterrestrial radiation data in mm.
    """

    # converting current time to Day-of-year(doy)
    doy = pd.Timestamp(time).day_of_year - 1

    # relative distance between sun and earth
    dist = 1 + (0.033 * np.cos(((2 * np.pi * doy) / 365)))

    # dec = np.radians(23.45 * np.cos((2 * np.pi * (doy - 172)) / 365))
    dec = np.radians(-23.44 * np.cos(np.radians((360 / 365) * (doy + 10))))

    # sunset hour angle
    ang = np.arccos(np.maximum(-1, np.minimum(1, -np.tan(lat) * np.tan(dec))))

    # extraterrestrial radiation
    e_rad = (ang * np.sin(lat) * np.sin(dec)) + (
        np.cos(lat) * np.cos(dec) * np.sin(ang)
    )

    # units (MJ/m2/day)
    return 37.5 * dist * e_rad


def main(ini_date, end_date, stat_freq, in_dir, out_dir, in_file, out_file, lon_number):
    """Main function to process temperature data and calculate PET."""

    # Construct the input file path
    input_file_path = f"{in_dir}/{in_file}"

    # Load the NetCDF dataset from in_file
    dataset = xr.open_dataset(input_file_path)

    tavg = dataset.tavg  # temp units: degC
    lat = dataset.lat  # lat units: degrees
    lon = dataset.lon  # lon units: degrees
    time = dataset.time  # time given in days

    # Convert latitude array to radians & prepare for computation
    lat_array = np.radians(lat.data)
    lat_array = np.repeat(lat_array[:, np.newaxis], lon_number, axis=1)
    lat_array = lat_array[np.newaxis, :, :]

    pet = np.empty(tavg.shape)

    for date, data in enumerate(tavg):
        # Getting date time & converting to datetime
        np_time = data.time.values
        current_time = datetime.fromtimestamp(int(np_time) / 1e9, tz=timezone.utc)

        # Getting data for each date as an array
        tavg_array = tavg.values[date : date + 1, :, :]

        # Calculating PET
        pet_data = pet_calculator(tavg_array, lat_array, current_time, stat_freq)

        # Add the data to PET
        pet[date] = pet_data

    # Set attributes for the PET DataArray
    pet_attrs = {"units": "mm", "missing_value": -9999.0, "_FillValue": -9999.0}

    # Create PET DataArray
    pet = xr.DataArray(
        pet,
        coords=[time, lat, lon],
        dims=["time", "lat", "lon"],
        attrs=pet_attrs,
    )

    # Save the PET dataset to out_file
    output_file_path = f"{out_dir}/{out_file}"
    pet_dataset = xr.Dataset({"pet": pet})
    pet_dataset.to_netcdf(output_file_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Reading and writing forcings files")
    parser.add_argument("--ini_date", required=True, help="Initial run date")
    parser.add_argument("--end_date", required=True, help="End run date")
    parser.add_argument("--stat_freq", required=True, help="Statistical frequency")
    parser.add_argument("--in_dir", required=True, help="Input directory for forcings")
    parser.add_argument("--out_dir", required=True, help="Output directory for PET")
    parser.add_argument("--in_file", required=True, help="Input NetCDF file name")
    parser.add_argument("--out_file", required=True, help="Output NetCDF file name")
    parser.add_argument(
        "--lon_number", type=int, required=True, help="Number of latitude repetitions"
    )
    args = parser.parse_args()

    main(
        args.ini_date,
        args.end_date,
        args.stat_freq,
        args.in_dir,
        args.out_dir,
        args.in_file,
        args.out_file,
        args.lon_number,
    )
