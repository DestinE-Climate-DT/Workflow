#!/bin/bash
# Utils functions for ini.sh

#####################################################
# Deletes IFS rundir in the INI step for a clean run
# Globals:
#    HPCROOTDIR
# Arguments:
#
#####################################################
function rm_rundir_ifs() {
    rm -rf "$HPCROOTDIR"/rundir
}

#####################################################
# Deletes ICON rundir in the INI step for a clean run
# Globals:
# Arguments:
#
#####################################################
function rm_rundir_icon() {
    true
}

###############################################
# If requested, perturb temperature field in
# IFS using the member number as seed.
# The first member (fc0) is the control one
# so it is not perturbed.
###############################################
function perturb_ifs() {
    # TO test and revise
    if [ "${OCE_ini_member_perturb}" = "true" ]; then

        ## standard deviation in gaussian normal distribution
        DEFAULT_PERTURBATION=0.0002

        ## realization starts at 1
        # lib/common/util.sh (get_member_number) (auto generated comment)
        MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

        RESTART_IN=${INIPATH}/${SIM_START_DATE}/${MEMBER}/${OCEAN_MODEL}/V40/${OCEAN_GRID}/${SIM_START_DATE}/restart.nc

        ADDITIONAL_BINDINGS=("$RESTART_IN")
        # lib/common/util.sh (setup_additional_binds) (auto generated comment)
        bindings=$(setup_additional_binds ${ADDITIONAL_BINDINGS})

        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        # TO-DO: copy container to LUMI!
        singularity exec \
            --env "RESTART_IN=${RESTART_IN}" \
            --env "MEMBER_NUMBER=${MEMBER_NUMBER}" \
            --env "DEFAULT_PERTURBATION=${DEFAULT_PERTURBATION}" \
            ${bindings} \
            ${CONTAINER_DIR}/ensembles/ensembles_${ENSEMBLES_VERSION}.sif \
            python3 ${SCRIPTDIR}/ensembles/perturb_nemo_restart.py -f $RESTART_IN -r $MEMBER_NUMBER -p $DEFAULT_PERTURBATION

        ## unlink unperturbed and link perturbed restart file
        unlink $RESTART_IN
        ln -s ${RESTART_IN%.*}_${MEMBER_NUMBER}_$DEFAULT_PERTURBATION.nc $RESTART_IN

    fi
}

function perturb_icon() {
    true
}

function perturb_nemo() {
    true
}

function copy_restarts_from_expid() {
    # For a restarted run, copy restarts from the source experiment's latest chunk
    # to the first chunk directory (chunk 1) of the new experiment
    # The 'current' symlink in RESTARTS_FROM_PATH points to the latest completed chunk
    RESTART_DIR=${PRE_RESTART_DIR}/1/

    if [ -d ${RESTARTS_FROM_PATH} ]; then
        mkdir -p ${RESTART_DIR}
        # Use rsync with -L to follow symlinks (resolves 'current' to actual chunk directory)
        # Copy all files and directories from the source experiment's final chunk, excluding backups
        # Also exclude stale restart leftovers from previous chunks (pattern: name_<runlength>_<jobid>)
        # which accumulate in old-workflow experiments that use a flat 'current' directory
        SRC_RESTART_DIR="${RESTARTS_FROM_PATH%/}"
        find "${SRC_RESTART_DIR}" -type f \
            ! -name '*-backup' \
            ! -name 'fesom_raw_restart_*' \
            ! -name 'rcf_*' \
            ! -name 'waminfo_*' |
            xargs -P 16 -I{} bash -c "
                rel=\"\${1#\$2/}\"
                dest=\"\$3/\$(dirname \"\$rel\")\"
                mkdir -p \"\$dest\"
                rsync -aL --inplace --info=progress2 \"\$1\" \"\$dest/\"
            " _ {} "${SRC_RESTART_DIR}" "${RESTART_DIR}"
        # Verify that files were copied
        if [ "$(ls -A ${RESTART_DIR})" ]; then
            echo "Restart files copied successfully from ${RESTARTS_FROM_PATH} to ${RESTART_DIR}"
        else
            echo "No restart files found in ${RESTARTS_FROM_PATH}"
            exit 1
        fi
    else
        echo "The given RESTART_FROM ${RESTART_FROM} does not contain the requested restarts files, or the given RESTARTS_FROM_PATH ${RESTARTS_FROM_PATH} does not exist"
        exit 1
    fi

    # Modify nemorcf file to point to the new location (IFS-NEMO specific)
    # FESOM does not have this file, so the modification is skipped if not present
    if [ -f ${RESTART_DIR}/nemorcf ]; then
        sed -i "s#${RESTARTS_FROM_PATH}#${RESTART_DIR}#" ${RESTART_DIR}/nemorcf
    fi
}

