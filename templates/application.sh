#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
APP=${4:-%APP.NAMES%}
EXPID=${5:-%DEFAULT.EXPID%}
DATELIST=${6:-%EXPERIMENT.DATELIST%}
MEMBERS=${7:-%EXPERIMENT.MEMBERS%}
CHUNK=${8:-%CHUNK%}
INI_DAY=${9:-%CHUNK_START_DAY%}
INI_MONTH=${10:-%CHUNK_START_MONTH%}
INI_YEAR=${11:-%CHUNK_START_YEAR%}
OPA_OUT=${12:-%OPAREQUEST.1.out_filepath%}
CHUNK_START_DATE=${13:-%CHUNK_START_DATE%}
MEMBER=${14:-%MEMBER%}
END_DAY=${15:-%CHUNK_SECOND_TO_LAST_DAY%}
END_MONTH=${16:-%CHUNK_SECOND_TO_LAST_MONTH%}
END_YEAR=${17:-%CHUNK_SECOND_TO_LAST_YEAR%}
JOBNAME=${18:-%JOBNAME%}
SPLIT=${19:-%SPLIT%}
APP_OUTPATH=${20:-%APP.OUTPATH%}
WORKFLOW=${21:-%RUN.WORKFLOW%}
RUN_TYPE=${22:-%RUN.TYPE%}
HPC_PROJECT=${23:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPC_SCRATCH=${24:-%CURRENT_PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${25:-%CONFIGURATION.CONTAINER_DIR%}
EXPVER=${26:-%REQUEST.EXPVER%}
CLASS=${27:-%REQUEST.CLASS%}
GSV_WEIGHTS_PATH=${28:-%GSV.WEIGHTS_PATH%}
LIBDIR=${29:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${30:-%CONFIGURATION.SCRIPTDIR%}
ENERGY_ONSHORE_VERSION=${31:-%ENERGY_ONSHORE.VERSION%}
ENERGY_OFFSHORE_VERSION=${32:-%ENERGY_OFFSHORE.VERSION%}
GSV_VERSION=${33:-%GSV.VERSION%}
AQUA_VERSION=${34:-%AQUA.VERSION%}
HYDROLAND_VERSION=${35:-%HYDROLAND.VERSION%}
WILDFIRES_WISE_VERSION=${36:-%WILDFIRES_WISE.VERSION%}
WILDFIRES_FWI_VERSION=${37:-%WILDFIRES_FWI.VERSION%}
HYDROMET_VERSION=${38:-%HYDROMET.VERSION%}
HPC_CONTAINER_DIR=${39:-%CONFIGURATION.CONTAINER_DIR%}
SPLIT_INI_DAY=${40:-%SPLIT_START_DAY%}
SPLIT_INI_MONTH=${41:-%SPLIT_START_MONTH%}
SPLIT_INI_YEAR=${42:-%SPLIT_START_YEAR%}
SPLIT_END_DAY=${43:-%SPLIT_END_DAY%}
SPLIT_END_MONTH=${44:-%SPLIT_END_MONTH%}
SPLIT_END_YEAR=${45:-%SPLIT_END_YEAR%}
PROJECT=${46:-%CURRENT_PROJECT%}
SPLITS=${47:-%SPLITS%}
FDB_HOME=${48:-%REQUEST.FDB_HOME%} # francesc: needed for Obsall
ENERGY_ONSHORE_IN_DATA_VERSION=${49:-%ENERGY_ONSHORE.IN_DATA_VERSION%}
ENERGY_OFFSHORE_IN_DATA_VERSION=${50:-%ENERGY_OFFSHORE.IN_DATA_VERSION%}
HYDROMET_IN_DATA_VERSION=${51:-%HYDROMET.IN_DATA_VERSION%}
HYDROLAND_IN_DATA_VERSION=${52:-%HYDROLAND.IN_DATA_VERSION%}
WILDFIRES_WISE_IN_DATA_VERSION=${53:-%WILDFIRES_WISE.IN_DATA_VERSION%}
WILDFIRES_FWI_IN_DATA_VERSION=${54:-%WILDFIRES_FWI.IN_DATA_VERSION%}
APP_AUX_IN_DATA_DIR=${55:-%APP_AUX_IN_DATA_DIR%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

#####################
# run ENERGY_ONSHORE
# GLOBALS:
#       LIBDIR
#####################
function run_ENERGY_ONSHORE() {
    cd "${SCRIPTDIR}/energy_onshore/" || exit
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/energy_onshore/

    # copy histograms as they were APP output
    FILE=${APP_OUTPATH}/energy_onshore/opa/*histogram_bin*
    if ls $FILE 1>/dev/null 2>&1; then
        mv $FILE ${APP_OUTPATH}/energy_onshore/
        echo "Histogram file(s) copied successfully."
    else
        echo "No histogram file found."
    fi

    # If the submodule does not exist, set PYTHONPATH to SCRIPTDIR (does not need to be SCRIPTDIR though)
    if [ -d "$SRC_DIR" ]; then
        export PYTHONPATH="${SRC_DIR}"
    else
        export PYTHONPATH="${SCRIPTDIR}"
    fi
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${SCRIPTDIR}/energy_onshore/" \
        --bind "${HPC_SCRATCH}" \
        --bind "${HPC_PROJECT}" \
        --bind "${APP_OUTPATH}/energy_onshore/opa/" \
        --bind "${APP_OUTPATH}/energy_onshore/" \
        --bind "${PYTHONPATH}" \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        --env PYTHONPATH="${PYTHONPATH}" \
        --env APP_OUTPATH="${APP_OUTPATH}" \
        --env "PYTHONNOUSERSITE=1" \
        $HPC_CONTAINER_DIR/energy_onshore/energy_onshore_${ENERGY_ONSHORE_VERSION}.sif \
        bash -c \
        "
    python3 "${SCRIPTDIR}"/energy_onshore/run_energy_onshore.py --iniyear ${SPLIT_INI_YEAR} --inimonth ${SPLIT_INI_MONTH} --iniday ${SPLIT_INI_DAY} --in_path "${APP_OUTPATH}/energy_onshore/opa/" --finyear ${SPLIT_INI_YEAR} --finmonth ${SPLIT_INI_MONTH} --finday ${SPLIT_INI_DAY} --out_path "${APP_OUTPATH}/energy_onshore/"
    "
}

#####################
# run ENERGY_OFFSHORE
# GLOBALS:
#       LIBDIR
#####################
function run_ENERGY_OFFSHORE() {
    cd "${SCRIPTDIR}/energy_offshore/" || exit
    REQUESTFILE=${HPCROOTDIR}/LOG_${EXPID}/request_${DATELIST}_${MEMBERS}_${CHUNK}_DN
    OUT_PATH="${APP_OUTPATH}/energy_offshore/"

    if [ ! -d "${OUT_PATH}" ]; then
        mkdir -p "${OUT_PATH}"
    fi

    # --app_outpath set as OPA path, although it would be meant as input path (worfklow issue #816)
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/energy_offshore/ #This step allows using dev versions of the application from the submodule

    # If the submodule does not exist, set PYTHONPATH to SCRIPTDIR (does not need to be SCRIPTDIR though)
    if [ -f "$SRC_DIR" ]; then
        export PYTHONPATH="${SRC_DIR}"
    else
        export PYTHONPATH="${SCRIPTDIR}"
    fi
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${SCRIPTDIR}/energy_offshore/" \
        --bind "${HPC_SCRATCH}" \
        --bind "${HPC_PROJECT}" \
        --bind "${PYTHONPATH}" \
        --bind "${OUT_PATH}" \
        --bind "${APP_OUTPATH}/energy_offshore/opa/" \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        --env PYTHONPATH=$PYTHONPATH \
        --env APP_OUTPATH="${APP_OUTPATH}/energy_offshore/opa/" \
        --env "PYTHONNOUSERSITE=1" \
        $HPC_CONTAINER_DIR/energy_offshore/energy_offshore_${ENERGY_OFFSHORE_VERSION}.sif \
        bash -c \
        "
    python3 "${SCRIPTDIR}"/energy_offshore/run_energy_offshore.py --hpcrootdir ${HPCROOTDIR} \
        --app_outpath "${APP_OUTPATH}/energy_offshore/opa/" \
        --projdest $PROJDEST --app $APP \
        --expid $EXPID --datelist $DATELIST --requestfile $REQUESTFILE \
        --start_year ${SPLIT_INI_YEAR} --start_month ${SPLIT_INI_MONTH} --start_day ${SPLIT_INI_DAY} \
        --end_year ${SPLIT_INI_YEAR} --end_month ${SPLIT_INI_MONTH} --end_day ${SPLIT_INI_DAY} --chunk ${SPLIT}
"
}

#####################
# run HYDROMET
# GLOBALS:
#       LIBDIR
#####################
function run_HYDROMET() {
    mkdir -p $APP_OUTPATH/hydromet/opa/kostra_out
    mkdir -p $APP_OUTPATH/hydromet/opa/WetCat_out_AL
    mkdir -p $APP_OUTPATH/hydromet/WetCat_out_AL
    mkdir -p $APP_OUTPATH/hydromet/opa/WetCat_out_BI
    mkdir -p $APP_OUTPATH/hydromet/WetCat_out_BI
    mkdir -p $APP_OUTPATH/hydromet/opa/WetCat_out_EA
    mkdir -p $APP_OUTPATH/hydromet/WetCat_out_EA
    mkdir -p $APP_OUTPATH/hydromet/opa/WetCat_out_FR
    mkdir -p $APP_OUTPATH/hydromet/WetCat_out_FR
    mkdir -p $APP_OUTPATH/hydromet/opa/WetCat_out_IB
    mkdir -p $APP_OUTPATH/hydromet/WetCat_out_IB
    mkdir -p $APP_OUTPATH/hydromet/opa/WetCat_out_ME
    mkdir -p $APP_OUTPATH/hydromet/WetCat_out_ME
    mkdir -p $APP_OUTPATH/hydromet/opa/WetCat_out_MD
    mkdir -p $APP_OUTPATH/hydromet/WetCat_out_MD
    mkdir -p $APP_OUTPATH/hydromet/opa/WetCat_out_SC
    mkdir -p $APP_OUTPATH/hydromet/WetCat_out_SC
    mkdir -p $APP_OUTPATH/hydromet/opa/processed_output $APP_OUTPATH/hydromet/opa/data
    cp -r ${APP_AUX_IN_DATA_DIR}/hydromet_v${HYDROMET_IN_DATA_VERSION}/* $APP_OUTPATH/hydromet/opa/data/
    cd $APP_OUTPATH/hydromet/
    REQUESTMODEL=%REQUEST.MODEL%
    REQUESTEXP=%REQUEST.EXPERIMENT%
    REQUESTACTIVITY=%REQUEST.ACTIVITY%
    REQUESTGEN=%REQUEST.GENERATION%
    PRECIP=%HYDROMET.2.OPAREQUEST.variable%
    if [ "$PRECIP" = "avg_tprate" ]; then
        echo "rain_unit: kg m-2 s-1" >temp.yml
        echo "data_var: avg_tprate" >>temp.yml
    else
        echo "rain_unit: m" >>temp.yml
        echo "data_var: tp" >temp.yml
    fi
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${SCRIPTDIR}/hydromet/" \
        --bind $HPC_PROJECT \
        --bind $APP_OUTPATH \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        --env APP_OUTPATH=${APP_OUTPATH} \
        --env "PYTHONNOUSERSITE=1" \
        --env REQUESTMODEL=$REQUESTMODEL \
        --env REQUESTEXP=$REQUESTEXP \
        --env REQUESTACTIVITY=$REQUESTACTIVITY \
        --env REQUESTGEN=$REQUESTGEN \
        --env SPLIT_INI_YEAR=${SPLIT_INI_YEAR} \
        --env SPLIT_INI_MONTH=${SPLIT_INI_MONTH} \
        --env SPLIT_INI_DAY=${SPLIT_INI_DAY} \
        --env SPLIT_END_YEAR=${SPLIT_END_YEAR} \
        --env SPLIT_END_MONTH=${SPLIT_END_MONTH} \
        --env SPLIT_END_DAY=${SPLIT_END_DAY} \
        $HPC_CONTAINER_DIR/hydromet/hydromet_${HYDROMET_VERSION}.sif \
        bash -c \
        "
    create_config
    sed '9d' -i template_config_hydromet.yml
    sed '24d' -i template_config_hydromet.yml
    sed "s,__OUTPATH__,$APP_OUTPATH/hydromet/opa/," -i template_config_hydromet.yml
    cat temp.yml >> template_config_hydromet.yml
    sed "s,ERA5-bias-corrected,$REQUESTMODEL," -i template_config_hydromet.yml
    sed "s,reanalysis,$REQUESTEXP," -i template_config_hydromet.yml
    sed "s,ScenarioMIP,$REQUESTACTIVITY," -i template_config_hydromet.yml
    sed "s,GENY,$REQUESTGEN," -i template_config_hydromet.yml
    sed '31,36d' -i template_config_hydromet.yml
    cp template_config_hydromet.yml template_config_hydromet_AL.yml
    cat "${SCRIPTDIR}"/hydromet/AL.txt  >> template_config_hydromet_AL.yml
    sed "s,WetCat_out,WetCat_out_AL," -i template_config_hydromet_AL.yml
    cp template_config_hydromet.yml template_config_hydromet_BI.yml
    cat "${SCRIPTDIR}"/hydromet/BI.txt  >> template_config_hydromet_BI.yml
    sed "s,WetCat_out,WetCat_out_BI," -i template_config_hydromet_BI.yml
    cp template_config_hydromet.yml template_config_hydromet_EA.yml
    cat "${SCRIPTDIR}"/hydromet/EA.txt  >> template_config_hydromet_EA.yml
    sed "s,WetCat_out,WetCat_out_EA," -i template_config_hydromet_EA.yml
    cp template_config_hydromet.yml template_config_hydromet_FR.yml
    cat "${SCRIPTDIR}"/hydromet/FR.txt  >> template_config_hydromet_FR.yml
    sed "s,WetCat_out,WetCat_out_FR," -i template_config_hydromet_FR.yml
    cp template_config_hydromet.yml template_config_hydromet_IB.yml
    cat "${SCRIPTDIR}"/hydromet/IB.txt  >> template_config_hydromet_IB.yml
    sed "s,WetCat_out,WetCat_out_IB," -i template_config_hydromet_IB.yml
    cp template_config_hydromet.yml template_config_hydromet_ME.yml
    cat "${SCRIPTDIR}"/hydromet/ME.txt  >> template_config_hydromet_ME.yml
    sed "s,WetCat_out,WetCat_out_ME," -i template_config_hydromet_ME.yml
    cp template_config_hydromet.yml template_config_hydromet_MD.yml
    cat "${SCRIPTDIR}"/hydromet/MD.txt  >> template_config_hydromet_MD.yml
    sed "s,WetCat_out,WetCat_out_MD," -i template_config_hydromet_MD.yml
    cp template_config_hydromet.yml template_config_hydromet_SC.yml
    cat "${SCRIPTDIR}"/hydromet/SC.txt  >> template_config_hydromet_SC.yml
    sed "s,WetCat_out,WetCat_out_SC," -i template_config_hydromet_SC.yml
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_AL.yml" ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_BI.yml" ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_EA.yml" ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_FR.yml" ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_IB.yml" ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_ME.yml" ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_MD.yml" ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_SC.yml" ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} ${SPLIT_INI_YEAR} ${SPLIT_INI_MONTH} ${SPLIT_INI_DAY} &
    wait
    mv ${APP_OUTPATH}/hydromet/opa/WetCat_out_AL/events/*.csv WetCat_out_AL/ 2>/dev/null || true
    mv ${APP_OUTPATH}/hydromet/opa/WetCat_out_BI/events/*.csv WetCat_out_BI/ 2>/dev/null || true
    mv ${APP_OUTPATH}/hydromet/opa/WetCat_out_EA/events/*.csv WetCat_out_EA/ 2>/dev/null || true
    mv ${APP_OUTPATH}/hydromet/opa/WetCat_out_FR/events/*.csv WetCat_out_FR/ 2>/dev/null || true
    mv ${APP_OUTPATH}/hydromet/opa/WetCat_out_IB/events/*.csv WetCat_out_IB/ 2>/dev/null || true
    mv ${APP_OUTPATH}/hydromet/opa/WetCat_out_ME/events/*.csv WetCat_out_ME/ 2>/dev/null || true
    mv ${APP_OUTPATH}/hydromet/opa/WetCat_out_MD/events/*.csv WetCat_out_MD/ 2>/dev/null || true
    mv ${APP_OUTPATH}/hydromet/opa/WetCat_out_SC/events/*.csv WetCat_out_SC/ 2>/dev/null || true
    "
}

#####################################################
# Run Hydroland application
######################################################
# defining needed Hydroland variables
function run_HYDROLAND() {
    HYDROLAND_DIR="${SCRIPTDIR}/hydroland"
    HYDROLAND_OPA="${APP_OUTPATH}/hydroland/opa"
    STAT_FREQ=%HYDROLAND.1.OPAREQUEST.stat_freq%
    GRID=%HYDROLAND.1.GSVREQUEST.grid%
    TEMP=%HYDROLAND.1.OPAREQUEST.variable%
    PRE=%HYDROLAND.2.OPAREQUEST.variable%
    INIT_FILES="${APP_AUX_IN_DATA_DIR}/hydroland_v${HYDROLAND_IN_DATA_VERSION}"
    SPLITSIZEUNIT=%EXPERIMENT.SPLITSIZEUNIT%

    cd "${HYDROLAND_DIR}" || exit
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${HPC_PROJECT}" \
        --bind "${HYDROLAND_OPA}" \
        --bind "${INIT_FILES}" \
        --bind "${HYDROLAND_DIR}" \
        --bind "${APP_OUTPATH}/hydroland/" \
        "${HPC_CONTAINER_DIR}/hydroland/hydroland_${HYDROLAND_VERSION}.sif" \
        bash -c "bash -e run_hydroland.sh \
        \"${HYDROLAND_DIR}\" \"${HYDROLAND_OPA}\" \"${SPLIT_INI_YEAR}\" \
        \"${SPLIT_INI_MONTH}\" \"${SPLIT_INI_DAY}\" \"${SPLIT_END_YEAR}\" \
        \"${SPLIT_END_MONTH}\" \"${SPLIT_END_DAY}\" \"${STAT_FREQ}\" \"${TEMP}\" \
        \"${PRE}\" \"${INIT_FILES}\" \"${APP_OUTPATH}\" \"${GRID}\" \"${SPLITSIZEUNIT}\""
}

#####################
# run WILDFIRES_WISE
# GLOBALS:
#       LIBDIR
#####################
function run_WILDFIRES_WISE() {
    cd "${SCRIPTDIR}/wildfires_wise/" || exit
    IN_PATH="${APP_AUX_IN_DATA_DIR}/wildfires_wise_v${WILDFIRES_WISE_IN_DATA_VERSION}"
    OUT_PATH="${APP_OUTPATH}/wildfires_wise/"

    if [ ! -d "${OUT_PATH}" ]; then
        mkdir -p "${OUT_PATH}"
    fi

    singularity exec \
        --bind "${HPC_SCRATCH}" \
        --bind "${HPC_PROJECT}" \
        --bind "${SCRIPTDIR}" \
        --bind "${HPC_PROJECT}" \
        --bind "${IN_PATH}":/testjobs \
        --bind "${OUT_PATH}":/wise_output \
        --bind "${APP_OUTPATH}/wildfires_wise/opa":/input_data \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        $HPC_CONTAINER_DIR/wildfires_wise/wildfires_wise_${WILDFIRES_WISE_VERSION}.sif \
        bash -c \
        "
        python3 "${SCRIPTDIR}"/wildfires_wise/run_wildfires_wise.py --in_path "/input_data/" --out_path "${OUT_PATH}" \
        --year_start "${SPLIT_INI_YEAR}" --month_start "${SPLIT_INI_MONTH}" --day_start "${SPLIT_INI_DAY}" \
        --year_end "${SPLIT_INI_YEAR}" --month_end "${SPLIT_INI_MONTH}" --day_end "${SPLIT_INI_DAY}"
        "
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

    cd "${SCRIPTDIR}/wildfires_fwi/" || exit
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/wildfires_fwi/

    # If the submodule does not exist, set PYTHONPATH to SCRIPTDIR (does not need to be SCRIPTDIR though)
    if [ -f "$SRC_DIR" ]; then
        export PYTHONPATH="${SRC_DIR}"
    else
        export PYTHONPATH="${SCRIPTDIR}"
    fi

    singularity exec \
        --bind "${SCRIPTDIR}/wildfires_fwi/" \
        --bind "${HPC_SCRATCH}" \
        --bind "${HPC_PROJECT}" \
        --bind "${PYTHONPATH}" \
        --bind "${APP_OUTPATH}/wildfires_fwi/opa" \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        $HPC_CONTAINER_DIR/wildfires_fwi/wildfires_fwi_${WILDFIRES_FWI_VERSION}.sif \
        bash -c \
        "
 python3 "${SCRIPTDIR}"/wildfires_fwi/run_wildfires_fwi.py --year ${INI_YEAR} --month ${INI_MONTH} --day ${INI_DAY}  --hpcrootdir ${HPCROOTDIR}  --hpcprojdir ${PROJDEST} --hpctmpdir "${APP_OUTPATH}"/wildfires_fwi/opa
"
}

#####################
# run OBSALL
# GLOBALS:
#       HPC_PROJEC, HPC_SCRATCH
#       EXPID, LIBDIR
#####################
function run_OBSALL() {
    # Define experiment tmp scratch folder
    # GSVEXTR_DATA_DIR : /scratch/project_465000454/tmp/EXPID - gsv extracted data is here
    # SRC_DIR : /scratch/project_465000454/ama/EXPID/git_project/obsall - run there py-script
    # lib/LUMI/config.sh (load_environment_OBSALL) (auto generated comment)
    load_environment_OBSALL "$HPC_PROJECT" "$EXPID"
    cd "${SCRIPTDIR}/obsall/" || exit

    load_environment_gsv "$HPC_PROJECT" "$EXPID" #TODO: obsall need to have the gsv container running, from what I see here.
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/obsall/
    export PYTHONPATH=$SRC_DIR:$PYTHONPATH
    export HPCROOTDIR=$HPCROOTDIR
    export EXPID=$EXPID
    export SRC_OBSALL_DIR=$SRC_DIR
    GSVEXTR_DATA_DIR=${APP_OUTPATH}       # dir where initially gsv_extraced modeled data are stored
    cp $GSVEXTR_DATA_DIR/*.nc ${SRC_DIR}/ # copying gsv extracted data to dir with OBSALL Apps
    cd ${SRC_DIR}
    cd ${SRC_OBSALL_DIR}
    pwd
    ./run_obsall.sh #sh-script to execute OBSALL Apps
    #python run_obsall.py # Aina, BSC suggested to replace py- by sh- script (run_obsall.sh)
}

###################################################
# Run dummy function fr the data retrieval workflow
###################################################
function run_DATA() {
    echo "Dummy script to run data retrieval workflow."
}

# source libraries
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

APP="${JOBNAME#*APP_}"

# load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# run apps
run_"${APP^^}"
