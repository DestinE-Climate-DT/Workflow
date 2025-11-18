import argparse
import warnings
from functools import partial
from pathlib import Path
import xarray as xr
import numpy as np
import glob
import os

from gsv import GSVRetriever
from one_pass.opa import Opa

try:
    from runscripts.utils import AppExperiment, add_app_experiment_arguments
except ImportError:
    # Fallback: running as a script, not as an installed package
    import sys

    # Add the parent of 'dn' (i.e., 'runscripts') to sys.path
    sys.path.append(str(Path(__file__).parent.parent.resolve()))
    from utils import AppExperiment, add_app_experiment_arguments


def _get_parser():
    parser = argparse.ArgumentParser(description="Runscript for OPA job.")
    parser.add_argument(
        "--request_dir",
        type=str,
        required=True,
        help="Directory where requests are stored",
    )
    parser.add_argument(
        "--read_from_databridge",
        required=True,
        help="Read from databridge",
        default=False,
    )
    parser.add_argument(
        "--request_number",
        type=int,
        required=True,
        help="Request number",
    )
    parser.add_argument(
        "--outpath",
        type=str,
        required=Path,
        help="Output path for OPA",
    )
    parser.add_argument(
        "--restart_dir",
        type=str,
        default=None,
        help="Output path for OPA",
    )
    parser.add_argument(
        "--mask_file",
        required=True,
        help="Name of the mask to be applied",
        default=None,
    )
    add_app_experiment_arguments(parser)
    return parser


def _normalize_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() == "true"
    raise TypeError("value should be either str or bool.")


OpaAppExperiment = partial(AppExperiment, _request_suffix="_OPA*")


def check_deprecation(oparequest):
    """Check deprecated keys in gsv request since One_Pass v0.7.0,
    i.e. integration with Bias Adjustment.
    """

    if "bias_adjustment" in oparequest:
        warnings.warn(
            "OPA request key 'bias_adjustment' was deprecated in One_Pass v0.7.0. "
            "Please, use the key 'bias_adjust' instead.",
            DeprecationWarning,
        )
        oparequest["bias_adjust"] = oparequest.pop("bias_adjustment")

    if "bias_adjustment_method" in oparequest:
        warnings.warn(
            "OPA request key 'bias_adjustment_method' was deprecated in One_Pass v0.7.0. "
            "Please, use the key 'ba_future_method' instead.",
            DeprecationWarning,
        )
        oparequest["ba_future_method"] = oparequest.pop("bias_adjustment_method")

    if oparequest.get("stat") == "bias_correction":
        raise RuntimeError(
            "Opa request key-value combination {'stat': 'bias_correction'} is deprecated. "
            "Please, use a valid stat key together with {'bias_adjust': True}. "
            "(Introduced in One_Pass v0.7.0)"
        )


def reshape_final_file(data, mask):
    """Reshape final output file after applying mask into original shape.

    Parameters
    ----------
    data : xarray.DataArray
        xarray data array containing the output of the t-digest flattened masked file.
    mask :
        Boolean mask to apply, of the same shape as "data" input xarray.

    Returns
    -------
    reshaped_data
        Reshaped xarray dataarray of shape (time:1, lat:mask.lat lon:mask.lon).
    """
    # mask=mask_ds.mask

    indices = np.where(mask == 1)

    data = data  # xr.open_dataset("2020_01_06_ws_timestep_60_weekly_histogram_bin_counts.nc")

    data_to_insert = data["None"].squeeze("lat").data  # shape (1, dimsize, N)

    print(f"data_to_insert: {data_to_insert}")

    if "percentile" in data["None"].dims:
        dim = "percentile"
        dimsize = 1
    elif "bin_count" in data["None"].dims:
        dim = "bin_count"
        dimsize = 30
    elif "bin_edges" in data["None"].dims:
        dim = "bin_edges"
        dimsize = 31
    else:
        print("Non recognised variable name.")

    new_dummy_xarray = xr.DataArray(
        np.full(
            (1, dimsize, len(mask.lat), len(mask.lon)), np.nan, dtype=np.float32
        ),  # shape = (time, lat, lon)
        dims=("time", dim, "lat", "lon"),
        coords={
            "time": 1,
            f"{dim}": np.arange(dimsize),  # 0..dimsize
            "lat": mask.lat,  # 0
            "lon": mask.lon,  # 0..sum(mask)-1
        },
    )

    arr = new_dummy_xarray.data  # direct access to underlying NumPy array

    ilat = indices[0]

    ilon = indices[1]

    # vectorized assignment
    arr[:, :, ilat, ilon] = data_to_insert

    # Suppose you still have the coordinate information:
    # (same shape and dims as your new_dummy_xarray)

    da_out = xr.DataArray(
        arr,
        dims=("time", dim, "lat", "lon"),
        coords={
            "time": data["None"].time,
            f"{dim}": new_dummy_xarray[f"{dim}"],
            "lat": new_dummy_xarray.lat,
            "lon": new_dummy_xarray.lon,
        },
        name="filled_data",
    )

    # reduce memory usage
    del arr, ilon, ilat, data_to_insert

    return da_out


