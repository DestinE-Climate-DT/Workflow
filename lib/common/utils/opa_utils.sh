#!/bin/bash

# Utils functions for opa.sh

#####################
# Runs OPA runscript (with GSV Interface and One_Pass in it)
#    Note: No support for multiple startdates as of now.
#          Therefore, datelist equates to startdate, i.e. a string with a single value.
# INPUT
#    request directory
#    chunk
#    split
#    expid
#    app_name
#    run_type
#    realization
#    datelist (or startdate)
#    request_number
#####################
function run_OPA() {

    request_dir="${1}"
    if [ ! -d "${OPA_OUTPATH}" ]; then
        mkdir -p "${OPA_OUTPATH}"
        echo "Directory created: ${OPA_OUTPATH}"
    else
        echo "Directory already exists: ${OPA_OUTPATH}"
    fi

    SRC_DIR=${HPCROOTDIR}/${PROJDEST}/one_pass/ #This step allows using dev versions of the application from the submodule
    # If the submodule does not exist, set PYTHONPATH to SCRIPTDIR (does not need to be SCRIPTDIR though)
    if [ -d "$SRC_DIR" ]; then
        export PYTHONPATH="${SRC_DIR}"
    else
        export PYTHONPATH="${SCRIPTDIR}"
    fi

    if [ -d "${BA_AUX}" ]; then
        echo "The directory ${BA_AUX} and therefore the bias adjustment will not be applied."
        BA_AUX="$SCRIPTDIR" #Shfmt does not like having it empty
    fi

    # move parsed data request
    cd "${SCRIPTDIR}/opa/" || exit
    singularity exec \
        --cleanenv \
        --no-home \
        --bind "${SCRIPTDIR}/opa/" \
        --bind "${FDB_HOME}" \
        --bind "${LOGDIR}" \
        --bind "${OPA_OUTPATH}" \
        --bind "${PYTHONPATH}" \
        --bind "${BA_AUX}" \
        --bind "${APP_AUX_IN_DATA_DIR}" \
        --bind "${DEVELOPMENT_PROJECT_SCRATCH}" \
        --bind "${OPERATIONAL_PROJECT_SCRATCH}" \
        --bind "${request_dir}" \
        --env request_dir="${request_dir}" \
        --env chunk="$2" \
        --env split="$3" \
        --env expid="$4" \
        --env app_name="$5" \
        --env run_type="$6" \
        --env member="$7" \
        --env startdate="$8" \
        --env request_number="$9" \
        --env realization="${REALIZATION}" \
        --env outpath="${OPA_OUTPATH}" \
        --env PYTHONPATH="${PYTHONPATH}" \
        --env FDB_HOME="${FDB_HOME}" \
        --env SCRIPTDIR="${SCRIPTDIR}" \
        --env READ_FROM_DATABRIDGE="${READ_FROM_DATABRIDGE}" \
        --env PYTHONNOUSERSITE="1" \
        --env GSV_WEIGHTS_PATH="${GSV_WEIGHTS_PATH}" \
        $HPC_CONTAINER_DIR/one_pass/one_pass_${OPA_VERSION}.sif bash -c \
        '
        python3 "${SCRIPTDIR}"/opa/run_opa.py \
            --request_dir "${request_dir}" \
            --chunk ${chunk} \
            --split ${split} \
            --expid ${expid} \
            --app_names ${app_name} \
            --member ${member} \
	          --realization ${realization} \
            --startdate ${startdate} \
            --request_number ${request_number} \
            --read_from_databridge "${READ_FROM_DATABRIDGE}" \
            --outpath "${outpath}"
        '
}

# Function to control parallel execution
function run_with_limit() {
    # Start the job and track its PID
    "$@" &
    PIDS="$PIDS $!"

    # Count the number of background jobs
    while [ "$(jobs -rp | wc -l)" -ge "$OPA_MAX_PROC" ]; do
        # Wait for any job to finish before starting a new one
        wait -n
    done
}
