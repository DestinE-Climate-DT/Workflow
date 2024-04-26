#!/bin/bash
#

set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL=${3:-%MODEL.MODEL_NAME%}
MODEL_SOURCE=${4:-%MODEL.SOURCE%}
MODEL_BRANCH=${5:-%MODEL.BRANCH%}
CURRENT_ARCH=${6:-%CURRENT_ARCH%}
PRECOMP_MODEL_PATH=${7:-%MODEL.PRECOMP_MODEL_PATH%}
APP=${8:-%RUN.APP%}
EXPID=${9:-%DEFAULT.EXPID%}
DATELIST=${10:-%EXPERIMENT.DATELIST%}
MEMBERS=${11:-%EXPERIMENT.MEMBERS%}
CHUNK=${12:-%CHUNK%}
SPLIT=${14:-%SPLIT%}

if [ $SPLIT == "-1" ] || [ $SPLIT == "None" ]; then
    SPLIT=1
fi

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)
source "${LIBDIR}"/"${HPC}"/config.sh

load_environment_maestro_apps
cd ${MSTRO_DIR}/examples

MSTRO_LIBRARIAN_REQUEST_FILE="${HPCROOTDIR}/LOG_${EXPID}/mstro_request_${CHUNK}_${SPLIT}.yml"
OPA_READY="${HPCROOTDIR}"/"LOG_${EXPID}"/"opa_"${CHUNK}"_"${SPLIT}"_mstrodep"
while [ ! -f $OPA_READY ]; do
    echo "Waiting for OPA_${CHUNK}_${SPLIT} to prepare ..."
    sleep 1
done
echo "done."
# By that point, the facing dedicated OPA instance is ready to listen, and the request file has already been prepared

LIBRARIAN_CMD="srun ${MSTRO_LIBRARIAN_PATH}/librarian 
               --stage --layer FDB --access ${MSTRO_LIBRARIAN_REQUEST_FILE}"

# Before we can run the Librarian, we need the Pool Manager info to
# connect to Maestro (file produced by templates/mstro_pm.sh)
pm_output="${HPCROOTDIR}/LOG_${EXPID}/pm_${CHUNK}.info"
while [ ! -s $pm_output ]; do
    echo "Waiting for pool manager credentials ..."
    sleep 1
done
echo "done."

# reading for semi-colon separated line in the $PM_INFO file
exec 4<$pm_output
read -d ';' -u 4 pm_info_varname
read -d ';' -u 4 pm_info
exec 4<&-

MSTRO_POOL_MANAGER_INFO="$pm_info"
export MSTRO_POOL_MANAGER_INFO
echo "MSTRO_POOL_MANAGER_INFO=${MSTRO_POOL_MANAGER_INFO}"

MSTRO_WORKFLOW_NAME="MSTRO_APP_${CHUNK}" MSTRO_COMPONENT_NAME="Librarian_${SPLIT}" ${LIBRARIAN_CMD}

touch "${HPCROOTDIR}/LOG_${EXPID}/producer_${CHUNK}_${SPLIT}_mstrodep"
