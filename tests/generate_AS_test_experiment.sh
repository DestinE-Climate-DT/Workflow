#!/usr/bin/env bash
set -euo pipefail
set -x

# sed on osx needs empty quotes for temp file
if [ $(uname -s) == "Darwin" ]; then
    SED="sed -i ''"
else
    SED="sed -i"
fi

# we are not using autosubmit to clone the workflow, but rather link to the
# one that is currently checked out, so we make sure we use the branch that is
# being tested.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

AS_folder_file="${SCRIPT_DIR}/AS_folder"
AS_id_file="${SCRIPT_DIR}/AS_expid"

if [[ ! -f "$AS_folder_file" || ! -f "$AS_id_file" ]]; then
    echo "No previously used experiment found. Running autosubmit expid..."
    while read -r line; do
        if [[ "$line" == Experiment\ folder:* ]]; then
            AS_folder=$(echo "$line" | awk -F': ' '{print $2}')
        fi
        if [[ "$line" == The\ new\ experiment* ]]; then
            AS_expid=$(echo "$line" | awk -F'\"' '{print $2}')
        fi
    done < <(autosubmit expid --description 'reusable experiment for tests' --HPC lumi --minimal_configuration --git_as_conf conf/bootstrap/)

    # Save the variables to files
    echo "$AS_folder" > "$AS_folder_file"
    echo "$AS_expid" > "$AS_id_file"
    echo "Info saved to files."

    # now we link the current folder to AS path
    mkdir -p "${AS_folder}/proj"
    ln -s "$SCRIPT_DIR/../" "${AS_folder}/proj/git_project"

    # and update the minimal.yml file
    line_origin=$(grep -n 'PROJECT_ORIGIN' "${AS_folder}/conf/minimal.yml" | cut -d ':' -f1)
    $SED "${line_origin}s,.*,  PROJECT_ORIGIN: \'https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow\'," "${AS_folder}/conf/minimal.yml"


else
    echo "Previously used experiment found. Loading from files..."
    AS_folder=$(cat "$AS_folder_file")
    AS_expid=$(cat "$AS_id_file")
    echo "AS_folder: $AS_folder"
    echo "AS_expid: $AS_expid"

fi
