#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models
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
INI_DAY=${14:-%CHUNK_START_DAY%}
INI_MONTH=${15:-%CHUNK_START_MONTH%}
INI_YEAR=${16:-%CHUNK_START_YEAR%}
OPA_OUT=${17:-%OPAREQUEST.1.out_filepath%}
CHUNK_START_DATE=${18:-%CHUNK_START_DATE%}
MEMBER=${19:-%MEMBER%}
END_DAY=${20:-%CHUNK_SECOND_TO_LAST_DAY%}
END_MONTH=${21:-%CHUNK_SECOND_TO_LAST_MONTH%}
END_YEAR=${22:-%CHUNK_SECOND_TO_LAST_YEAR%}
READ_EXPID=${23:-%RUN.READ_EXPID%}
JOBNAME=${24:-%JOBNAME%}
SPLIT=${25:-%SPLIT%}
APP_OUTPATH=${26:-%APP.OUTPATH%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo ${CURRENT_ARCH} | cut -d- -f1 )

#####################
# get current app date
# GLOBALS:
#       CHUNK_START_DATE
#       SPLIT
#####################
get_current_date() {
    # Assuming $CHUNK_START_DATE is in the format YYYYMMDD
    # and $SPLIT is a number you want to add to it
    increment=$((SPLIT-1))
    CURRENT_DATE=$(date -d "$CHUNK_START_DATE + $increment days" "+%Y%m%d")
    export CURRENT_DATE
}

#####################
# get current app yyyy, mm, dd
# GLOBALS:
#       CURRENT_DATE
#####################
get_yyyy_mm_dd() {
    # Assuming CURRENT_DATE is in the format YYYYMMDD
    export YYYY="${CURRENT_DATE:0:4}"
    export MM="${CURRENT_DATE:4:2}"
    export DD="${CURRENT_DATE:6:2}"
}

#####################
function run_DUMMY() {
    cd ${LIBDIR}/runscript/
    python run_dummy.py
}

#####################
# run DUMMY
# GLOBALS:
# 	LIBDIR 
#####################
function run_DUMMY() {
    cd ${LIBDIR}/runscript/
    python run_dummy.py
}

#####################
# run AQUA
# GLOBALS:
#       LIBDIR
#####################
function run_AQUA() {
    module --force purge
    cd ${LIBDIR}/runscript/run_aqua/
    only_lra="only_lra_${CHUNK_START_DATE}_${MEMBER}_${CHUNK}_1_APP_${APP}" #this is constant
    lra_file=$HPCROOTDIR/LOG_${EXPID}/${only_lra}
    if [ -e "$lra_file" ]; then
        # The file exists
        cp $HPCROOTDIR/LOG_${EXPID}/${only_lra} only_lra.yaml #TODO: change cp by mv
    fi
    singularity exec  \
    --cleanenv \
    --env FDB5_CONFIG_FILE=$FDB5_CONFIG_FILE \
    --env GSV_WEIGHTS_PATH=$GSV_WEIGHTS_PATH \
    --env GRID_DEFINITION_PATH=$GRID_DEFINITION_PATH \
    --env PYTHONPATH=/opt/conda/lib/python3.10/site-packages \
    --env ESMFMKFILE=/opt/conda/lib/esmf.mk  \
    --env HPCROOTDIR=$HPCROOTDIR \
    --env PROJDEST=$PROJDEST \
    --bind $HPC_SCRATCH  \
    --bind $HPC_PROJECT  \
    $HPC_CONTAINER_DIR/aqua/aqua-v0.4.sif \
    bash -c \
    '
    bash run_aqua_dummy.sh
    '  
}


#####################
# run ENERGY_ONSHORE
# GLOBALS:
#       LIBDIR
#####################
function run_ENERGY_ONSHORE() {
    cd ${LIBDIR}/runscript/
    python run_energy_onshore.py
}

