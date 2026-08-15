#!/bin/bash

# Utils used in the sim templates

#####################################################
# Scans RAPS output file for critical/fatal error
# patterns and reports them to stderr.
# Arguments:
#   $1 - path to the RAPS output file
#####################################################
function report_errors_in_raps_output() {
    local outfile="$1"
    local patterns=("Error" "ABOR1" "Exception" "forrtl" "APPLICATION TERMINATED" "Backtrace" "FAILED" "Abort")

    if grep -qiE "$(
        IFS='|'
        echo "${patterns[*]}"
    )" "$outfile"; then
        {
            echo "Errors found in the output of RAPS"
            echo "---------------------------------"
            grep -iE "$(
                IFS='|'
                echo "${patterns[*]}"
            )" "$outfile"
            echo ""
            echo "Check $outfile for more details."
        } >&2
    fi
}

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
    t1=$(TZ=UTC date -d "${IFS_START_DATE}" +%s)
    t2=$(TZ=UTC date -d "${SIM_START_DATE}" +%s)
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
#	1  RAPS_FLAGS
#	2  RAPS_IO_FLAGS
#	3  hres_out_dir
#	4  jobname
######################################################
# lib/common/utils/sim_utils.sh (run_experiment_ifs) (auto generated comment)
function run_experiment_ifs() {

    RAPS_FLAGS=$1
    RAPS_IO_FLAGS=$2
    hres_out_dir=$3
    jobname=$4

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

    outfile=${hres_out_dir}/${jobname}_${jobid}_${retrial_number}_hres.log

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
        # Tell the resource monitor this chunk failed so it stops cleanly
        # instead of running until its wallclock.
        signal_performance_done
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
# Globals:
#   SLURM_JOB_NAME
#   SLURM_JOB_ID
#   MODEL_NAME
#   HPCROOTDIR
#   CHUNK_RUNDIR
#   runlength
#   TOTAL_RETRIALS
# Arguments:
#   $1 - jobname (optional, defaults to SLURM_JOB_NAME)
####################################################

# lib/common/utils/sim_utils.sh (check_rundir_name) (auto generated comment)
function check_rundir_name() {
    jobname=${1:-$SLURM_JOB_NAME}
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
        # FESOM specific - remove stale destination from prior retrial if it exists
        [ -d "$((CHUNK + 1))/fesom_raw_restart" ] && rm -rf "$((CHUNK + 1))/fesom_raw_restart"
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
# Performance monitoring: shared env file
#
# The MONITOR_RESOURCES and PERFORMANCE_METRICS jobs both depend on SIM and
# need the SAME set of values (SIM job id, model/grid/request metadata, I/O
# layout, complexity, container, ...). Instead of re-rendering that whole list
# in each of those templates, the SIM job — which already owns most of these
# variables and is the only place that knows its own SLURM_JOB_ID — writes them
# once to a per-chunk JSON file. The monitor/performance templates then read
# that file plus their own job-specific variables.
#
# Layout (consolidates the formerly separate monitor/ and performance_metrics/
# trees under a single per-chunk directory):
#
#   ${HPCROOTDIR}/performance/<jobname>-<jobid>/<sdate>_<member>_<chunk>/
#       env.json       <- written here
#       monitor/       <- MONITOR_RESOURCES output
#       performance/   <- PERFORMANCE_METRICS output
#
# Arguments:
#   $1 - resolved run directory for this chunk (optional; "N/A" when the rundir
#        is not known yet, e.g. on the pre-run call that only needs to publish
#        the job id so the monitor can attach).
# Globals (read, all optional — missing ones fall back to N/A / 0):
#   HPCROOTDIR SIM_START_DATE MEMBER CHUNK EXPID MODEL_NAME CURRENT_ARCH LIBDIR
#   SCRIPTDIR RUNDIR_PATH HPC_CONTAINER_DIR PERFORMANCE_METRICS_VERSION
#   GRID_ATM ATM_GRID GRID_OCE OCEAN_GRID RESOLUTION PERFORMANCE_RESOLUTION
#   START_DATE_CHUNK CHUNK_START_DATE END_DATE_CHUNK CHUNK_SECOND_TO_LAST_DATE
#   FDB_HOME CLASS DATASET ACTIVITY EXPERIMENT GENERATION MODEL_REQ MODEL
#   REALIZATION EXPVER STREAM PROCESSOR_UNIT PU
#   COMPLEXITY_ATMOSPHERE COMPLEXITY_OCEAN COMPLEXITY_LAND COMPLEXITY_IFS
#   COMPLEXITY_NEMO IFS_IO_TASKS NEMO_IO_TASKS FESOM_IO_TASKS IFS_IO_NODES
#   NEMO_IO_NODES FESOM_IO_NODES IFS_IO_PPN NEMO_IO_PPN FESOM_IO_PPN
#####################################################
# Echo the per-chunk performance directory for the CURRENT chunk. Used by both
# write_performance_env and signal_performance_done so they agree on the path.
#
# Wrapper-aware: a wrapper runs several chunks under ONE SLURM_JOB_ID, so the
# <jobname>-<jobid> level is shared; the <sdate>_<member>_<chunk> leaf keeps
# each chunk's files separate. Returns non-zero (and echoes nothing) when there
# is no SLURM_JOB_ID (e.g. on a login node), so callers can no-op.
# lib/common/utils/sim_utils.sh (_performance_chunk_dir) (auto generated comment)
function _performance_chunk_dir() {
    local jobname jobid
    jobname="${SLURM_JOB_NAME:-${EXPID}_${SIM_START_DATE}_${MEMBER}_${CHUNK}_SIM}"
    jobid="${SLURM_JOB_ID:-}"
    [ -z "${jobid}" ] && return 1
    echo "${HPCROOTDIR}/performance/${jobname}-${jobid}/${SIM_START_DATE}_${MEMBER}_${CHUNK}"
}

# True (exit 0) when the MONITOR_RESOURCES job is scheduled for this run. The
# SIM-side perf hooks (write_performance_env, signal_performance_done) exist only
# to feed that monitor (env.json + sim_done), so they no-op when it is off.
# PERFORMANCE_METRICS depends on MONITOR_RESOURCES, so this also covers it. The
# toggle comes from CONFIGURATION.ADDITIONAL_JOBS and is exported by the SIM
# template (the only place Autosubmit substitutes it).
# lib/common/utils/sim_utils.sh (_resource_monitor_enabled) (auto generated comment)
function _resource_monitor_enabled() {
    case "${MONITOR_RESOURCES_ENABLED:-}" in
    [Tt]rue) return 0 ;;
    esac
    return 1
}

# Coerce a value to a non-negative integer for JSON emission. Anything that is
# not a run of digits (empty, "N/A", ...) becomes 0.
# lib/common/utils/sim_utils.sh (_pe_int) (auto generated comment)
function _pe_int() {
    local v="${1:-0}"
    case "${v}" in
    '' | *[!0-9]*) echo 0 ;;
    *) echo "${v}" ;;
    esac
}

