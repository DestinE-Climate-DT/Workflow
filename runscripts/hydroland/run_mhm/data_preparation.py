import xarray as xr
import numpy as np
import pathlib
import argparse
import pandas as pd


def clone_day(ds):
    # Shift the time and concatenate the data.
    shift = np.timedelta64(1, "D")
    ds_shifted = ds.copy()
    ds_shifted["time"] = ds["time"] + shift
    ds = xr.concat([ds, ds_shifted], dim="time")
    return ds


def set_days_to_zero(ds):
    # Set HH:MM:SS to zeros for daily time steps.
    start_date = pd.Timestamp(ds.time.values[0]).normalize()
    time_zeros = pd.date_range(start=start_date, periods=ds.time.size, freq="D")
    ds["time"] = time_zeros
    return ds


def convert_units(ds, var, freq):
    if var == "2t":
        new_var = "tavg"
        ds = ds.rename({var: new_var})
        ds[new_var] = ds[new_var] - 273.15
        ds[new_var].attrs["units"] = "degC"
    elif var == "tp":
        new_var = "pre"
        ds = ds.rename({var: new_var})
        ds[new_var] = ds[new_var] * 1000
        ds[new_var].attrs["units"] = "mm"
    elif var in {"tprate", "avg_tprate"}:
        new_var = "pre"
        ds = ds.rename({var: new_var})
        factor = 86400 if freq == "daily" else 3600 if freq == "hourly" else 1
        ds[new_var] = ds[new_var] * factor
        ds[new_var].attrs["units"] = "mm"
    else:
        raise ValueError(f"Invalid Hydroland variable: {var}.")

    # Set missing value attributes.
    missing_value = -9999.0
    ds[new_var].attrs["_FillValue"] = missing_value
    ds[new_var].attrs["missing_value"] = missing_value

    return ds


def str2bool(value):
    if isinstance(value, bool):
        return value
    if value.lower() in ("yes", "true", "t", "y", "1"):
        return True
    elif value.lower() in ("no", "false", "f", "n", "0"):
        return False
    else:
        raise argparse.ArgumentTypeError("Boolean value expected.")


def ensure_lat_lon_order(ds):
    # Check for the latitude variable.
    if "lat" in ds:
        lat_name = "lat"
    elif "latitude" in ds:
        lat_name = "latitude"
    else:
        raise ValueError(
            "Latitude variable ('lat' or 'latitude') not found in the dataset."
        )

    # Check for the longitude variable.
    if "lon" in ds:
        lon_name = "lon"
    elif "longitude" in ds:
        lon_name = "longitude"
    else:
        raise ValueError(
            "Longitude variable ('lon' or 'longitude') not found in the dataset."
        )

    # Get latitude and longitude values.
    lat_values = ds[lat_name].values
    lon_values = ds[lon_name].values

    # Ensure latitude is descending.
    if not (lat_values[1:] < lat_values[:-1]).all():
        ds = ds.sortby(lat_name, ascending=False)

    # Ensure longitude is ascending.
    if not (lon_values[1:] > lon_values[:-1]).all():
        ds = ds.sortby(lon_name, ascending=True)
    return ds


def main_mhm(in_dir, in_file, out_dir, out_file, var, stat_freq):
    input_path = pathlib.Path(in_dir, in_file)
    ds = xr.open_dataset(input_path)

    # Check the number of time steps.
    ntime = ds.time.size

    # Clone day if necessary.
    if ntime == 1:
        ds = clone_day(ds)

    # Set days to zero if frequency is daily.
    if stat_freq == "daily":
        ds = set_days_to_zero(ds)

    # Convert units.
    ds = convert_units(ds, var, stat_freq)

    # Ensure latitude is descending and longitude is ascending.
    ds = ensure_lat_lon_order(ds)

    # Save the processed file.
    output_path = pathlib.Path(out_dir, out_file)
    ds.to_netcdf(output_path)


def main_mrm(in_dir, in_file, out_dir, out_file, stat_freq):
    input_path = pathlib.Path(in_dir, in_file)
    ds = xr.open_dataset(input_path)

    # Check the number of time steps.
    ntime = ds.time.size

    # Clone day if necessary.
    if ntime == 1:
        ds = clone_day(ds)

    # Set days to zero if frequency is daily.
    if stat_freq == "daily":
        ds = set_days_to_zero(ds)
        output_path = pathlib.Path(out_dir, out_file)
        ds.to_netcdf(output_path)
        return True
    else:
        return False