#####################
# run ENERGY_OFFSHORE
# GLOBALS:
#       LIBDIR
#####################
function run_ENERGY_OFFSHORE() {
    cd ${LIBDIR}/runscript/
    python run_energy_offshore.py
}
#####################
# run URBAN
# GLOBALS:
#       LIBDIR
#####################
function run_URBAN() {
    cd ${LIBDIR}/runscript/
    load_environment_gsv $HPC_PROJECT $EXPID
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/urban/ # TODO: do it better when gsv is a package
    export PYTHONPATH=$SRC_DIR:$PYTHONPATH
    export HPCROOTDIR=$HPCROOTDIR
    export EXPID=$EXPID
    export OPA_OUT=$OPA_OUT
    python run_urban.py -iniyear ${YYYY} -inimonth ${MM} -iniday ${DD} -hpcrootdir ${APP_OUTPATH} -finyear ${YYYY} -finmonth ${MM} -finday ${DD}
}

#####################
# run HYDROMET
# GLOBALS:
#       LIBDIR
#####################
function run_HYDROMET() {
    cd ${LIBDIR}/runscript/
    python run_hydromet.py
}

#####################
# run MHM
# GLOBALS:
#       LIBDIR
#####################
function run_MHM() {
    load_environment_MHM
    #in the very benining, get the initial conditions file.
    if [ "${CHUNK}" -eq 1 ] && [ "${SPLIT}" -eq 1 ]; then
        cp /projappl/project_465000454/models/mhm/mHM_restart_001.nc ${HPCROOTDIR}/git_project/lib/runscript/run_mhm/output/mHM_restart_001.nc
    fi

    # update namelist
    cd ${LIBDIR}/runscript/run_mhm
    python update_mhm.py -date ${CURRENT_DATE}

    #run mhm/mrm # TODO: set end- and ini- dates independently
    cd ${LIBDIR}/runscript/
    python run_mhm.py -HPCROOTDIR "${HPCROOTDIR}" -PROJDEST "${PROJDEST}" -EXPID "${EXPID}"\
                        -start_year "${YYYY}" -start_month "${MM}" -start_day "${DD}" \
                        -end_year "${YYYY}" -end_month "${MM}" -end_day "${DD}"
    cp ${LIBDIR}/runscript/run_mhm/output/mHM_Fluxes_States.nc ${LIBDIR}/runscript/run_mhm/output/mHM_Fluxes_States_${YYYY}_${MM}_${DD}.nc
    cp ${LIBDIR}/runscript/run_mhm/output/mHM_Fluxes_States.nc ${APP_OUTPATH}/mHM_Fluxes_States_${YYYY}_${MM}_${DD}.nc

}

#####################
# run WILDFIRES_WISE
# GLOBALS:
#       LIBDIR
#####################
function run_WILDFIRES_WISE() {
    cd ${LIBDIR}/runscript/
    python run_wildfires_wise.py
}

#####################
# run WILDFIRES_SPITFIRE
# GLOBALS:
#       LIBDIR
#####################
function run_WILDFIRES_SPITFIRE() {
    cd ${LIBDIR}/runscript/
    python run_wildfires_spitfire.py
}

#####################
# run WILDFIRES_FWI
# GLOBALS:
#       HPC_PROJEC, HPC_SCRATCH
#       EXPID, LIBDIR
#       HPC_CONTAINER_DIR
#       YYYY, MM, DD
#####################
function run_WILDFIRES_FWI() {
    # Define experiment tmp scratch folder
    HPCTMPDIR="${HPC_SCRATCH}"tmp/"${EXPID}"
	
    cd "${LIBDIR}"/runscript/

    singularity exec  \
    --bind $HPC_SCRATCH  \
    --bind $HPC_PROJECT  \
    $HPC_CONTAINER_DIR/wildfires_fwi/wildfire-fwi_0.1.0.sif \
    bash -c \
    "
    python3 ./run_wildfires_fwi.py -year ${YYYY} -month ${MM} -day ${DD} -hpctmpdir ${HPCTMPDIR} 
    "
}

#####################
# run OBS
# GLOBALS:
#       LIBDIR
#####################
function run_OBS() {
    cd ${LIBDIR}/runscript/
    python run_obs.py
}

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh

# Get current run app name
load_dirs
load_environment_gsv $HPC_PROJECT $READ_EXPID

APP="${JOBNAME#*APP_}"

# Get current date
get_current_date

# get yyyy mm dd
get_yyyy_mm_dd

# run apps
run_${APP^^}