#####################################################
# Per-model performance-env builders.
#
# Each one sets the two pieces of the env file that differ by model — the
# complexity tag and the I/O layout (io_config) — as JSON strings in
# PERFENV_COMPLEXITY_JSON / PERFENV_IO_CONFIG_JSON, which the general
# write_performance_env then embeds verbatim. Everything else (paths, request
# metadata, allocation shape, ...) is shared and handled by the general
# function. To support a new model, add a _performance_env_<model> function and
# a matching case entry in write_performance_env.
#####################################################

# IFS-FESOM: complexity {IFS,NEMO}; io_config {IFS,FESOM}.
# lib/common/utils/sim_utils.sh (_performance_env_ifs_fesom) (auto generated comment)
function _performance_env_ifs_fesom() {
    PERFENV_COMPLEXITY_JSON=$(printf '{"IFS":"%s","NEMO":"%s"}' \
        "${COMPLEXITY_IFS:-N/A}" "${COMPLEXITY_NEMO:-N/A}")
    PERFENV_IO_CONFIG_JSON=$(printf \
        '{"IFS":{"tasks":%s,"nodes":%s,"ppn":%s},"FESOM":{"tasks":%s,"nodes":%s,"ppn":%s}}' \
        "$(_pe_int "${IFS_IO_TASKS}")" "$(_pe_int "${IFS_IO_NODES}")" "$(_pe_int "${IFS_IO_PPN}")" \
        "$(_pe_int "${FESOM_IO_TASKS}")" "$(_pe_int "${FESOM_IO_NODES}")" "$(_pe_int "${FESOM_IO_PPN}")")
    export PERFENV_COMPLEXITY_JSON PERFENV_IO_CONFIG_JSON
}