def pass_DGOV_attrs(opa_data, hydroland_ds, out_dir, out_file):
    """
    Copy selected DGOV attributes from the OPA data array to the global attributes of
    the Hydroland dataset and save the updated dataset to a NetCDF file.

    Parameters:
        opa_data (xarray.DataArray): Data array from the OPA file containing DGOV attributes.
        hydroland_ds (xarray.Dataset): Hydroland dataset whose global attributes will be updated.
        out_dir (str): Output directory where the updated file will be saved.
        out_file (str): The output NetCDF file name.
    """
    # List of attributes to check and copy.
    attributes_to_copy = [
        "activity",
        "dataset",
        "experiment",
        "generation",
        "type",
        "levtype",
        "model",
        "class",
        "realization",
        "stream",
        "resolution",
        "expver",
    ]

    # Copy each attribute from opa_data to hydroland_ds if it exists.
    for attr in attributes_to_copy:
        if attr in opa_data.attrs:
            hydroland_ds.attrs[attr] = opa_data.attrs[attr]

    # Add a global attribute for the application.
    hydroland_ds.attrs["application"] = "Hydroland"

    # Save the updated Hydroland dataset.
    output_path = pathlib.Path(out_dir, out_file)
    hydroland_ds.to_netcdf(output_path)


# Parsing arguments.
parser = argparse.ArgumentParser(description="Preprocess NetCDF files")
parser.add_argument(
    "--in_dir", required=True, help="Input directory containing the NetCDF file"
)
parser.add_argument("--in_file", required=False, help="Input NetCDF file")
parser.add_argument(
    "--out_dir",
    required=True,
    help="Output directory to save the processed NetCDF file",
)
parser.add_argument(
    "--out_file", required=True, help="Name of the processed NetCDF file"
)
parser.add_argument("--var", required=False, help="Variable name to be modified")
parser.add_argument(
    "--stat_freq", required=False, help="Frequency of the NetCDF: daily or hourly"
)
parser.add_argument(
    "--mRM",
    type=str2bool,
    const=True,
    default=False,
    nargs="?",
    help="If running mRM, the script will prepare mRM files.",
)
parser.add_argument(
    "--add_DGOV_data",
    type=str2bool,
    const=True,
    default=False,
    nargs="?",
    help="Add Data Governance attributes coming from input OPA file to Hydroland output files.",
)
parser.add_argument(
    "--current_ini_date", required=False, help="Initial date for the current execution"
)
parser.add_argument(
    "--current_end_date", required=False, help="End date for the current execution"
)
parser.add_argument(
    "--in_hydroland_dir",
    required=False,
    help="Input directory pointing to the Hydroland NetCDF file to add Data Governance attributes",
)
args = parser.parse_args()

if args.add_DGOV_data:
    # Build the wildcard patterns for the OPA
    if args.stat_freq == "hourly":
        opa_pattern = f"{args.current_ini_date}*{args.current_end_date}*{args.var}*.nc"
    else:
        opa_pattern = f"{args.current_ini_date}*{args.var}*.nc"

    # Hydroland file name
    if args.mRM:
        hydroland_pattern = "mHM_Fluxes_States.nc"
        if args.stat_freq == "hourly":
            hydroland_pattern = f"{args.current_ini_date}_T00_00_to_{args.current_end_date}_T23_00_mRM_Fluxes_States.nc"
        else:
            hydroland_pattern = f"{args.current_ini_date}_mRM_Fluxes_States.nc"
    else:
        hydroland_pattern = "mHM_Fluxes_States.nc"

    # Use pathlib to find matching files.
    opa_files = list(pathlib.Path(args.in_dir).glob(opa_pattern))
    hydroland_files = list(pathlib.Path(args.in_hydroland_dir).glob(hydroland_pattern))

    if opa_files:
        opa_ds = xr.open_dataset(opa_files[0])
    else:
        raise FileNotFoundError(
            f"No OPA file found matching {opa_pattern} in {args.in_dir}"
        )

    if hydroland_files:
        hydroland_ds = xr.open_dataset(hydroland_files[0])
    else:
        raise FileNotFoundError(
            f"No Hydroland file found matching {hydroland_pattern} in {args.in_hydroland_dir}"
        )

    pass_DGOV_attrs(opa_ds[args.var], hydroland_ds, args.out_dir, args.out_file)
elif args.mRM:
    main_mrm(args.in_dir, args.in_file, args.out_dir, args.out_file, args.stat_freq)
else:
    if args.var is None:
        raise ValueError(
            "A variable name must be provided using the --var argument when running mHM."
        )
    main_mhm(
        args.in_dir, args.in_file, args.out_dir, args.out_file, args.var, args.stat_freq
    )
