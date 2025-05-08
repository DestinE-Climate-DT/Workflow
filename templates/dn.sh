#!/bin/bash
#

# This step runs the data notifier, that reads from GSV and checks that data exists.

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
EXPID=${4:-%DEFAULT.EXPID%}
DATELIST=${5:-%EXPERIMENT.DATELIST%}
MEMBER_LIST=${6:-%EXPERIMENT.MEMBERS%}
CHUNK=${7:-%CHUNK%}
CHUNK_START_DATE=${8:-%CHUNK_START_DATE%}
CHUNK_END_DATE=${9:-%CHUNK_END_DATE%}
SPLIT=${10:-%SPLIT%}
EXPVER=${11:-%REQUEST.EXPVER%}
RUN_TYPE=${12:-%RUN.TYPE%}
WORKFLOW=${13:-%RUN.WORKFLOW%}
OPA_NAMES=${14:-%RUN.OPA_NAMES%}
APP_NAMES=${15:-%RUN.APP_NAMES%}
OUTDIR=${16:-%APP.OUTPATH%}
READ_FROM_DATABRIDGE=${17:-%APP.READ_FROM_DATABRIDGE%}
DATABRIDGE_FDB_HOME=${18:-%CURRENT_DATABRIDGE_FDB_HOME%}
SCRATCH=${19:-%CURRENT_SCRATCH_DIR%}
PROJECT=${20:-%CURRENT_PROJECT%}
HPC_PROJECT=${21:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPC_SCRATCH=${22:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${23:-%CONFIGURATION.CONTAINER_DIR%}
FDB_HOME=${24:-%REQUEST.FDB_HOME%}
MEMBER=${25:-%MEMBER%}
LIBDIR=${26:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${27:-%CONFIGURATION.SCRIPTDIR%}
GSV_VERSION=${28:-%GSV.VERSION%}
HPC_SCRATCH=${29:-%CONFIGURATION.PROJECT_SCRATCH%}
OPERATIONAL_PROJECT_SCRATCH=${30:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${31:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
LOGDIR=${HPCROOTDIR}/LOG_${EXPID}

#temporal solution
#ensure correct format of the list:
#count number of elements:
list_length=$(echo "${OPA_NAMES}" | tr -cd ',' | wc -c)
list_length=$((list_length + 1))

# Check that there are no empty spaces between the app names:
APP_NAMES="${APP_NAMES// /}"

source "${LIBDIR}"/common/util.sh
# lib/common/util.sh (get_member_number) (auto generated comment)
get_member_number "${MEMBER_LIST}" ${MEMBER}

REALIZATION=${MEMBER_NUMBER}

#run dn
#####################################################
# runs data notifier
# Globals:
#   LIBDIR
# Arguments:
#   REQUESTFILE
######################################################
function run_DN() {
    # move parsed data request
    cd "${SCRIPTDIR}/dn/" || exit
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${SCRIPTDIR}/dn/" \
        --bind "${FDB_HOME}" \
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
        --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
        --bind "${LOGDIR}/" \
        --env FDB_HOME=${FDB_HOME} \
        --env request="$1" \
        --env chunk="$2" \
        --env split="$3" \
        --env expid="$4" \
        --env app_names="$5" \
        --env run_type="$6" \
        --env realization="$7" \
        --env WORKFLOW="$8" \
        --env datelist="$9" \
        --env "PYTHONNOUSERSITE=1" \
        --env LOGDIR="${LOGDIR}" \
        $HPC_CONTAINER_DIR/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        '
    if [ "${WORKFLOW}" == "end-to-end" ] || [ "${WORKFLOW}" == "model" ]; then
        python3 run_dn.py --request $request --chunk $chunk \
        --split $split --expid $expid --app_names $app_names --run_type $run_type \
        --realization $realization --logdir $LOGDIR --datelist $datelist
    else
        python3 run_dn.py --request $request --chunk $chunk \
        --split $split --expid $expid --app_names $app_names --logdir $LOGDIR --datelist $datelist
    fi
    '
}

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

#declare filename for the gsv request
REQUESTFILE=${LOGDIR}/mother_request_${DATELIST}_${MEMBER}_${CHUNK}_${SPLIT}_DN

#run DN request

if [ "${READ_FROM_DATABRIDGE,,}" == "true" ]; then
    export FDB_HOME=${DATABRIDGE_FDB_HOME}
    sed -i 's/:\(.*\)/:\L\1/g' ${REQUESTFILE}
else
    export FDB_HOME=${FDB_HOME}
fi

# load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# lib/common/util.sh (print_data_gov) (auto generated comment)
print_data_gov

run_DN "${REQUESTFILE}" "${CHUNK}" "${SPLIT}" "${EXPVER}" \
    "${APP_NAMES}" "${RUN_TYPE,,}" "${REALIZATION}" "${WORKFLOW}" "${DATELIST}"
