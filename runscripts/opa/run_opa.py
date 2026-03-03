"""OPA runscript. To be run with One_Pass 0.9.1 or higher."""

import argparse
from datetime import datetime
from functools import partial
import glob
import json
import os
from pathlib import Path
import shutil
import warnings

import xarray as xr
import numpy as np

from gsv import GSVRetriever
from one_pass import Opa, StatKey

try:
    from runscripts.utils import AppExperiment, add_app_experiment_arguments
except ImportError:
    # Fallback: running as a script, not as an installed package
    import sys

    # Add the parent of 'dn' (i.e., 'runscripts') to sys.path
    sys.path.append(str(Path(__file__).parent.parent.resolve()))
    from utils import AppExperiment, add_app_experiment_arguments

KEEP_TEMPORARY_DIRECTORY = False


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
    parser.add_argument(
        "--log_level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        required=True,
        help="Name of the mask to be applied",
    )
    add_app_experiment_arguments(parser)
    return parser


def _normalize_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() == "true"
    raise TypeError("value should be either str or bool.")


def _normalize_none(value):
    if isinstance(value, str) and value.casefold() == "none":
        return None
    return value


OpaAppExperiment = partial(AppExperiment, _request_suffix="_OPA*")


def _check_deprecation(oparequest):
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


def _create_temporary_directory(outpath):
    """Create a temporary directory in outpath with an incrementing pattern.

    Creates a directory with pattern `tmp_opa_0001`, `tmp_opa_0002`, etc.
    in the outpath. If a directory already exists, increments the number
    until an available name is found.

    Parameters
    ----------
    outpath : str or Path
        Base directory where the temporary directory will be created.

    Returns
    -------
    str
        Path to the created temporary directory.

    Raises
    ------
    RuntimeError
        If more than 9999 temporary directories already exist.
    OSError
        If the base directory cannot be created or other filesystem errors occur.
    """
    outpath = Path(outpath)
    outpath.mkdir(parents=True, exist_ok=True)

    # Find the first available directory name
    for counter in range(1, 100000):
        temp_dir = outpath / f"tmp_opa_{counter:05d}"
        if not temp_dir.exists():
            try:
                temp_dir.mkdir(parents=False, exist_ok=False)
                return str(temp_dir)
            except OSError:
                # Race condition: directory was created between exists() and mkdir()
                continue

    raise RuntimeError(
        f"Could not create temporary directory in {outpath}. "
        "Too many existing temporary directories (max 99999)."
    )


def _determine_save_filepath(outpath, mask_file):
    """Determine the filepath where OPA should save its output.

    If a mask file is provided, creates a temporary directory in outpath.
    Otherwise, uses outpath directly.

    Parameters
    ----------
    outpath : str or Path
        Base output directory.
    mask_file : str or None
        Path to mask file. If None, no temporary directory is needed.

    Returns
    -------
    str
        Path where OPA should save its output files.
    """
    if mask_file is None:
        return outpath
    return _create_temporary_directory(outpath)


def sanitize_request(oparequest, save_filepath, checkpoint_filepath):
    """Sanitize and update OPA request with configuration settings.

    Updates the OPA request dictionary with save and checkpoint settings based
    on whether a mask file is provided. When a mask file is provided, saving
    is handled in OPA, but on a temporary directory. Postprocessing will then
    apply the mask, reshape the data and save it in the original outpath.

    Parameters
    ----------
    oparequest : dict
        OPA request dictionary to be updated in place.
    save_filepath : str or Path
        Directory (potentially temporary) where OPA results are saved.
    checkpoint_filepath : str or Path
        Directory where OPA checkpoints are saved.

    Notes
    -----
    This function modifies the oparequest dictionary in place. It also
    checks for deprecated keys and issues warnings or raises errors as
    appropriate.
    """

    oparequest.update(
        {
            "save": True,
            "checkpoint": True,
            "save_filepath": save_filepath,
            "checkpoint_filepath": checkpoint_filepath,
            "bias_adjust": _normalize_bool(oparequest.get("bias_adjust", False)),
        }
    )

    # Check whether deprecated variables are used from old One_Pass version
    # (Prior to v0.7.0)
    _check_deprecation(oparequest)


