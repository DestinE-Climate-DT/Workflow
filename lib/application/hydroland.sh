#!/bin/bash

_HYDROLAND_LIB="${BASH_SOURCE[0]}"

#####################
# Return the configured monthly subdomain count.
#####################
function _hydroland_num_subdomains() {
    if [[ -z "${HYDROLAND_NUM_SUBDOMAINS:-}" ]] || [[ "${HYDROLAND_NUM_SUBDOMAINS}" -lt 1 ]]; then
        echo "HYDROLAND_NUM_SUBDOMAINS must be a positive integer." >&2
        exit 1
    fi
    echo "${HYDROLAND_NUM_SUBDOMAINS}"
}

#####################
# Export runtime variables needed by srun child processes.
#####################
function _hydroland_export_runtime_env() {
    export APP_OUTPATH OPA_OUTPATH SCRIPTDIR HPC_PROJECT HPC_CONTAINER_DIR
    export HYDROLAND_VERSION HYDROLAND_INIT_FILES
    export INI_YEAR INI_MONTH INI_DAY END_YEAR END_MONTH END_DAY
    export SPLIT_INI_YEAR SPLIT_INI_MONTH SPLIT_INI_DAY
    export HYDROLAND_STAT_FREQ HYDROLAND_PRE HYDROLAND_TEMP HYDROLAND_GRID
    export HYDROLAND_RUN_FREQUENCY HYDROLAND_PRIOR_APP_OUTPATH HYDROLAND_OMP_NUM_THREADS_MHM
    export HYDROLAND_BIAS_ADJUSTMENT HYDROLAND_DELETE_FILES HYDROLAND_APPLY_INDICATORS
    export HYDROLAND_RESTART_FROM_PRIOR_RUN HYDROLAND_NUM_SUBDOMAINS
    export HYDROLAND_MAX_WORKERS HYDROLAND_MRM_PARALLEL_SUBDOMAINS
    export HYDROLAND_MERGE_BUFFER_TARGET_MB HYDROLAND_MERGE_COMPRESSION_LEVEL
}

#####################
# Point INI_*/END_* at the window of one calendar month.
#
# Arguments:
#   $1 - year (YYYY)
#   $2 - month (1-12, with or without leading zero)
#####################
function _hydroland_set_month_window() {
    local year="${1}"
    local month="${2}"
    printf -v month '%02d' "$((10#${month}))"
    INI_YEAR="${year}"
    INI_MONTH="${month}"
    INI_DAY="01"
    END_YEAR="${year}"
    END_MONTH="${month}"
    END_DAY="$(date -d "${year}-${month}-01 +1 month -1 day" +%d)"
}

#####################
# Return 0 if one subdomain already completed the month INI_*..END_*
# (its monthly mHM/mRM flux files and the next-month restarts exist and are
# non-empty). Used by run_HYDROLAND_SUBDOMAIN when resuming is opted into
# (_HYDROLAND_RESUME=1) - off by default on the automatic STAGE=all path,
# since a "done" file only proves something was written, not that it's still
# correct (e.g. a forcing gap fixed after the fact needs a real re-run).
# Always on in the run_HYDROLAND_YEAR_SUBDOMAINS manual/recovery utility.
#
# Arguments:
#   $1 - SUBDOMAIN id
#####################
function _hydroland_subdomain_month_done() {
    local subdomain="${1}"
    local root="${APP_OUTPATH}/hydroland/subdomains/subdomain_${subdomain}"
    local ini_tag="${INI_YEAR}_${INI_MONTH}_${INI_DAY}"
    local end_tag="${END_YEAR}_${END_MONTH}_${END_DAY}"

    local flux_tag="${ini_tag}_to_${end_tag}"
    if [[ "${HYDROLAND_STAT_FREQ}" == "hourly" ]]; then
        flux_tag="${ini_tag}_T00_00_to_${end_tag}_T23_00"
    fi

    local next_ini next_end
    next_ini="$(date -d "${INI_YEAR}-${INI_MONTH}-01 +1 month" +%Y_%m_%d)"
    next_end="$(date -d "${INI_YEAR}-${INI_MONTH}-01 +2 month -1 day" +%Y_%m_%d)"

    [[ -s "${root}/mhm/fluxes/${flux_tag}_mHM_Fluxes_States.nc" ]] &&
        [[ -s "${root}/mrm/fluxes/${flux_tag}_mRM_Fluxes_States.nc" ]] &&
        [[ -s "${root}/mhm/restart_files/${next_ini}_to_${next_end}_mHM_restart.nc" ]] &&
        [[ -s "${root}/mrm/restart_files/${next_ini}_to_${next_end}_mRM_restart.nc" ]]
}

