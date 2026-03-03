#!/bin/bash

# Utils used in the sim templates

#####################################################
# Passes the SLURM variables onto variables used
# in hres for IFS-based models.
#####################################################
function load_variables_ifs() {
    export nodes=${SLURM_JOB_NUM_NODES}
    export mpi=${SLURM_NPROCS}
    export omp=${SLURM_CPUS_PER_TASK}

    export jobid=${SLURM_JOB_ID}
    export jobname=${SLURM_JOB_NAME}
}

#####################################################
# Selects the host based on the PU
# Globals:
#   None
# Arguments:
#   PU
#   RAPS_HOST_CPU
#   RAPS_HOST_GPU
#####################################################
function get_host_for_raps() {
    # Input
    PU=$1
    RAPS_HOST_CPU=$2
    RAPS_HOST_GPU=$3

    case $PU in
    cpu)
        host=$RAPS_HOST_CPU
        ;;
    gpu)
        host=$RAPS_HOST_GPU
        ;;
    *)
        echo "ERROR: Unknown PU=$PU in $0::${FUNCNAME[0]}"
        exit 1
        ;;
    esac

    # Return
    echo $host
}

#####################################################
# Sets experiment dependent variables for RAPS
# Globals:
#	CHUNKSIZEUNIT
#	CHUNK
#	CHUNKSIZE
#	CHUNK_END_IN_DAYS
#	IFS_START_DATE
#	SIM_START_DATE
#	ATM_MODEL
#	input_expver
#	label
#	gtype
#	resol
#	levels
# Arguments:
#
######################################################
# lib/common/utils/sim_utils.sh (load_experiment_ifs) (auto generated comment)
function load_experiment_ifs() {

    export input_expver=${input_expver}
    export label=${label}
    export gtype=${gtype}
    export resol=${resol}
    export levels=${levels}

    yyyymmdd=${IFS_START_DATE::8}
    export yyyymmddzz=${yyyymmdd}00

    # Compute offset between IFS restart's fixed start date and the current sim start date
    t1=$(date -d "${IFS_START_DATE}" +%s)
    t2=$(date -d "${SIM_START_DATE}" +%s)
    offset_days=$(((t2 - t1) / 86400))

    if [ "${CHUNKSIZEUNIT,,}" == "month" ] || [ "${CHUNKSIZEUNIT,,}" == "year" ]; then
        runlength=${CHUNK_END_IN_DAYS}
        CHUNKSIZEUNIT=day
    else
        runlength=$((CHUNK * CHUNKSIZE))
    fi

    # Add offset from restart base date
    runlength=$((runlength + offset_days))

    export fclen=${CHUNKSIZEUNIT:0:1}${runlength}
    export runlength

    load_variables_"${ATM_MODEL}"
}

#####################################################
# Runs an hres simulation
# Globals:
#	RAPS_BIN
#	RAPS_BIN_HPC_NAME
#	BUNDLE_BUILD_DIR
#	ICMCL
#	OCEAN_GRID
#	nemox
#	nemoy
#	IFS_IO_TASKS
#	NEMO_IO_TASKS
#	PREV
#	RUN_DAYS
#	EXPID
#	RESTART_DIR
#	FDB_DIRS
#	nproma
#	depth
#	ht
#	RAPS_ROOTDIR
# Arguments:
######################################################
# lib/common/utils/sim_utils.sh (run_experiment_ifs) (auto generated comment)
function run_experiment_ifs() {

    RAPS_FLAGS=$1
    RAPS_IO_FLAGS=$2
    hres_out_dir=$3

    cd "${RAPS_BIN}"/SLURM/"${RAPS_BIN_HPC_NAME}"

    if [ ${IO_ON,,} == "false" ]; then
        echo "IO is off"
    else
        RAPS_FLAGS+=" $RAPS_IO_FLAGS"
        # Undefined IO for NEMO, default configuration. Uses half of the IO resources for IFS and half for NEMO.
        if [ -z "${NEMO_IO_TASKS}" ] && [ -z "${NEMO_IO_NODES}" ] && [ -n "${IFS_IO_NODES}" ]; then
            echo "Same tasks for IFS and NEMO"
            IFS_IO_TASKS=$((${IFS_IO_NODES} * ${SLURM_CPUS_ON_NODE} / ${SLURM_CPUS_PER_TASK} / 2))
            NEMO_IO_TASKS=$((${IFS_IO_NODES} * ${SLURM_CPUS_ON_NODE} / ${SLURM_CPUS_PER_TASK} / 2))
        fi

        # Check for IFS and NEMO server resources
        if [ -n "${IFS_IO_TASKS}" ] && [ -n "${NEMO_IO_TASKS}" ]; then
            RAPS_FLAGS+=" --io-tasks=${IFS_IO_TASKS} --nemo-multio-server-num=${NEMO_IO_TASKS}"
        elif [ -n "${IFS_IO_NODES}" ] && [ -n "${NEMO_IO_NODES}" ]; then
            RAPS_FLAGS+=" --io-nodes=${IFS_IO_NODES} --io-ppn=${IFS_IO_PPN} --nemo-multio-server-nodes=${NEMO_IO_NODES} --nemo-multio-server-ppn=${NEMO_IO_PPN}"
        else
            echo 'Error: No resources selected for IFS or NEMO servers. Add IFS_IO_NODES and NEMO_IO_NODES or IFS_IO_TASKS and NEMO_IO_TASKS variables.'
            exit 1
        fi
    fi

    set +e
    source ../../../.again
    set -e

    # Run the RAPS script

    set -eux

    ifsMASTER=""

    nproma=${nproma:-32}
    depth=${depth:-$omp}
    ht=${ht:-$(htset.pl "$SLURM_NTASKS_PER_NODE" "$SLURM_CPUS_PER_TASK")}

    outfile=${hres_out_dir}/${SLURM_JOB_NAME}_${SLURM_JOB_ID}_${retrial_number}_hres.log

    echo "Model run starts. hres output will be stored in ${outfile}"

    # Run hres, capturing stdout+stderr
    set +e
    hres \
        -p "$mpi" -t "$omp" -h "$ht" \
        -j "$jobid" -J "$jobname" \
        -d "$yyyymmddzz" -e "$input_expver" -L "$label" \
        -T "$gtype" -r "$resol" -l "$levels" -f "$fclen" \
        -x "$ifsMASTER" \
        -N "$nproma" \
        -H "$host" -n "$nodes" -C "$RAPS_COMPILER" $RAPS_FLAGS \
        >"$outfile" 2>&1

    status=$?
    set -e

    if [ $status -ne 0 ]; then
        # Print only the lines containing "Error" to stderr
        grep -i "Error" "$outfile" >&2 || true
        exit $status
    else
        echo "Model run completed successfully."
    fi

}