def _extract_variable_name(dataset):
    """Extract the variable name from a dataset.

    Parameters
    ----------
    dataset : xarray.Dataset
        Dataset containing one or more data variables.

    Returns
    -------
    str
        Variable name to use. Prefers "None" for backward compatibility
        if present, otherwise uses the first variable.
    """
    data_vars = list(dataset.data_vars.keys())
    if len(data_vars) == 0:
        raise ValueError("Dataset has no data variables.")
    if len(data_vars) > 1:
        var_name = "None" if "None" in data_vars else data_vars[0]
        if var_name != "None":
            print(
                f"Warning: Dataset has multiple variables {data_vars}, using '{var_name}'"
            )
        return var_name
    return data_vars[0]


def _get_coord_attrs(coord):
    """Extract attributes from a coordinate if available.

    Parameters
    ----------
    coord : xarray.DataArray or array-like
        Coordinate to extract attributes from.

    Returns
    -------
    dict
        Dictionary of coordinate attributes, empty if none available.
    """
    return coord.attrs.copy() if hasattr(coord, "attrs") else {}


def _determine_statistic_dimension(var_data):
    """Determine the statistic dimension name and size from variable data.

    Parameters
    ----------
    var_data : xarray.DataArray
        Variable data array containing statistic dimensions.

    Returns
    -------
    tuple
        (dim_name, dim_size) tuple where dim_name is the dimension name
        and dim_size is the size of that dimension.
    """
    if "percentile" in var_data.dims:
        dim_name = "percentile"
        dim_size = len(var_data.percentile) if "percentile" in var_data.coords else 1
    elif "bin_count" in var_data.dims:
        dim_name = "bin_count"
        dim_size = len(var_data.bin_count) if "bin_count" in var_data.coords else 30
    elif "bin_edges" in var_data.dims:
        dim_name = "bin_edges"
        dim_size = len(var_data.bin_edges) if "bin_edges" in var_data.coords else 31
    else:
        raise ValueError(
            "Unrecognized dimension. Expected 'percentile', 'bin_count', or 'bin_edges'."
        )
    return dim_name, dim_size


def _extract_data_variable_info(data):
    """Extract variable information from DataArray or Dataset.

    Parameters
    ----------
    data : xarray.DataArray or xarray.Dataset
        Input data structure.

    Returns
    -------
    tuple
        (var_data, var_name, var_attrs, dataset_attrs) where:
        - var_data: The actual variable DataArray
        - var_name: Name of the variable
        - var_attrs: Variable-level attributes
        - dataset_attrs: Dataset-level attributes (empty dict for DataArray)
    """
    if isinstance(data, xr.Dataset):
        data_vars = list(data.data_vars.keys())
        if len(data_vars) == 0:
            raise ValueError("Dataset has no data variables.")
        if len(data_vars) > 1:
            raise ValueError(
                f"Dataset has multiple variables {data_vars}. "
                "Cannot determine which variable to process."
            )
        var_name = data_vars[0]
        var_data = data[var_name]
        var_attrs = var_data.attrs.copy() if hasattr(var_data, "attrs") else {}
        dataset_attrs = data.attrs.copy() if hasattr(data, "attrs") else {}
    else:
        var_data = data
        var_name = data.name if data.name is not None else "data"
        var_attrs = data.attrs.copy() if hasattr(data, "attrs") else {}
        dataset_attrs = {}
    return var_data, var_name, var_attrs, dataset_attrs