# IFS-NEMO: complexity {IFS,NEMO}; io_config {IFS,NEMO}.
# lib/common/utils/sim_utils.sh (_performance_env_ifs_nemo) (auto generated comment)
function _performance_env_ifs_nemo() {
    PERFENV_COMPLEXITY_JSON=$(printf '{"IFS":"%s","NEMO":"%s"}' \
        "${COMPLEXITY_IFS:-N/A}" "${COMPLEXITY_NEMO:-N/A}")
    PERFENV_IO_CONFIG_JSON=$(printf \
        '{"IFS":{"tasks":%s,"nodes":%s,"ppn":%s},"NEMO":{"tasks":%s,"nodes":%s,"ppn":%s}}' \
        "$(_pe_int "${IFS_IO_TASKS}")" "$(_pe_int "${IFS_IO_NODES}")" "$(_pe_int "${IFS_IO_PPN}")" \
        "$(_pe_int "${NEMO_IO_TASKS}")" "$(_pe_int "${NEMO_IO_NODES}")" "$(_pe_int "${NEMO_IO_PPN}")")
    export PERFENV_COMPLEXITY_JSON PERFENV_IO_CONFIG_JSON
}

# ICON: complexity {ATMOSPHERE,OCEAN,LAND}; io_config {ICON:{atm/oce/yaco}} but
# only once sim_icon.sh has captured the runtime task counts — otherwise {} so
# the io_analyzer falls back to parsing the *.run script (e.g. on the early
# publish call, before the run).
# lib/common/utils/sim_utils.sh (_performance_env_icon) (auto generated comment)
function _performance_env_icon() {
    PERFENV_COMPLEXITY_JSON=$(printf '{"ATMOSPHERE":"%s","OCEAN":"%s","LAND":"%s"}' \
        "${COMPLEXITY_ATMOSPHERE:-N/A}" "${COMPLEXITY_OCEAN:-N/A}" "${COMPLEXITY_LAND:-N/A}")
    # Defaulted with :-0 because the early publish call (before the run) fires
    # under 'set -u' before sim_icon.sh has captured the task counts from the run
    # log — unbound there, so default to 0 and emit io_config {} as intended.
    local atm oce yaco
    atm=$(_pe_int "${ICON_ATM_COMPUTE_TASKS:-0}")
    oce=$(_pe_int "${ICON_OCE_TASKS:-0}")
    yaco=$(_pe_int "${ICON_YACO_TASKS:-0}")
    if [ "${atm}" -gt 0 ] || [ "${oce}" -gt 0 ] || [ "${yaco}" -gt 0 ]; then
        PERFENV_IO_CONFIG_JSON=$(printf \
            '{"ICON":{"atm_compute_tasks":%s,"oce_tasks":%s,"yaco_tasks":%s}}' \
            "${atm}" "${oce}" "${yaco}")
    else
        PERFENV_IO_CONFIG_JSON='{}'
    fi
    export PERFENV_COMPLEXITY_JSON PERFENV_IO_CONFIG_JSON
}

# Unknown model: all-N/A complexity, empty io_config.
# lib/common/utils/sim_utils.sh (_performance_env_default) (auto generated comment)
function _performance_env_default() {
    PERFENV_COMPLEXITY_JSON='{"ATMOSPHERE":"N/A","OCEAN":"N/A","LAND":"N/A","IFS":"N/A","NEMO":"N/A"}'
    PERFENV_IO_CONFIG_JSON='{}'
    export PERFENV_COMPLEXITY_JSON PERFENV_IO_CONFIG_JSON
}