###################################################
# Checking, before the actual model run, if there
# was a previous directory with the same chunk number
# (so the same runlength and jobname) in the wrapper
# (same jobid), and in case it exists, renaming
# it with the RETRIAL number.
####################################################

# lib/common/utils/sim_utils.sh (check_rundir_name) (auto generated comment)
function check_rundir_name() {
    jobname=$SLURM_JOB_NAME
    jobid=$SLURM_JOB_ID
    retrial_number=0

    if [ "${MODEL_NAME,,}" == "nemo" ]; then
        rundir=$(find "${HPCROOTDIR}" -type d -name "${CHUNK_RUNDIR}" -print -quit)
    else
        rundir=$(find "${HPCROOTDIR}" -type d -name "h$(($runlength * 24))*${jobname}-${jobid}" -print -quit)
    fi

    if [ -z "${rundir}" ]; then
        echo "Rundir variable is empty. No previous rundir found. "
    else
        echo "Previous rundir found. This is a retrial inside a wrapper"
        echo "The previous rundir was: ${rundir}"

    fi

    if [ -d "$rundir" ]; then
        for i in $(seq 0 "$TOTAL_RETRIALS"); do
            if [ -d "${rundir}"."$i" ]; then
                echo "Found the $i attempt to run this chunk inside the wrapper"
                retrial_number=$((i + 1))
            fi
        done
        mv "$rundir" "${rundir}".$retrial_number
        echo "The previous rundir: ${rundir} has been renamed"
        echo "It can be found in: ${rundir}.${retrial_number}"
    fi
}

