#! /usr/bin/env python3
# -*- coding: utf-8 -*-

"""
=================
Copyright
=================
Copyright © 2023 STORMS, DestinE
* Created by [ STORMS ] on 27 January 2023
* Modified by [ DestinE ] on 18 March 2025
* author: Clément Bouvier (STORMS, DestinE)
"""

# ======================
# Imports Modules
# ======================
from Synop import Synop
from Temp import Temp
from AMSUA import AMSUA
from Input import Input, JSONInput
import Config
import LoggerInit
import logging
import json
import argparse

# ======================
# GLOBALS
# ======================

LoggerInit.init()
logger = logging.getLogger(__file__)
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="OBSALL application")
    group = parser.add_mutually_exclusive_group()
    print(group)
    # For JSON as input:
    group.add_argument(
        "--inputFile",
        "-i",
        type=argparse.FileType("r"),
        # default=sys.stdin,
        help="Input file name containing a valid JSON",
    )
    group.add_argument(
        "--config", type=bool, default=False, help="Run without any input"
    )
    parser.add_argument("--outputFile", "-o", type=str, help="Output file name")

    # For classic command line:
    parser.add_argument(
        "--dataType",
        type=str,
        default="SYNOP",
        help="data_type name (between SYNOP, TEMP and AMSUA)",
    )
    parser.add_argument(
        "--runType",
        type=str,
        default="HadISD",
        help="run_type (between test, FMI and HadISD)",
    )
    parser.add_argument(
        "--dataPathIn", type=str, default="", help="Path to the input data repository"
    )
    parser.add_argument(
        "--dataPathOut", type=str, default="", help="Path to the output data repository"
    )
    parser.add_argument(
        "--expName",
        type=str,
        default="test_clement",
        help="Name of the OBSALL experiment",
    )
    parser.add_argument("--sDate", type=int, help="Start date in the format YYYYMMDDHH")
    parser.add_argument("--eDate", type=int, help="End date in the format YYYYMMDDHH")
    parser.add_argument(
        "--cleanScratch",
        type=bool,
        default=False,
        help="Flag to clean intermediate data",
    )
    parser.add_argument(
        "--restart",
        type=bool,
        default=False,
        help="Flag to force the deletion of previously generated data",
    )
    parser.add_argument(
        "--grid",
        type=str,
        default="1.0/1.0",
        help="Horizontal resolution (between 1.0/1.0, 0.25/0.25, 0.1/0.1)",
    )
    parser.add_argument("--expID", type=str, default="a216", help="Model experiment ID")
    parser.add_argument(
        "--timeStep",
        type=str,
        default="0100",
        help="Timestep of the model experiment in the format of HHMM",
    )
    parser.add_argument(
        "--metVariable",
        dest="metVariable",
        nargs="+",
        help="List of meteorological variable codes",
    )
    parser.add_argument(
        "--obsPath", type=str, default="", help="Path to the observation data"
    )
    parser.add_argument(
        "--graphCompute",
        type=bool,
        default=False,
        help="Flag to trigger graph computation",
    )
    parser.add_argument(
        "--mode", type=str, default="offline", help="Offline or online mode."
    )
    parser.add_argument(
        "--GsvDataDump",
        type=str,
        default="",
        help="Path to raw GSV data. To be used in online mode. ",
    )

    args = parser.parse_args()
    # read_input_from_json = True
    data = {}
    logger.info("Parse arguments")
    if args.inputFile:  # args.json or args.inputFile
        data = args.inputFile.read()
        logger.info("Load json file")
        data = json.loads(data)
        logger.info("Convert JSON arguments")
        data = JSONInput.jsonConvert(data, args.outputFile)
    elif args.config:
        data = Input(
            args.outputFile,
            Config.data_type,
            Config.run_type,
            Config.python_rep,
            Config.exp_name,
            Config.sdate,
            Config.edate,
            Config.clean_scratch,
            Config.restart,
            Config.grid,
            Config.climate_simulation,
            Config.timestep,
            Config.met_variable,
            Config.obs_path_in,
            Config.obs_path_out,
            Config.graph_compute,
            Config.mode,
            Config.GsvDataDump,
        )
    else:
        data = Input(
            args.outputFile,
            args.dataType,
            args.runType,
            args.dataPathIn,
            args.dataPathOut,
            args.expName,
            args.sDate,
            args.eDate,
            args.cleanScratch,
            args.restart,
            args.grid,
            args.expID,
            args.timeStep,
            args.metVariable,
            args.obsPath,
            args.graphCompute,
            args.mode,
            args.GsvDataDump,
        )

    logger.info("Run OBSALL")
    if data.dataType == "SYNOP":
        logger.info("Run SYNOP")
        synop = Synop(data)
        synop.creation_data_structure()
        synop.process_data()
    elif data.dataType == "TEMP":
        logger.info("Run TEMP")
        temp = Temp(data)
        temp.creation_data_structure()
        temp.process_data()
    elif data.dataType == "AMSUA":
        logger.info("Run AMSU-A")
        amsua = AMSUA(data)
        amsua.creation_data_structure()
        amsua.process_data()
    output = {}

    # CODE CONNAISSANCE METIER
    # synop.generate_message()
    # logger.info("Message generated")
    # synop.save_txt_file()
    # logger.info("Greetings have been written in the output file")

    if data.outputFile is not None:
        with open(args.outputFile, "w") as json_file:
            json.dump(output, json_file)
    logger.info(output)
