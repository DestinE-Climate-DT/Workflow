#!/usr/bin/env bash

# Usage function to display help message
usage() {
    cat <<EOF
Usage: run_hydroland.sh HYDROLAND_DIR HYDROLAND_OPA INI_YEAR INI_MONTH INI_DAY \\
                        END_YEAR END_MONTH END_DAY STAT_FREQ TEMP PRE \\
                        INIT_FILES APP_OUTPATH GRID SPLITSIZEUNIT

Run Hydroland workflows.

Arguments:
  HYDROLAND_DIR       Path to your Hydroland repo directory.
  HYDROLAND_OPA       Operator/model flag (e.g. climate model date or experiment).
  INI_YEAR            Start year (YYYY).
  INI_MONTH           Start month (MM).
  INI_DAY             Start day (DD).
  END_YEAR            End   year (YYYY).
  END_MONTH           End   month (MM).
  END_DAY             End   day   (DD).
  STAT_FREQ           Data frequency: “daily” or “hourly”.
  TEMP                Temperature variable name.
  PRE                 Precipitation variable name.
  INIT_FILES          Path to initialization files.
  APP_OUTPATH         Base path for all outputs.
  GRID                Grid resolution (“0.1/0.1” or “0.05/0.05”).
  SPLITSIZEUNIT       How you split time (“month” or “day”).
EOF
    exit 0
}

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
fi

# Need exactly 15 arguments now
if [[ $# -lt 15 ]]; then
    echo "Error: Missing required arguments." >&2
    usage
fi

# Positional arguments
HYDROLAND_DIR="$1"
HYDROLAND_OPA="$2"
INI_YEAR="$3"
INI_MONTH="$4"
INI_DAY="$5"
END_YEAR="$6"
END_MONTH="$7"
END_DAY="$8"
STAT_FREQ="$9"
TEMP="${10}"
PRE="${11}"
INIT_FILES="${12}"
APP_OUTPATH="${13}"
GRID="${14}"
SPLITSIZEUNIT="${15}"

# Define needed hydroland directories
CURRENT_MHM_DIR="${APP_OUTPATH}/hydroland/mhm/current_run"
MHM_LOG_DIR="${APP_OUTPATH}/hydroland/mhm/log_files"
MHM_RESTART_DIR="${APP_OUTPATH}/hydroland/mhm/restart_files"
MHM_FLUXES_DIR="${APP_OUTPATH}/hydroland/mhm/fluxes"
FORCINGS_DIR="${APP_OUTPATH}/hydroland/forcings"
CURRENT_MRM_DIR="${APP_OUTPATH}/hydroland/mrm/current_run"
MRM_LOG_DIR="${APP_OUTPATH}/hydroland/mrm/log_files/"
MRM_RESTART_DIR="${APP_OUTPATH}/hydroland/mrm/restart_files"
MRM_FLUXES_DIR="${APP_OUTPATH}/hydroland/mrm/fluxes/"

if [[ "${SPLITSIZEUNIT}" == "day" ]]; then
    END_YEAR="${INI_YEAR}"
    END_MONTH="${INI_MONTH}"
    END_DAY="${INI_DAY}"
else
    echo "Error: Invalid SPLITSIZEUNIT: '${SPLITSIZEUNIT}'. Only supported value: 'day'." >&2
    exit 1
fi

# select the resolution and number of longitude cells based on the given GRID
if [ "$GRID" == "0.1/0.1" ]; then
    RESOLUTION=0.1
    LON_NUMBER=3600
elif [ "$GRID" == "0.05/0.05" ]; then
    RESOLUTION=0.05
    LON_NUMBER=7200
else
    echo "Error: Invalid GRID value '$GRID'. Supported resolutions are '0.1/0.1' or '0.05/0.05'."
    exit 1
fi

# run period dates
INI_DATE="${INI_YEAR}_${INI_MONTH}_${INI_DAY}"
END_DATE="${END_YEAR}_${END_MONTH}_${END_DAY}"
PREVIOUS_DATE=$(date -d "${INI_YEAR}-${INI_MONTH}-${INI_DAY} - 1 day" "+%Y_%m_%d")
NEXT_DATE=$(date -d "${END_YEAR}-${END_MONTH}-${END_DAY} + 1 day" "+%Y_%m_%d")

# creating mHM out file name
if [ "${STAT_FREQ}" == "hourly" ]; then
    MHM_OUT_FILE="${INI_DATE}_T00_00_to_${END_DATE}_T23_00_mHM_Fluxes_States.nc"
    MRM_OUT_FILE="${INI_DATE}_T00_00_to_${END_DATE}_T23_00_mRM_Fluxes_States.nc"
else
    MHM_OUT_FILE="${INI_DATE}_mHM_Fluxes_States.nc"
    MRM_OUT_FILE="${INI_DATE}_mRM_Fluxes_States.nc"
fi

# Hydroland initialization
bash hydroland_initialisation.sh "$HYDROLAND_DIR" "$INI_YEAR" "$INI_MONTH" "$END_YEAR" "$END_MONTH" \
    "$INI_DATE" "$END_DATE" "$PREVIOUS_DATE" "$STAT_FREQ" "$INIT_FILES" "$APP_OUTPATH" "$RESOLUTION" \
    "$CURRENT_MHM_DIR" "$FORCINGS_DIR" "$MHM_RESTART_DIR" "$CURRENT_MRM_DIR" "$MRM_RESTART_DIR" \
    "$TEMP" "$PRE" "$HYDROLAND_OPA"

# Run mHM section
cd $HYDROLAND_DIR/run_mhm
bash -e "main_mhm.sh" "$HYDROLAND_DIR" "$INI_DATE" "$END_DATE" "$NEXT_DATE" "$STAT_FREQ" \
    "$TEMP" "$PRE" "$INIT_FILES" "$CURRENT_MHM_DIR" "$FORCINGS_DIR" "$MHM_LOG_DIR" \
    "$MHM_FLUXES_DIR" "$MHM_RESTART_DIR" "$LON_NUMBER" "$HYDROLAND_OPA" "${MHM_OUT_FILE}"

# Run mRM section
cd $HYDROLAND_DIR/run_mrm
bash -e "main_mrm.sh" "$CURRENT_MHM_DIR" "$CURRENT_MRM_DIR" "$MRM_RESTART_DIR" "$APP_OUTPATH" "$INI_DATE" \
    "$END_DATE" "$NEXT_DATE" "$STAT_FREQ" "$INIT_FILES" "$FORCINGS_DIR" "$MHM_FLUXES_DIR" "$MRM_FLUXES_DIR" \
    "${HYDROLAND_DIR}" "${MHM_OUT_FILE}" "${MRM_OUT_FILE}" "$HYDROLAND_OPA" "$PRE" "$RESOLUTION"

# Terminate current hydroland chunk/split
cd $HYDROLAND_DIR
bash -e "hydroland_terminate.sh" "$INI_DATE" "$PREVIOUS_DATE" "$FORCINGS_DIR" "$MHM_RESTART_DIR" \
    "$MHM_LOG_DIR" "$MRM_RESTART_DIR" "$MRM_LOG_DIR" "$HYDROLAND_OPA"
