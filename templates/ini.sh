#!/bin/bash
#
# This step prepares any necessary initial data for the climate model runs
set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%MODEL.NAME%}
CURRENT_ARCH=${4:-%CURRENT_ARCH%}
expver=${5:-%CONFIGURATION.IFS.EXPVER%}
label=${6:-%CONFIGURATION.IFS.LABEL%}
SDATE=${7:-%SDATE%00}
ATM_GRID=${8:-%MODEL.GRID_ATM%}
OCEAN_GRID=${9:-%MODEL.GRID_OCE%}
EXPID=${11:-%DEFAULT_EXPID%}
HPC_PROJECT=${12:-%CURRENT_HPC_PROJECT_DIR%}
MODEL_VERSION=${13:-%MODEL.VERSION%}
HPCARCH=${14:-%HPCARCH%}
ENVIRONMENT=${15:-%RUN.ENVIRONMENT%}
MEMBER=${16:-%MEMBER%}
MEMBER_LIST=${17:-%EXPERIMENT.MEMBERS%}
PU=${18:-%RUN.PROCESSOR_UNIT%}
INPUTS=${19:-%CONFIGURATION.INPUTS%}
ATM_ini_member_perturb=${20:-%RUN.ATM_INI_MEMBER_PERTURB%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
PLUGINDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib/runscript/ensembles
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

ATM_MODEL=${MODEL_NAME%%-*}
OCEAN_MODEL=${MODEL_NAME##*-}

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

load_model_dir
load_inproot_precomp_path

INIPATH=${HPCROOTDIR}/inipath

###############################################
# If requested, perturb temperature field in
# IFS ising the member number as seed.
# The first member (fc0) is the control one
# so it is not perturbed
###############################################
perturb_ifs() {
    if [ "${ATM_ini_member_perturb}" = "true" ]; then

        ## load the climate-dt python environment
        load_python_climate_dt

        ## standard deviation in gaussian normal distribution
        DEFAULT_PERTURBATION=0.0002

        ## Creates a directory where the inputs are symlinked to the real ones.
        if [ ! -d "${INIPATH}/${MEMBER}" ]; then
            mkdir -p $INIPATH
            cp -rs "$INPROOT" "$INIPATH/${MEMBER}"
        fi

        ## realization starts at 1
        get_member_number "${MEMBER_LIST}" ${MEMBER}

        RESTART_IN=${INIPATH}/${MEMBER}/${OCEAN_MODEL}/V40/${OCEAN_GRID}/${SDATE}/restart.nc
        python ${PLUGINDIR}/perturb_nemo_restart.py -f $RESTART_IN -r $MEMBER_NUMBER -p $DEFAULT_PERTURBATION

        ## unlink unperturbed and link perturbed restart file
        unlink $RESTART_IN
        ln -s ${RESTART_IN%.*}_${MEMBER_NUMBER}_$DEFAULT_PERTURBATION.nc $RESTART_IN

    fi
}

perturb_icon() {
    true
}

# Main code
load_SIM_env_"${ATM_MODEL}"_"${PU}"

# THE CLEAN RUN OPTION HAS BEEN DISABLED FOR SAFETY PURPOSES

perturb_${ATM_MODEL}
