#!/bin/bash
#

# This step runs the data notifier, that reads from GSV and checks that data exists.

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
SPLIT=${14:-%SPLIT%}
READ_EXPID=${15:-%RUN.READ_EXPID%}

# START_DATE=${13:-%SDATE%} #this might be used in the fdb start date in run_dn.py but not always
LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo ${CURRENT_ARCH} | cut -d- -f1 )

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
    cd ${LIBDIR}/runscript/
    python run_dn.py -request $1 -chunk $2 -split_day $3 -split $4
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
    cd ${HPCROOTDIR}/${PROJDEST}/gsv_interface/
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

	# Add N hours to the date
	new_date=$(date -d "$formatted_date $2 hour" "+%Y%m%d")
        
        SPLIT_DATE=${new_date}

        export SPLIT_DATE

	echo "Original date: $formatted_date"
	echo "New date with 24 hour added: $new_date"
}

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh

#load env # TODO : installation is happening twice (REMOTE SETUP also)
load_dirs
load_environment_gsv $HPC_PROJECT $READ_EXPID 

#declare filename for the gsv request
REQUESTFILE=${HPCROOTDIR}/LOG_${EXPID}/mother_request_${DATELIST}_${MEMBERS}_${CHUNK}_${SPLIT}_DN

# Get date of the current split
get_SPLIT_DATE ${CHUNK_START_DATE} ${SPLIT}

#run DN request
run_DN ${REQUESTFILE} ${CHUNK} ${SPLIT_DATE} ${SPLIT}