def _build_reshaped_coordinates(var_data, stat_dim, stat_dim_size, mask, has_level):
    """Build coordinate dictionary for reshaped output.

    Parameters
    ----------
    var_data : xarray.DataArray
        Variable data array with original coordinates.
    stat_dim : str
        Statistic dimension name (percentile, bin_count, or bin_edges).
    stat_dim_size : int
        Size of the statistic dimension.
    mask : xarray.DataArray
        Mask with original spatial coordinates.
    has_level : bool
        Whether level dimension exists.

    Returns
    -------
    tuple
        (coords_dict, dims, output_shape) where:
        - coords_dict: Dictionary of coordinates with values and attributes
        - dims: Tuple of dimension names
        - output_shape: Tuple of output array shape
    """
    # Extract coordinate values and attributes
    stat_dim_values = (
        var_data.coords[stat_dim].values
        if stat_dim in var_data.coords
        else np.arange(stat_dim_size)
    )
    stat_dim_attrs = (
        _get_coord_attrs(var_data.coords[stat_dim])
        if stat_dim in var_data.coords
        else {}
    )

    time_values = var_data.time.values if "time" in var_data.coords else [1]
    time_attrs = _get_coord_attrs(var_data.time) if "time" in var_data.coords else {}

    level_values = None
    level_attrs = {}
    if has_level:
        if "level" in var_data.coords:
            level_values = var_data.level.values
            level_attrs = _get_coord_attrs(var_data.level)
        else:
            level_values = [1]

    # Get lat/lon attributes from original data (stored in masked_data during _apply_mask)
    # These are stored as JSON strings in masked_data.attrs for NetCDF compatibility
    def _parse_attrs_from_source(source_attrs, key):
        """Parse attributes from a source, handling both JSON strings and dicts."""
        if key not in source_attrs:
            return None
        value = source_attrs[key]
        if isinstance(value, dict):
            return value.copy()
        if isinstance(value, str):
            try:
                return json.loads(value)
            except (json.JSONDecodeError, TypeError):
                return None
        return None

    lat_attrs = None
    lon_attrs = None

    # Try to retrieve from OPA output var_data first (if OPA preserved them from masked_data)
    if hasattr(var_data, "attrs"):
        lat_attrs = _parse_attrs_from_source(var_data.attrs, "_original_lat_attrs")
        lon_attrs = _parse_attrs_from_source(var_data.attrs, "_original_lon_attrs")

    # Fallback to mask coordinates if not found in OPA output
    if lat_attrs is None:
        lat_attrs = _get_coord_attrs(mask.lat)
    if lon_attrs is None:
        lon_attrs = _get_coord_attrs(mask.lon)

    # Build coordinate dictionary
    coords = {
        "time": (["time"], time_values, time_attrs),
        stat_dim: (stat_dim, stat_dim_values, stat_dim_attrs),
        "lat": (["lat"], mask.lat.values, lat_attrs),
        "lon": (["lon"], mask.lon.values, lon_attrs),
    }

    # Determine output dimensions and shape
    if has_level:
        coords["level"] = (["level"], level_values, level_attrs)
        dims = ("time", stat_dim, "level", "lat", "lon")
        output_shape = (
            1,
            stat_dim_size,
            len(level_values),
            len(mask.lat),
            len(mask.lon),
        )
    else:
        dims = ("time", stat_dim, "lat", "lon")
        output_shape = (1, stat_dim_size, len(mask.lat), len(mask.lon))

    return coords, dims, output_shape


def _add_history_entry(attrs, entry):
    """Add a history entry to attributes dictionary."""
    if "history" in attrs:
        attrs["history"] += entry
    else:
        attrs["history"] = entry


