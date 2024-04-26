#!/bin/bash
#
# This step backups restarts and rundir of the current running simulation
set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
EXPID=${2:-%DEFAULT_EXPID%}
HPC_PROJECT=${3:-%CURRENT_HPC_PROJECT_DIR%}
CHUNK=${4:-%CHUNK%}
PROJDEST=${5:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${6:-%CURRENT_ARCH%}
BACKUP_PROCESSORS=${9:-%JOBS.BACKUP.PROCESSORS%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)
. "${LIBDIR}"/"${HPC}"/config.sh

load_backup_env

OUTROOT=${HPCROOTDIR}/rundir
PRE_RESTART_DIR=${HPCROOTDIR}/restarts
RESTART_DIR=${PRE_RESTART_DIR}/$((CHUNK + 1))

BACKUP_RESTARTS_PATH=${HPC_PROJECT}/backup/${EXPID}/restarts/$((CHUNK + 1))
mkdir -p "${BACKUP_RESTARTS_PATH}"

BACKUP_RUNDIR_PATH=${HPC_PROJECT}/backup/${EXPID}/rundir/
mkdir -p "${BACKUP_RUNDIR_PATH}"

# Copy the restart files to the backup directory
parallel -j ${BACKUP_PROCESSORS} --eta rsync -a --exclude '*-backup' {} "${BACKUP_RESTARTS_PATH}" ::: "${RESTART_DIR}"/*

# Copy the rundir files to the backup directory
parallel -j ${BACKUP_PROCESSORS} --eta rsync -a {} "${BACKUP_RUNDIR_PATH}" ::: "${OUTROOT}"/

# Check that the backup of the restarts was successful
number_of_files_original_restarts=$(ls -1 "${RESTART_DIR}" | grep -v "backup" | wc -l)
number_of_files_backup_restarts=$(ls -1 "${BACKUP_RESTARTS_PATH}" | wc -l)

if [ "${number_of_files_original_restarts}" -eq "${number_of_files_backup_restarts}" ]; then
    echo "The number of files in both directories match"
else
    echo "Backup of the restarts failed"
    exit 1
fi

files_to_check="waminfo rcf nemorcf"

for file in $files_to_check; do
    if [ -f ${BACKUP_RESTARTS_PATH}/$file ]; then
        echo "Found $file"
    else
        echo "Missing $file"
        exit 1
    fi
done

# Check that the backup of the rundir was successful
number_of_files_original_rundir=$(ls -1 "${OUTROOT}" | wc -l)
number_of_files_backup_rundir=$(ls -1 "${BACKUP_RUNDIR_PATH}" | wc -l)

if [ "${number_of_files_original_rundir}" -eq "${number_of_files_backup_rundir}" ]; then
    echo "Backup of the rundir successful"
else
    echo "Backup of the rundir failed"
    exit 1
fi

# Delete previous restart files