#####################
# Return 0 if the month INI_*..END_* was already merged onto the global grid
# (both whole-domain flux files exist and are non-empty).
#####################
function _hydroland_month_merge_done() {
    local root="${APP_OUTPATH}/hydroland/fluxes"
    local ini_tag="${INI_YEAR}_${INI_MONTH}_${INI_DAY}"
    local end_tag="${END_YEAR}_${END_MONTH}_${END_DAY}"

    local flux_tag="${ini_tag}_to_${end_tag}"
    if [[ "${HYDROLAND_STAT_FREQ}" == "hourly" ]]; then
        flux_tag="${ini_tag}_T00_00_to_${end_tag}_T23_00"
    fi

    [[ -s "${root}/mhm/${flux_tag}_mHM_Fluxes_States.nc" ]] &&
        [[ -s "${root}/mrm/${flux_tag}_mRM_Fluxes_States.nc" ]]
}

#####################
# Run one HydroLand singularity invocation.
#
# Arguments:
#   $1 - STAGE (all, forcings, subdomain, merge)
#   $2 - SUBDOMAIN id or "None"
#
# GLOBALS USED
# ============
#    - APP_OUTPATH: Output path for application results
#    - OPA_OUTPATH: OPA output path used as hydroland input
#    - SCRIPTDIR: Path to workflow scripts (hydroland runscript)
#    - HPC_PROJECT: HPC project directory
#    - HPC_CONTAINER_DIR: Directory containing singularity images
#    - HYDROLAND_VERSION: Container version tag
#    - HYDROLAND_INIT_FILES: Path to hydroland initialization files
#    - INI_YEAR, INI_MONTH, INI_DAY: Chunk start date
#    - END_YEAR, END_MONTH, END_DAY: Chunk end date
#    - SPLIT_INI_YEAR, SPLIT_INI_MONTH, SPLIT_INI_DAY: Split start date
#    - HYDROLAND_STAT_FREQ, HYDROLAND_PRE, HYDROLAND_TEMP, HYDROLAND_GRID
#    - HYDROLAND_RUN_FREQUENCY, HYDROLAND_PRIOR_APP_OUTPATH
#    - HYDROLAND_OMP_NUM_THREADS_MHM
#    - HYDROLAND_BIAS_ADJUSTMENT, HYDROLAND_DELETE_FILES
#    - HYDROLAND_APPLY_INDICATORS, HYDROLAND_RESTART_FROM_PRIOR_RUN
#####################
function _run_hydroland_core() {
    local stage="${1}"
    local subdomain="${2}"
    local merge_model="${3:-None}"
    local skip_merge="${4:-False}"
    local skip_cleanup="${5:-False}"

    if [ ! -d "${APP_OUTPATH}" ]; then
        mkdir -p "${APP_OUTPATH}"
    fi

    # Conditionally append optional flags
    local extra_args=()
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
    if [[ "${subdomain}" != "None" ]]; then
        extra_args+=(--subdomain "${subdomain}")
    fi
    if [[ "${HYDROLAND_RUN_FREQUENCY}" == "month" ]]; then
        extra_args+=(--num-subdomains "$(_hydroland_num_subdomains)")
        extra_args+=(--max-workers "${HYDROLAND_MAX_WORKERS}")
    fi
    if [[ "${HYDROLAND_RUN_FREQUENCY}" == "day" && "${HYDROLAND_MRM_PARALLEL_SUBDOMAINS:-None}" != "None" ]]; then
        extra_args+=(--mrm-parallel-subdomains "${HYDROLAND_MRM_PARALLEL_SUBDOMAINS}")
    fi
    if [[ "${stage}" == "forcings" && "${HYDROLAND_MERGE_COMPRESSION_LEVEL:-None}" != "None" ]]; then
        extra_args+=(--merge-compression-level "${HYDROLAND_MERGE_COMPRESSION_LEVEL}")
    fi
    if [[ "${stage}" == "merge" ]]; then
        extra_args+=(--merge-buffer-target-mb "${HYDROLAND_MERGE_BUFFER_TARGET_MB:-4096}")
        if [[ "${merge_model}" != "None" ]]; then
            extra_args+=(--merge-model "${merge_model}")
        fi
        if [[ "${skip_merge}" == "True" ]]; then
            extra_args+=(--skip-merge)
        fi
        if [[ "${skip_cleanup}" == "True" ]]; then
            extra_args+=(--skip-cleanup)
        fi
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
        --stage "${stage}" \
        --prior-app-outpath "${HYDROLAND_PRIOR_APP_OUTPATH}" \
        --omp-num-threads-mhm "${HYDROLAND_OMP_NUM_THREADS_MHM}" \
        "${extra_args[@]}"
}

