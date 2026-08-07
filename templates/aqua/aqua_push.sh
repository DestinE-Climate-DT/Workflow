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
RUN_LRA_GENERATOR=${21:-%CONFIGURATION.ADDITIONAL_JOBS.LRA%}
PREV_AQUA_EXP=${22:-%AQUA.PREV_EXP%}
RESOLUTION=${23:-%MODEL.RESOLUTION%}

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
			--bucket ${BUCKET} --repository ${REPOSITORY} --no-update \
			${indir} ${exps}"
}

#####################################################
# True if this member's realization is already on the
# remote catalog branch (pushed by a sibling member).
# Globals:
#   branch, CATALOG, MODEL_AND_RES, EXPERIMENT_NAME, REALIZATION
#####################################################
function realization_on_remote() {
    ENTRY="catalogs/${CATALOG}/catalog/${MODEL_AND_RES}/${EXPERIMENT_NAME}.yaml"

    git fetch -q origin "${branch}" || return 1
    # Anchored so that r1 does not match r10
    git show "origin/${branch}:${ENTRY}" 2>/dev/null |
        grep -qE "^[[:space:]]*- r${REALIZATION}$"
}

function push_updated_catalog() {
    # Commit and push the new catalog entry to the catalog repository
    cd ${TARGET_CATALOG}

    # Check if the remote branch exists
    if git ls-remote --exit-code origin ${branch} >/dev/null 2>&1; then
        echo "Branch ${branch} exists on remote"
        # Stage first, then test the index: rsync mtime noise cannot fake a change
        git add .
        # Branch exists but there is nothing to commit
        if git diff --cached --quiet; then
            # Nothing of ours left to add: only correct if it reached the remote
            if realization_on_remote; then
                echo "Realization r${REALIZATION} already on ${branch}, nothing to push"
            else
                echo "ERROR: nothing to commit but r${REALIZATION} is missing from ${branch}" >&2
                return 1
            fi
        # Branch exists and there is something to commit
        else
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
    # Branch does not exist on remote
    else
        echo "Branch ${branch} does not exist on remote, creating it"
        git add .
        if git diff --cached --quiet; then
            echo "No new catalog entry to push, skipping"
            return 0
        fi
        git commit -m "New catalog entry for ${MODEL} ${EXPERIMENT_NAME}"

        # Create and push the new branch
        git checkout -B ${branch}
        git push origin ${branch}
        echo "Successfully created and pushed to ${branch}"
    fi
}

# AQUA writes plots under ${CATALOG}/${MODEL}-${RESOLUTION}/... (see aqua_analysis.sh)
MODEL_AND_RES="${MODEL}-${RESOLUTION}"

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
branch="${CATALOG}-${EXPERIMENT_NAME}-${EXP}"

# if LRA generator was skipped and a previous AQUA experiment name was entered
# we must be analyzing data from an older experiment
if [ "${RUN_LRA_GENERATOR,,}" != "true" ] && [ -n "${PREV_AQUA_EXP}" ]; then
    branch="${CATALOG}-${EXPERIMENT_NAME}-${EXP}-reanalysis_of_${PREV_AQUA_EXP}"
    EXP="${PREV_AQUA_EXP}"
    EXPERIMENT_NAME="${PREV_AQUA_EXP}"
fi

indir="${ROOTDIR}"/aqua-analysis
exps=${CATALOG}/${MODEL_AND_RES}/${EXPERIMENT_NAME}/r${REALIZATION}

AQUA_CONTAINER="${CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"

# Rsync the new catalog entry to the catalog repository
SOURCE_CATALOG="${HPCROOTDIR}/catalog/catalogs/${CATALOG}"/
TARGET_CATALOG="${ROOTDIR}"/tmp/catalog/catalogs/${CATALOG}/
rsync_to_local "${HPCUSER}" "${HPCHOST}" "${SOURCE_CATALOG}" "${TARGET_CATALOG}"

if [ "${PUSH_FIGURES,,}" == "true" ]; then
    push_figures
else
    echo "Skipping pushing figures to aqua-web"
fi

# only push to the AQUA Github if LRA_GENERATOR was run
if [ "${PUSH_CATALOG,,}" == "true" ] && [ "${RUN_LRA_GENERATOR,,}" == "true" ]; then
    push_updated_catalog
else
    echo "Skipping pushing updated catalog to the AQUA catalog Github"
fi