def _create_mask_flattening_history(mask_size, coverage_percentage, total_grid_points):
    """Create history entry for mask flattening operation."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return (
        f"\n{timestamp} OPA: data flattened using mask "
        f"({mask_size:,} tiles, {coverage_percentage:.2f}% coverage, "
        f"{total_grid_points:,} total grid points)"
    )


def _create_reshape_history(lat_size, lon_size):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return (
        f"\n{timestamp} OPA: data reshaped from flattened mask format "
        f"back to original spatial dimensions ({lat_size}×{lon_size} grid)"
    )


def _insert_flattened_data_into_array(
    flattened_data, output_array, lat_indices, lon_indices, has_level
):
    """Insert flattened data into output array at masked positions."""
    if has_level:
        output_array[:, :, :, lat_indices, lon_indices] = flattened_data
    else:
        output_array[:, :, lat_indices, lon_indices] = flattened_data


def _reshape_final_file(data, mask, var_name, dataset_attrs=None):
    """Reshape final output file after applying mask into original shape.

    Parameters
    ----------
    data : xarray.Dataset
        xarray dataset containing the output of the t-digest flattened masked file.
        Should contain a data variable with the flattened data.
    mask : xarray.DataArray
        Boolean mask to apply, of the same spatial (lat, lon) shape as the original data.
    var_name : str
        Name of the variable to use in the output dataset (from OPA request).
    dataset_attrs : dict, optional
        Dataset attributes from the OPA output file. If None, uses attributes
        from the input dataset.

    Returns
    -------
    xarray.Dataset
        Reshaped xarray dataset with the variable as a data variable,
        of shape (time:1, dim:dimsize, level?:1, lat:mask.lat, lon:mask.lon)
        with all metadata from the input dataset preserved.
    """
    if not isinstance(data, xr.Dataset):
        raise TypeError(f"Expected xarray.Dataset, got {type(data)}")

    # Extract variable information
    data_var_name = _extract_variable_name(data)
    var_data = data[data_var_name]
    var_attrs = var_data.attrs.copy() if hasattr(var_data, "attrs") else {}

    # Use provided dataset attributes if available, otherwise use from input dataset
    output_dataset_attrs = (
        dataset_attrs.copy()
        if dataset_attrs is not None
        else (data.attrs.copy() if hasattr(data, "attrs") else {})
    )

    # Get masked indices and flattened data
    lat_indices, lon_indices = np.where(mask == 1)
    has_level = "level" in var_data.dims
    flattened_data = var_data.squeeze("lat").data

    # Determine statistic dimension and build coordinates
    stat_dim, stat_dim_size = _determine_statistic_dimension(var_data)
    coords, dims, output_shape = _build_reshaped_coordinates(
        var_data, stat_dim, stat_dim_size, mask, has_level
    )

    # Create output array template
    output_template = xr.DataArray(
        np.full(output_shape, np.nan, dtype=np.float32),
        dims=dims,
        coords=coords,
    )

    # Insert flattened data into output array
    output_array = output_template.data
    _insert_flattened_data_into_array(
        flattened_data, output_array, lat_indices, lon_indices, has_level
    )

    # Create output DataArray with preserved metadata
    output_dataarray = xr.DataArray(
        output_array,
        dims=dims,
        coords=output_template.coords,
        name=var_name,
        attrs=var_attrs.copy(),
    )

    # Remove internal helper attributes that were only needed for reshaping
    # These should not appear in the final output files
    for internal_attr in ("_original_lat_attrs", "_original_lon_attrs"):
        output_dataarray.attrs.pop(internal_attr, None)

    # Add reshaping information to history
    reshape_history_entry = _create_reshape_history(len(mask.lat), len(mask.lon))
    _add_history_entry(output_dataarray.attrs, reshape_history_entry)

    # Convert to Dataset using the correct variable name from OPA request
    output_var_name = var_name if var_name and var_name != "None" else data_var_name
    output_dataset = output_dataarray.to_dataset(name=output_var_name)

    # Ensure internal helper attributes are not present on the variable in the final dataset
    for internal_attr in ("_original_lat_attrs", "_original_lon_attrs"):
        output_dataset[output_var_name].attrs.pop(internal_attr, None)

    # Apply dataset-level attributes from OPA output
    output_dataset.attrs.update(output_dataset_attrs)
    _add_history_entry(output_dataset.attrs, reshape_history_entry)

    return output_dataset


def _calculate_mask_statistics(mask):
    """Calculate mask statistics.

    Parameters
    ----------
    mask : xarray.DataArray
        Boolean mask array.

    Returns
    -------
    tuple
        (mask_size, coverage_percentage, total_grid_points)
    """
    total_grid_points = int(mask.size)
    mask_size = int(mask.sum().values)
    coverage_percentage = (
        (mask_size / total_grid_points * 100) if total_grid_points > 0 else 0.0
    )
    return mask_size, coverage_percentage, total_grid_points


def _extract_masked_values(var_data, mask):
    """Extract unmasked values from data using mask.

    Parameters
    ----------
    var_data : xarray.DataArray
        Variable data array to mask.
    mask : xarray.DataArray
        Boolean mask to apply.

    Returns
    -------
    numpy.ndarray
        Reshaped array of masked values with shape (time, 1, mask_size).
    """
    mask_expanded = mask.expand_dims({"time": var_data.time}, axis=0)
    mask_flat = mask_expanded.data.flatten()
    data_flat = var_data.data.flatten()

    if len(data_flat) != len(mask_flat):
        raise ValueError(
            f"Shapes of data ({len(data_flat)}) and mask ({len(mask_flat)}) are not equal."
        )

    masked_values = data_flat[mask_flat == 1]
    return masked_values.reshape(
        len(var_data.time), 1, len(masked_values) // len(var_data.time)
    )


def _apply_mask(data, mask):
    """Apply mask to an xarray dataset, flattening spatial dimensions.

    Parameters
    ----------
    data : xarray.DataArray or xarray.Dataset
        xarray data array or dataset containing the output of the gsv_interface.
    mask : xarray.DataArray
        Boolean mask to apply, of the same spatial (lat, lon) shape as data.

    Returns
    -------
    xarray.DataArray
        Masked xarray dataarray of shape (time:24, lat:1, lon:mask_size)
        where mask_size is the number of unmasked grid points.
        Preserves variable-level and coordinate attributes from input data.
    """
    var_data, var_name, var_attrs, dataset_attrs = _extract_data_variable_info(data)
    mask_size, coverage_percentage, total_grid_points = _calculate_mask_statistics(mask)
    masked_values = _extract_masked_values(var_data, mask)

    # Preserve coordinate attributes
    time_attrs = _get_coord_attrs(var_data.time) if "time" in var_data.coords else {}

    # Extract original lat/lon attributes from input data
    lat_attrs = _get_coord_attrs(var_data.lat) if "lat" in var_data.coords else {}
    lon_attrs = _get_coord_attrs(var_data.lon) if "lon" in var_data.coords else {}

    # Create output DataArray with flattened spatial dimensions
    masked_data = xr.DataArray(
        masked_values,
        dims=("time", "lat", "lon"),
        coords={
            "time": (["time"], var_data.time.values, time_attrs),
            "lat": np.arange(1),
            "lon": np.arange(mask_size),
        },
        name=var_name,
        attrs=var_attrs.copy(),
    )

    # Store original lat/lon attributes in masked_data as JSON strings for NetCDF compatibility
    masked_data.attrs["_original_lat_attrs"] = json.dumps(lat_attrs)
    masked_data.attrs["_original_lon_attrs"] = json.dumps(lon_attrs)

    # Add mask flattening information to history
    mask_history_entry = _create_mask_flattening_history(
        mask_size, coverage_percentage, total_grid_points
    )
    _add_history_entry(masked_data.attrs, mask_history_entry)

    # Store dataset attributes in the DataArray attrs if available
    if dataset_attrs:
        for key, value in dataset_attrs.items():
            if key not in masked_data.attrs:
                masked_data.attrs[key] = value
        # Update history if present in dataset attributes
        if "history" in dataset_attrs:
            masked_data.attrs["history"] = dataset_attrs["history"] + mask_history_entry

    return masked_data


def preprocess_mask(data, mask_file):
    """Apply mask to input data before OPA computation.

    If a mask file is provided, loads the mask and applies it to the input
    data, flattening the spatial dimensions to only include unmasked points.
    This reduces the data size for OPA computation.

    Parameters
    ----------
    data : xarray.DataArray
        Input data array to be masked.
    mask_file : str or None
        Path to NetCDF file containing the mask. If None, no masking is applied.

    Returns
    -------
    tuple
        Two-element tuple containing:
        - masked_data : xarray.DataArray
            Masked data array with flattened spatial dimensions, or original
            data if mask_file is None.
        - mask_data : xarray.DataArray or None
            The mask data array used for masking, or None if no mask was applied.
    """
    # Apply mask to data
    if mask_file is None:
        print("No mask applied.")
        return data, None

    print(f"Applying mask: {mask_file}")

    # Preserve original attributes
    # _apply_mask will handle attribute preservation internally
    if isinstance(data, xr.Dataset):
        data_attrs = data.attrs.copy() if hasattr(data, "attrs") else {}
    else:
        # For DataArray, attrs are the variable-level attributes
        # There are no separate dataset-level attributes
        data_attrs = {}

    # Load mask and preserve attributes
    mask_data = xr.open_dataset(mask_file, engine="netcdf4").mask
    if hasattr(mask_data, "attrs"):
        mask_data.attrs.update(data_attrs)

    # Apply mask (this preserves attributes internally and stores lat/lon attrs in masked_data)
    data = _apply_mask(data, mask_data)

    # Also store lat/lon attributes in mask_data as fallback (in case OPA doesn't preserve them)
    if hasattr(data, "attrs") and "_original_lat_attrs" in data.attrs:
        if not hasattr(mask_data, "attrs"):
            mask_data.attrs = {}
        mask_data.attrs["_original_lat_attrs"] = data.attrs["_original_lat_attrs"]
        mask_data.attrs["_original_lon_attrs"] = data.attrs["_original_lon_attrs"]

    # Ensure attributes are preserved on the output
    if hasattr(data, "attrs"):
        data.attrs.update(data_attrs)

    return data, mask_data


def _get_filename_stem(opa):
    """Construct filename stem using the same pattern as save_final.py.

    Parameters
    ----------
    opa : Opa
        OPA instance containing request and data set information.

    Returns
    -------
    str
        Filename stem without extension or suffix.
    """
    stat_freq = opa.request.stat_freq
    base_filename = opa.data_set_info.filename
    filename_stem = (
        f"{base_filename}_{opa.request.variable}_"
        f"timestep_{opa.request.time_step}_"
        f"{stat_freq.value}_{opa.request.stat.value}"
    )
    return filename_stem


def _find_opa_output_files(save_filepath, pattern):
    """Find OPA output files matching a pattern in the save directory.

    Parameters
    ----------
    save_filepath : str or Path
        Directory where OPA saved the output files.
    pattern : str
        Glob pattern to match files (e.g., "*counts*.nc", "*percentile*.nc").

    Returns
    -------
    str or None
        Path to the most recently modified matching file, or None if no files found.
    """
    search_pattern = os.path.join(save_filepath, pattern)
    matching_files = glob.glob(search_pattern)

    if not matching_files:
        return None

    return max(matching_files, key=os.path.getmtime)


def _postprocess_histogram(opa, mask_data, save_filepath, outpath):
    """Postprocess histogram statistics by reshaping to original spatial dimensions.

    Retrieves histogram data (bin counts and bin edges) from OPA output files,
    reshapes them from flattened masked format back to original spatial dimensions,
    and saves the results to the final output directory.

    Parameters
    ----------
    opa : Opa
        OPA instance containing computed histogram statistics.
    mask_data : xarray.DataArray
        Mask data array used to reshape the flattened data back to original
        spatial dimensions.
    save_filepath : str or Path
        Directory where OPA saved the output files (may be temporary).
    outpath : str or Path
        Final output directory where reshaped files will be saved.

    Notes
    -----
    This function saves two files:
    - One for bin counts (*_bin_counts.nc)
    - One for bin edges (*_bin_edges.nc)
    """
    counts_file = _find_opa_output_files(save_filepath, "*counts*.nc")
    edges_file = _find_opa_output_files(save_filepath, "*edges*.nc")

    if not counts_file or not edges_file:
        print("No histogram files found to be processed.")
        return

    # Load flattened data from OPA output
    bin_counts_flattened = xr.open_dataset(counts_file, engine="netcdf4")
    bin_edges_flattened = xr.open_dataset(edges_file, engine="netcdf4")

    # Get variable name from OPA request
    var_name = opa.request.variable
    # Get global attributes from OPA output files
    dataset_attrs = (
        bin_counts_flattened.attrs.copy()
        if hasattr(bin_counts_flattened, "attrs")
        else {}
    )

    # Reshape to original spatial dimensions
    bin_counts_reshaped = _reshape_final_file(
        bin_counts_flattened, mask_data, var_name, dataset_attrs
    )
    bin_edges_reshaped = _reshape_final_file(
        bin_edges_flattened, mask_data, var_name, dataset_attrs
    )

    # Save reshaped files to final output directory
    filename_stem = _get_filename_stem(opa)
    output_counts_path = os.path.join(outpath, filename_stem + "_bin_counts.nc")
    output_edges_path = os.path.join(outpath, filename_stem + "_bin_edges.nc")

    bin_counts_reshaped.to_netcdf(output_counts_path)
    bin_edges_reshaped.to_netcdf(output_edges_path)
    print(
        f"Histograms saved at original shape: {output_counts_path} and {output_edges_path}"
    )


def _postprocess_percentile(opa, mask_data, save_filepath, outpath):
    """Postprocess percentile statistics by reshaping to original spatial dimensions.

    Retrieves percentile data from OPA output files, reshapes it from
    flattened masked format back to original spatial dimensions, and saves
    the result to the final output directory.

    Parameters
    ----------
    opa : Opa
        OPA instance containing computed percentile statistics.
    mask_data : xarray.DataArray
        Mask data array used to reshape the flattened data back to original
        spatial dimensions.
    save_filepath : str or Path
        Directory where OPA saved the output files (may be temporary).
    outpath : str or Path
        Final output directory where reshaped file will be saved.

    Notes
    -----
    This function saves a single file with the percentile statistics.
    """
    percentile_file = _find_opa_output_files(save_filepath, "*percentile*.nc")

    if not percentile_file:
        print("No percentile file found to be processed.")
        return

    # Load flattened data from OPA output
    percentiles_flattened = xr.open_dataset(percentile_file, engine="netcdf4")

    # Get variable name from OPA request
    var_name = opa.request.variable
    # Get global attributes from OPA output file
    dataset_attrs = (
        percentiles_flattened.attrs.copy()
        if hasattr(percentiles_flattened, "attrs")
        else {}
    )

    # Reshape to original spatial dimensions
    percentiles_reshaped = _reshape_final_file(
        percentiles_flattened, mask_data, var_name, dataset_attrs
    )

    # Save reshaped file to final output directory
    filename_stem = _get_filename_stem(opa)
    output_path = os.path.join(outpath, filename_stem + ".nc")

    percentiles_reshaped.to_netcdf(output_path)
    print(f"Percentiles saved at original shape: {output_path}")


def postprocess_mask(opa, mask_data, save_filepath, outpath):
    """Postprocess OPA results by reshaping masked data to original dimensions.

    Routes to the appropriate postprocessing function based on the statistic
    type. Reshapes the flattened masked data back to original spatial dimensions
    and saves the results to the final output directory.

    Parameters
    ----------
    opa : Opa
        OPA instance containing computed statistics.
    mask_data : xarray.DataArray or None
        Mask data array used for reshaping. If None, no postprocessing is performed.
    save_filepath : str or Path
        Directory where OPA saved the output files (may be temporary).
    outpath : str or Path
        Final output directory where reshaped files will be saved.

    Raises
    ------
    ValueError
        If the statistic type is not supported for mask reshaping (currently
        only HISTOGRAM and PERCENTILE are supported).
    """
    if mask_data is None:
        return

    stat = opa.request.stat
    postprocessors = {
        StatKey.HISTOGRAM: ("histogram", _postprocess_histogram),
        StatKey.PERCENTILE: ("percentile", _postprocess_percentile),
    }

    if stat not in postprocessors:
        raise ValueError(f"Cannot apply mask reshape for stat '{stat}'.")

    stat_name, postprocess_func = postprocessors[stat]
    print(f"Applying reshape to {stat_name}.")
    postprocess_func(opa, mask_data, save_filepath, outpath)


def _validate_request_number(request_number, gsvrequests):
    """Validate that request number is within valid range.

    Parameters
    ----------
    request_number : int
        Request number to validate.
    gsvrequests : list
        List of GSV requests.

    Raises
    ------
    ValueError
        If request number is out of valid range.
    """
    max_request_number = len(gsvrequests)
    if request_number < 1 or request_number > max_request_number:
        raise ValueError(
            f"Request number ({request_number}) is out of allowed range: "
            f"(1, {max_request_number})."
        )


def cleanup_temporary_directory(save_filepath, outpath, mask_file):
    """Clean up temporary directory if it was created.

    Parameters
    ----------
    save_filepath : str or Path
        Path to temporary directory (may be same as outpath).
    outpath : str or Path
        Final output directory.
    mask_file : str or None
        Mask file path (None if no mask was used).
    """
    if KEEP_TEMPORARY_DIRECTORY:
        return
    if mask_file is not None and save_filepath != outpath:
        try:
            shutil.rmtree(save_filepath)
            print(f"Cleaned up temporary directory: {save_filepath}")
        except OSError as e:
            print(f"Warning: Could not remove temporary directory {save_filepath}: {e}")


def _should_checkpoint(restart_dir, oparequest):
    """Determine if checkpointing should be performed.

    Parameters
    ----------
    restart_dir : str or None
        Restart directory path.
    oparequest : dict
        OPA request dictionary.

    Returns
    -------
    bool
        True if checkpointing should be performed, False otherwise.
    """
    if restart_dir is None or restart_dir == "":
        return False
    if oparequest.get("stat") == "raw":
        return False
    return True


def main():
    """Run OPA."""
    args = _get_parser().parse_args()

    # Extract and print arguments
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
    restart_dir = args.restart_dir
    mask_file = _normalize_none(args.mask_file)
    log_level = args.log_level

    print("--request_dir: ", request_dir)
    print("--read_from_databridge: ", read_from_databridge)
    print("--request_number: ", request_number)
    print("--outpath", outpath)
    print("--chunk: ", chunk)
    print("--split: ", split)
    print("--expid", expid)
    print("--app_names", app_names)
    print("--member", member)
    print("--realization", realization)
    print("--startdate", startdate)
    print("--restart_dir", restart_dir)
    print("--mask_file", mask_file)
    print("--log_level", log_level)

    # Load requests
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
    _validate_request_number(request_number, gsvrequests)

    gsvrequest = gsvrequests[request_number - 1]
    oparequest = oparequests[request_number - 1]

    # Configure OPA request
    save_filepath = _determine_save_filepath(outpath, mask_file)
    sanitize_request(
        oparequest, save_filepath=save_filepath, checkpoint_filepath=outpath
    )

    # Get and preprocess data
    gsv = GSVRetriever()
    data = gsv.request_data(gsvrequest, use_stream_iterator=read_from_databridge)
    data, mask_data = preprocess_mask(data, mask_file)
    data = data.compute()

    # Run OPA computation
    opa_stat = Opa(oparequest, logging_level=log_level)
    opa_stat.compute(data)

    # Postprocess and save results
    postprocess_mask(opa_stat, mask_data, save_filepath, outpath)
    cleanup_temporary_directory(save_filepath, outpath, mask_file)

    # Checkpoint if needed
    if _should_checkpoint(restart_dir, oparequest):
        opa_stat.checkpoint(restart_dir)

    return 0


if __name__ == "__main__":
    main()
