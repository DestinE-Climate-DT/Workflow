import argparse
import logging
from pathlib import Path

import yaml

from gsv.derived.derived import get_derived_variables_components
from gsv.requests.parser import parse_request


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Generate YAML files per variable from an application dictionary."
    )
    parser.add_argument(
        "--file", help="YAML file with application dictionary (e.g. ENERGY_INDICATORS)."
    )
    parser.add_argument(
        "--omit-keys",
        help="Comma-separated list of keys to omit from mars-keys (e.g., grid,method,area).",
        default="",
    )
    parser.add_argument(
        "--output-dir",
        help="Directory to write the output YAML files (default: output_variables).",
        default="output_variables",
    )
    parser.add_argument(
        "--jobname",
        help="Job name to use as a suffix in output file names (e.g., myjob → v_myjob.yaml).",
        required=True,
    )
    parser.add_argument(
        "--process-derived-variables",
        help="Process derived variables (default: False).",
        action="store_true",
    )
    parser.add_argument(
        "--realization",
        help="Define the realization to be read.",
        default="1",
    )
    return parser.parse_args(argv)


def main(argv=None):
    """
    Main function to convert a YAML application dictionary into individual
    YAML files following the DQC profile structure.
    """
    # Parse command line arguments
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.DEBUG)

    # Parse CL arguments
    args = parse_args(argv)

    # Get set of omit keys
    omit_keys = set(k.strip() for k in args.omit_keys.split(",") if k.strip())

    # Load YAML
    with open(args.file, "r") as f:
        root = yaml.safe_load(f)

    # Validate structure
    if len(root) != 1:
        raise ValueError(
            "Expected exactly one top-level application key (e.g. ENERGY_INDICATORS)."
        )

    # Get list of requested variables
    app_requests = next(iter(root.values()))

    # Generate output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    for key, item in app_requests.items():
        gsv = item.get("GSVREQUEST", {})
        variable = gsv.get("param")
        stream = gsv.get("stream", "")

        if not variable:
            print(f"Skipping entry {key}: no 'param' key in GSVREQUEST.")
            continue

        # Determine date-format
        date_format = "date" if stream == "clte" else "month"

        # Filter mars-keys
        mars_keys = {
            k: v for k, v in gsv.items() if v is not None and k not in omit_keys
        }

        # Define realization number
        mars_keys["realization"] = args.realization

        if args.process_derived_variables:
            print("Processing derived variables...")
            request = parse_request(mars_keys)
            print(f"Before: {request}")
            mars_keys = get_derived_variables_components(request, logger=logger)
            print(f"After: {mars_keys}")

        # Construct output YAML content
        output_data = {"date-format": date_format, "mars-keys": mars_keys}

        # Write YAML file
        filename = f"{variable}_{args.jobname}.yaml"
        output_path = output_dir / filename

        with open(output_path, "w") as out_file:
            yaml.dump(output_data, out_file, sort_keys=False)

        print(f"Written {output_path}")


if __name__ == "__main__":
    main()
