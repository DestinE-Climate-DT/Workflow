#!/bin/bash
#
# This step loads the necessary environment and then compiles the different models
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
EXPID=${4:-%DEFAULT.EXPID%}
DATELIST=${5:-%EXPERIMENT.DATELIST%}
MEMBER_LIST=${6:-%EXPERIMENT.MEMBERS%}
CHUNK=${7:-%CHUNK%}
INI_DAY=${8:-%CHUNK_START_DAY%}
INI_MONTH=${9:-%CHUNK_START_MONTH%}
INI_YEAR=${10:-%CHUNK_START_YEAR%}
OPA_OUT=${11:-%OPAREQUEST.1.out_filepath%}
CHUNK_START_DATE=${12:-%CHUNK_START_DATE%}
CHUNK_SECOND_TO_LAST_DATE=${13:-%CHUNK_SECOND_TO_LAST_DATE%}
MEMBER=${14:-%MEMBER%}
END_DAY=${15:-%CHUNK_SECOND_TO_LAST_DAY%}
END_MONTH=${16:-%CHUNK_SECOND_TO_LAST_MONTH%}
END_YEAR=${17:-%CHUNK_SECOND_TO_LAST_YEAR%}
JOBNAME=${18:-%JOBNAME%}
SPLIT=${19:-%SPLIT%}
WORKFLOW=${20:-%RUN.WORKFLOW%}
RUN_TYPE=${21:-%RUN.TYPE%}
HPC_PROJECT=${22:-%CONFIGURATION.HPC_PROJECT_DIR%}
HPC_SCRATCH=${23:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${24:-%CURRENT_CONTAINER_DIR%}
EXPVER=${25:-%REQUEST.EXPVER%}
CLASS=${26:-%REQUEST.CLASS%}
GSV_WEIGHTS_PATH=${27:-%GSV.WEIGHTS_PATH%}
LIBDIR=${28:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${29:-%CONFIGURATION.SCRIPTDIR%}
ENERGY_INDICATORS_VERSION=${30:-%ENERGY_INDICATORS.VERSION%}
ENERGY_OFFSHORE_VERSION=${31:-%ENERGY_OFFSHORE.VERSION%}
GSV_VERSION=${32:-%GSV.VERSION%}
AQUA_VERSION=${33:-%AQUA.VERSION%}
HYDROLAND_VERSION=${34:-%HYDROLAND.VERSION%}
WILDFIRES_WISE_VERSION=${35:-%WILDFIRES_WISE.VERSION%}
WILDFIRES_FWI_VERSION=${36:-%WILDFIRES_FWI.VERSION%}
HYDROMET_VERSION=${37:-%HYDROMET.VERSION%}
HPC_CONTAINER_DIR=${38:-%CURRENT_CONTAINER_DIR%}
SPLIT_INI_DAY=${39:-%SPLIT_START_DAY%}
SPLIT_INI_MONTH=${40:-%SPLIT_START_MONTH%}
SPLIT_INI_YEAR=${41:-%SPLIT_START_YEAR%}
SPLIT_END_DAY=${42:-%SPLIT_END_DAY%}
SPLIT_END_MONTH=${43:-%SPLIT_END_MONTH%}
SPLIT_END_YEAR=${44:-%SPLIT_END_YEAR%}
SPLIT_SECOND_TO_LAST_DATE=${45:-%SPLIT_SECOND_TO_LAST_DATE%}
PROJECT=${46:-%CURRENT_PROJECT%}
SPLITS=${47:-%SPLITS%}
ENERGY_INDICATORS_IN_DATA_VERSION=${48:-%ENERGY_INDICATORS.IN_DATA_VERSION%}
ENERGY_OFFSHORE_IN_DATA_VERSION=${49:-%ENERGY_OFFSHORE.IN_DATA_VERSION%}
HYDROMET_IN_DATA_VERSION=${50:-%HYDROMET.IN_DATA_VERSION%}
HYDROLAND_IN_DATA_VERSION=${51:-%HYDROLAND.IN_DATA_VERSION%}
WILDFIRES_WISE_IN_DATA_VERSION=${52:-%WILDFIRES_WISE.IN_DATA_VERSION%}
WILDFIRES_FWI_IN_DATA_VERSION=${53:-%WILDFIRES_FWI.IN_DATA_VERSION%}
APP_AUX_IN_DATA_DIR=${54:-%APP_AUX_IN_DATA_DIR%}
HPC_PROJECT_ROOT=${55:-%CURRENT_HPC_PROJECT_ROOT%}
SCRATCH_DIR=${56:-%CURRENT_SCRATCH_DIR%}
LOCAL_DIR=${57:-%CURRENT_LOCAL_DIR%}
HYDROLAND_STAT_FREQ=${58:-%HYDROLAND.STAT_FREQ%}
HYDROLAND_GRID=${59:-%HYDROLAND.GRID%}
HYDROLAND_TEMP=${60:-%HYDROLAND.TAVG_VARIABLE%}
HYDROLAND_PRE=${61:-%HYDROLAND.PRE_VARIABLE%}
HYDROLAND_RUN_FREQUENCY=${62:-%HYDROLAND.RUN_FREQUENCY%}
HYDROLAND_INIT_FILES=${63:-%HYDROLAND.INIT_FILES%}
HYDROLAND_BIAS_ADJUSTMENT=${64:-%HYDROLAND.BIAS_ADJUSTMENT.APPLY_BA%}
HYDROLAND_DELETE_FILES=${65:-%HYDROLAND.DELETE_FILES%}
HYDROLAND_APPLY_INDICATORS=${66:-%HYDROLAND.APPLY_INDICATORS%}
HYDROLAND_PRIOR_APP_OUTPATH=${67:-%HYDROLAND.PRIOR_APP_OUTPATH%}
HYDROLAND_RESTART_FROM_PRIOR_RUN=${68:-%HYDROLAND.RESTART_FROM_PRIOR_RUN%}
HYDROLAND_APPLY_CDO_MERGETIME=${69:-%HYDROLAND.APPLY_CDO_MERGETIME%}
OBSALL_VERSION=${70:-%OBSALL.VERSION%}
REQUEST_REALIZATION=${71:-%REQUEST.REALIZATION%}
HYDROMET_RUN_FREQUENCY=${72:-%HYDROMET.RUN_FREQUENCY%}
ENERGY_INDICATORS_MASK_FILE_5=${73:-%ENERGY_INDICATORS.MASK_FILE_5%}
ENERGY_INDICATORS_MASK_FILE_10=${74:-%ENERGY_INDICATORS.MASK_FILE_10%}
ENERGY_INDICATORS_MASK_FILE_25=${75:-%ENERGY_INDICATORS.MASK_FILE_25%}
ENERGY_INDICATORS_GRID=${76:-%ENERGY_INDICATORS.GRID%}
ENERGY_OFFSHORE_COMPUTE_ICING=${77:-%ENERGY_OFFSHORE.COMPUTE_ICING%}
OBSALL_IN_DATA_VERSION=${78:-%OBSALL.IN_DATA_VERSION%}

# END_HEADER

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1) # Value of the HPC variable based on the current architecture

# select mask file depending on grid
if [ "$ENERGY_INDICATORS_GRID" == "0.05/0.05" ]; then
    ENERGY_INDICATORS_MASK_FILE=$ENERGY_INDICATORS_MASK_FILE_5
elif [ "$ENERGY_INDICATORS_GRID" == "0.1/0.1" ]; then
    ENERGY_INDICATORS_MASK_FILE=$ENERGY_INDICATORS_MASK_FILE_10
elif [ "$ENERGY_INDICATORS_GRID" == "0.25/0.25" ]; then
    ENERGY_INDICATORS_MASK_FILE=$ENERGY_INDICATORS_MASK_FILE_25
else
    echo "No mask applied as grid is not 5, 10 or 25 km."
fi

#####################
# run ENERGY_INDICATORS
# GLOBALS:
#       LIBDIR
#####################
function run_ENERGY_INDICATORS() {
    cd "${SCRIPTDIR}/energy_indicators/" || exit
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/energy_indicators/

    # Check if output directory exists and create it otherwise
    mkdir -p "${APP_OUTPATH}/${SPLIT_INI_YEAR}/${SPLIT_INI_MONTH}/"

    # If the submodule does not exist, set PYTHONPATH to SCRIPTDIR (does not need to be SCRIPTDIR though)
    if [ -d "$SRC_DIR" ]; then
        export PYTHONPATH="${SRC_DIR}"
    else
        export PYTHONPATH="${SCRIPTDIR}"
    fi

    export MASK_FILE="${APP_AUX_IN_DATA_DIR}/energy_indicators_v${ENERGY_INDICATORS_IN_DATA_VERSION}/${ENERGY_INDICATORS_MASK_FILE}"

    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${SCRIPTDIR}/energy_indicators/" \
        --bind "${HPC_SCRATCH}" \
        --bind "${HPC_PROJECT}" \
        --bind "${APP_OUTPATH}" \
        --bind "${OPA_OUTPATH}" \
        --bind "${PYTHONPATH}" \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        --env PYTHONPATH="${PYTHONPATH}" \
        --env APP_OUTPATH="${APP_OUTPATH}" \
        --env OPA_OUTPATH="${OPA_OUTPATH}" \
        --env "PYTHONNOUSERSITE=1" \
        --env MASK_FILE="${MASK_FILE}" \
        $HPC_CONTAINER_DIR/energy_indicators/energy_indicators_${ENERGY_INDICATORS_VERSION}.sif \
        bash -c \
        "
    python3 "${SCRIPTDIR}"/energy_indicators/run_energy_indicators.py --iniyear ${SPLIT_INI_YEAR} --inimonth ${SPLIT_INI_MONTH} --iniday ${SPLIT_INI_DAY} --in_path "${OPA_OUTPATH}/" --finyear ${SPLIT_INI_YEAR} --finmonth ${SPLIT_INI_MONTH} --finday ${SPLIT_INI_DAY} --out_path "${APP_OUTPATH}/${SPLIT_INI_YEAR}/${SPLIT_INI_MONTH}/" --mask_file ${MASK_FILE}
    "

    if [ "${CHUNK_SECOND_TO_LAST_DATE}" = "${SPLIT_SECOND_TO_LAST_DATE}" ]; then
        echo "Execution at the end of the month."

        # copy histograms, percentiles and other opa stats as if they were APP output, at the end of the month.
        WS_HISTO_FILE=${OPA_OUTPATHTDIG2}/${SPLIT_INI_YEAR}_${SPLIT_INI_MONTH}*ws_timestep_60_monthly_histogram_bin*.nc
        WS_PERCENTILE_FILE=${OPA_OUTPATHTDIG1}/${SPLIT_INI_YEAR}_${SPLIT_INI_MONTH}*ws_timestep_60_monthly_percentile.nc

        # other OPA files
        OPA_FILE=${OPA_OUTPATH}/${SPLIT_INI_YEAR}_${SPLIT_INI_MONTH}*ws_timestep_60_daily_max.nc

        if ls $WS_HISTO_FILE 1>/dev/null 2>&1; then
            mv $WS_HISTO_FILE ${APP_OUTPATH}/${SPLIT_INI_YEAR}/${SPLIT_INI_MONTH}/
            echo "WS histogram file(s) copied successfully."
        else
            echo "No WS histogram file found."
        fi
        if ls $WS_PERCENTILE_FILE 1>/dev/null 2>&1; then
            mv $WS_PERCENTILE_FILE ${APP_OUTPATH}/${SPLIT_INI_YEAR}/${SPLIT_INI_MONTH}/
            echo "WS 99th percentile file(s) copied successfully."
        else
            echo "No 99th percentile file found."
        fi
        if ls $OPA_FILE 1>/dev/null 2>&1; then
            mv $OPA_FILE ${APP_OUTPATH}/${SPLIT_INI_YEAR}/${SPLIT_INI_MONTH}/
            echo "Monthly aggreg of WS daily max file copied successfully."
        else
            echo "No monthly aggreg of WS daily max file found."
        fi

        shopt -s nullglob

        dir="${APP_OUTPATH}/${SPLIT_INI_YEAR}/${SPLIT_INI_MONTH}/"

        CF_I_FILES=("$dir"/*cf_I*)
        CF_S_FILES=("$dir"/*cf_S*)
        HISTO_I_FILES=("$dir"/*cf_i*_histogram_bin_*.nc)
        HISTO_S_FILES=("$dir"/*cf_s*_histogram_bin_*.nc)

        FILES=("${CF_I_FILES[@]}" "${CF_S_FILES[@]}" "${HISTO_I_FILES[@]}" "${HISTO_S_FILES[@]}")

        if [ ${#FILES[@]} -gt 0 ]; then
            rm -v "${FILES[@]}"
        fi

        # delete trailing *final # TODO: do that at runscript level
        cd "$dir" || exit 1

        for f in *_final; do
            mv "$f" "${f%_final}"
        done
    fi
}

#####################
# run ENERGY_OFFSHORE
# GLOBALS:
#       LIBDIR
#####################
function run_ENERGY_OFFSHORE() {
    cd "${SCRIPTDIR}/energy_offshore/" || exit
    REQUESTFILE=${HPCROOTDIR}/LOG_${EXPID}/request_${DATELIST}_${MEMBER}_${CHUNK}_DN
    OUT_PATH="${APP_OUTPATH}/"

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

    # app devs to have a look at --app_outpath "${OPA_OUTPATH}/". They share opa and app path.
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${SCRIPTDIR}/energy_offshore/" \
        --bind "${HPC_SCRATCH}" \
        --bind "${HPC_PROJECT}" \
        --bind "${PYTHONPATH}" \
        --bind "${OUT_PATH}" \
        --bind "${OPA_OUTPATH}/" \
        --bind "${APP_OUTPATH}/" \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        --env PYTHONPATH=$PYTHONPATH \
        --env APP_OUTPATH="${APP_OUTPATH}/" \
        --env "PYTHONNOUSERSITE=1" \
        $HPC_CONTAINER_DIR/energy_offshore/energy_offshore_${ENERGY_OFFSHORE_VERSION}.sif \
        bash -c \
        "
    python3 "${SCRIPTDIR}"/energy_offshore/run_energy_offshore.py \
        --hpcrootdir ${HPCROOTDIR} \
        --opa_outpath "${OPA_OUTPATH}" \
        --app_outpath "${APP_OUTPATH}/" \
        --app $APP \
        --expid $EXPID \
        --datelist $DATELIST \
        --requestfile $REQUESTFILE \
        --start_year ${SPLIT_INI_YEAR} \
        --start_month ${SPLIT_INI_MONTH} \
        --start_day ${SPLIT_INI_DAY} \
        --end_year ${SPLIT_INI_YEAR} \
        --end_month ${SPLIT_INI_MONTH} \
        --end_day ${SPLIT_INI_DAY} \
        --chunk ${SPLIT} \
        --compute_icing ${ENERGY_OFFSHORE_COMPUTE_ICING}
"
}

#####################
# run HYDROMET
# GLOBALS:
#       LIBDIR
#####################
function run_HYDROMET() {
    REQUESTMODEL=%REQUEST.MODEL%
    mkdir -p $APP_OUTPATH/kostra_out/
    mkdir -p $APP_OUTPATH/WetCat_out_AL/processed_output
    mkdir -p $APP_OUTPATH/WetCat_out_BI/processed_output
    mkdir -p $APP_OUTPATH/WetCat_out_EA/processed_output
    mkdir -p $APP_OUTPATH/WetCat_out_FR/processed_output
    mkdir -p $APP_OUTPATH/WetCat_out_IB/processed_output
    mkdir -p $APP_OUTPATH/WetCat_out_ME/processed_output
    mkdir -p $APP_OUTPATH/WetCat_out_MD/processed_output
    mkdir -p $APP_OUTPATH/WetCat_out_SC/processed_output
    mkdir -p $APP_OUTPATH/data
    cp -r ${APP_AUX_IN_DATA_DIR}/hydromet_v${HYDROMET_IN_DATA_VERSION}/${REQUESTMODEL,,}/* $APP_OUTPATH/data/
    cp ${SCRIPTDIR}/hydromet/*.txt $APP_OUTPATH/
    cd $APP_OUTPATH
    if [ "$HYDROMET_RUN_FREQUENCY" = "day" ] && [ -n "$SPLIT_INI_YEAR" ]; then
        H_INI_YEAR="$SPLIT_INI_YEAR"
        H_INI_MONTH="$SPLIT_INI_MONTH"
        H_INI_DAY="$SPLIT_INI_DAY"
        H_END_YEAR="$SPLIT_END_YEAR"
        H_END_MONTH="$SPLIT_END_MONTH"
        H_END_DAY="$SPLIT_END_DAY"
    else
        H_INI_YEAR="$INI_YEAR"
        H_INI_MONTH="$INI_MONTH"
        H_INI_DAY="$INI_DAY"
        H_END_YEAR="$END_YEAR"
        H_END_MONTH="$END_MONTH"
        H_END_DAY="$END_DAY"
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
        --env H_INI_YEAR=${H_INI_YEAR} \
        --env H_INI_MONTH=${H_INI_MONTH} \
        --env H_INI_DAY=${H_INI_DAY} \
        --env H_END_YEAR=${H_END_YEAR} \
        --env H_END_MONTH=${H_END_MONTH} \
        --env H_END_DAY=${H_END_DAY} \
        --env PRECIP=${HYDROLAND_PRE} \
        --env OPA_OUTPATH=${OPA_OUTPATH} \
        $HPC_CONTAINER_DIR/hydromet/hydromet_${HYDROMET_VERSION}.sif \
        bash -c \
        "
    create_config create
    sed "s,__OUTPATH__,$APP_OUTPATH/," -i template_config_hydromet.yml
    sed "s,__OPAPATH__,$OPA_OUTPATH/," -i template_config_hydromet.yml
    cp template_config_hydromet.yml template_config_hydromet_AL.yml
    cp template_config_hydromet.yml template_config_hydromet_BI.yml
    cp template_config_hydromet.yml template_config_hydromet_EA.yml
    cp template_config_hydromet.yml template_config_hydromet_FR.yml
    cp template_config_hydromet.yml template_config_hydromet_IB.yml
    cp template_config_hydromet.yml template_config_hydromet_ME.yml
    cp template_config_hydromet.yml template_config_hydromet_MD.yml
    cp template_config_hydromet.yml template_config_hydromet_SC.yml
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_AL.yml" ${H_INI_YEAR} ${H_INI_MONTH} ${H_INI_DAY} ${H_END_YEAR} ${H_END_MONTH} ${H_END_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_BI.yml" ${H_INI_YEAR} ${H_INI_MONTH} ${H_INI_DAY} ${H_END_YEAR} ${H_END_MONTH} ${H_END_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_EA.yml" ${H_INI_YEAR} ${H_INI_MONTH} ${H_INI_DAY} ${H_END_YEAR} ${H_END_MONTH} ${H_END_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_FR.yml" ${H_INI_YEAR} ${H_INI_MONTH} ${H_INI_DAY} ${H_END_YEAR} ${H_END_MONTH} ${H_END_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_IB.yml" ${H_INI_YEAR} ${H_INI_MONTH} ${H_INI_DAY} ${H_END_YEAR} ${H_END_MONTH} ${H_END_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_ME.yml" ${H_INI_YEAR} ${H_INI_MONTH} ${H_INI_DAY} ${H_END_YEAR} ${H_END_MONTH} ${H_END_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_MD.yml" ${H_INI_YEAR} ${H_INI_MONTH} ${H_INI_DAY} ${H_END_YEAR} ${H_END_MONTH} ${H_END_DAY} &
    python3 "${SCRIPTDIR}"/hydromet/run_hydromet.py "template_config_hydromet_SC.yml" ${H_INI_YEAR} ${H_INI_MONTH} ${H_INI_DAY} ${H_END_YEAR} ${H_END_MONTH} ${H_END_DAY} &
    wait
    if { [[ "$H_INI_YEAR" == "2014" && "$H_INI_MONTH" == "12" ]] \
    || [[ "$H_INI_YEAR" == "2049" && "$H_INI_MONTH" == "12" ]]; }; then
    clean_output --path $APP_OUTPATH/
    fi
    "

}

#####################################################
# Run Hydroland application
######################################################
# defining needed Hydroland variables
function run_HYDROLAND() {
    if [ ! -d "${APP_OUTPATH}" ]; then
        mkdir -p "${APP_OUTPATH}"
    fi

    # Conditionally append optional flags
    extra_args=()
    if [[ "${HYDROLAND_BIAS_ADJUSTMENT}" == "True" ]]; then
        extra_args+=(--bias-adjustment)
    fi
    if [[ "${HYDROLAND_DELETE_FILES}" == "True" ]]; then
        extra_args+=(--delete-files)
    fi
    if [[ "${HYDROLAND_APPLY_INDICATORS}" == "True" ]]; then
        extra_args+=(--apply-indicators)
    fi
    if [[ "${HYDROLAND_RESTART_FROM_PRIOR_RUN}" == "True" ]]; then
        extra_args+=(--restart-from-prior-run)
    fi
    if [[ "${HYDROLAND_APPLY_CDO_MERGETIME}" == "True" ]]; then
        extra_args+=(--apply-cdo-mergetime)
    fi

    # Executing Hydroland
    cd "${SCRIPTDIR}/hydroland" || exit 1
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${HPC_PROJECT}" \
        --bind "${OPA_OUTPATH}/" \
        --bind "${HYDROLAND_INIT_FILES}" \
        --bind "${APP_OUTPATH}/" \
        "${HPC_CONTAINER_DIR}/hydroland/hydroland_${HYDROLAND_VERSION}.sif" \
        python3 "${SCRIPTDIR}/hydroland/run_hydroland.py" \
        --hydroland-opa "${OPA_OUTPATH}/" \
        --init-files "${HYDROLAND_INIT_FILES}" \
        --app-outpath "${APP_OUTPATH}/" \
        --ini-year-chunk "${INI_YEAR}" \
        --ini-month-chunk "${INI_MONTH}" \
        --ini-day-chunk "${INI_DAY}" \
        --end-year-chunk "${END_YEAR}" \
        --end-month-chunk "${END_MONTH}" \
        --end-day-chunk "${END_DAY}" \
        --ini-year-split "${SPLIT_INI_YEAR}" \
        --ini-month-split "${SPLIT_INI_MONTH}" \
        --ini-day-split "${SPLIT_INI_DAY}" \
        --stat-freq "${HYDROLAND_STAT_FREQ}" \
        --pre "${HYDROLAND_PRE}" \
        --temp "${HYDROLAND_TEMP}" \
        --grid "${HYDROLAND_GRID}" \
        --run-frequency "${HYDROLAND_RUN_FREQUENCY}" \
        --prior-app-outpath "${HYDROLAND_PRIOR_APP_OUTPATH}" \
        "${extra_args[@]}"
}

#####################
# run WILDFIRES_WISE
# GLOBALS:
#       LIBDIR
#####################
function run_WILDFIRES_WISE() {
    cd "${SCRIPTDIR}/wildfires_wise/" || exit
    IN_PATH="${APP_AUX_IN_DATA_DIR}/wildfires_wise_v${WILDFIRES_WISE_IN_DATA_VERSION}"
    OUT_PATH="${APP_OUTPATH}/"

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
        --bind "${OPA_OUTPATH}":/input_data \
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

    if [ ! -d "${APP_OUTPATH}" ]; then
        mkdir -p "${APP_OUTPATH}"
    fi

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
        --bind "${OPA_OUTPATH}/" \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        $HPC_CONTAINER_DIR/wildfires_fwi/wildfires_fwi_${WILDFIRES_FWI_VERSION}.sif \
        bash -c \
        "
 python3 "${SCRIPTDIR}"/wildfires_fwi/run_wildfires_fwi.py --year ${INI_YEAR} --month ${INI_MONTH} --day ${INI_DAY}  --hpcrootdir ${HPCROOTDIR}  --hpcprojdir ${PROJDEST} --hpctmpdir "${OPA_OUTPATH}"/
"
}

#####################
# run OBSALL
# GLOBALS:
#       HPC_PROJEC, HPC_SCRATCH
#       EXPID, LIBDIR
#####################
function run_OBSALL() {

    cd "${SCRIPTDIR}/obsall/" || exit
    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/obsall/

    # Check if output directory exists and create it otherwise
    mkdir -p "${APP_OUTPATH}"

    # If the submodule does not exist, set PYTHONPATH to SCRIPTDIR (does not need to be SCRIPTDIR though)
    if [ -d "$SRC_DIR" ]; then
        export PYTHONPATH="${SRC_DIR}"
    else
        export PYTHONPATH="${SCRIPTDIR}"
    fi

    container=$HPC_CONTAINER_DIR/obsall/obsall_${OBSALL_VERSION}.sif
    obsallDataPath="${APP_AUX_IN_DATA_DIR}/obsall_v${OBSALL_IN_DATA_VERSION}"
    experiment=$EXPID
    current_date=$CHUNK_START_DATE
    #end_date=${END_YEAR}${END_MONTH}${END_DAY}
    # Started thinking about possible monthly application implementation
    # given that the workflow provides one month of daily files at once.
    if [ $(echo $current_date | cut -c 5-8) == '1231' ]; then
        plots="--graphCompute True"
    else
        plots=""
    fi
    restart=''
    clean_scratch='--cleanScratch True'
    datatype=("SYNOP" "TEMP")
    obsPath=(
        "$obsallDataPath/SYNOP/input/STATDATASYNOP/HadISD/station_lists"
        "$obsallDataPath/TEMP/input/STATDATATEMP/RHARM/station_lists"
        "$obsallDataPath/TEMP/input/radsim_conf_files"
    )
    timestep=("0100" "1200" "0100")
    grid=("0.1/0.1" "0.1/0.1" "2.0/2.0")
    metvars=("2t"
        "2t t"
        "2t 2d skt sp 10u 10v t q clwc avg_siconc"
    )
    mode="online"

    for i in "${!datatype[@]}"; do
        singularity exec --cleanenv --no-home \
            --bind $SCRIPTDIR/obsall \
            --bind ${OPA_OUTPATH} \
            --bind $APP_OUTPATH \
            --bind $obsallDataPath \
            --env SCRIPTDIR=$SCRIPTDIR \
            --env dataPathIn=$obsallDataPath \
            --env dataPathOut=$APP_OUTPATH \
            --env experiment=$experiment \
            --env cur_date_s=$current_date \
            --env plots="$plots" \
            --env restart="$restart" \
            --env clean_scratch="$clean_scratch" \
            --env datatype="$datatype" \
            --env obspath="$obsPath" \
            --env timestep="$timestep" \
            --env grid=$grid \
            --env metvars=$metvars \
            --env mode="$mode" \
            --env OPA_OUTPATH="${OPA_OUTPATH}" \
            --env PYTHONPATH=/OBSALL \
            $container bash -c "
                cd $SCRIPTDIR/obsall
                python3 run_obsall.py \
                    --dataPathIn \$dataPathIn \
                    --dataPathOut \$dataPathOut \
                    --expName \$experiment \
                    --sDate \${cur_date_s}00 \
                    --eDate \${cur_date_s}23 \
                    --grid ${grid[$i]} \
                    --metVariable ${metvars[$i]} \
                    --obsPath ${obsPath[$i]} \
                    \$plots \$restart \$clean_scratch \
                    --dataType ${datatype[$i]} \
                    --timeStep ${timestep[$i]} \
                    --mode \$mode \
                    --GsvDataDump \$OPA_OUTPATH
            "
    done
    year=$(echo $current_date | cut -c 1-4)
    month=$(echo $current_date | cut -c 5-6)
    day=$(echo $current_date | cut -c 7-8)
    # Remove GSV files that have been used.
    rm ${OPA_OUTPATH}/${year}_${month}_${day}_*raw_data.nc
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

# lib/common/util.sh (get_member_number) (auto generated comment)
REALIZATION=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

# For apps workflows and a single request member,
# then read the REQUEST.REALIZATION variable
# Otherwise, REALIZATION is the current member number.
# See https://earth.bsc.es/gitlab/digital-twins/de_340-2/workflow/-/issues/1191
read -r -a MEMBER_LIST <<<"$MEMBER_LIST"

if [[ ${WORKFLOW,,} == "apps" && "${#MEMBER_LIST[@]}" == 1 ]]; then
    REALIZATION=${REQUEST_REALIZATION}
fi

APP="${JOBNAME#*APP_}"

# APP and OPA outpaths
APP_OUTPATH="${HPCROOTDIR}/output/${APP,,}/${DATELIST}/member0${REALIZATION}/"
OPA_OUTPATH="${HPCROOTDIR}/opa/${APP,,}/${DATELIST}/member0${REALIZATION}/"
# trick to deal with multiple opas for energy indicators.
if [[ "${APP^^}" == "ENERGY_INDICATORS" ]]; then
    export OPA_OUTPATHTDIG1="${HPCROOTDIR}/opa/energytdig1/${DATELIST}/member0${REALIZATION}/"
    export OPA_OUTPATHTDIG2="${HPCROOTDIR}/opa/energytdig2/${DATELIST}/member0${REALIZATION}/"
fi

# load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# run apps
run_"${APP^^}"
