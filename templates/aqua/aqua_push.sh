#!/bin/bash
#
# This step is in charge of syncing the plots coming from aqua-analysis to the aqua-web

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
ROOTDIR=${2:-%ROOTDIR%}
HPCUSER=${3:-%HPCUSER%}
HPCHOST=${4:-%HPCHOST%}
PROJDEST=${5:-%PROJECT.PROJECT_DESTINATION%}
MODEL=${6:-%REQUEST.MODEL%}
EXP=${7:-%REQUEST.EXPVER%}
APP_OUTPATH=${8:-%APP.OUTPATH%}
HPCARCH=${9:-%DEFAULT.HPCARCH%}
CATALOG=${10:-%HPCCATALOG_NAME%}
BUCKET=${11:-%AQUA.BUCKET%}
REPOSITORY=${12:-%AQUA.REPOSITORY%}

# END_HEADER

#####################################################
# Synchronizes file or directory to remote
# Globals:
# Arguments:
#   Remote user
#   Target host
#   Source file or directory
#   Target directory
#####################################################
function rsync_to_local() {
    echo "rsyncing the dir to the target platform"
    USR=$1
    HOST=$2
    SOURCE=$3
    TARGET=$4

    rsync -avp "${USR}"@"${HOST}":"${SOURCE}" "${TARGET}"
}

# MAIN code

cd "${ROOTDIR}"/proj

AQUA_ANALYSIS_RESULTS="${APP_OUTPATH}"/aqua-analysis
SOURCE="${AQUA_ANALYSIS_RESULTS}"/
TARGET="${ROOTDIR}"/aqua-analysis

mkdir -p $TARGET

# Sync the aqua-analysis results to the local proj directory
rsync_to_local "${HPCUSER}" "${HPCHOST}" "${SOURCE}" "${TARGET}"

indir="${ROOTDIR}"/aqua-analysis
exps=${CATALOG}/${MODEL}/${EXP}
branch=${EXP}

# Push the analysis results to aqua-web, using the code from a local copy of AQUA

# TODO: This should be done in a more general way, not hardcoding the path
# IDEALLY WITH A CONTAINER
LOCAL_AQUA=/appl/AS/AUTOSUBMIT_DATA/environments/AQUA
source ${LOCAL_AQUA}/aqua_venv/bin/activate

# Push the analysis results to aqua-web
${LOCAL_AQUA}/cli/aqua-web/push_analysis.sh --bucket ${BUCKET} --repository ${REPOSITORY} ${indir} ${exps}

# Rsync the new catalog entry to the catalog repository
SOURCE_CATALOG="${HPCROOTDIR}/${PROJDEST}/catalog/catalogs/${CATALOG}"/
TARGET_CATALOG="${ROOTDIR}"/proj/"${PROJDEST}"/catalog/catalogs/${CATALOG}/
rsync_to_local "${HPCUSER}" "${HPCHOST}" "${SOURCE_CATALOG}" "${TARGET_CATALOG}"

# Commit and push the new catalog entry to the catalog repository
cd ${TARGET_CATALOG}

# Check if the remote branch exists
if git ls-remote --exit-code origin ${branch} >/dev/null 2>&1; then
    echo "Branch ${branch} exists on remote"
    # Check if there are changes to commit
    if git diff-index --quiet HEAD --; then
        echo "No changes to commit, skipping all operations"
    else
        git add .
        git commit -m "Update catalog entry for ${MODEL} ${EXP}"
        git checkout -B ${branch}
        git fetch origin ${branch}
        # Merge strategy with preference for preserving local changes
        if ! git merge -s recursive -X ours origin/${branch}; then
            echo "Merge failed. Attempting to resolve conflicts."
            git merge origin/${branch}
        fi
        # Check if there are any changes to push
        if [[ $(git cherry -v origin/${branch}) ]]; then
            # Push only if there are local commits not on the remote
            git push origin ${branch}
            echo "Successfully pushed to ${branch}"
        else
            echo "No changes to push"
        fi
    fi
else
    echo "Branch ${branch} does not exist on remote, creating it"
    git add .
    git commit -m "New catalog entry for ${MODEL} ${EXP}"

    # Create and push the new branch
    git checkout -B ${branch}
    git push origin ${branch}
    echo "Successfully created and pushed to ${branch}"
fi
