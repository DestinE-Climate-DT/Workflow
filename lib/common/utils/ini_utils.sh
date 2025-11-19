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

        RESTART_IN=${INIPATH}/${START_DATE}/${MEMBER}/${OCEAN_MODEL}/V40/${OCEAN_GRID}/${SDATE}/restart.nc

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
    RESTART_DIR=${PRE_RESTART_DIR}/1/
    if [ -d ${RESTARTS_FROM_PATH} ]; then
        mkdir -p ${RESTART_DIR}
        find "${RESTARTS_FROM_PATH}/" -type f ! -name '*-backup' -exec cp {} "${RESTART_DIR}/" \;
        # Check that it copied something
        if [ "$(ls -A ${RESTART_DIR})" ]; then
            echo "Restart files copied successfully from ${RESTARTS_FROM_PATH} to ${RESTART_DIR}"
        else
            echo "No restart files found in ${RESTARTS_FROM_PATH}"
            exit 1
        fi
    else
        echo "The given RESTART_FROM ${RESTART_FROM} does not contain the requested restarts files"
        exit 1
    fi
    # Modify nemorcf file to point to the new location of the restarts
    if [ -f ${RESTART_DIR}/nemorcf ]; then
        sed -i "s#${RESTARTS_FROM_PATH}#${RESTART_DIR}#" ${RESTART_DIR}/nemorcf
    fi
}
