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
CHUNK_START_DATE=${13:-%CHUNK_START_DATE%}
CHUNK_END_DATE=${13:-%CHUNK_END_DATE%}
SPLIT=${14:-%SPLIT%}
READ_EXPID=${15:-%APP.READ_EXPID%}
FDB_DIR=${16:-%CURRENT_FDB_DIR%}
PRODUCTION=${17:-%RUN.PRODUCTION%}
WORKFLOW=${18:-%RUN.WORKFLOW%}
HPC_FDB_HOME=${15:-%CURRENT_FDB_PROD%}
RAPS_EXPERIMENT=${16:-%CONFIGURATION.RAPS_EXPERIMENT%}
OPA_NAMES=${21:-%RUN.OPA_NAMES%}
APP_NAMES=${21:-%RUN.APP_NAMES%}
OUTDIR=${15:-%APP.OUTPATH%}
READ_FROM_DATABRIDGE=${16:-%APP.READ_FROM_DATABRIDGE%}
DATABRIDGE_FDB_HOME=${17:-%CURRENT_DATABRIDGE_FDB_HOME%}

# START_DATE=${13:-%SDATE%} #this might be used in the fdb start date in run_dn.py but not always
LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

#####################################################
# Skip DN if date not real
#
#
#
#
#####################################################
check_date() {
    # Given dates in the format YYYY-MM-DD
    start_date="$1"
    end_date="$2"
    check_date="$3"

    # Convert dates to timestamps
    start_timestamp=$(date -d "$start_date" +%s)
    end_timestamp=$(date -d "$end_date" +%s)
    check_timestamp=$(date -d "$check_date" +%s)

    # Check if the date is between the start and end dates
    if [ "$check_timestamp" -ge "$start_timestamp" ] && [ "$check_timestamp" -le "$end_timestamp" ]; then
        echo "The date is between $start_date and $end_date. Date OK."
    else
        echo "The date is outside the chunk range."
    fi
}

#run dn
#####################################################
# runs data notifier
# Globals:
#   LIBDIR
# Arguments:
#   REQUESTFILE
######################################################
function run_DN() {
    #move parsed data request
    cd "${LIBDIR}"/runscript/
    python run_mstro_opa.py -request "$1" -chunk "$2" -start_date "$3" -end_date "$4" -split "$5" -hpcrootdir "$6" -expid "$7" -static "$8" -librarianfile "$9"

}

#install gsv
#####################################################
# installs gsv interface
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments:
######################################################
function install_GSV_INTERFACE() {
    # install opa from local clone into the project
    cd "${HPCROOTDIR}"/"${PROJDEST}"/gsv_interface/
    pip install .
}

# split day
#####################################################
# gets split day given an inidate and current split, taking 1Split=1Hour
# Globals:
#       HPCROOTDIR
#       PROJDEST
# Arguments: CHUNK_INI_DATE SPLITNUMBER
######################################################
function get_SPLIT_DATE() {
    # Original string
    date_string=$1

    # Transform string to date format
    formatted_date=$(date -d "$date_string" +%Y%m%d)

    # Add $2 days to the chunk ini date
    new_date=$(date -d "$formatted_date $(($2 - 1)) day" "+%Y%m%d")

    SPLIT_DATE=${new_date}

    export SPLIT_DATE

    echo "Original date: $formatted_date"
    echo "Date corresponding to split $2: $new_date"
}

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

if [ "${PRODUCTION,,}" = "true" ]; then
    unset FDB5_CONFIG_FILE
    export FDB_HOME=${HPC_FDB_HOME}
fi

#declare filename for the gsv request
REQUESTFILE=${HPCROOTDIR}/LOG_${EXPID}/mother_request_${DATELIST}_${MEMBERS}_${CHUNK}_${SPLIT}_DN

# Get date of the current split
#get_SPLIT_DATE "${CHUNK_START_DATE}" "${SPLIT}"

# check if date is valid
#check_date "${CHUNK_START_DATE}" "${CHUNK_END_DATE}" "${SPLIT_DATE}"

#run DN request

if [ "${READ_FROM_DATABRIDGE,,}" == "true" ]; then
    unset FDB5_CONFIG_FILE
    # temporal
    export PATH=/users/lrb_465000454_fdb/mars/versions/6.99.1.3/bin:$PATH
    export LD_LIBRARY_PATH=/users/lrb_465000454_fdb/mars/versions/6.99.1.3/lib64:$LD_LIBRARY_PATH
    export FDB_HOME=${DATABRIDGE_FDB_HOME}
    sed -i 's/:\(.*\)/:\L\1/g' ${REQUESTFILE}
fi

if [ "${WORKFLOW}" != "apps" ] && [ "${WORKFLOW}" != "maestro-apps" ]; then
    export_MULTIO_variables "${RAPS_EXPERIMENT}"
else
    MULTIO_ACTIVITY=""
    MULTIO_EXPERIMENT=""
fi

if [ "$WORKFLOW" == "maestro-apps" ] || [ "$WORKFLOW" == "maestro-end-to-end" ]; then
    load_environment_maestro_gsv
else
    echo "DEBUG :: "
    fdb-info --all
fi

if [ $SPLIT == "-1" ] || [ $SPLIT == "None" ]; then
    SPLIT=1
fi

# [maestro] Wait for pminfo file to appear before running OPA component
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

REQUESTFILE="${HPCROOTDIR}"/"${PROJDEST}"/conf/mstro_request.yml
LIBRARIANFILE=""
if [ "$WORKFLOW" == "maestro-apps" ]; then
    load_environment_maestro_apps
    STATIC=1
    LIBRARIANFILE="${HPCROOTDIR}/LOG_${EXPID}/mstro_request_${CHUNK}_${SPLIT}.yml"
    export MSTRO_WORKFLOW_NAME="MSTRO_APP_${CHUNK}"
fi
if [ "$WORKFLOW" == "maestro-end-to-end" ]; then
    load_environment_maestro_end_to_end
    STATIC=0
    export MSTRO_WORKFLOW_NAME="Maestro ECMWF Demo Workflow"
fi
load_environment_maestro_python
export MSTRO_COMPONENT_NAME="Maestro_OPA_${SPLIT}"
export MSTRO_LOG_LEVEL=DEBUG

cd "${LIBDIR}"/runscript/
CONSUMER_ERR="${HPCROOTDIR}/LOG_${EXPID}/consumer_${CHUNK}_${SPLIT}.err"
CONSUMER_OUT="${HPCROOTDIR}/LOG_${EXPID}/consumer_${CHUNK}_${SPLIT}.out"

run_DN "${REQUESTFILE}" "${CHUNK}" "${CHUNK_START_DATE}" "${CHUNK_END_DATE}" "${SPLIT}" "${HPCROOTDIR}" "${EXPID}" "${STATIC}" "${LIBRARIANFILE}" 1>${CONSUMER_OUT} 2>${CONSUMER_ERR}

touch "${HPCROOTDIR}/LOG_${EXPID}/consumer_${CHUNK}_${SPLIT}_mstrodep"
