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
OUTDIR=${14:-%APP.OUTPATH%}
READ_FROM_DATABRIDGE=${15:-%APP.READ_FROM_DATABRIDGE%}
DATABRIDGE_FDB_HOME=${16:-%CURRENT_DATABRIDGE_FDB_HOME%}
SCRATCH_DIR=${17:-%CURRENT_SCRATCH_DIR%}
PROJECT=${18:-%CURRENT_PROJECT%}
HPC_PROJECT=${19:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPC_SCRATCH=${20:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${21:-%CONFIGURATION.CONTAINER_DIR%}
FDB_HOME=${22:-%REQUEST.FDB_HOME%}
MEMBER=${23:-%MEMBER%}
LIBDIR=${24:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${25:-%CONFIGURATION.SCRIPTDIR%}
GSV_VERSION=${26:-%GSV.VERSION%}
HPC_SCRATCH=${27:-%CONFIGURATION.PROJECT_SCRATCH%}
OPERATIONAL_PROJECT_SCRATCH=${28:-%CONFIGURATION.OPERATIONAL_PROJECT_SCRATCH%}
DEVELOPMENT_PROJECT_SCRATCH=${29:-%CONFIGURATION.DEVELOPMENT_PROJECT_SCRATCH%}
APP_ENERGY_INDICATORS=${30:-%APP.ENERGY_INDICATORS%}
APP_ENERGY_OFFSHORE=${31:-%APP.ENERGY_OFFSHORE%}
APP_HYDROLAND=${32:-%APP.HYDROLAND%}
APP_HYDROMET=${33:-%APP.HYDROMET%}
APP_OBSALL=${34:-%APP.OBSALL%}
APP_WILDFIRES_FWI=${35:-%APP.WILDFIRES_FWI%}
APP_WILDFIRES_WISE=${36:-%APP.WILDFIRES_WISE%}
APP_DATA=${37:-%APP.DATA%}
HPC_PROJECT_ROOT=${38:-%CURRENT_HPC_PROJECT_ROOT%}
LOCAL_DIR=${39:-%CURRENT_LOCAL_DIR%}
FDB_CONFIG_GATEWAY=${40:-%CONFIGURATION.FDB_CONFIG_GATEWAY%}
JOBNAME=${41:-%JOBNAME%}
CONTAINER_COMMAND=${42:-%CURRENT_CONTAINER_COMMAND%}
CURRENT_ROOTDIR=${43:-%CURRENT_ROOTDIR%}
FDB_COPY_BIN=${44:-%CURRENT_FDB_COPY_BIN%}
FDB_CONFIG_DATABRIDGE=${45:-%CONFIGURATION.FDB_CONFIG_DATABRIDGE%}
FDB_CONFIG_HPC=${46:-%CONFIGURATION.FDB_CONFIG_HPC%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture
LOGDIR=${CURRENT_ROOTDIR}/LOG_${EXPID}
REQUESTDIR="${LOGDIR}"

# Build the list
APP_NAMES=()

for var in APP_ENERGY_INDICATORS APP_ENERGY_OFFSHORE APP_HYDROLAND APP_HYDROMET APP_OBSALL APP_WILDFIRES_FWI APP_WILDFIRES_WISE APP_DATA; do
    value="${!var}"
    if [[ "$value" == "True" ]]; then
        # Strip the "APP_" prefix
        APP_NAMES+=("${var#APP_}")
    fi
done

# Print list of requested apps:
echo "Enabled apps: ${APP_NAMES[*]}"

source "${LIBDIR}"/common/util.sh
# lib/common/util.sh (get_member_number) (auto generated comment)
get_member_number "${MEMBER_LIST}" ${MEMBER}

REALIZATION=${MEMBER_NUMBER}

#####################################################
# run_DN
#   Runs Data Notifier.
# Globals:
#   SCRIPTDIR
#   FDB_HOME
#   DEVELOPMENT_PROJECT_SCRATCH
#   OPERATIONAL_PROJECT_SCRATCH
#   LOGDIR
#   REQUESTDIR (may match LOGDIR)
#   HPC_CONTAINER_DIR
#   GSV_VERSION
# Arguments:
#   chunk
#   split
#   expver
#   app_names[*]
#   run_type
#   member
#   workflow
#   datelist
######################################################
function run_DN() {
    # lib/common/util.sh (print_data_gov) (auto generated comment)
    print_data_gov
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
        --bind "${REQUESTDIR}"/ \
        --env FDB_HOME=${FDB_HOME} \
        --env request_dir="${REQUESTDIR}" \
        --env chunk="$1" \
        --env split="$2" \
        --env expid="$3" \
        --env app_names="$4" \
        --env run_type="$5" \
        --env member="$6" \
        --env WORKFLOW="$7" \
        --env datelist="$8" \
        --env "PYTHONNOUSERSITE=1" \
        --env LOGDIR="${LOGDIR}" \
        ${HPC_CONTAINER_DIR}/gsv/gsv_${GSV_VERSION}.sif \
        bash -c \
        '
        python3 run_dn.py \
            --request_dir ${request_dir} \
            --chunk ${chunk} \
            --split ${split} \
            --expid ${expid} \
            --app_names ${app_names} \
            --run_type ${run_type} \
            --member ${member} \
            --datelist ${datelist}
        '
}

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/"${HPC}-TRANSFER"/config.sh
source "${LIBDIR}"/common/util.sh

if [ "${READ_FROM_DATABRIDGE,,}" == "true" ]; then
    export FDB_HOME=${DATABRIDGE_FDB_HOME}
fi

# load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

JOBNAME_WITHOUT_EXPID=$(echo ${JOBNAME} | sed 's/^[^_]*_//')

run_DN "${CHUNK}" "${SPLIT}" "${EXPVER}" \
    "${APP_NAMES[*]}" "${RUN_TYPE,,}" "${MEMBER}" "${WORKFLOW}" "${DATELIST}" "${JOBNAME_WITHOUT_EXPID}" \
    "${REQUESTDIR}"
