#!/bin/bash

set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
EXPID=${2:-%DEFAULT.EXPID%}
HPC_PROJECT=${3:-%CONFIGURATION.HPC_PROJECT_DIR%}
PROJDEST=${4:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${5:-%CURRENT_ARCH%}

# AQUA configuration
CONTAINER_VERSION=${6:-%AQUA.CONTAINER_VERSION%}
CATALOG_NAME=${7:-%HPCCATALOG_NAME%}
EXPVER=${8:-%REQUEST.EXPVER%}
MODEL_NAME_UPPER=${9:-%REQUEST.MODEL_NAME_UPPER%}
MODEL_NAME=${10:-%MODEL.NAME%}

# Grid build configuration
CHECK_EXISTING=${11:-%AQUA_GRID_BUILD.CHECK_EXISTING_GRIDS%}
SKIP_IF_AVAILABLE=${12:-%AQUA_GRID_BUILD.SKIP_IF_AVAILABLE%}
REBUILD=${13:-%AQUA_GRID_BUILD.REBUILD%}
VERIFY_GRIDS=${14:-%AQUA_GRID_BUILD.VERIFY_GRIDS%}
FIX_COORDINATES=${15:-%AQUA_GRID_BUILD.FIX_COORDINATES%}
LOGLEVEL=${16:-%AQUA_GRID_BUILD.LOGLEVEL%}

# Sources for grid extraction
SOURCE_ATM=${17:-%AQUA_GRID_BUILD.SOURCE_ATM%}
SOURCE_OCE_2D=${18:-%AQUA_GRID_BUILD.SOURCE_OCE_2D%}
SOURCE_OCE_3D=${19:-%AQUA_GRID_BUILD.SOURCE_OCE_3D%}

# Vertical coordinate for 3D grids
VERT_COORD_3D=${20:-%AQUA_GRID_BUILD.VERT_COORD_3D%}

# Grid output directory
GRID_OUTDIR=${21:-%AQUA_GRID_BUILD.GRID_OUTDIR%}

# Model grids and resolutions
AQUA_GRID_ATM=${22:-%AQUA.GRID_ATM%}
AQUA_RES_ATM=${23:-%AQUA.RESOLUTION_ATM%}
AQUA_RES_OCE=${24:-%AQUA.RESOLUTION_OCE%}

# Grid versioning and ocean grid (from config)
GRID_VERSION=${25:-%AQUA_GRID_BUILD.GRID_VERSION%}
GRID_OCE=${26:-%AQUA.GRID_OCE%}

# IFS configuration (for resolution)
IFS_RESOL=${27:-%CONFIGURATION.IFS.RESOL%}

# Platform/environment
HPC_SCRATCH=${28:-%CONFIGURATION.PROJECT_SCRATCH%}
HPC_CONTAINER_DIR=${29:-%CURRENT_CONTAINER_DIR%}
GSV_DEFINITION_PATH=${30:-%GSV.DEFINITION_PATH%}

# Variables required by load_singularity (LUMI)
LOCAL_DIR=${31:-%CURRENT_LOCAL_DIR%}
SCRATCH_DIR=${32:-%CURRENT_SCRATCH_DIR%}
HPC_PROJECT_ROOT=${33:-%CURRENT_HPC_PROJECT_ROOT%}

# Model resolution, appended to the catalog model name (e.g. IFS-FESOM-5km)
RESOLUTION=${34:-%MODEL.RESOLUTION%}

# END_HEADER

################################################################################
# AQUA_GRID_BUILD Job Template
# Purpose: Build grid definition files from simulation output for AQUA/LRA
#          AQUA needs grid definitions to read/mask native resolution data
#          before regridding to analysis grids for archiving
# Uses: aqua grids build command in AQUA container
# Author: Climate DT Workflow Team
#
# Required config parameters:
#   - AQUA.GRID_OCE: Ocean grid name (CORE2, DARS, NG5, eORCA1, eORCA025, eORCA12)
#   - CONFIGURATION.IFS.RESOL: Numeric resolution (79, 399, 1279, 2559)
#   - MODEL.NAME: Model name (ifs-fesom, ifs-nemo, icon)
################################################################################

echo "==================================================================="
echo "AQUA_GRID_BUILD: Building grid definition files for AQUA"
echo "==================================================================="
echo "Experiment: ${EXPID}"
echo "Model: ${MODEL_NAME_UPPER}"
echo "Catalog: ${CATALOG_NAME}"
echo "EXPVER: ${EXPVER}"
echo "AQUA Container Version: ${CONTAINER_VERSION}"
echo "==================================================================="

# Setup
AQUA_CONTAINER="${HPC_CONTAINER_DIR}/aqua/aqua_${CONTAINER_VERSION}.sif"
AQUA_CONFIG="${HPCROOTDIR}/.aqua"

# Catalog model name carries the resolution suffix (e.g. IFS-FESOM-5km) so that
# `aqua grids build -m` resolves the model/exp/source triplet in the catalog.
MODEL_AND_RES="${MODEL_NAME_UPPER}-${RESOLUTION}"

LIBDIR="${HPCROOTDIR}/${PROJDEST}/lib"
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Source libraries
. "${LIBDIR}/${HPC}/config.sh"
. "${LIBDIR}/common/util.sh"
. "${LIBDIR}/common/utils/grid_build_utils.sh"

# Load singularity
# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

# Setup singularity bindings
ADDITIONAL_BINDINGS=(
    "$(realpath ${HPC_PROJECT})" "${HPC_PROJECT}"
    "$(realpath ${HPC_SCRATCH})" "${HPC_SCRATCH}"
)
# lib/common/util.sh (setup_additional_binds) (auto generated comment)
bindings=$(setup_additional_binds "${ADDITIONAL_BINDINGS[@]}")

################################################################################
# Extract parameters from config
################################################################################
echo "-------------------------------------------------------------------"
echo "Using grid parameters from config"
echo "-------------------------------------------------------------------"

# Extract ocean component from MODEL_NAME using bash pattern (e.g., ifs-fesom → fesom)
OCEAN_MODEL=${MODEL_NAME##*-}
OCE_COMPONENT=$(echo "${OCEAN_MODEL}" | tr '[:lower:]' '[:upper:]')
echo "Ocean component: ${OCE_COMPONENT}"

# Use ocean grid from config (AQUA.GRID_OCE)
ORIGINAL_RESOLUTION="${GRID_OCE}"
if [ -z "${ORIGINAL_RESOLUTION}" ] || [ "${ORIGINAL_RESOLUTION}" = "null" ]; then
    echo "ERROR: AQUA.GRID_OCE not defined in config"
    echo "Please add GRID_OCE to the AQUA section in your model config file"
    exit 1
fi
echo "Ocean grid (from AQUA.GRID_OCE): ${ORIGINAL_RESOLUTION}"

# Use numeric resolution from config (CONFIGURATION.IFS.RESOL)
NUMERIC_RESOL="${IFS_RESOL}"
echo "Numeric resolution (from CONFIGURATION.IFS.RESOL): ${NUMERIC_RESOL}"

# Validate grid version from config (AQUA.GRID_VERSION)
if [ -z "${GRID_VERSION}" ] || [ "${GRID_VERSION}" = "null" ]; then
    echo "ERROR: GRID_VERSION not defined in model config (AQUA.GRID_VERSION)"
    echo "       Please define AQUA.GRID_VERSION in conf/model/${MODEL_NAME}/${MODEL_NAME}.yml"
    exit 1
fi
echo "Using grid version from config: v${GRID_VERSION}"

################################################################################
# Create output directories
################################################################################
mkdir -p "${GRID_OUTDIR}/${OCE_COMPONENT}"
echo "Grid output directory: ${GRID_OUTDIR}/${OCE_COMPONENT}"

################################################################################
# Main Execution
################################################################################

echo "-------------------------------------------------------------------"
echo "Building ocean 2D grid (MANDATORY)"
echo "-------------------------------------------------------------------"

# Build 2D ocean grid - this is CRITICAL for workflow
if [ "${CHECK_EXISTING,,}" = "true" ] && [ "${SKIP_IF_AVAILABLE,,}" = "true" ]; then
    # lib/common/utils/grid_build_utils.sh (check_grid_exists) (auto generated comment)
    if check_grid_exists "${GRID_OUTDIR}/${OCE_COMPONENT}" "${ORIGINAL_RESOLUTION}" "2D"; then
        echo "2D ocean grid already exists - skipping build"
        GRID_2D_EXISTS=true
    else
        GRID_2D_EXISTS=false
    fi
else
    GRID_2D_EXISTS=false
fi

if [ "${GRID_2D_EXISTS}" = false ] || [ "${REBUILD,,}" = "true" ]; then
    # lib/common/utils/grid_build_utils.sh (build_grid_with_aqua) (auto generated comment)
    build_grid_with_aqua \
        "${CATALOG_NAME}" \
        "${MODEL_AND_RES}" \
        "${EXPVER}" \
        "${SOURCE_OCE_2D}" \
        "$(echo ${OCE_COMPONENT} | tr '[:upper:]' '[:lower:]')" \
        "${OCE_COMPONENT}" \
        "${ORIGINAL_RESOLUTION}" \
        "${GRID_VERSION}" \
        "${GRID_OUTDIR}/${OCE_COMPONENT}" \
        "${LOGLEVEL}" \
        "${VERIFY_GRIDS}" \
        "${FIX_COORDINATES}" \
        "${REBUILD}" \
        "${AQUA_CONTAINER}" \
        "${AQUA_CONFIG}" \
        "${bindings}"

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to build 2D ocean grid"
        echo "This is a critical failure - workflow cannot proceed"
        exit 1
    fi

    # Update grid YAML registry with correctly named entry
    # lib/common/utils/grid_build_utils.sh (update_grid_registry) (auto generated comment)
    update_grid_registry \
        "${AQUA_CONFIG}" \
        "$(echo ${OCE_COMPONENT} | tr '[:upper:]' '[:lower:]')" \
        "${OCE_COMPONENT}" \
        "${ORIGINAL_RESOLUTION}" \
        "${AQUA_RES_OCE}" \
        "${GRID_VERSION}" \
        "2D"

    echo "SUCCESS: 2D ocean grid built"
else
    echo "2D ocean grid exists and rebuild not requested"
fi

################################################################################
# Build 3D ocean grid (CRITICAL, requires AQUA v0.19.7+)
################################################################################

if [ "${SOURCE_OCE_3D}" != "null" ] && [ -n "${SOURCE_OCE_3D}" ]; then
    echo "-------------------------------------------------------------------"
    echo "Building ocean 3D grid"
    echo "-------------------------------------------------------------------"
    echo "Using AQUA v0.19.7+ with --vert_coord ${VERT_COORD_3D}"

    GRID_3D_EXISTS=false
    if [ "${CHECK_EXISTING,,}" = "true" ] && [ "${SKIP_IF_AVAILABLE,,}" = "true" ]; then
        # lib/common/utils/grid_build_utils.sh (check_grid_exists) (auto generated comment)
        if check_grid_exists "${GRID_OUTDIR}/${OCE_COMPONENT}" "${ORIGINAL_RESOLUTION}" "3D"; then
            echo "3D ocean grid already exists - skipping build"
            GRID_3D_EXISTS=true
        fi
    fi

    if [ "${GRID_3D_EXISTS}" = false ] || [ "${REBUILD,,}" = "true" ]; then
        # lib/common/utils/grid_build_utils.sh (build_grid_with_aqua) (auto generated comment)
        build_grid_with_aqua \
            "${CATALOG_NAME}" \
            "${MODEL_AND_RES}" \
            "${EXPVER}" \
            "${SOURCE_OCE_3D}" \
            "$(echo ${OCE_COMPONENT} | tr '[:upper:]' '[:lower:]')" \
            "${OCE_COMPONENT}" \
            "${ORIGINAL_RESOLUTION}" \
            "${GRID_VERSION}" \
            "${GRID_OUTDIR}/${OCE_COMPONENT}" \
            "${LOGLEVEL}" \
            "${VERIFY_GRIDS}" \
            "${FIX_COORDINATES}" \
            "${REBUILD}" \
            "${AQUA_CONTAINER}" \
            "${AQUA_CONFIG}" \
            "${bindings}" \
            "${VERT_COORD_3D}"

        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to build 3D ocean grid"
            echo "This is a critical failure - workflow cannot proceed"
            exit 1
        fi

        # Update grid YAML registry with correctly named 3D entry
        # lib/common/utils/grid_build_utils.sh (update_grid_registry) (auto generated comment)
        update_grid_registry \
            "${AQUA_CONFIG}" \
            "$(echo ${OCE_COMPONENT} | tr '[:upper:]' '[:lower:]')" \
            "${OCE_COMPONENT}" \
            "${ORIGINAL_RESOLUTION}" \
            "${AQUA_RES_OCE}" \
            "${GRID_VERSION}" \
            "3D" \
            "${VERT_COORD_3D}"

        echo "SUCCESS: 3D ocean grid built"
    else
        echo "3D ocean grid exists and rebuild not requested"
    fi
else
    echo "-------------------------------------------------------------------"
    echo "Skipping 3D ocean grid (SOURCE_OCE_3D not configured)"
    echo "-------------------------------------------------------------------"
fi

################################################################################
# Build atmosphere/HEALPix grid (CRITICAL, registry-only)
################################################################################

if [ "${SOURCE_ATM}" != "null" ] && [ -n "${SOURCE_ATM}" ]; then
    echo "-------------------------------------------------------------------"
    echo "Building atmosphere/HEALPix grid"
    echo "-------------------------------------------------------------------"
    echo "Using HEALPix resolution: ${AQUA_RES_ATM}"

    # AQUA.GRID_ATM already has the clean native resolution for all models:
    # ICON: R2B8, R2B9    IFS-FESOM/IFS-NEMO: tco79, tco1279, etc.
    ATM_NATIVE_RES="${AQUA_GRID_ATM}"
    echo "Native resolution: ${ATM_NATIVE_RES}"

    GRID_ATM_EXISTS=false
    if [ "${CHECK_EXISTING,,}" = "true" ] && [ "${SKIP_IF_AVAILABLE,,}" = "true" ]; then
        # lib/common/utils/grid_build_utils.sh (check_grid_exists) (auto generated comment)
        if check_grid_exists "${GRID_OUTDIR}/HealPix" "${AQUA_RES_ATM}" ""; then
            echo "Atmosphere grid already exists - skipping build"
            GRID_ATM_EXISTS=true
        fi
    fi

    if [ "${GRID_ATM_EXISTS}" = false ] || [ "${REBUILD,,}" = "true" ]; then
        # Create HealPix directory if it doesn't exist
        mkdir -p "${GRID_OUTDIR}/HealPix"

        # Atmosphere is registry-only (no physical .nc file), so pass
        # write_yaml=true to let AQUA write the healpix.yaml entry
        # lib/common/utils/grid_build_utils.sh (build_grid_with_aqua) (auto generated comment)
        build_grid_with_aqua \
            "${CATALOG_NAME}" \
            "${MODEL_AND_RES}" \
            "${EXPVER}" \
            "${SOURCE_ATM}" \
            "healpix" \
            "IFS" \
            "${ATM_NATIVE_RES}" \
            "${GRID_VERSION}" \
            "${GRID_OUTDIR}/HealPix" \
            "${LOGLEVEL}" \
            "${VERIFY_GRIDS}" \
            "${FIX_COORDINATES}" \
            "${REBUILD}" \
            "${AQUA_CONTAINER}" \
            "${AQUA_CONFIG}" \
            "${bindings}" \
            "" \
            "true"

        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to build atmosphere grid"
            echo "This is a critical failure - workflow cannot proceed"
            exit 1
        fi

        echo "SUCCESS: Atmosphere grid built"
    else
        echo "Atmosphere grid exists and rebuild not requested"
    fi
else
    echo "-------------------------------------------------------------------"
    echo "Skipping atmosphere grid (SOURCE_ATM not configured)"
    echo "-------------------------------------------------------------------"
fi

################################################################################
# Summary
################################################################################

echo "==================================================================="
echo "AQUA_GRID_BUILD job completed"
echo "==================================================================="
echo "Model: ${MODEL_NAME_UPPER}"
echo "Ocean component: ${OCE_COMPONENT}"
echo "Original resolution: ${ORIGINAL_RESOLUTION}"
echo "Grid version: v${GRID_VERSION}"
echo "Output directory: ${GRID_OUTDIR}/${OCE_COMPONENT}"
echo ""
echo "Grids created:"
ls -lh "${GRID_OUTDIR}/${OCE_COMPONENT}/" 2>/dev/null || echo "  (no files or directory not accessible)"
echo ""
echo "AQUA configuration: ${AQUA_CONFIG}"
echo "Grids are now available for LRA_GENERATOR and AQUA tools"
echo "==================================================================="

################################################################################
# END OF SCRIPT