def apply_mask(data, mask):
    """Apply mask to an xarray dataset.

    Parameters
    ----------
    data : xarray.DataArray
        xarray data array containing the output of the gsv_interface
    mask : xarray.DataArray
        Boolean mask to apply, of the same spatial (lat lon) shape as "data" input xarray.

    Returns
    -------
    masked_data
        Masked xarray dataarray of shape (time:24, lat:1, lon:sum(mask)).
    """
    # Get grid points of the mask.
    mask_size = int(sum(mask.data.flatten()))

    # add time dimension
    mask_expanded = mask.expand_dims({"time": data.time}, axis=0)

    # Create new DataArray
    new_dummy_xarray = xr.DataArray(
        np.full(
            (24, 1, mask_size), np.nan, dtype=np.float32
        ),  # shape = (time, lat, lon)
        dims=("time", "lat", "lon"),
        coords={
            "time": data.time,  # 0..23 hours
            "lat": np.arange(1),  # 0
            "lon": np.arange(mask_size),  # 0..sum(mask)-1
        },
    )

    # flatten the xarrays
    mask_flat = mask_expanded.data.flatten()
    data_flat = data.ws.data.flatten()

    if len(data_flat) != len(mask_flat):
        raise ValueError("Shapes of data and mask are not equal.")

    # select the points that have some meaning (not masked points).
    masked_data = data_flat[mask_flat == 1]

    # reduce memory usage
    del data_flat, mask_flat

    reshaped = masked_data.reshape(24, 1, mask_size)

    new_dummy_xarray.values[:] = reshaped

    masked_data = new_dummy_xarray

    return masked_data


