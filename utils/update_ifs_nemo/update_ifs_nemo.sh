#!/bin/bash

###############################################################################
# Script to update IFS-NEMO to a new version
# Compiles the model in the desired platform
# and runs a test simulation
#
# Usage: ./update_ifs_nemo.sh --version <version> --platform <platform> --branch <branch>
#
# Author: Aina Gaya, 2025
###############################################################################

# parse arguments --version and --platform
while [[ "$#" -gt 0 ]]; do
    case $1 in
    -v | --version)
        version="$2"
        shift
        ;;
    -p | --platform)
        platform="$2"
        shift
        ;;
    -b | --branch)
        branch="$2"
        shift
        ;;
    *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
    shift
done

module load autosubmit/4.1.12-dev-e326af7

if [ -z "$version" ] || [ -z "$platform" ]; then
    echo "Usage: $0 --version <version> --platform <platform>"
    exit 1
fi

if [ $platform == "marenostrum5" ]; then
    env=intel
elif [ $platform == "lumi" ]; then
    env=cray
else
    echo "Unknown platform: $platform"
    exit 1
fi

cd /appl/AS/AUTOSUBMIT_DATA/

# equivalent of %%capture output --no-stderr in bash
output=$({ autosubmit expid \
    --description "Update IFS-NEMO to ${version}" \
    --HPC ${platform} \
    --minimal_configuration \
    --git_as_conf conf/bootstrap/ \
    --git_repo https://earth.bsc.es/gitlab/digital-twins/de_340/workflow \
    --git_branch ${branch}; } 2>&1)

# capture the expid from the output, that is like this:

# Autosubmit is running with 4.1.12
# The new experiment "a28j" has been registered.
# Generating folder structure...
# Experiment folder: /appl/AS/AUTOSUBMIT_DATA/a28j
# Generating config files...
# Experiment a28j created

expid=$(echo "$output" | grep -oP '(?<=The new experiment ")(.*)(?=" has been registered)')
echo "expid: $expid"

cat >/appl/AS/AUTOSUBMIT_DATA/${expid}/conf/main.yml <<EOF
RUN:
  WORKFLOW: model
  ENVIRONMENT: ${env}
  PROCESSOR_UNIT: cpu
  TYPE: test
MODEL:
  NAME: ifs-nemo
  SIMULATION: test-ifs-nemo
  GRID_ATM: tco79l137
  GRID_OCE: eORCA1_Z75
  VERSION: ${version}
  DVC_INPUTS_BRANCH: "ClimateDT-phase2"
  COMPILE: "True"
  INPUTS: "%HPCROOTDIR%/%PROJECT.PROJECT_DESTINATION%/dvc-cache-de340"
EXPERIMENT:
  DATELIST: 19900101 #Startdate
  MEMBERS: fc0
  CHUNKSIZEUNIT: month
  CHUNKSIZE: 1
  NUMCHUNKS: 2
  CALENDAR: standard
CONFIGURATION:
  RAPS_EXPERIMENT: "control"
  RAPS_USER_FLAGS: "--inproot-namelists"
  ADDITIONAL_JOBS:
    TRANSFER: "False"
    BACKUP: "False"
    WIPE: "False"
    MEMORY_CHECKER: "True"
    DQC: "True"
    CLEAN: "True"
    AQUA: "True"
EOF

autosubmit create $expid -np
nohup autosubmit run $expid >/appl/AS/AUTOSUBMIT_DATA/${expid}/autosubmit.log 2>&1 &
echo "Experiment $expid started"