# lib/common/utils/sim_utils.sh (write_performance_env) (auto generated comment)
function write_performance_env() {
    # Skip entirely when the resource monitor is not scheduled this run.
    _resource_monitor_enabled || return 0
    local resolved_rundir="${1:-N/A}"

    local perf_chunk_dir
    perf_chunk_dir=$(_performance_chunk_dir) || {
        echo "WARNING: SLURM_JOB_ID not set; skipping performance env file" >&2
        return 0
    }
    local jobname jobid
    jobname="${SLURM_JOB_NAME:-${EXPID}_${SIM_START_DATE}_${MEMBER}_${CHUNK}_SIM}"
    jobid="${SLURM_JOB_ID}"
    mkdir -p "${perf_chunk_dir}/monitor" "${perf_chunk_dir}/performance"

    # ---- Shared env vars (common to every model). Exported so the embedded
    # python reads them from the environment without any shell-quoting hazards.
    export PERFENV_SIM_JOBID="${jobid}"
    export PERFENV_SIM_JOBNAME="${jobname}"
    export PERFENV_PERF_CHUNK_DIR="${perf_chunk_dir}"
    export PERFENV_MODEL_NAME="${MODEL_NAME:-N/A}"
    export PERFENV_EXPID="${EXPID:-N/A}"
    export PERFENV_MEMBER="${MEMBER:-N/A}"
    export PERFENV_CHUNK="${CHUNK:-N/A}"
    export PERFENV_HPC="${CURRENT_ARCH:-N/A}"
    export PERFENV_LIBDIR="${LIBDIR:-N/A}"
    export PERFENV_SCRIPTDIR="${SCRIPTDIR:-N/A}"
    export PERFENV_RUNDIR_PATH="${RUNDIR_PATH:-N/A}"
    export PERFENV_RUNDIR="${resolved_rundir:-N/A}"
    export PERFENV_HPC_CONTAINER_DIR="${HPC_CONTAINER_DIR:-N/A}"
    export PERFENV_PERFORMANCE_METRICS_VERSION="${PERFORMANCE_METRICS_VERSION:-N/A}"
    export PERFENV_GRID_ATM="${GRID_ATM:-${ATM_GRID:-N/A}}"
    export PERFENV_GRID_OCE="${GRID_OCE:-${OCEAN_GRID:-N/A}}"
    export PERFENV_RESOLUTION_KM="${RESOLUTION:-N/A}"
    export PERFENV_PERFORMANCE_RESOLUTION="${PERFORMANCE_RESOLUTION:-N/A}"
    export PERFENV_START_DATE_CHUNK="${START_DATE_CHUNK:-${CHUNK_START_DATE:-N/A}}"
    export PERFENV_END_DATE_CHUNK="${END_DATE_CHUNK:-${CHUNK_SECOND_TO_LAST_DATE:-N/A}}"
    export PERFENV_FDB_HOME="${FDB_HOME:-N/A}"
    export PERFENV_CLASS="${CLASS:-N/A}"
    export PERFENV_DATASET="${DATASET:-N/A}"
    export PERFENV_ACTIVITY="${ACTIVITY:-${activity:-N/A}}"
    export PERFENV_EXPERIMENT="${EXPERIMENT:-${experiment:-N/A}}"
    export PERFENV_GENERATION="${GENERATION:-${generation:-N/A}}"
    export PERFENV_MODEL_REQ="${MODEL_REQ:-${MODEL:-N/A}}"
    export PERFENV_REALIZATION="${REALIZATION:-${realization:-N/A}}"
    export PERFENV_EXPVER="${EXPVER:-N/A}"
    export PERFENV_STREAM="${STREAM:-N/A}"
    export PERFENV_PROCESSOR_UNIT="${PROCESSOR_UNIT:-${PU:-cpu}}"
    # Allocation shape: SLURM env is authoritative inside the SIM allocation.
    export PERFENV_TASKS_PER_NODE="${SLURM_NTASKS_PER_NODE:-${TASKS_PER_NODE:-0}}"
    export PERFENV_THREADS="${SLURM_CPUS_PER_TASK:-${THREADS:-1}}"
    export PERFENV_OUT_FILE="${perf_chunk_dir}/env.json"

    # ---- Model-specific env vars: set PERFENV_COMPLEXITY_JSON and
    # PERFENV_IO_CONFIG_JSON via the per-model builder.
    local model_key="${MODEL_NAME,,}"
    model_key="${model_key//_/-}"
    case "${model_key}" in
    ifs-fesom) _performance_env_ifs_fesom ;;
    ifs-nemo) _performance_env_ifs_nemo ;;
    icon) _performance_env_icon ;;
    *) _performance_env_default ;;
    esac

    python3 - <<'PY'
import json
import os


def env(name, default="N/A"):
    return os.environ.get("PERFENV_" + name, default)


def as_int(name):
    try:
        return int(float(env(name, "0")))
    except (TypeError, ValueError):
        return 0


