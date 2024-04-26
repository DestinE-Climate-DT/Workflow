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
APP=${8:-%APP.NAMES%}
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
READ_EXPID=${23:-%APP.READ_EXPID%}
JOBNAME=${24:-%JOBNAME%}
SPLIT=${25:-%SPLIT%}
APP_OUTPATH=${26:-%APP.OUTPATH%}
PRODUCTION=${27:-%RUN.PRODUCTION%}
WORKFLOW=${28:-%RUN.WORKFLOW%}
HPC_FDB_HOME=${29:-%CURRENT_FDB_PROD%}
CONTAINER_VERSION=${22:-%APP.CONTAINER_VERSION%} #I LIKE APP.VERSION_CONTAINER LIKE IN 3.0.0-DEV
AQUA_MODEL_NAME=${3:-%AQUA.MODEL%}
AQUA_EXP=${3:-%AQUA.EXP%}
AQUA_SOURCE=${3:-%AQUA.SOURCE%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

if [ "${PRODUCTION,,}" == "true" ]; then
    READ_EXPID="0001"
elif [ "${WORKFLOW}" == "end-to-end" ]; then
    READ_EXPID="$EXPID"
fi

ATM_MODEL=${AQUA_MODEL_NAME%%-*}
OCEAN_MODEL=${AQUA_MODEL_NAME##*-}

#####################
# get current app date
# GLOBALS:
#       CHUNK_START_DATE
#       SPLIT
#####################
get_current_date() {
    # Assuming $CHUNK_START_DATE is in the format YYYYMMDD
    # and $SPLIT is a number you want to add to it
    increment=$((SPLIT - 1))
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
# get current app yyyy, mm, dd
# GLOBALS:
#       CURRENT_DATE
#####################
function last_day_of_the_month() {
    YYYY=$1
    MM=$2
    export last_day_of_the_month=$(cal $MM $YYYY | egrep -v [a-z] | wc -w)
    echo "The last day of the month is ${last_day_of_the_month}"
}

#####################
# run AQUA
# GLOBALS:
#       LIBDIR
#####################
function run_AQUA() {
    module --force purge
    cd "${LIBDIR}"/runscript/run_aqua/
    #module load singularity
    AQUA=$HPCROOTDIR/$PROJDEST/aqua
    AQUA_EXP="%AQUA.EXP%"
    AQUA_SOURCE="%AQUA.SOURCE%"
    only_lra="only_lra_${DATELIST}_${MEMBER}_${CHUNK}_${SPLIT}_APP_AQUA"
    mv "$HPCROOTDIR"/LOG_"${EXPID}"/"${only_lra}" only_lra.yaml
    if [ "${PRODUCTION,,}" == "true" ]; then
        singularity exec \
            --cleanenv \
            --env FDB_HOME="$FDB_HOME" \
            --env GSV_WEIGHTS_PATH="$GSV_WEIGHTS_PATH" \
            --env GRID_DEFINITION_PATH="$GRID_DEFINITION_PATH" \
            --env PYTHONPATH=/opt/conda/lib/python3.10/site-packages \
            --env ESMFMKFILE=/opt/conda/lib/esmf.mk \
            --env HPCROOTDIR="$HPCROOTDIR" \
            --env PROJDEST="$PROJDEST" \
            --env AQUA="$AQUA" \
            --env ATM_MODEL="${ATM_MODEL^^}" \
            --env OCEAN_MODEL="${OCEAN_MODEL^^}" \
            --env AQUA_EXP=$AQUA_EXP \
            --env AQUA_SOURCE=$AQUA_SOURCE \
            --env CURRENT_ARCH="${CURRENT_ARCH}" \
            --bind "$HPC_SCRATCH" \
            --bind "$HPC_PROJECT" \
            --bind /pfs/lustrep3"$HPC_PROJECT" \
            "$HPC_CONTAINER_DIR"/aqua/aqua-"${CONTAINER_VERSION}".sif \
            bash -c \
            '
    	bash run_aqua.sh $HPCROOTDIR $PROJDEST
    	'
    else
        singularity exec \
            --cleanenv \
            --env FDB5_CONFIG_FILE="$FDB5_CONFIG_FILE" \
            --env GSV_WEIGHTS_PATH="$GSV_WEIGHTS_PATH" \
            --env GRID_DEFINITION_PATH="$GRID_DEFINITION_PATH" \
            --env PYTHONPATH=/opt/conda/lib/python3.10/site-packages \
            --env ESMFMKFILE=/opt/conda/lib/esmf.mk \
            --env HPCROOTDIR="$HPCROOTDIR" \
            --env PROJDEST="$PROJDEST" \
            --env AQUA="$AQUA" \
            --env ATM_MODEL="${ATM_MODEL^^}" \
            --env OCEAN_MODEL="${OCEAN_MODEL^^}" \
            --env AQUA_EXP=$AQUA_EXP \
            --env AQUA_SOURCE=$AQUA_SOURCE \
            --env CURRENT_ARCH="${CURRENT_ARCH}" \
            --bind "$HPC_SCRATCH" \
            --bind "$HPC_PROJECT" \
            --bind /pfs/lustrep3"$HPC_PROJECT" \
            "$HPC_CONTAINER_DIR"/aqua/aqua-"${CONTAINER_VERSION}".sif \
            bash -c \
            '
        bash run_aqua.sh $HPCROOTDIR $PROJDEST
        '
    fi
}

#####################
# run ENERGY_ONSHORE
# GLOBALS:
#       LIBDIR
#####################
function run_ENERGY_ONSHORE() {
    cd ${LIBDIR}/runscript/
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/energy_onshore/ # TODO: do it better when gsv is a package
    export PYTHONPATH=$SRC_DIR:$PYTHONPATH
    python run_energy_onshore.py -iniyear ${INI_YEAR} -inimonth ${INI_MONTH} -iniday ${INI_DAY} -hpcrootdir ${HPCROOTDIR} -finyear ${END_YEAR} -finmonth ${END_MONTH} -finday ${END_DAY} -hpcprojdir ${HPC_PROJECT}
}

#####################
# run ENERGY_OFFSHORE
# GLOBALS:
#       LIBDIR
#####################
function run_ENERGY_OFFSHORE() {
    cd ${LIBDIR}/runscript/
    REQUESTFILE=${HPCROOTDIR}/LOG_${EXPID}/request_${DATELIST}_${MEMBERS}_${CHUNK}_DN

    python run_energy_offshore.py --hpcrootdir ${HPCROOTDIR} --app_outpath ${APP_OUTPATH} --projdest $PROJDEST --app $APP \
        --expid $EXPID --datelist $DATELIST --chunk $CHUNK --requestfile $REQUESTFILE \
        --start_year "${INI_YEAR}" --start_month "${INI_MONTH}" --start_day "${INI_DAY}" \
        --end_year "${END_YEAR}" --end_month "${END_MONTH}" --end_day "${END_DAY}" --chunk "${CHUNK}"
}
#####################
# run URBAN
# GLOBALS:
#       LIBDIR
#####################
function run_URBAN() {
    cd "${LIBDIR}"/runscript/
    load_environment_gsv "$HPC_PROJECT" "$EXPID"
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/urban/ # TODO: do it better when gsv is a package
    export PYTHONPATH=$SRC_DIR:$PYTHONPATH
    export HPCROOTDIR=$HPCROOTDIR
    export EXPID=$EXPID
    export OPA_OUT=$OPA_OUT
    python run_urban.py -iniyear "${YYYY}" -inimonth "${MM}" -iniday "${DD}" -hpcrootdir "${APP_OUTPATH}" -finyear "${YYYY}" -finmonth "${MM}" -finday "${DD}" -hpcprojdir "${HPC_PROJECT}"
}

#####################
# run HYDROMET
# GLOBALS:
#       LIBDIR
#####################
function run_HYDROMET() {
    cd ${LIBDIR}/runscript/
    export HYDROMET_CONFIG=${HPCROOTDIR}/${PROJDEST}/hydromet/HydroMet/
    python run_hydromet.py -config_dir ${HYDROMET_CONFIG} -iniyear ${INI_YEAR} -inimonth ${INI_MONTH} -iniday ${INI_DAY} -finyear ${END_YEAR} -finmonth ${END_MONTH} -finday ${END_DAY}
}

#####################################################
# Function to run application mHM
# Globals:
#    HPCROOTDIR
#    PROJDEST
#    APP
# Arguments:
#
######################################################
function run_MHM() {
    load_environment_MHM
    #in the very benining, get the initial conditions file.
    if [ "${CHUNK}" -eq 1 ] && [ "${SPLIT}" -eq 1 ]; then
        cp /projappl/project_465000454/models/mhm/mHM_restart_001.nc ${HPCROOTDIR}/git_project/lib/runscript/run_mhm/output/mHM_restart_001.nc
    fi

    # update namelist
    cd ${LIBDIR}/runscript/run_mhm
    python update_mhm.py -date ${CHUNK_START_DATE}

    #run mhm/mrm # TODO: set end- and ini- dates independently
    cd ${LIBDIR}/runscript/
    python run_mhm.py -HPCROOTDIR "${HPCROOTDIR}" -PROJDEST "${PROJDEST}" -EXPID "${EXPID}" \
        -start_year "${INI_YEAR}" -start_month "${INI_MONTH}" -start_day "${INI_DAY}" \
        -end_year "${END_YEAR}" -end_month "${END_MONTH}" -end_day "${END_DAY}"
    cp ${LIBDIR}/runscript/run_mhm/output/mHM_Fluxes_States.nc ${LIBDIR}/runscript/run_mhm/output/mHM_Fluxes_States_${INI_YEAR}_${INI_MONTH}_${INI_DAY}.nc
    mkdir -p ${HPCROOTDIR}/results #TEMPORAL BC APP OUTPATH IS NOT DEFINED
    cp ${LIBDIR}/runscript/run_mhm/output/mHM_Fluxes_States.nc ${HPCROOTDIR}/results/mHM_Fluxes_States_${INI_YEAR}_${INI_MONTH}_${INI_DAY}.nc

}

#####################
# run WILDFIRES_WISE
# GLOBALS:
#       LIBDIR
#####################
function run_WILDFIRES_WISE() {
    cd ${LIBDIR}/runscript/
    python run_wildfires_wise.py -year_start ${INI_YEAR} -month_start ${INI_MONTH} -day_start ${INI_DAY} -year_end ${END_YEAR} -month_end ${END_MONTH} -day_end ${END_DAY} -expid ${EXPID}
}
#-expid {READ_EXPID}
#####################
# run WILDFIRES_SPITFIRE
# GLOBALS:
#       LIBDIR
#####################
function run_WILDFIRES_SPITFIRE() {
    cd "${LIBDIR}"/runscript/
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
    HPCTMPDIR="${HPC_SCRATCH}"/tmp/"${EXPID}"

    cd "${LIBDIR}"/runscript/

    singularity exec \
        --bind $HPC_SCRATCH \
        --bind $HPC_PROJECT \
        $HPC_CONTAINER_DIR/wildfires_fwi/wildfire-fwi.sif \
        bash -c \
        "
 python3 ./run_wildfires_fwi.py -year ${INI_YEAR} -month ${INI_MONTH} -day ${INI_DAY}  -hpcrootdir ${HPCROOTDIR}  -hpcprojdir ${PROJDEST} -hpctmpdir ${HPCTMPDIR}
    "
}
#####################
# run OBS
# GLOBALS:
#       LIBDIR
#####################
function run_OBS() {
    cd "${LIBDIR}"/runscript/
    python run_obs.py
}

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

# Get current run app name
load_dirs
load_environment_gsv "$HPC_PROJECT" "$READ_EXPID"

if [ "${PRODUCTION,,}" = "true" ]; then
    unset FDB5_CONFIG_FILE
    export FDB_HOME=${HPC_FDB_HOME}
fi

APP="${JOBNAME#*APP_}"

# Get current date
get_current_date

# get yyyy mm dd
get_yyyy_mm_dd

# get last day of the month
last_day_of_the_month ${YYYY} ${MM}

# run apps
run_"${APP^^}"