#####################
# Launch one HydroLand step as an srun sub-step when inside a SLURM job.
#
# Arguments:
#   $1 - STAGE (all, forcings, subdomain, merge)
#   $2 - SUBDOMAIN id or "None"
#   $3 - node placement slot (0-based) or "None" for Slurm's default
#   $4 - merge model ("mhm"/"mrm") or "None" for both (merge stage only)
#   $5 - skip_merge, $6 - skip_cleanup ("True"/"False", merge stage only)
#####################
function _run_hydroland_srun() {
    local stage="${1}"
    local subdomain="${2}"
    local node_slot="${3:-None}"
    local merge_model="${4:-None}"
    local skip_merge="${5:-False}"
    local skip_cleanup="${6:-False}"

    if [[ -z "${SLURM_JOB_ID:-}" ]]; then
        _run_hydroland_core "${stage}" "${subdomain}" "${merge_model}" "${skip_merge}" "${skip_cleanup}"
        return $?
    fi

    _hydroland_export_runtime_env

    local srun_name="hydroland"
    if [[ "${subdomain}" != "None" ]]; then
        srun_name="hydroland_sd${subdomain}"
    elif [[ "${merge_model}" != "None" ]]; then
        srun_name="hydroland_merge_${merge_model}"
    else
        srun_name="hydroland_${stage}"
    fi

    # Explicit round-robin node placement: srun --overlap --exact's default
    # placement on LUMI does not spread evenly across the allocation (see
    # hydroland README, "Running in the Workflow"). Pin each step to
    # node_slot instead of leaving it to Slurm's placement heuristic.
    local -a target_node_args=()
    if [[ "${node_slot}" != "None" && -n "${SLURM_JOB_NODELIST:-}" ]]; then
        local -a _hl_nodes
        mapfile -t _hl_nodes < <(scontrol show hostnames "${SLURM_JOB_NODELIST}")
        if [[ "${#_hl_nodes[@]}" -gt 0 ]]; then
            local idx=$((node_slot % ${#_hl_nodes[@]}))
            target_node_args=(--nodelist="${_hl_nodes[$idx]}")
        fi
    fi

    # --mem is a per-step cgroup safety net only, not admission control (see
    # README) - the real throttle is HYDROLAND_SUBDOMAINS_PER_NODE. Merge
    # steps are pinned 1:1 to their own node_slot instead, no throttle needed.
    #
    # _HL_STEP_CPUS / _HL_STEP_MEM_GB let a caller size its own steps. They
    # default to the monthly subdomain values (one mHM instance per step:
    # OMP_NUM_THREADS_MHM cores, MEM_PER_SUBDOMAIN GB). Day-mode mRM steps are
    # single-threaded and much denser per node, so run_HYDROLAND_DAY_MRM
    # overrides both. An empty _HL_STEP_MEM_GB omits --mem entirely.
    local step_cpus="${_HL_STEP_CPUS:-${HYDROLAND_OMP_NUM_THREADS_MHM}}"
    local -a mem_args=()
    local step_mem="${_HL_STEP_MEM_GB-${HYDROLAND_MEM_PER_SUBDOMAIN:-64}}"
    if [[ -n "${step_mem}" ]]; then
        mem_args=(--mem="${step_mem}G")
    fi

    srun --overlap --mpi=none --exact \
        --jobid="${SLURM_JOB_ID}" \
        -n1 -N1 -c"${step_cpus}" \
        "${mem_args[@]}" \
        "${target_node_args[@]}" \
        --job-name="${srun_name}" \
        bash -c "source '${_HYDROLAND_LIB}' && _run_hydroland_core '${stage}' '${subdomain}' '${merge_model}' '${skip_merge}' '${skip_cleanup}'"
}

#####################
# Run Hydroland application "subdomain" step (monthly execution).
# Launches one srun step per subdomain (1..HYDROLAND_NUM_SUBDOMAINS), or a
# single subdomain when HYDROLAND_SUBDOMAIN is set.
#
# GLOBALS USED
# ============
#    - HYDROLAND_SUBDOMAIN, HYDROLAND_NUM_SUBDOMAINS
#    - (see _run_hydroland_core)
#####################
function run_HYDROLAND_SUBDOMAIN() {
    local subdomain
    local -a pids=()
    local -a subdomains=()
    local status=0
    local num_subdomains
    num_subdomains="$(_hydroland_num_subdomains)"

    if [[ "${HYDROLAND_SUBDOMAIN}" != "None" ]]; then
        if [[ "${HYDROLAND_SUBDOMAIN}" -lt 1 || "${HYDROLAND_SUBDOMAIN}" -gt "${num_subdomains}" ]]; then
            echo "HYDROLAND_SUBDOMAIN must be between 1 and ${num_subdomains}." >&2
            exit 1
        fi
        subdomains=("${HYDROLAND_SUBDOMAIN}")
    else
        mapfile -t subdomains < <(seq 1 "${num_subdomains}")
    fi

    # Peak-memory profiling on LUMI found that srun --overlap --exact steps
    # are NOT admission-controlled on memory: passing --mem to the per-step
    # srun call (see _run_hydroland_srun) only caps that one step's own
    # cgroup, it does not stop Slurm from freely co-scheduling many such
    # steps onto the same node. Confirmed empirically: with --mem=64G set,
    # 16 subdomain steps still landed concurrently on one node and it OOM'd
    # for real (mHM alone peaks ~56.5GB per instance; 16 * 56GB >> 224GB).
    # So concurrency has to be throttled here, at the launcher, independent
    # of Slurm's step placement: launch in batches of (allocated nodes *
    # HYDROLAND_SUBDOMAINS_PER_NODE), with a hard wait between batches.
    # Validated on LUMI: 9 nodes * 3/node covers 26 subdomains with zero
    # OOMs (max observed per-node demand ~179GB of the 224GB budget), vs.
    # the 18-26 nodes previously needed with no throttle/placement control.
    local per_node="${HYDROLAND_SUBDOMAINS_PER_NODE:-3}"
    local nodes="${SLURM_JOB_NUM_NODES:-1}"
    local batch_size=$((nodes * per_node))
    [[ "${batch_size}" -lt 1 ]] && batch_size=1

    local i=0
    local n=${#subdomains[@]}
    while [[ "${i}" -lt "${n}" ]]; do
        pids=()
        local batch_end=$((i + batch_size))
        [[ "${batch_end}" -gt "${n}" ]] && batch_end="${n}"
        for (( ; i < batch_end; i++)); do
            subdomain="${subdomains[$i]}"
            # Opt-in resume (set _HYDROLAND_RESUME=1 externally): skip a
            # subdomain-month whose outputs already exist, so a retried job
            # doesn't redo completed work. Off by default - a "done" file
            # only proves something was written, not that it's still correct.
            if [[ "${_HYDROLAND_RESUME:-0}" == "1" ]] && _hydroland_subdomain_month_done "${subdomain}"; then
                echo "HydroLand: subdomain ${subdomain} already completed ${INI_YEAR}-${INI_MONTH} - skipping."
                continue
            fi
            # Node slot = subdomain id - 1, so _run_hydroland_srun pins this
            # step to node (subdomain - 1) % nodes. Without it node_slot
            # defaults to "None", the --nodelist block is skipped, and Slurm's
            # default placement stacks steps onto the batch node again.
            _run_hydroland_srun "subdomain" "${subdomain}" "$((subdomain - 1))" &
            pids+=($!)
        done
        for pid in "${pids[@]}"; do
            if ! wait "${pid}"; then
                status=1
            fi
        done
    done

    return "${status}"
}

#####################
# Manual/recovery utility: run the "subdomain" step for every month of one
# year (Jan -> Dec), all subdomains in parallel within each month, with a
# barrier between months so the per-subdomain warm-start chain (month M needs
# M-1's restart) holds. Resumable: completed subdomain-months are skipped.
#
# Not on the automatic STAGE=all path (each chunk now runs its own month via
# run_HYDROLAND_MONTH); kept for bulk manual reprocessing of a whole year.
#
# Arguments:
#   $1 - year (YYYY)
#####################
function run_HYDROLAND_YEAR_SUBDOMAINS() {
    local year="${1}"
    local month

    for month in $(seq 1 12); do
        _hydroland_set_month_window "${year}" "${month}"
        echo "HydroLand year loop: subdomain stage for ${INI_YEAR}-${INI_MONTH} (${INI_YEAR}-${INI_MONTH}-${INI_DAY} to ${END_YEAR}-${END_MONTH}-${END_DAY})."
        if ! _HYDROLAND_RESUME=1 run_HYDROLAND_SUBDOMAIN; then
            echo "HydroLand year loop: subdomain stage FAILED for ${INI_YEAR}-${INI_MONTH} - aborting the year loop (later months need this month's restarts)." >&2
            return 1
        fi
    done
}

#####################
# Manual/recovery utility: run the "merge" step for every month of one year
# (Jan -> Dec), sequentially. Resumable: months whose merged global flux files
# already exist are skipped.
#
# Not on the automatic STAGE=all path (each chunk now runs its own month via
# run_HYDROLAND_MONTH); kept for bulk manual reprocessing of a whole year.
#
# Arguments:
#   $1 - year (YYYY)
#####################
function run_HYDROLAND_YEAR_MERGES() {
    local year="${1}"
    local month

    for month in $(seq 1 12); do
        _hydroland_set_month_window "${year}" "${month}"
        if _hydroland_month_merge_done; then
            echo "HydroLand year loop: ${INI_YEAR}-${INI_MONTH} already merged - skipping."
            continue
        fi
        echo "HydroLand year loop: merge stage for ${INI_YEAR}-${INI_MONTH}."
        run_HYDROLAND_MERGE || return $?
    done
}

#####################
# Run Hydroland application "merge" step (monthly execution).
#
# HYDROLAND_MERGE_SPLIT_NODES=True runs mHM's and mRM's merges as two
# separate srun steps on two different nodes instead of one process on this
# node (see hydroland README, "Running in the Workflow"); off by default.
#
# GLOBALS USED
# ============
#    - HYDROLAND_MERGE_SPLIT_NODES
#    - (see _run_hydroland_core)
#####################
function run_HYDROLAND_MERGE() {
    if [[ "${HYDROLAND_MERGE_SPLIT_NODES:-False}" != "True" || -z "${SLURM_JOB_ID:-}" ]]; then
        _run_hydroland_core "merge" "None"
        return $?
    fi

    _hydroland_export_runtime_env

    local -a pids=()
    local status=0

    _run_hydroland_srun "merge" "None" 0 "mhm" "False" "True" &
    pids+=($!)
    _run_hydroland_srun "merge" "None" 1 "mrm" "False" "True" &
    pids+=($!)

    for pid in "${pids[@]}"; do
        if ! wait "${pid}"; then
            status=1
        fi
    done

    if [[ "${status}" -ne 0 ]]; then
        echo "HydroLand: merge stage FAILED for mHM and/or mRM - skipping cleanup." >&2
        return "${status}"
    fi

    # Cleanup-only pass: cheap, runs directly on this node (no srun needed).
    _run_hydroland_core "merge" "None" "None" "True" "False"
}

#####################
# Return the mRM subdomain count for daily runs (fixed by the resolution).
#####################
function _hydroland_day_mrm_subdomains() {
    if [[ "${HYDROLAND_GRID}" == "0.1/0.1" ]]; then
        echo 53
    else
        echo 26
    fi
}

#####################
# Daily stage B: one srun step per mRM subdomain, spread over the allocation.
#
# mRM cannot place itself: hydroland runs inside a singularity container
# launched with --cleanenv, so no SLURM_* variable reaches it, and the image
# carries neither srun nor scontrol - its internal multi-node detection always
# falls back to "run everything here". Placement therefore has to happen out
# here, exactly as the monthly subdomain stage already does it.
#
# Density and per-step cores are DERIVED, not configured - there is only ever
# one sensible value for each, and both were got wrong by hand once already
# (job 20847898: 5/node and -c1 turned a 2:15 stage into 9:26).
#
#   density = as many per node as it takes to finish in ONE wave, capped so a
#             node's share still fits in its RAM. A second wave costs a full
#             extra mRM runtime and buys nothing.
#   cores   = the node's cores divided by that density, so the steps on a node
#             exactly fill it. mRM runs with OMP_NUM_THREADS=1 but the binary
#             and its CDO calls still use more than one core.
#
# _HL_MRM_GB_PER_SUBDOMAIN is measured, not guessed: LUMI job 20847898 ran all
# 26 subdomains as separate Slurm steps and sacct reported 4.4-9.9 GB each
# (median 8.8) at 5 km hourly. 10 GB is that maximum rounded up; the extra 20%
# node-memory headroom below covers the driver and page cache. All 26 together
# come to 215 GB, which is why they do not fit on one 224 GB node.
#
# HYDROLAND_MRM_SUBDOMAINS_PER_NODE / HYDROLAND_MRM_CPUS_PER_STEP override the
# derivation if set. They are deliberately NOT in hydroland.yml - they exist
# for experiments, not for routine configuration.
#
# GLOBALS USED
# ============
#    - HYDROLAND_GRID
#    - (see _run_hydroland_core)
#####################
_HL_MRM_GB_PER_SUBDOMAIN=10

function run_HYDROLAND_DAY_MRM() {
    local -a pids=()
    local status=0
    local num_subdomains
    num_subdomains="$(_hydroland_day_mrm_subdomains)"

    local nodes="${SLURM_JOB_NUM_NODES:-1}"

    # One wave if the memory allows it, otherwise as many as do fit.
    local one_wave=$(((num_subdomains + nodes - 1) / nodes))
    local node_mem_gb
    node_mem_gb="$(awk '/MemTotal/{printf "%d", $2 / 1048576}' /proc/meminfo)"
    local mem_cap=$((node_mem_gb * 80 / 100 / _HL_MRM_GB_PER_SUBDOMAIN))
    [[ "${mem_cap}" -lt 1 ]] && mem_cap=1

    local per_node="${one_wave}"
    [[ "${per_node}" -gt "${mem_cap}" ]] && per_node="${mem_cap}"
    per_node="${HYDROLAND_MRM_SUBDOMAINS_PER_NODE:-${per_node}}"

    # Fill each node's cores across the steps that will share it.
    local cpus=$(("${SLURM_CPUS_ON_NODE:-128}" / per_node))
    [[ "${cpus}" -lt 1 ]] && cpus=1
    local _HL_STEP_CPUS="${HYDROLAND_MRM_CPUS_PER_STEP:-${cpus}}"
    # No --mem: on an srun step it is a cgroup ceiling, not admission control,
    # so it can only kill a step, never prevent over-subscription. per_node is
    # the real throttle.
    local _HL_STEP_MEM_GB=""

    local batch_size=$((nodes * per_node))
    [[ "${batch_size}" -lt 1 ]] && batch_size=1

    echo "HydroLand: daily mRM - node RAM ${node_mem_gb}GB -> at most ${mem_cap}/node; one wave needs ${one_wave}/node."

    echo "HydroLand: daily mRM - ${num_subdomains} subdomains over ${nodes} node(s), ${per_node}/node per wave, ${_HL_STEP_CPUS} core(s)/step."

    local i=1
    while [[ "${i}" -le "${num_subdomains}" ]]; do
        pids=()
        local batch_end=$((i + batch_size - 1))
        [[ "${batch_end}" -gt "${num_subdomains}" ]] && batch_end="${num_subdomains}"
        for (( ; i <= batch_end; i++)); do
            _run_hydroland_srun "day-mrm" "${i}" "$((i - 1))" &
            pids+=($!)
        done
        for pid in "${pids[@]}"; do
            if ! wait "${pid}"; then
                status=1
            fi
        done
        if [[ "${status}" -ne 0 ]]; then
            echo "HydroLand: daily mRM FAILED - aborting before the remaining waves." >&2
            return "${status}"
        fi
    done

    return "${status}"
}

#####################
# Run Hydroland application on daily executions.
#
# Which path runs is decided by the allocation, not by a config flag: asking
# for more than one node IS the request to use them.
#
# One node (or outside Slurm): STAGE=all, the whole pipeline in one process -
# unchanged behaviour. Every mRM subdomain runs here, which at 5 km needs
# ~215GB and therefore LUMI's largemem partition.
#
# Two or more nodes: split into day-pre (init -> preprocess -> mHM -> stage mRM
# inputs, on this node), one srun step per mRM subdomain spread across the
# allocation, then day-post (merge mRM + cleanup). This is what lets a daily
# run use ordinary `standard` nodes. Nothing regresses by auto-detecting: a
# multi-node daily job previously just wasted the extra nodes, since mRM's own
# placement never engages inside the container.
#
# GLOBALS USED
# ============
#    - (see run_HYDROLAND_DAY_MRM, _run_hydroland_core)
#####################
function run_HYDROLAND_DAY() {
    if [[ -z "${SLURM_JOB_ID:-}" || "${SLURM_JOB_NUM_NODES:-1}" -le 1 ]]; then
        _run_hydroland_core "all" "None"
        return $?
    fi

    _hydroland_export_runtime_env

    _run_hydroland_core "day-pre" "None" || return $?
    run_HYDROLAND_DAY_MRM || return $?
    _run_hydroland_core "day-post" "None"
}

#####################
# Run Hydroland application on monthly executions.
#
# STAGE=all: every chunk runs its own forcings, then the subdomain stage
# (all subdomains in parallel), for that chunk's month only, unconditionally
# (no auto-skip/resume). Does NOT merge - the merge is run separately,
# later, outside this automatic pipeline. Chunks still depend on each other:
# month M's subdomain stage needs month M-1's restart, so chunks must run in
# order (the APP_HYDROLAND job dependency chain already enforces this).
#
# STAGE=forcings/subdomain/merge run a single stage for the chunk's month
# (manual / recovery modes, e.g. re-running just one failed subdomain via
# SUBDOMAIN: N, or the merge itself once ready). run_HYDROLAND_YEAR_SUBDOMAINS/
# _MERGES remain available as separate manual/recovery utilities for bulk
# reprocessing a whole year, with resumability always on there.
#
# GLOBALS USED
# ============
#    - HYDROLAND_STAGE, INI_* / END_* (chunk dates)
#    - (see _run_hydroland_core)
#####################
function run_HYDROLAND_MONTH() {
    case "${HYDROLAND_STAGE}" in
    forcings)
        _run_hydroland_core "forcings" "None"
        ;;
    subdomain)
        run_HYDROLAND_SUBDOMAIN
        ;;
    merge)
        run_HYDROLAND_MERGE
        ;;
    forcings-cleanup)
        _run_hydroland_core "forcings-cleanup" "None"
        ;;
    all)
        _run_hydroland_core "forcings" "None" || return $?
        run_HYDROLAND_SUBDOMAIN || return $?
        # Once every subdomain has finished, drop the window's global pet/tavg
        # and reduce its pre file. Here rather than inside the subdomain stage:
        # the 26 subdomain processes share this directory and would race on it.
        # Only runs when HYDROLAND.DELETE_FILES is set; hydroland itself is the
        # one that checks, so nothing is duplicated here.
        _run_hydroland_core "forcings-cleanup" "None"
        ;;
    *)
        echo "Unknown HYDROLAND stage: ${HYDROLAND_STAGE}" >&2
        exit 1
        ;;
    esac
}