payload = {
    "SIM_JOBID": env("SIM_JOBID"),
    "SIM_JOBNAME": env("SIM_JOBNAME"),
    "PERF_CHUNK_DIR": env("PERF_CHUNK_DIR"),
    "MODEL_NAME": env("MODEL_NAME"),
    "EXPID": env("EXPID"),
    "MEMBER": env("MEMBER"),
    "CHUNK": env("CHUNK"),
    "HPC": env("HPC"),
    "LIBDIR": env("LIBDIR"),
    "SCRIPTDIR": env("SCRIPTDIR"),
    "RUNDIR_PATH": env("RUNDIR_PATH"),
    "RUNDIR": env("RUNDIR"),
    "HPC_CONTAINER_DIR": env("HPC_CONTAINER_DIR"),
    "PERFORMANCE_METRICS_VERSION": env("PERFORMANCE_METRICS_VERSION"),
    "GRID_ATM": env("GRID_ATM"),
    "GRID_OCE": env("GRID_OCE"),
    "RESOLUTION_KM": env("RESOLUTION_KM"),
    "PERFORMANCE_RESOLUTION": env("PERFORMANCE_RESOLUTION"),
    "START_DATE_CHUNK": env("START_DATE_CHUNK"),
    "END_DATE_CHUNK": env("END_DATE_CHUNK"),
    "FDB_HOME": env("FDB_HOME"),
    "CLASS": env("CLASS"),
    "DATASET": env("DATASET"),
    "ACTIVITY": env("ACTIVITY"),
    "EXPERIMENT": env("EXPERIMENT"),
    "GENERATION": env("GENERATION"),
    "MODEL_REQ": env("MODEL_REQ"),
    "REALIZATION": env("REALIZATION"),
    "EXPVER": env("EXPVER"),
    "STREAM": env("STREAM"),
    "PROCESSOR_UNIT": env("PROCESSOR_UNIT", "cpu"),
    "TASKS_PER_NODE": as_int("TASKS_PER_NODE"),
    "THREADS": as_int("THREADS") or 1,
    # Model-specific, pre-built as JSON strings by the per-model builder.
    "COMPLEXITY": json.loads(os.environ.get("PERFENV_COMPLEXITY_JSON", "{}") or "{}"),
    "IO_CONFIG": json.loads(os.environ.get("PERFENV_IO_CONFIG_JSON", "{}") or "{}"),
}

out_file = os.environ["PERFENV_OUT_FILE"]
with open(out_file, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
print(f"INFO: wrote performance env file {out_file}")
PY

    # Publish a chunk-keyed pointer to THIS run's chunk dir so MONITOR_RESOURCES
    # and PERFORMANCE_METRICS bind to the current attempt deterministically,
    # instead of scanning <jobname>-<jobid> folders by mtime (fragile across
    # re-runs). Overwritten every run; PERFORMANCE_METRICS deletes it when done.
    # Best-effort: a failure here must not abort the SIM (env.json is the
    # critical artifact and was already written above).
    local current_dir="${HPCROOTDIR}/performance/.current"
    mkdir -p "${current_dir}" 2>/dev/null || true
    printf '%s\n' "${perf_chunk_dir}" \
        >"${current_dir}/${SIM_START_DATE}_${MEMBER}_${CHUNK}" 2>/dev/null || true
}

#####################################################
# Signal that THIS chunk's simulation has finished so the resource monitor can
# stop cleanly.
#
# Why a marker (not just job state): a wrapper runs all its chunks under one
# SLURM_JOB_ID, so the monitor cannot tell "my chunk ended" from "the whole
# allocation ended" by job liveness alone — it would keep running into the next
# chunk and mis-attribute its steps. The SIM writes a per-chunk marker at the
# end of its compute; the monitor polls for it and exits.
#
# Call it on the success path (at the end of the SIM template), on the failure
# paths (before each exit), and from an ERR trap as a catch-all for an
# unexpected 'set -e' abort. The catch-all uses ERR, NOT EXIT: Autosubmit's
# header installs its own EXIT trap (as_exit_handler) which writes the
# _COMPLETED stat file, and trapping EXIT in the template would replace it,
# leaving every successful job marked FAILED. Idempotent and never fails the SIM:
#   - It signals at most ONCE per SIM (guarded by _PERF_SIM_DONE_SIGNALLED), so
#     an explicit call plus the ERR trap do not double-write the marker or log
#     a second time.
#   - It always returns 0 and never aborts under 'set -e', so it is safe to run
#     from a trap without disturbing the job's exit status.
# Arguments:
#   None
#####################################################
# lib/common/utils/sim_utils.sh (signal_performance_done) (auto generated comment)
function signal_performance_done() {
    # Skip entirely when the resource monitor is not scheduled this run.
    _resource_monitor_enabled || return 0
    # Already signalled (e.g. explicit call, then the ERR trap) -> no-op.
    if [ "${_PERF_SIM_DONE_SIGNALLED:-0}" = "1" ]; then
        return 0
    fi
    local perf_chunk_dir
    perf_chunk_dir=$(_performance_chunk_dir) || return 0
    # Best-effort: if the marker cannot be written, don't mark as signalled and
    # don't fail the SIM.
    mkdir -p "${perf_chunk_dir}" && touch "${perf_chunk_dir}/sim_done" || return 0
    _PERF_SIM_DONE_SIGNALLED=1
    echo "INFO: signalled SIM completion to resource monitor: ${perf_chunk_dir}/sim_done"
    return 0
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