#####################################################
# Setup IFS-FESOM inipath structure for restarted runs
# Creates symlinks for atmospheric forcing with date redirection
# when IFS_START_DATE differs from SIM_START_DATE
# Example: Use 1990 forcing for 1991+ simulations
# Globals:
#    MODEL_NAME, RESTARTED_RUN, IFS_START_DATE, SIM_START_DATE
#    MODEL_INPUTS, ATM_GRID, IFS_EXPVER, IFS_LABEL, INIPATH
# Arguments:
#    None
#####################################################
function create_inipath_symlinks_for_date_redirection() {
    # Only for IFS-FESOM restarted runs
    [[ "${MODEL_NAME^^}" != "IFS-FESOM" ]] && return
    [ "${RESTARTED_RUN,,}" != "true" ] && return

    # Only if using different forcing year than simulation year
    [ -z "${IFS_START_DATE:-}" ] && return
    [ "${IFS_START_DATE}" = "${SIM_START_DATE}" ] && return

    echo "IFS-FESOM restarted run: Using atmospheric forcing from ${IFS_START_DATE} for simulation starting ${SIM_START_DATE}"

    # Normalize dates to 10 digits (append '00' hour if needed)
    if [ ${#IFS_START_DATE} -eq 8 ]; then
        IFS_START_DATE_FULL="${IFS_START_DATE}00"
    else
        IFS_START_DATE_FULL="${IFS_START_DATE}"
    fi

    if [ ${#SIM_START_DATE} -eq 8 ]; then
        START_DATE_FULL="${SIM_START_DATE}00"
    else
        START_DATE_FULL="${SIM_START_DATE}"
    fi

    # Validate forcing directory exists
    IFS_FORCING_DIR="${MODEL_INPUTS}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${IFS_START_DATE_FULL}/gfc"
    if [ ! -d "${IFS_FORCING_DIR}" ]; then
        echo "ERROR: Atmospheric forcing directory not found: ${IFS_FORCING_DIR}"
        exit 1
    fi

    # Create inipath directory structure
    mkdir -p ${INIPATH}/${SIM_START_DATE}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}

    # Symlink IFS_START_DATE forcing directory
    ln -sfn "${MODEL_INPUTS}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${IFS_START_DATE_FULL}" \
        "${INIPATH}/${SIM_START_DATE}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${IFS_START_DATE_FULL}"

    # Symlink SIM_START_DATE to IFS_START_DATE (date redirection)
    ln -sfn "${MODEL_INPUTS}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${IFS_START_DATE_FULL}" \
        "${INIPATH}/${SIM_START_DATE}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${START_DATE_FULL}"

    # Symlink data directory (contains ifsdata, remap, etc.)
    if [ -d "${MODEL_INPUTS}/${ATM_GRID}/${IFS_EXPVER}/data" ]; then
        ln -sfn "${MODEL_INPUTS}/${ATM_GRID}/${IFS_EXPVER}/data" \
            "${INIPATH}/${SIM_START_DATE}/${ATM_GRID}/${IFS_EXPVER}/data"
    fi

    # Symlink top-level directories
    for dir in ifsdata ifsINIT fesom tools storyline_forcing; do
        if [ -e "${MODEL_INPUTS}/${dir}" ]; then
            ln -sfn "${MODEL_INPUTS}/${dir}" "${INIPATH}/${SIM_START_DATE}/${dir}"
        fi
    done

    echo "Created inipath structure:"
    echo "  ${INIPATH}/${SIM_START_DATE}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${IFS_START_DATE_FULL} -> ${MODEL_INPUTS}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${IFS_START_DATE_FULL}"
    if [ "${IFS_START_DATE}" != "${SIM_START_DATE}" ]; then
        echo "  ${INIPATH}/${SIM_START_DATE}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${START_DATE_FULL} -> ${MODEL_INPUTS}/${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${IFS_START_DATE_FULL}"
    fi
    echo "  ${INIPATH}/${SIM_START_DATE}/${ATM_GRID}/${IFS_EXPVER}/data -> ${MODEL_INPUTS}/${ATM_GRID}/${IFS_EXPVER}/data"
}
