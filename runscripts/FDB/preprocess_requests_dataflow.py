import argparse
import yaml
import os


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="Generate YAML files per variable from an application dictionary."
    )
    parser.add_argument(
        "--file", help="YAML file with application dictionary or direct requests."
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
    return parser.parse_args(argv)


def main(argv=None):
    # Parse command line arguments
    args = parse_args(argv)
    omit_keys = set(k.strip() for k in args.omit_keys.split(",") if k.strip())

    # Load YAML
    with open(args.file, "r") as f:
        root = yaml.safe_load(f)

    os.makedirs(args.output_dir, exist_ok=True)

    # Normalize entries: accept either app structure or direct requests
    if (
        isinstance(root, dict)
        and len(root) == 1
        and isinstance(next(iter(root.values())), dict)
    ):
        # application structure (e.g. ENERGY_INDICATORS)
        app_name = next(iter(root))
        entries = root[app_name]
    else:
        # Direct request(s) → wrap into pseudo-entries
        if isinstance(root, dict):
            entries = {"REQ": {"GSVREQUEST": root}}
        elif isinstance(root, list):
            entries = {f"REQ{i}": {"GSVREQUEST": r} for i, r in enumerate(root, 1)}
        else:
            raise ValueError("Unsupported YAML structure")
    for key, item in entries.items():
        if "GSVREQUEST" in item:
            requests = [item["GSVREQUEST"]]
        else:
            print(f"Skipping entry {key}: no 'GSVREQUEST(S)' key.")
            continue

        for idx, gsv in enumerate(requests, start=1):
            variable = gsv.get("param")
            stream = gsv.get("stream", "")

            if not variable:
                print(f"Skipping entry {key}, request {idx}: no 'param' key.")
                continue

            # Determine date-format
            date_format = "date" if stream == "clte" else "month"

            # Filter mars-keys
            mars_keys = {
                k: v for k, v in gsv.items() if v is not None and k not in omit_keys
            }

            # Construct output YAML content
            output_data = {"date-format": date_format, "mars-keys": mars_keys}

            # Handle param list for filename
            param_str = (
                "-".join(map(str, variable))
                if isinstance(variable, list)
                else str(variable)
            )
            suffix = f"_{idx}" if len(requests) > 1 else ""
            filename = f"{param_str}_{args.jobname}{suffix}.yaml"
            output_path = os.path.join(args.output_dir, filename)

            with open(output_path, "w") as out_file:
                yaml.dump(output_data, out_file, sort_keys=False)

            print(f"Written {output_path}")


if __name__ == "__main__":
    main()
