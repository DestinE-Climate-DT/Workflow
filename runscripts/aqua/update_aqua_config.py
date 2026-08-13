#!/usr/bin/env python3
"""
Update AQUA YAML configuration files for experiment-local grid building.

Called from remote_setup_utils.sh (inside the AQUA Singularity container)
when AQUA_GRID_BUILD is enabled. Replaces inline python3 -c blocks with
a standalone, testable script.

Usage:
    python3 update_aqua_config.py update-paths \
        --machine_yaml <path> --platform <name> --data_dir <path>
    python3 update_aqua_config.py update-grids \
        --matching_grids_yaml <path> --model <name> --profile <name> \
        --atm_grid <grid> --ocean_grid <grid>
    python3 update_aqua_config.py update-realizations \
        --catalog_file <path> --realizations "16 17 18"
"""

import argparse
import os
import sys
import yaml


def update_paths(args):
    """Update grids/weights/areas paths in machine.yaml for a given platform."""
    machine_yaml = args.machine_yaml
    platform = args.platform
    data_dir = args.data_dir

    if not os.path.isfile(machine_yaml):
        print(f"ERROR: File not found: {machine_yaml}", file=sys.stderr)
        return 1

    with open(machine_yaml, "r") as f:
        data = yaml.safe_load(f)

    if platform not in data:
        print(
            f"ERROR: Platform '{platform}' not found in {machine_yaml}", file=sys.stderr
        )
        return 1
    if "paths" not in data[platform]:
        print(
            f"ERROR: No 'paths' section under '{platform}' in {machine_yaml}",
            file=sys.stderr,
        )
        return 1

    data[platform]["paths"]["grids"] = f"{data_dir}/grids"
    data[platform]["paths"]["weights"] = f"{data_dir}/weights"
    data[platform]["paths"]["areas"] = f"{data_dir}/areas"

    with open(machine_yaml, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)

    print(f"Updated {machine_yaml} for platform {platform}:")
    print(f"  grids:   {data_dir}/grids")
    print(f"  weights: {data_dir}/weights")
    print(f"  areas:   {data_dir}/areas")
    return 0


def update_grids(args):
    """Update atm_grid and ocean_grid entries in matching_grids.yaml."""
    matching_grids_yaml = args.matching_grids_yaml
    model = args.model
    profile = args.profile
    atm_grid = args.atm_grid
    ocean_grid = args.ocean_grid

    if not os.path.isfile(matching_grids_yaml):
        print(f"ERROR: File not found: {matching_grids_yaml}", file=sys.stderr)
        return 1

    with open(matching_grids_yaml, "r") as f:
        data = yaml.safe_load(f)

    if "atm_grid" in data and model in data["atm_grid"]:
        data["atm_grid"][model][profile] = atm_grid
    else:
        print(
            f"WARNING: atm_grid.{model} not found in {matching_grids_yaml}",
            file=sys.stderr,
        )

    if "ocean_grid" in data and model in data["ocean_grid"]:
        data["ocean_grid"][model][profile] = ocean_grid
    else:
        print(
            f"WARNING: ocean_grid.{model} not found in {matching_grids_yaml}",
            file=sys.stderr,
        )

    with open(matching_grids_yaml, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)

    print(f"Updated {matching_grids_yaml}:")
    print(f"  atm_grid.{model}.{profile} = {atm_grid}")
    print(f"  ocean_grid.{model}.{profile} = {ocean_grid}")
    return 0


def update_realizations(args):
    """Sets a catalog entry's realizations to the experiment's actual set.

    catgen only knows the member count, so it writes ``allowed: [1..N]``. This needs to be changed if the ensemble does not start at ``fc0``.
    """
    catalog_file = args.catalog_file
    realizations = sorted({int(x) for x in args.realizations.split()})

    if not os.path.isfile(catalog_file):
        print(f"ERROR: File not found: {catalog_file}", file=sys.stderr)
        return 1
    if not realizations:
        print("ERROR: No realizations provided", file=sys.stderr)
        return 1

    with open(catalog_file, "r") as f:
        data = yaml.safe_load(f)

    updated = 0
    for source in (data.get("sources") or {}).values():
        realization = (source.get("parameters") or {}).get("realization")
        if realization is not None:
            # fresh list per source so PyYAML does not emit anchors/aliases
            realization["allowed"] = list(realizations)
            realization["default"] = realizations[0]
            updated += 1
        elif len(realizations) == 1:
            # single-member entries have no parameter block, so pin the request instead
            request = (source.get("args") or {}).get("request")
            if request is not None and "realization" in request:
                request["realization"] = realizations[0]
                updated += 1

    with open(catalog_file, "w") as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)

    print(f"Updated {catalog_file}: {updated} source(s)")
    print(f"  realizations: {realizations}")
    return 0


def _get_parser():
    """Build argument parser for update_aqua_config."""
    parser = argparse.ArgumentParser(
        description="Update AQUA config YAML files for grid building"
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # update-paths subcommand
    p_paths = subparsers.add_parser(
        "update-paths", help="Update machine.yaml grid paths"
    )
    p_paths.add_argument(
        "--machine_yaml", type=str, required=True, help="Path to machine.yaml"
    )
    p_paths.add_argument(
        "--platform",
        type=str,
        required=True,
        help="Platform key (e.g. lumi-o26.1, MN5-o26.1)",
    )
    p_paths.add_argument(
        "--data_dir",
        type=str,
        required=True,
        help="Base data directory (e.g. /path/to/aqua-data)",
    )

    # update-grids subcommand
    p_grids = subparsers.add_parser("update-grids", help="Update matching_grids.yaml")
    p_grids.add_argument(
        "--matching_grids_yaml",
        type=str,
        required=True,
        help="Path to matching_grids.yaml",
    )
    p_grids.add_argument(
        "--model", type=str, required=True, help="Model name (e.g. ifs-fesom)"
    )
    p_grids.add_argument(
        "--profile",
        type=str,
        required=True,
        help="DQC profile (e.g. production, develop)",
    )
    p_grids.add_argument(
        "--atm_grid", type=str, required=True, help="Atmosphere grid (e.g. tco319)"
    )
    p_grids.add_argument(
        "--ocean_grid", type=str, required=True, help="Ocean grid (e.g. CORE2, eORCA1)"
    )

    # update-realizations subcommand
    p_reals = subparsers.add_parser(
        "update-realizations",
        help="Set a catalog entry's allowed realizations to an explicit set",
    )
    p_reals.add_argument(
        "--catalog_file",
        type=str,
        required=True,
        help="Path to the generated catalog entry YAML (e.g. .../<expver>.yaml)",
    )
    p_reals.add_argument(
        "--realizations",
        type=str,
        required=True,
        help='Space-separated realization integers (e.g. "16 17 18")',
    )

    return parser


def main():
    """Run update_aqua_config."""
    args = _get_parser().parse_args()

    print("--command: ", args.command)

    if args.command == "update-paths":
        print("--machine_yaml: ", args.machine_yaml)
        print("--platform: ", args.platform)
        print("--data_dir: ", args.data_dir)
        return update_paths(args)
    elif args.command == "update-grids":
        print("--matching_grids_yaml: ", args.matching_grids_yaml)
        print("--model: ", args.model)
        print("--profile: ", args.profile)
        print("--atm_grid: ", args.atm_grid)
        print("--ocean_grid: ", args.ocean_grid)
        return update_grids(args)
    elif args.command == "update-realizations":
        print("--catalog_file: ", args.catalog_file)
        print("--realizations: ", args.realizations)
        return update_realizations(args)

    return 1


if __name__ == "__main__":
    sys.exit(main())
