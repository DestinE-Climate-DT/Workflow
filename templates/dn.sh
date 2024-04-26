#!/bin/bash
#

# This step runs the data notifier, that reads from GSV and checks that data exists.

set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL=${3:-%MODEL.NAME%}
MODEL_SOURCE=${4:-%MODEL.SOURCE%}
MODEL_BRANCH=${5:-%MODEL.BRANCH%}
CURRENT_ARCH=${6:-%CURRENT_ARCH%}
PRECOMP_MODEL_PATH=${7:-%MODEL.PRECOMP_MODEL_PATH%}
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

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

#temporal solution
#ensure correct format of the list:
#count number of elements:
list_length=$(echo "${OPA_NAMES}" | tr -cd ',' | wc -c)
list_length=$((list_length + 1))

if [ "${CHUNK}" != "1" ]; then
    if [ "${SPLIT}" = "1" ]; then
        # Assuming list is an array or a list of items

        while [ "$(find "${OUTDIR}" -type f -name "green_flag_*" | wc -l)" -ne $list_length ]; do
            sleep 1
        done

        # Your code here for when the condition is true
        echo "Number of green flags is equal to the number of OPAs."
        rm "${OUTDIR}"/green_flag_*

    fi
fi

if [ "${PRODUCTION,,}" == "true" ]; then
    READ_EXPID="0001"
    echo "READ_EXPID is set to the production id, that is ${READ_EXPID}"
elif [ "${WORKFLOW}" == "end-to-end" ]; then
    READ_EXPID="$EXPID"
    echo "READ_EXPID is set to end-to-end id, that is ${READ_EXPID}"
fi

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
    if [ "${WORKFLOW}" == "end-to-end" ]; then
        python run_dn.py -request "$1" -chunk "$2" -split_day "$3" -split "$4" -expid "$5" -app_names "$6" -model "$7" -activity "$8" -experiment "$9"
    elif [ "${WORKFLOW}" == "apps" ] && [ "${READ_EXPID}" == "a0h3" ]; then #TODO: read fields from READ_EXPERIMENT config file. Possible better inside the python sctipt.
        python run_dn.py -request "$1" -chunk "$2" -split_day "$3" -split "$4" -expid "$5" -app_names "$6" -model "IFS-NEMO" -activity "CMIP6" -experiment "hist"
    else
        python run_dn.py -request "$1" -chunk "$2" -split_day "$3" -split "$4" -expid "$5" -app_names "$6"
    fi
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

#load env # TODO : installation is happening twice (REMOTE SETUP also)
load_dirs
load_environment_gsv "${FDB_DIR}" "${READ_EXPID}"

if [ "${PRODUCTION,,}" = "true" ]; then
    unset FDB5_CONFIG_FILE
    export FDB_HOME=${HPC_FDB_HOME}
fi

#declare filename for the gsv request
REQUESTFILE=${HPCROOTDIR}/LOG_${EXPID}/mother_request_${DATELIST}_${MEMBERS}_${CHUNK}_${SPLIT}_DN

# Get date of the current split
get_SPLIT_DATE "${CHUNK_START_DATE}" "${SPLIT}"

# check if date is valid
check_date "${CHUNK_START_DATE}" "${CHUNK_END_DATE}" "${SPLIT_DATE}"

#run DN request

if [ "${READ_FROM_DATABRIDGE,,}" == "true" ]; then
    unset FDB5_CONFIG_FILE
    # temporal
    export PATH=/users/lrb_465000454_fdb/mars/versions/6.99.1.3/bin:$PATH
    export LD_LIBRARY_PATH=/users/lrb_465000454_fdb/mars/versions/6.99.1.3/lib64:$LD_LIBRARY_PATH
    export FDB_HOME=${DATABRIDGE_FDB_HOME}
    sed -i 's/:\(.*\)/:\L\1/g' ${REQUESTFILE}
fi

if [ "${WORKFLOW}" != "apps" ]; then
    export_MULTIO_variables "${RAPS_EXPERIMENT}"
else
    MULTIO_ACTIVITY=""
    MULTIO_EXPERIMENT=""
fi

echo "DEBUG :: "
fdb-info --all

run_DN "${REQUESTFILE}" "${CHUNK}" "${SPLIT_DATE}" "${SPLIT}" "${READ_EXPID}" "${APP_NAMES}" "${MODEL^^}" "${MULTIO_ACTIVITY}" "${MULTIO_EXPERIMENT}"
