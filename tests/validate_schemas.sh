#!/usr/bin/env bash
set -euo pipefail

# this can be run without arguments and then it will run all of the simulations
# from the mains folder. Or you give the path of the main file to test as the argument. CI
# should always run all, but when you want to debug, you probably only want to test
# one specific simulation
#

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PATH="$SCRIPT_DIR:$PATH" # use local versions of yq
PATH="/home/autosubmit/.local/bin:$PATH" # use path from pipx



RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

AS_folder_file="${SCRIPT_DIR}/AS_folder"
AS_id_file="${SCRIPT_DIR}/AS_expid"

# make sure we have an experiment prepared already
if [[ ! -f "$AS_folder_file" || ! -f "$AS_id_file" ]]; then
    echo "No previously used experiment found. Creating it..."
    "$SCRIPT_DIR/generate_AS_test_experiment.sh"
fi
AS_folder=$(cat "$AS_folder_file")
AS_expid=$(cat "$AS_id_file")
echo "AS_folder: $AS_folder"
echo "AS_expid: $AS_expid"



if [ $# -gt 0 ]; then
    # cli arguments given
    simulations=("$@")
    for mainfile in "${simulations[@]}"
    do
        echo "$mainfile"
        cp $mainfile "${AS_folder}/conf/main.yml"

        echo "creating job files from mother request..."
        python3 ${SCRIPT_DIR}/../conf/create_jobs_from_mother_request.py --path-to-conf ${SCRIPT_DIR}/../conf --main "${AS_folder}/conf" --output-path ${SCRIPT_DIR}/../conf

        echo "running autosubmit create..."
        autosubmit create --noplot ${AS_expid}

        # schema validation can only be done on json files
        cat ${AS_folder}/conf/metadata/experiment_data.yml |yq e -o json > experiment_data_${AS_expid}.json

        jsonschema validate -v ./tests/schemas/main.schema.json experiment_data_${AS_expid}.json --resolve ./tests/schemas --extension schema.json
        retVal=$?
        if [ $retVal -ne 0 ]; then
            echo -e "${RED}Validation of ${mainfile} failed!${NC}"
        else
            echo -e "${GREEN}Validation of ${mainfile} suceeded!${NC}"
        fi
    done
else
    echo "No simulation provided. Testing complete catalog."
    for mainfile in "${SCRIPT_DIR}/../mains/"*.yml
    do
        echo "$mainfile"
        shortname="$(basename $mainfile .yml)"
        cp $mainfile "${AS_folder}/conf/main.yml"

        # always delete old jobs_end-to-end.yml and jobs_apps.yml
        rm -rf ${SCRIPT_DIR}../conf/jobs_end-to-end.yml
        rm -rf ${SCRIPT_DIR}../conf/jobs_apps.yml
        if [ $(yq .RUN.WORKFLOW "${AS_folder}/conf/main.yml") == "end-to-end" ] || [ $(yq .RUN.WORKFLOW "${AS_folder}/conf/main.yml") == "apps" ]
        then
          echo "creating job files from mother request..."
          python3 ${SCRIPT_DIR}/../conf/create_jobs_from_mother_request.py --path-to-conf ${SCRIPT_DIR}/../conf --main "${AS_folder}/conf/main.yml" --output-path ${SCRIPT_DIR}/../conf
        fi

        echo "running autosubmit create..."
        sed -i "s/PROJECT_SUBMODULES: ''/PROJECT_SUBMODULES: false/g" "${AS_folder}/conf/minimal.yml"
        autosubmit create --noplot ${AS_expid}

        # schema validation can only be done on json files
        # cat ${AS_folder}/conf/metadata/experiment_data.yml |yq e -o json > experiment_data_${shortname}.json
        cat ${AS_folder}/conf/metadata/experiment_data.yml | yq  e 'with_entries(select(.key | (test("RUN$") or test("MODEL$") or test("CONFIGURATION$") or test("REQUEST$") or test("EXPERIMENT$") or test("ICMCL$") or test("AQUA$"))  ))' -o json > experiment_data_${shortname}.json
        #jsonschema validate -v ./tests/schemas/main.json experiment_data_${shortname}.json --resolve ./tests/schemas --extension schema.json
        echo "Validating experiment_data_${shortname}.json with check-jsonschema"
        check-jsonschema --schemafile ./tests/schemas/main.schema.json experiment_data_${shortname}.json --verbose
        retVal=$?
        if [ $retVal -ne 0 ]; then
            echo -e "${RED}Validation of ${mainfile} failed!${NC}"
        else
            echo -e "${GREEN}Validation of ${mainfile} suceeded!${NC}"
        fi
    done
fi
