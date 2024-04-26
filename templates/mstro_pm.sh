#!/bin/bash
#
# This step loads the necessary enviroment and then compiles the diferent models

set -xuve

# Interface
HPCROOTDIR=${1:-%HPCROOTDIR%}
PROJDEST=${2:-%PROJECT.PROJECT_DESTINATION%}
MODEL=${3:-%MODEL.MODEL_NAME%}
MODEL_SOURCE=${4:-%MODEL.SOURCE%}
MODEL_BRANCH=${5:-%MODEL.BRANCH%}
CURRENT_ARCH=${6:-%CURRENT_ARCH%}
PRECOMP_MODEL_PATH=${7:-%MODEL.PRECOMP_MODEL_PATH%}
APP=${8:-%RUN.APP%}
EXPID=${9:-%DEFAULT.EXPID%}
DATELIST=${10:-%EXPERIMENT.DATELIST%}
MEMBERS=${11:-%EXPERIMENT.MEMBERS%}
CHUNK=${12:-%CHUNK%}
SPLITS=${13:-%JOBS.MSTRO_OPA.SPLITS%}
WORKFLOW=${14:-%RUN.WORKFLOW%}

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$(echo ${CURRENT_ARCH} | cut -d- -f1)
source "${LIBDIR}"/"${HPC}"/config.sh
source "${LIBDIR}"/common/util.sh

if [ "$WORKFLOW" == "maestro-apps" ]; then
    load_environment_maestro_apps
    export MSTRO_WORKFLOW_NAME="MSTRO_APP_${CHUNK}"
    export MSTRO_DIR=/scratch/project_465000454/chaine/maestro-core/
    export MSTRO_SCHEMA_PATH="${MSTRO_DIR}"/examples
    export MSTRO_SCHEMA_LIST="gsv.yaml;fdb_request_schema.yaml"
fi
if [ "$WORKFLOW" == "maestro-end-to-end" ]; then
    load_environment_maestro_end_to_end
    export MSTRO_WORKFLOW_NAME="Maestro ECMWF Demo Workflow"
fi

cd ${MSTRO_DIR}/tests/
PM_CMD="srun ./simple_pool_manager"
PM_INFO="${HPCROOTDIR}/LOG_${EXPID}/pm_${CHUNK}.info"
PM_ERR="${HPCROOTDIR}/LOG_${EXPID}/pm_${CHUNK}.err"

#clean old pm info files before starting a new run
if [ "$CHUNK" == "1" ]; then
    rm -f ${HPCROOTDIR}/LOG_${EXPID}/pm_* ${HPCROOTDIR}/LOG_${EXPID}/*_mstrodep
fi

exec 3< <(env ${PM_CMD} 1>${PM_INFO} 2>${PM_ERR})
PM_PID=$!

# The Pool Manager job is running continuously, it needs to be told when to
# stop. To that end, we will wait here for completion files from the other
# jobs (ie when there is no more work for the Pool Manager), before initiating
# termination of the Pool Manager.
if [ "$SPLITS" == "-1" ]; then
    SPLITS="1"
fi

for i in $(seq 1 $SPLITS); do
    if [ "$WORKFLOW" == "maestro-apps" ]; then
        producer_completed="${HPCROOTDIR}/LOG_${EXPID}/producer_${CHUNK}_${i}_mstrodep"
    fi
    if [ "$WORKFLOW" == "maestro-end-to-end" ]; then
        producer_completed="${HPCROOTDIR}/LOG_${EXPID}/producer_${CHUNK}_mstrodep"
    fi
    consumer_completed="${HPCROOTDIR}/LOG_${EXPID}/consumer_${CHUNK}_${i}_mstrodep"
    while [ ! -f $producer_completed ]; do
        echo "Waiting for ${producer_completed} ..."
        sleep 1
    done
    while [ ! -f $consumer_completed ]; do
        echo "Waiting for ${consumer_completed} ..."
        sleep 1
    done
done

scancel -sSIGUSR2 $SLURM_JOB_ID
echo "exit, stopping pool manager"