def main():
    """Run OPA."""

    args = _get_parser().parse_args()

    request_dir = args.request_dir
    read_from_databridge = args.read_from_databridge
    request_number = args.request_number
    outpath = args.outpath
    chunk = args.chunk
    split = args.split
    app_names = args.app_names
    expid = args.expid
    member = args.member
    realization = args.realization
    startdate = args.startdate
    mask = args.mask_file

    print("--request_dir: ", request_dir)
    print("--read_from_databridge: ", read_from_databridge)
    print("--request_number: ", request_number)
    print("--outpath", outpath)
    print("--chunk: ", chunk)
    print("--split: ", split)
    print("--expid", expid)
    print("--app_names", app_names)
    # Use either member or realization, not both
    print("--member", member)
    print("--realization", realization)
    print("--startdate", startdate)
    print("--mask_file", mask)

    app_experiment = OpaAppExperiment(
        chunk=chunk,
        split=split,
        expid=expid,
        member=member,
        realization=realization,
        app_names=app_names,
        startdate=startdate,
    )

    gsvrequests, oparequests = app_experiment.get_requests(request_dir)

    request_number_range = (1, len(gsvrequests) + 1)

    if (
        request_number < request_number_range[0]
        or request_number > request_number_range[1]
    ):
        raise ValueError(
            f"Request number ({request_number}) is out of allowed range: "
            f"({request_number_range[0]}, {request_number_range[1]})."
        )
    gsvrequest = gsvrequests[request_number - 1]
    oparequest = oparequests[request_number - 1]

    # Update OPA request with outpath for save and checkpoint functionalities
    # bias_adjust is parsed to bool in order to avoid issues with AS substituted
    # "false" (or "False") being evaluated to True.
    oparequest.update(
        {
            "save": True,
            "checkpoint": True,
            "save_filepath": outpath,
            "checkpoint_filepath": outpath,
            "bias_adjust": _normalize_bool(oparequest.get("bias_adjust", False)),
        }
    )

    # Check whether deprecated variables are used from old One_Pass version
    # (Prior to v0.7.0)
    print("DEBUG")
    check_deprecation(oparequest)

    # Get data from gsv
    gsv = GSVRetriever()
    data = gsv.request_data(gsvrequest, use_stream_iterator=read_from_databridge)

    # Apply mask to data
    if mask is not None and mask.lower() != "none":
        print(f"Applying mask: {mask}")
        data_attrs = data.attrs
        mask_data = xr.open_dataset(mask, engine="netcdf4").mask
        mask_data.attrs = data_attrs
        data = apply_mask(data, mask_data)
        data.attrs = data_attrs
    else:
        print("No mask applied.")

    # Load all (otherwise dask-enabled) xarray into memory
    data = data.compute()

    # Run One Pass algorithm on a specific stat & variable controlled by the oparequest
    opa_stat = Opa(oparequest)
    opa_stat.compute(data)

    if mask is not None and mask.lower() != "none":
        print("Applying reshape to original format.")
        mask_data = xr.open_dataset(mask, engine="netcdf4").mask

        if glob.glob(f"{outpath}/*histogram*"):  # if histogram do counts and edges
            files_counts = glob.glob(f"{outpath}/*counts*.nc")
            files_edges = glob.glob(f"{outpath}/*edges*.nc")
            if files_counts == [] and files_edges == []:
                print("No histogram file to be processed.")
            else:
                # find latest file
                latest_counts = max(files_counts, key=os.path.getmtime)
                latest_edges = max(files_edges, key=os.path.getmtime)

                # load data
                bin_counts_data = xr.open_dataset(f"{latest_counts}", engine="netcdf4")
                bin_edges_data = xr.open_dataset(f"{latest_edges}", engine="netcdf4")

                # get original shape and save
                bin_counts = reshape_final_file(bin_counts_data, mask_data)
                bin_edges = reshape_final_file(bin_edges_data, mask_data)
                bin_counts.to_netcdf(f"{latest_counts}_test")
                bin_edges.to_netcdf(f"{latest_edges}_test")
                print(
                    f"Histograms final file saved at original shape at {latest_edges} and {latest_counts}."
                )

        else:  # do percentiles
            files_percentiles = glob.glob(f"{outpath}/*percentile*.nc")

            print(f"files_percentiles: {files_percentiles}")

            # find latest file
            if files_percentiles == []:
                print("No percentile file to be processed.")

            else:
                latest_percentiles = max(files_percentiles, key=os.path.getmtime)

                print(f"latest_percentiles: {latest_percentiles}")

                # load data
                percentiles_data = xr.open_dataset(
                    f"{latest_percentiles}", engine="netcdf4"
                )

                # get original shape and save
                percentiles = reshape_final_file(percentiles_data, mask_data)
                percentiles.to_netcdf(f"{latest_percentiles}_test")
                print(
                    f"Percentiles final file saved at original shape at {latest_percentiles}."
                )

    restart_dir = args.restart_dir

    # Checkpoint only if restart_dir is passed (and not empty)
    if restart_dir is None or restart_dir == "":
        return 0

    # Do not checkpoint raw variables
    if oparequest.get("stat") == "raw":
        return 0

    # Checkpoint in restart dir (for potential future restarts)
    opa_stat.checkpoint(restart_dir)

    return 0


if __name__ == "__main__":
    main()
