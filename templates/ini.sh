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
ATM_GRID=${8:-%MODEL.GRID_ATM%}
OCEAN_GRID=${9:-%MODEL.GRID_OCE%}
EXPID=${10:-%DEFAULT.EXPID%}
HPC_PROJECT=${11:-%CONFIGURATION.HPC_PROJECT_DIR%}
MODEL_VERSION=${12:-%MODEL.VERSION%}
HPCARCH=${13:-%HPCARCH%}
ENVIRONMENT=${14:-%RUN.ENVIRONMENT%}
MEMBER=${15:-%MEMBER%}
MEMBER_LIST=${16:-%EXPERIMENT.MEMBERS%}
PU=${17:-%RUN.PROCESSOR_UNIT%}
DVC_INPUTS_BRANCH=${18:-%MODEL.DVC_INPUTS_BRANCH%}
OCE_ini_member_perturb=${19:-%RUN.OCE_INI_MEMBER_PERTURB%}
namelist_cfg_patch=${20:-%NAMELIST_PATCHES.namelist_cfg%}
namelist_ice_cfg_patch=${21:-%NAMELIST_PATCHES.namelist_ice_cfg%}
fort_4_patch=${22:-%NAMELIST_PATCHES.fort_4%}
IFS_EXPVER=${23:-%CONFIGURATION.IFS.EXPVER%}
IFS_LABEL=${24:-%CONFIGURATION.IFS.LABEL%}
LIBDIR=${25:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${26:-%CONFIGURATION.SCRIPTDIR%}
MODEL_PATH=${27:-%MODEL.PATH%}
MODEL_INPUTS=${28:-%MODEL.INPUTS%}
TOOLS_VERSION=${29:-%TOOLS.VERSION%}
BASE_VERSION=${30:-%BASE.VERSION%}
ENSEMBLES_VERSION=${31:-%ENSEMBLES.VERSION%}
CONTAINER_DIR=${32:-%CURRENT_CONTAINER_DIR%}
HPC_PROJECT_ROOT=${33:-%CURRENT_HPC_PROJECT_ROOT%}
SCRATCH_DIR=${34:-%CURRENT_SCRATCH_DIR%}
LOCAL_DIR=${35:-%CURRENT_LOCAL_DIR%}
SIM_START_DATE=${36:-%SDATE%}
RESTART_FROM=${37:-%RUN.RESTART_FROM%}
RESTARTS_FROM_PATH=${38:-%MODEL.RESTARTS_FROM_PATH%}
RESTARTED_RUN=${39:-%RUN.RESTARTED_RUN%}
PRE_RESTART_DIR=${40:-%CONFIGURATION.PRE_RESTART_DIR%}
IFS_START_DATE=${41:-%CONFIGURATION.IFS.START_DATE%}

# END_HEADER

SDATE=${SIM_START_DATE}00

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

ATM_MODEL=${MODEL_NAME%%-*}
OCEAN_MODEL=${MODEL_NAME##*-}

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/common/utils/ini_utils.sh

INIPATH=${HPCROOTDIR}/inipath

# Main code

# only do the following for NEMO, IFS-NEMO and ICON, IFS-FESOM input has many files and contains links (DVC)
# which leads to problems
if [[ "${MODEL_NAME^^}" == "NEMO" || "${MODEL_NAME^^}" == "IFS-NEMO" || "${MODEL_NAME^^}" == "ICON" ]]; then
    ## Creates a directory where the inputs are symlinked to the real ones.
    if [ ! -d "${INIPATH}/${SIM_START_DATE}/${MEMBER}" ]; then
        mkdir -p ${INIPATH}/${SIM_START_DATE}
        cp -rLs "${MODEL_INPUTS}" "${INIPATH}/${SIM_START_DATE}/${MEMBER}"
    fi
# For IFS-FESOM restarted runs, create inipath structure with date redirection
elif [[ "${MODEL_NAME^^}" == "IFS-FESOM" ]]; then
    # lib/common/utils/ini_utils.sh (create_inipath_symlinks_for_date_redirection) (auto generated comment)
    create_inipath_symlinks_for_date_redirection
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
        INIPATH_MEM=${INIPATH}/${SIM_START_DATE}/${MEMBER}
        cp ${HPCROOTDIR}/$PROJDEST/conf/namelist_patches/${!patch} ${INIPATH_MEM}/${namelist}_patch

        ADDITIONAL_BINDINGS=("$INIPATH_MEM")
        # lib/common/util.sh (setup_additional_binds) (auto generated comment)
        bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

        # lib/LUMI/config.sh (load_singularity) (auto generated comment)
        # lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
        load_singularity
        singularity exec \
            --env "namelist=${namelist}" \
            --env "patch=${namelist}_patch" \
            --env "SCRIPTDIR=${SCRIPTDIR}" \
            ${bindings} \
            ${CONTAINER_DIR}/tools/tools_${TOOLS_VERSION}.sif \
            python3 ${SCRIPTDIR}/namelists/mod_namelists.py -n "${INIPATH_MEM}/${namelist}" -p "${INIPATH_MEM}/${namelist}_patch"
        mv ${INIPATH_MEM}/${namelist}_mod ${INIPATH_MEM}/${namelist}
    fi
done

if [ "${RESTARTED_RUN,,}" = "true" ]; then
    # lib/common/utils/ini_utils.sh (copy_restarts_from_expid) (auto generated comment)
    copy_restarts_from_expid
fi

perturb_${ATM_MODEL}
