#!/bin/bash

###############################################################################
# Script to update IFS-NEMO to a new version
# Compiles the model in LUMI and MN5
# Pushes the changes to the workflow repository
# and runs a test simulation
#
# Usage: ./update_ifs_nemo.sh --version <version>
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
    *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
    shift
done

module load autosubmit/4.1.12-dev-mem-fixes

if [ -z "$version" ]; then
    echo "Usage: $0 --version <version>"
    exit 1
fi

platform="marenostrum5"
env="intel"

cd /appl/AS/AUTOSUBMIT_DATA/

function create_expid() {
    local version=$1
    local platform=$2
    local branch=${3:-main}
    autosubmit expid \
        --description "Update IFS-NEMO to ${version}" \
        --HPC ${platform} \
        --minimal_configuration \
        --git_as_conf conf/bootstrap/ \
        --git_repo https://earth.bsc.es/gitlab/digital-twins/de_340/workflow \
        --git_branch $branch
}

function create_main() {
    local expid=$1
    local version=$2
    local platform=$3
    local env=$4
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

}

output=$(create_expid $version $platform)

# capture the expid from the output, that is like this:

# Autosubmit is running with 4.1.12
# The new experiment "a28j" has been registered.
# Generating folder structure...
# Experiment folder: /appl/AS/AUTOSUBMIT_DATA/a28j
# Generating config files...
# Experiment a28j created
expid_mn5=$(echo "$output" | grep -oP '(?<=The new experiment ")(.*)(?=" has been registered)')
echo "expid: $expid_mn5"

create_main $expid_mn5 $version $platform $env
autosubmit create $expid_mn5 -np

cd /appl/AS/AUTOSUBMIT_DATA/${expid_mn5}/proj/git_project/
git checkout -b "update-ifs-nemo-${version}"
cd /appl/AS/AUTOSUBMIT_DATA/${expid_mn5}/proj/git_project/ifs-nemo
git pull origin ${version}
cd ..
git add ifs-nemo
git commit -m "update ifs-nemo to ${version}"
git push origin "update-ifs-nemo-${version}"

nohup autosubmit run $expid_mn5 >/appl/AS/AUTOSUBMIT_DATA/${expid_mn5}/autosubmit.log 2>&1 &
echo "Experiment $expid_mn5 started"

platform=lumi
env=cray
output=$(create_expid $version $platform update-ifs-nemo-${version})
expid_lumi=$(echo "$output" | grep -oP '(?<=The new experiment ")(.*)(?=" has been registered)')
create_main $expid_lumi $version $platform $env
autosubmit create $expid_lumi -np
nohup autosubmit run $expid_lumi >/appl/AS/AUTOSUBMIT_DATA/${expid_mn5}/autosubmit.log 2>&1 &
echo "Experiment $expid_lumi started"

# Write message for GitLab
echo "Experiment $expid_mn5 started in MN5 and $expid_lumi started in LUMI"
echo "Check the status of the experiments in the Autosubmit GUI"
echo "https://climatedt-wf.csc.fi/experiment/${expid_mn5}/quick"
echo "https://climatedt-wf.csc.fi/experiment/${expid_lumi}/quick"
