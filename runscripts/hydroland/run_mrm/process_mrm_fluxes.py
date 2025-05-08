#!/usr/bin/env python3
import argparse
import os
import shutil

import xarray as xr


def merge_two_files(file1: str, file2: str, outfile: str) -> None:
    """
    Merge two NetCDF files using xarray.

    Opens each file and attempts to merge them by aligning on their coordinates.
    If xr.combine_by_coords fails, it falls back to ds1.combine_first(ds2).
    Before writing the merged dataset, conflicting encoding attributes
    (_FillValue and missing_value) for "lon" and "lat" are removed.
    """
    print(f"Merging files:\n  {file1}\n  {file2}\ninto\n  {outfile}")
    ds1 = xr.open_dataset(file1)
    ds2 = xr.open_dataset(file2)
    try:
        ds_merged = xr.combine_by_coords([ds1, ds2])
    except Exception as e:
        print("combine_by_coords failed, using combine_first:", e)
        ds_merged = ds1.combine_first(ds2)
    # Remove conflicting encoding attributes for coordinate variables.
    for coord in ["lon", "lat"]:
        if coord in ds_merged:
            ds_merged[coord].encoding.pop("_FillValue", None)
            ds_merged[coord].encoding.pop("missing_value", None)
    ds_merged.to_netcdf(outfile)
    ds1.close()
    ds2.close()


def merge_files(
    prefix_in: str,
    num_in: int,
    prefix_out: str,
    num_out: int,
    num_pairs: int,
    current_mrm_dir: str,
) -> None:
    """
    Merge files in pairs using the given prefixes.

    For instance, merge:
      {prefix_in}_1.nc and {prefix_in}_2.nc  => {prefix_out}_1.nc,
      {prefix_in}_3.nc and {prefix_in}_4.nc  => {prefix_out}_2.nc, etc.
    """
    i = 1
    j = 2
    num = 1
    while num_pairs > 0:
        if j <= num_in:
            file1 = os.path.join(current_mrm_dir, f"{prefix_in}_{i}.nc")
            file2 = os.path.join(current_mrm_dir, f"{prefix_in}_{j}.nc")
            outfile = os.path.join(current_mrm_dir, f"{prefix_out}_{num}.nc")
            merge_two_files(file1, file2, outfile)
        i += 2
        j += 2
        num += 1
        num_pairs -= 1


def main(args: argparse.Namespace) -> None:
    current_mrm_dir = args.current_mrm_dir
    mrm_out_file = args.mrm_out_file

    # --- Merging mRM fluxes ---
    # Copy subdomain_53/output/mRM_Fluxes_States.nc to temp_second_loop_14.nc
    src = os.path.join(
        current_mrm_dir, "subdomain_53", "output", "mRM_Fluxes_States.nc"
    )
    dst = os.path.join(current_mrm_dir, "temp_second_loop_14.nc")
    print(f"Copying {src} to {dst}")
    shutil.copy(src, dst)

    # --- Initial merge of subdomain files ---
    # Merge pairs: subdomain_1 with subdomain_2, subdomain_3 with subdomain_4, …, subdomain_51 with subdomain_52.
    i = 1
    j = 2
    num = 1
    while j <= 52:
        infile1 = os.path.join(
            current_mrm_dir, f"subdomain_{i}", "output", "mRM_Fluxes_States.nc"
        )
        infile2 = os.path.join(
            current_mrm_dir, f"subdomain_{j}", "output", "mRM_Fluxes_States.nc"
        )
        outfile = os.path.join(current_mrm_dir, f"temp_first_loop_{num}.nc")
        merge_two_files(infile1, infile2, outfile)
        i += 2
        j += 2
        num += 1

    # --- Subsequent merge operations using merge_files() ---
    merge_files("temp_first_loop", 26, "temp_second_loop", 14, 13, current_mrm_dir)
    merge_files("temp_second_loop", 14, "temp_third_loop", 7, 7, current_mrm_dir)
    merge_files("temp_third_loop", 7, "temp_fourth_loop", 4, 4, current_mrm_dir)

    # Rename temp_third_loop_7.nc to temp_fourth_loop_4.nc (as in the original bash script)
    src_file = os.path.join(current_mrm_dir, "temp_third_loop_7.nc")
    dst_file = os.path.join(current_mrm_dir, "temp_fourth_loop_4.nc")
    print(f"Renaming {src_file} to {dst_file}")
    os.rename(src_file, dst_file)

    merge_files("temp_fourth_loop", 4, "temp_fifth_loop", 2, 2, current_mrm_dir)

    # Final merge: merge temp_fifth_loop_1.nc and temp_fifth_loop_2.nc to produce the final output file.
    infile1 = os.path.join(current_mrm_dir, "temp_fifth_loop_1.nc")
    infile2 = os.path.join(current_mrm_dir, "temp_fifth_loop_2.nc")
    final_out = os.path.join(current_mrm_dir, mrm_out_file)
    merge_two_files(infile1, infile2, final_out)
    print("Final merged file created:", final_out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Merge mRM fluxes using xarray.")
    parser.add_argument(
        "--current_mrm_dir", required=True, help="Current mRM directory"
    )
    parser.add_argument("--mrm_out_file", required=True, help="MRM output file name")
    args = parser.parse_args()
    main(args)
