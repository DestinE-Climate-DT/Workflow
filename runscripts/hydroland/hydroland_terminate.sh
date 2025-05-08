#!/bin/bash

set -xuve

# Pass in the required arguments
INI_DATE=${1}
PREVIOUS_DATE=${2}
FORCINGS_DIR=${3}
MHM_RESTART_DIR=${4}
MHM_LOG_DIR=${5}
MRM_RESTART_DIR=${6}
MRM_LOG_DIR=${7}
HYDROLAND_OPA=${8}

# Function to convert a date string to epoch seconds using Python
convert_date_to_epoch_python() {
    python3 -c "
from datetime import datetime
import sys
print(
    int(
        datetime.strptime(
            sys.argv[1].replace('_', '-'), '%Y-%m-%d'
        ).timestamp()
    )
)
" "$1"
}

THRESHOLD_DATE="1990_01_01"

convert_date_to_epoch_python() {
    python3 -c "
from datetime import datetime
import sys
date_str = sys.argv[1].replace('_', '-')
dt = datetime.strptime(date_str, '%Y-%m-%d')
print(int(dt.timestamp()))
" "$1"
}

# Define a threshold date (in the same format)
THRESHOLD_DATE="1990_01_01"

# Convert the threshold date and the initial date to epoch seconds.
threshold_seconds=$(convert_date_to_epoch_python "$THRESHOLD_DATE")
current_seconds=$(convert_date_to_epoch_python "$INI_DATE")

# Remove restart and forcings files at the end,
# except when they belong to the start or end of a month.
if ((current_seconds > threshold_seconds)); then

    PREVIOUS_YEAR="${PREVIOUS_DATE:0:4}"
    PREVIOUS_MONTH="${PREVIOUS_DATE:5:2}"
    PREVIOUS_DAY="${PREVIOUS_DATE:8:2}"

    # Calculate the last and the second-to-last day of the previous month.
    last_day_of_month=$(date -d "${PREVIOUS_YEAR}-${PREVIOUS_MONTH}-01 +1 month -1 day" "+%d")
    second_last_day_of_month=$(date -d "${PREVIOUS_YEAR}-${PREVIOUS_MONTH}-01 +1 month -2 day" "+%d")

    # Only remove files if the previous day is NOT the first, last, or second-to-last day of the month.
    if [[ "${PREVIOUS_DAY}" != "01" && "${PREVIOUS_DAY}" != "${last_day_of_month}" && "${PREVIOUS_DAY}" != "${second_last_day_of_month}" ]]; then
        rm -rf "${MHM_LOG_DIR}/mhm_${PREVIOUS_DATE}.log" \
            "${FORCINGS_DIR}"/*"${PREVIOUS_DATE}"_*.nc "${HYDROLAND_OPA}"/*"${PREVIOUS_DATE}"*
        for i in {1..53}; do
            rm -rf "${MRM_LOG_DIR}/subdomain_${i}/mrm_${PREVIOUS_DATE}.log"
        done
    fi
fi