#################################################
# Identifying the new restart files generated
# and moving them to the next chunk's folder
# in order to use them in the following chunk.
################################################
# lib/common/utils/sim_utils.sh (restarts_moving) (auto generated comment)
function restarts_moving() {
    cd ${PRE_RESTART_DIR}

    # Common IFS restart files (shared by both models)
    SDATE_LONG=${IFS_START_DATE}000000

    formatted_days=$(printf "%06d" "$runlength")0000

    CHUNK_END_IN_DAYS_1=$((runlength - 1))
    formatted_days_1=$(printf "%06d" "$CHUNK_END_IN_DAYS_1")

    mkdir -p $((CHUNK + 1))/

    # Move IFS atmospheric restart files (common to both)
    mv "$CHUNK"/"LAW${SDATE_LONG}_${formatted_days_1}"* $((CHUNK + 1))/
    mv "$CHUNK"/"srf${formatted_days}"* $((CHUNK + 1))/
    mv "$CHUNK"/"BLS"${SDATE_LONG}_"${formatted_days_1}"* $((CHUNK + 1))/
    mv "$CHUNK"/waminfo $((CHUNK + 1))/
    mv "$CHUNK"/rcf $((CHUNK + 1))/

    # Model-specific ocean restart files
    if [[ "${MODEL_NAME,,}" == "ifs-nemo" ]]; then
        # NEMO specific
        mv "$CHUNK"/"${EXPVER}_${END_DATE}"* $((CHUNK + 1))/
        mv "$CHUNK"/nemorcf $((CHUNK + 1))/
        mv "$CHUNK"/nemorcf.${END_DATE}* $((CHUNK + 1))/
        sed -i "s#${PRE_RESTART_DIR}/${CHUNK}#${PRE_RESTART_DIR}/$((CHUNK + 1))#" ${RESTART_DIR}/../$((CHUNK + 1))/nemorcf

        # Restore NEMO backups for retrials
        if [ -f "$CHUNK/nemorcf-backup" ]; then
            mv "$CHUNK"/"nemorcf-backup" "$CHUNK/nemorcf"
        fi

        if [ -f "$CHUNK/nemorcf.${CHUNK_START_DATE}-backup" ]; then
            mv "$CHUNK"/"nemorcf.${CHUNK_START_DATE}-backup" "$CHUNK/nemorcf.${CHUNK_START_DATE}_000000"
        fi

    elif [[ "${MODEL_NAME,,}" == "ifs-fesom" ]]; then
        # FESOM specific
        mv "$CHUNK"/fesom_raw_restart $((CHUNK + 1))/

        # Restore FESOM backups for retrials
        [ -d "$CHUNK/fesom_raw_restart-backup" ] && mv "$CHUNK/fesom_raw_restart-backup" "$CHUNK/fesom_raw_restart"
    fi

    # Common IFS backup restoration for retrials
    [ -f "$CHUNK/rcf-backup" ] && mv "$CHUNK/rcf-backup" "$CHUNK/rcf"
    [ -f "$CHUNK/waminfo-backup" ] && mv "$CHUNK/waminfo-backup" "$CHUNK/waminfo"

    # Handle current symlink based on model
    rm -rf current

    if [[ "${MODEL_NAME,,}" == "ifs-fesom" ]]; then
        # FESOM: Update to point to N+1
        ln -sfn $((CHUNK + 1)) current
    fi
}

#####################################################
# Translates ISO8601 time duration format to its
# equivalent in seconds.
# Globals:
# Arguments:
#  iso8601 time duration
######################################################
function iso8601_to_seconds() {
    duration=$1
    seconds=0

    # Check if "M" (months) and/or "Y" (years) unit is present
    if [[ $"${duration%%T*}" =~ ('Y'|'M') ]]; then
        echo "Error: Yearly and/or monthly durations are not supported. Exiting."
        return 1
    fi

    # Extracting components (days, hours, minutes, seconds)
    for unit in D H M S; do
        value=$(echo $duration | grep -oP "\d+$unit" | sed "s/$unit//")
        if [ -n "$value" ]; then
            case $unit in
            D) ((seconds += value * 86400)) ;;
            H) ((seconds += value * 3600)) ;;
            M) ((seconds += value * 60)) ;;
            S) ((seconds += value)) ;;
            esac
        fi
    done

    echo $seconds
}

#####################################################
# Rename restart files inside CHUNK_RESTART to expected
# EXPNAME format.
# Globals:
#   CHUNK_RESTART
#   EXPNAME
# Arguments:
#   start_date  ISO date/time string used to create timestamp
######################################################
function rename_chunk_restarts() {
    # Generate restart timestamp from start_date
    rsttStartDate=$(date -u -d "${start_date}" +"%Y%m%dT%H%M%SZ")
    # Loop over restart files and rename them
    for src in "${CHUNK_RESTART}"/*_restart_*.mfr; do
        [ -e "$src" ] || continue
        # Determine component from filename
        case "$(basename "$src")" in
        *_restart_atm_*) comp="atm" ;;
        *_restart_oce_*) comp="oce" ;;
        *)
            echo "Skipping unknown restart file: $src"
            continue
            ;;
        esac
        # Construct destination filename
        dst="${CHUNK_RESTART}/${EXPNAME}_restart_${comp}_${rsttStartDate}.mfr"
        # Rename file if destination does not exist
        if [ "$src" != "$dst" ] && [ ! -e "$dst" ]; then
            echo "Renaming restart file: '$src' -> '$(basename "$dst")'"
            mv -v -- "$src" "$dst"
        else
            echo "Warning: destination file exists or already named correctly: $dst"
        fi
    done
}

#####################################################
# Export variables as desired by the user.
# Globals:
#   VARS_TO_EXPORT
# Arguments:
######################################################
function export_vars {
    # Split wrapper string into an array
    read -ra VARS_TO_EXPORT_ARRAY <<<"${VARS_TO_EXPORT}"

    for var in "${VARS_TO_EXPORT_ARRAY[@]}"; do
        if [[ -v "${var}" ]]; then
            echo "Exporting ${var}=${!var}"
            export "${var}"
        else
            echo "Variable ${var} is undefined." >&2
        fi
    done
}
