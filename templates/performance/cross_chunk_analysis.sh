#!/bin/bash

set -xuve

# HEADER
USER=${1:-%CURRENT_USER%}
HPCROOTDIR=${2:-%HPCROOTDIR%}
SCRIPTDIR=${3:-%CONFIGURATION.SCRIPTDIR%}
# END_HEADER

HPCROOTDIR="${1:-%HPCROOTDIR%}"
SCRIPTDIR="${2:-%CONFIGURATION.SCRIPTDIR%}"

echo "INFO: HPCROOTDIR=${HPCROOTDIR}"
echo "INFO: SCRIPTDIR=${SCRIPTDIR}"

cd "${HPCROOTDIR}"

# Load Python module (MN5)

#module load python/3.10.15

echo "INFO: Ensuring Python venv exists"
PYTHON_VENV_PATH="python3/venv"
if [[ ! -d "${PYTHON_VENV_PATH}" ]]; then
    echo "INFO: Creating venv at ${PYTHON_VENV_PATH}"
    python3 -m venv "${PYTHON_VENV_PATH}"
else
    echo "INFO: venv already present"
fi

echo "INFO: Activating venv"

# shellcheck source=/dev/null
source "${PYTHON_VENV_PATH}/bin/activate"

#echo "INFO: Upgrading pip and installing dependencies"
#python3 -m pip install --upgrade pip
#python3 -m pip install pandas seaborn matplotlib

echo "INFO: Checking Python analysis script"

PYTHON_SCRIPT="${SCRIPTDIR}/CPMIP/cross_chunk_analysis.py"
if [[ ! -f "${PYTHON_SCRIPT}" ]]; then
    echo "ERROR: Script not found at: ${PYTHON_SCRIPT}" >&2
    exit 1
fi

echo "INFO: Starting cross-chunk analysis"

INPUT_DIR="performance/performance_metrics"

OUTPUT_DIR="performance/"

PYTHON_ARGS=(
    --input-dir "${INPUT_DIR}"
    --output-dir "${OUTPUT_DIR}"
    --exclude-sections "^Metadata$"
    --exclude-vars "SY-Related.Start_Date|SY-Related.End_Date|HPC_data|CHSY_No_IO\."
)

python3 "${PYTHON_SCRIPT}" "${PYTHON_ARGS[@]}"

echo "INFO: Completed cross-chunk analysis. Outputs under: ${OUTPUT_DIR}/cross_chunk_analysis/"
