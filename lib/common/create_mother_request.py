# This is the script to create the mother request in the app-workflow
import logging
from itertools import chain
from pathlib import Path
from typing import Dict, Union

import yaml


def main():
    """Combine many request files into a single (mother) request."""

    # Define the directory where you want to start the search
    start_dir = "../../conf/applications/"

    logging.debug("Start directory [%s]", start_dir)

    allvariables = set()

    # Find any .yaml, .yml, .YAML, etc., files.
    for file_path in chain(
        Path(start_dir).rglob("*.[yY][mM][lL]"),
        Path(start_dir).rglob("*.[yY][aA][mM][lL]"),
    ):
        with open(file_path, "r") as request:
            oparequest: Dict[str, Union[str, Dict]] = yaml.load(
                request, Loader=yaml.FullLoader
            )
            logging.debug("----------------")
            logging.debug(oparequest)
            for variable_entry in oparequest["OPAREQUEST"].items():
                if variable_entry[0] != "NSTATS":
                    ivar = variable_entry[1]
                    logging.debug(ivar)
                    allvariables.add(tuple(ivar))

    output_dict = {
        k: dict(v) for k, v in zip(range(1, len(allvariables) + 1), allvariables)
    }
    mother_request = {
        "GSVREQUEST": oparequest[
            "GSVREQUEST"
        ],  # Using the last GSV loaded as we expect them to be the same for now.
        "OPAREQUEST": output_dict,
    }
    logging.debug("Mother request:")
    logging.debug(mother_request)

    # Define the output file name
    output_file = "../mother_request.yml"

    # Write the dictionary to a YAML file with the desired format
    with open(output_file, "w") as yaml_file:
        yaml.dump(mother_request, yaml_file, default_flow_style=False)

    print(f"DataFrame has been converted to {output_file}.")


if __name__ == "__main__":
    main()
