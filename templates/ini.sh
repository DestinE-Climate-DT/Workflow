#!/bin/bash
#
# This step prepares any necessary initial data for the climate model runs
set -xuve

# HEADER
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL_NAME=${3:-%MODEL.NAME%}
MODEL_ROOT_PATH=${4:-%MODEL.ROOT_PATH%}
CURRENT_ARCH=${5:-%CURRENT_ARCH%}
expver=${6:-%CONFIGURATION.IFS.EXPVER%}
label=${7:-%CONFIGURATION.IFS.LABEL%}
SDATE=${8:-%SDATE%}
ATM_GRID=${9:-%MODEL.GRID_ATM%}
OCEAN_GRID=${10:-%MODEL.GRID_OCE%}
EXPID=${11:-%DEFAULT_EXPID%}
HPC_PROJECT=${12:-%CONFIGURATION.HPC_PROJECT_DIR%}
MODEL_VERSION=${13:-%MODEL.VERSION%}
HPCARCH=${14:-%HPCARCH%}
ENVIRONMENT=${15:-%RUN.ENVIRONMENT%}
MEMBER=${16:-%MEMBER%}
MEMBER_LIST=${17:-%EXPERIMENT.MEMBERS%}
PU=${18:-%RUN.PROCESSOR_UNIT%}
DVC_INPUTS_BRANCH=${19:-%MODEL.DVC_INPUTS_BRANCH%}
OCE_ini_member_perturb=${20:-%RUN.OCE_INI_MEMBER_PERTURB%}
namelist_cfg_patch=${21:-%NAMELIST_PATCHES.namelist_cfg%}
namelist_ice_cfg_patch=${22:-%NAMELIST_PATCHES.namelist_ice_cfg%}
fort_4_patch=${23:-%NAMELIST_PATCHES.fort_4%}
IFS_EXPVER=${24:-%CONFIGURATION.IFS.EXPVER%}
IFS_LABEL=${25:-%CONFIGURATION.IFS.LABEL%}
LIBDIR=${26:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${27:-%CONFIGURATION.SCRIPTDIR%}
MODEL_PATH=${28:-%MODEL.PATH%}
MODEL_INPUTS=${29:-%MODEL.INPUTS%}
TOOLS_VERSION=${30:-%TOOLS.VERSION%}
BASE_VERSION=${31:-%BASE.VERSION%}
ENSEMBLES_VERSION=${32:-%ENSEMBLES.VERSION%}
CONTAINER_DIR=${33:-%CONFIGURATION.CONTAINER_DIR%}

# END_HEADER

SDATE=${SDATE}00

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

ATM_MODEL=${MODEL_NAME%%-*}
OCEAN_MODEL=${MODEL_NAME##*-}

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

INIPATH=${HPCROOTDIR}/inipath

###############################################
# If requested, perturb temperature field in
# IFS ising the member number as seed.
# The first member (fc0) is the control one
# so it is not perturbed
###############################################
perturb_ifs() {
    # TO test and revise
    if [ "${OCE_ini_member_perturb}" = "true" ]; then

        ## standard deviation in gaussian normal distribution
        DEFAULT_PERTURBATION=0.0002

        ## realization starts at 1
        # lib/common/util.sh (get_member_number) (auto generated comment)
        MEMBER_NUMBER=$(get_member_number "${MEMBER_LIST}" ${MEMBER})

        RESTART_IN=${INIPATH}/${MEMBER}/${OCEAN_MODEL}/V40/${OCEAN_GRID}/${SDATE}/restart.nc

        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        export SINGULARITY_BIND="${SCRIPTDIR},${RESTART_IN}"
        export SINGULARITYENV_RESTART_IN=${RESTART_IN}
        export SINGULARITYENV_MEMBER_NUMBER=${MEMBER_NUMBER}
        export SINGULARITYENV_DEFAULT_PERTURBATION=${DEFAULT_PERTURBATION}
        # TO-DO: copy container to LUMI!
        singularity exec ${CONTAINER_DIR}/ensembles/ensembles_${ENSEMBLES_VERSION}.sif \
            python3 ${SCRIPTDIR}/ensembles/perturb_nemo_restart.py -f $RESTART_IN -r $MEMBER_NUMBER -p $DEFAULT_PERTURBATION

        ## unlink unperturbed and link perturbed restart file
        unlink $RESTART_IN
        ln -s ${RESTART_IN%.*}_${MEMBER_NUMBER}_$DEFAULT_PERTURBATION.nc $RESTART_IN

    fi
}

perturb_icon() {
    true
}

perturb_nemo() {
    true
}

# Main code

# THE CLEAN RUN OPTION HAS BEEN DISABLED FOR SAFETY PURPOSES

# only do the following for NEMO, IFS-NEMO and ICON, IFS-FESOM input has many files and contains links (DVC)
# which leads to problems
if [[ "${MODEL_NAME^^}" == "NEMO" || "${MODEL_NAME^^}" == "IFS-NEMO" || "${MODEL_NAME^^}" == "ICON" ]]; then
    ## Creates a directory where the inputs are symlinked to the real ones.
    if [ ! -d "${INIPATH}/${MEMBER}" ]; then
        mkdir -p $INIPATH
        cp -rLs "${MODEL_INPUTS}" "$INIPATH/${MEMBER}"
    fi
fi

#Copy selected (with a configuration parameter in main) patches from runscripts/patches to rundir
#Configuration should be:
#NAMELIST_PATCHES:
# - namelist_cfg: NAME-OF-THE PATCH
# - namelist_ice_cfg: NAME-OF-THE PATCH
# Then we would take those files and copy them to the rundir.
# To apply them

list_of_namelists_ifs_nemo=("nemo/V40/${OCEAN_GRID}/${SDATE}/namelist_cfg" "nemo/V40/${OCEAN_GRID}/${SDATE}/namelist_ice_cfg" "${ATM_GRID}/${IFS_EXPVER}/${IFS_LABEL}/${SDATE}/gfc/fort.4")

for namelist in "${list_of_namelists_ifs_nemo[@]}"; do
    formatted_namelist=$(echo "$namelist" | tr '.' '_')
    patch="$(basename "$formatted_namelist")_patch"
    if [ -n "${!patch}" ]; then
        cp ${HPCROOTDIR}/$PROJDEST/conf/namelist_patches/${!patch} ${INIPATH}/${MEMBER}/${namelist}_patch
        INIPATH_MEM=${INIPATH}/${MEMBER}
        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        export SINGULARITY_BIND="${INIPATH_MEM},${SCRIPTDIR}",${HPCROOTDIR}
        export SINGULARITYENV_namelist=${namelist}
        export SINGULARITYENV_patch=${namelist}_patch
        export SINGULARITYENV_SCRIPTDIR=${SCRIPTDIR}
        singularity exec ${CONTAINER_DIR}/tools/tools_${TOOLS_VERSION}.sif \
            python3 ${SCRIPTDIR}/namelists/mod_namelists.py -n "${INIPATH_MEM}/${namelist}" -p "${INIPATH_MEM}/${namelist}_patch"
        mv ${INIPATH}/${MEMBER}/${namelist}_mod ${INIPATH}/${MEMBER}/${namelist}
    fi
done

perturb_${ATM_MODEL}
