import subprocess
import shlex
import argparse
import json


def calculate_memory_bloat(jobID, model_name, resolution):
    # Define restart sizes in GB for different models and resolutions
    restart_sizes = {
        "ICON": {"10km": 148, "5km": 592},
        "IFS-NEMO": {"10km": 200, "5km": 650},
        "IFS-FESOM": {"10km": 200, "5km": 650},
    }

    if model_name not in restart_sizes:
        print(
            f"Error: Unknown model name '{model_name}'. Valid options are: {', '.join(restart_sizes.keys())}"
        )
        return

    if resolution not in restart_sizes[model_name]:
        print(
            f"Error: Unknown resolution '{resolution}'. Valid options for {model_name} are: {', '.join(restart_sizes[model_name].keys())}"
        )
        return

    restart_size_GB = restart_sizes[model_name][resolution]

    # Execute sacct command and parse output
    sacct_command = f"sacct -j {jobID} --noconvert --noheader -o NTasks,MaxRSS"
    try:
        sacct_output = subprocess.check_output(
            shlex.split(sacct_command), universal_newlines=True
        ).strip()
        sa = " ".join(sacct_output.split())
        a = sa.split()

        if len(a) < 4:
            raise ValueError("Unexpected output format from sacct command")

        # Remove newline characters from a[3] (MaxRSS)
        a[3] = a[3].replace("\n", "")

        # Calculate memory bloat
        try:
            n_tasks = float(a[2])
            max_rss = float(a[3])
            memory_bloat = (n_tasks * max_rss) / (restart_size_GB * 1024 * 1024 * 1024)

            print(
                f"Memory bloat for job ID {jobID} ({model_name}, {resolution}): {memory_bloat:.2f}"
            )
        except ValueError:
            print("Error: Unable to parse numerical values from sacct output")

    except subprocess.CalledProcessError as e:
        print(f"Error executing sacct command: {e}")

    return {jobID: [model_name, resolution, memory_bloat]}


def parse_arguments(argv=None) -> argparse.Namespace:
    """
    Parse command line arguments.

    Returns
    -------
    argparse.Namespace
        Arguments parsed from the command line.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--jobID", help="JobID of the SIM chunk")
    parser.add_argument("--model", help="Climate model in use")
    parser.add_argument("--resolution", help="Spatial resolucion of the climate model")
    parser.add_argument("--jsonfile", help="Path to the resulting JSON file")

    return parser.parse_args(argv)


def main(argv=None):
    args = parse_arguments(argv)
    jobID = args.jobID
    model = args.model
    resolution = args.resolution
    dict = calculate_memory_bloat(jobID, model, resolution)

    # Write results in a JSON file, in the path specified by the json-file flag
    with open(args.jsonfile + ".json", "w") as f:
        json.dump(dict, f)


if __name__ == "__main__":
    main()
