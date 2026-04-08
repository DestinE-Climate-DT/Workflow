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
MODEL=${6:-%REQUEST.MODEL_NAME_UPPER%}
EXP=${7:-%REQUEST.EXPVER%}
APP_OUTPATH=${8:-%APP.OUTPATH%}
HPCARCH=${9:-%DEFAULT.HPCARCH%}
CATALOG=${10:-%HPCCATALOG_NAME%}
BUCKET=${11:-%AQUA.BUCKET%}
REPOSITORY=${12:-%AQUA.REPOSITORY%}
CONTAINER_DIR=${13:-%CURRENT_CONTAINER_DIR%}
CONTAINER_VERSION=${14:-%AQUA.CONTAINER_VERSION%}
PUSH_FIGURES=${15:-%CURRENT_PUSH_FIGURES%}
PUSH_CATALOG=${16:-%CURRENT_PUSH_CATALOG%}
MEMBER=${17:-%MEMBER%}
MEMBER_LIST=${18:-%EXPERIMENT.MEMBERS%}
AWS_PROFILE=${19:-%AQUA.AWS_PROFILE%}
EXPERIMENT_NAME=${20:-%AQUA.EXPERIMENT_NAME%}

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

function push_figures() {
    echo "Pushing figures to aqua-web"
    singularity exec \
        --cleanenv \
        --env BUCKET=${BUCKET} \
        --env REPOSITORY=${REPOSITORY} \
        --env indir=${indir} \
        --env exps=${exps} \
        --env PYTHONUSERBASE=1 \
        --env SSH_AUTH_SOCK="${SSH_AUTH_SOCK}" \
        --env AWS_PROFILE=${AWS_PROFILE} \
        --bind "${SSH_AUTH_SOCK}" \
        --bind "${indir}" \
        --no-mount /etc/localtime \
        ${AQUA_CONTAINER} \
        bash -c " \
			ls ${SSH_AUTH_SOCK}
			unset AWS_ACCESS_KEY_ID
			unset AWS_SECRET_ACCESS_KEY
			export AWS_PROFILE=${AWS_PROFILE}
			/app/AQUA/cli/aqua-web/push_analysis.sh \
			--bucket ${BUCKET} --repository ${REPOSITORY} \
			${indir} ${exps} "
}

function push_updated_catalog() {
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
            git commit -m "Update catalog entry for ${MODEL} ${EXPERIMENT_NAME}"
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
        git commit -m "New catalog entry for ${MODEL} ${EXPERIMENT_NAME}"

        # Create and push the new branch
        git checkout -B ${branch}
        git push origin ${branch}
        echo "Successfully created and pushed to ${branch}"
    fi
}

# MAIN code
LIBDIR="${ROOTDIR}"/proj/"${PROJDEST}"/lib
. "${LIBDIR}"/common/util.sh

cd "${ROOTDIR}"/proj

AQUA_ANALYSIS_RESULTS="${APP_OUTPATH}"/aqua-analysis
SOURCE="${AQUA_ANALYSIS_RESULTS}"/
TARGET="${ROOTDIR}"/aqua-analysis

mkdir -p $TARGET

# Sync the aqua-analysis results to the local proj directory
rsync_to_local "${HPCUSER}" "${HPCHOST}" "${SOURCE}" "${TARGET}"

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

indir="${ROOTDIR}"/aqua-analysis
exps=${CATALOG}/${MODEL}/${EXPERIMENT_NAME}/r${REALIZATION}
branch=${EXPERIMENT_NAME}

AQUA_CONTAINER="${CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"

# Rsync the new catalog entry to the catalog repository
SOURCE_CATALOG="${HPCROOTDIR}/${PROJDEST}/catalog/catalogs/${CATALOG}"/
TARGET_CATALOG="${ROOTDIR}"/proj/"${PROJDEST}"/catalog/catalogs/${CATALOG}/
rsync_to_local "${HPCUSER}" "${HPCHOST}" "${SOURCE_CATALOG}" "${TARGET_CATALOG}"

if [ "${PUSH_FIGURES,,}" == "true" ]; then
    push_figures
else
    echo "Skipping pushing figures to aqua-web"
fi

if [ "${PUSH_CATALOG,,}" == "true" ]; then
    push_updated_catalog
else
    echo "Skipping pushing updated catalog to aqua-web"
fi