#####################
# Run Hydroland application.
#
# Only RUN_FREQUENCY=day is enabled. Daily runs always execute the full
# pipeline via run_HYDROLAND_DAY (STAGE=all).
#
# GLOBALS USED
# ============
#    - HYDROLAND_RUN_FREQUENCY, HYDROLAND_STAGE, INI_MONTH
#    - (see _run_hydroland_core)
#####################
function run_HYDROLAND() {
    if [[ "${HYDROLAND_RUN_FREQUENCY}" != "day" ]]; then
        echo "ERROR: HYDROLAND_RUN_FREQUENCY=${HYDROLAND_RUN_FREQUENCY}; only \"day\" is enabled." >&2
        exit 1
    fi
    if [[ "${HYDROLAND_SUBDOMAIN}" != "None" ]]; then
        echo "ERROR: HYDROLAND.SUBDOMAIN=${HYDROLAND_SUBDOMAIN} is only valid with RUN_FREQUENCY=month (daily runs are whole-domain). Set SUBDOMAIN: \"None\"." >&2
        exit 1
    fi
    if [[ "${HYDROLAND_STAGE}" != "all" ]]; then
        echo "ERROR: HYDROLAND.STAGE=${HYDROLAND_STAGE} is only valid with RUN_FREQUENCY=month (daily runs always use STAGE=all)." >&2
        exit 1
    fi
    run_HYDROLAND_DAY
}
