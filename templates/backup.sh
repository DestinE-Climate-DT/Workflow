#!/bin/bash
#
# This step backs up the restarts and rundir of the current running simulation
set -xuve

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
EXPID=${2:-%DEFAULT.EXPID%}
HPC_PROJECT=${3:-%CONFIGURATION.HPC_PROJECT_DIR%}
CHUNK=${4:-%CHUNK%}
PROJDEST=${5:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${6:-%CURRENT_ARCH%}
BACKUP_PROCESSORS=${7:-%JOBS.BACKUP.PROCESSORS%}
LIBDIR=${8:-%CONFIGURATION.LIBDIR%}
START_DATE=${9:-%SDATE%}
MEMBER=${10:-%MEMBER%}
KEEP_EVERY=${11:-%CONFIGURATION.RESTARTS.KEEP_EVERY%}
RESTARTS_BACKUP_PATH=${12:-%CONFIGURATION.RESTARTS_BACKUP_PATH%}
RUNDIR_BACKUP_PATH=${13:-%CONFIGURATION.RUNDIR_BACKUP_PATH%}
RUNDIR_PATH=${14:-%CONFIGURATION.RUNDIR_PATH%}
MODEL_NAME=${15:-%MODEL.NAME%}
RESTART_FILES_TO_CHECK=${16:-%CONFIGURATION.RESTARTS.FILES_TO_CHECK%}
RESTART_DIRS_TO_CHECK=${17:-%CONFIGURATION.RESTARTS.DIRS_TO_CHECK%}

# END_HEADER

. "${LIBDIR}/common/utils/backup_utils.sh"
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)
. "${LIBDIR}"/"${HPC}"/config.sh

# lib/LUMI/config.sh (load_backup_env) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_backup_env) (auto generated comment)
load_backup_env
# lib/common/utils/backup_utils.sh (determine_should_backup) (auto generated comment)
should_backup_restarts=$(determine_should_backup)

if [[ "${should_backup_restarts}" == "true" ]]; then

    PRE_RESTART_DIR=${HPCROOTDIR}/restarts/${START_DATE}/${MEMBER}
    RESTART_DIR=${PRE_RESTART_DIR}/$((CHUNK + 1))

    BACKUP_RESTARTS_PATH=${RESTARTS_BACKUP_PATH}/${EXPID}/${START_DATE}/${MEMBER}/$((CHUNK + 1))
    mkdir -p "${BACKUP_RESTARTS_PATH}"

    # Copy the restart files to the backup directory
    parallel -j ${BACKUP_PROCESSORS} --eta rsync -a --exclude '*-backup' {} "${BACKUP_RESTARTS_PATH}" ::: "${RESTART_DIR}"/

    # Check that the backup of the restarts was successful
    number_of_files_original_restarts=$(ls -1 "${RESTART_DIR}" | grep -v "backup" | wc -l)
    number_of_files_backup_restarts=$(ls -1 "${BACKUP_RESTARTS_PATH}" | wc -l)

    if [ "${number_of_files_original_restarts}" -eq "${number_of_files_backup_restarts}" ]; then
        echo "The number of files in both directories match"
    else
        echo "Backup of the restarts failed"
        exit 1
    fi

    # Check for critical restart files based on model type
    for file in $RESTART_FILES_TO_CHECK; do
        if [ -f ${BACKUP_RESTARTS_PATH}/$file ]; then
            echo "Found $file"
        else
            echo "Missing $file"
            exit 1
        fi
    done

    for dir in $RESTART_DIRS_TO_CHECK; do
        if [ -d ${BACKUP_RESTARTS_PATH}/$dir ]; then
            echo "Found $dir"
        else
            echo "Missing $dir"
            exit 1
        fi
    done
fi

# always back up the RUNDIR
OUTROOT=${RUNDIR_PATH}
mkdir -p "${RUNDIR_BACKUP_PATH}"

# Copy the rundir files to the backup directory
parallel -j ${BACKUP_PROCESSORS} --eta rsync -a {} "${RUNDIR_BACKUP_PATH}" ::: "${OUTROOT}"/

# Check that the backup of the rundir was successful
number_of_files_original_rundir=$(ls -1 "${OUTROOT}" | wc -l)
number_of_files_backup_rundir=$(ls -1 "${RUNDIR_BACKUP_PATH}" | wc -l)

if [ "${number_of_files_original_rundir}" -eq "${number_of_files_backup_rundir}" ]; then
    echo "Backup of the rundir successful"
else
    echo "Backup of the rundir failed"
    exit 1
fi
