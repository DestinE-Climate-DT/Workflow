#!/bin/bash
#

# This script can be run without workflow manager with the following syntax:
# sbatch -p standard -J htco79 -o htco79-%j.out -N 1 --ntasks-per-node=64 --cpus-per-task=2 --account=project_462000048 --time=00:10:00 --export=ALL,HPCROOTDIR=/scratch/project_462000048/anmartinez/exp1,PROJDEST=,PRECOMP_MODEL_PATH=/scratch/project_462000048/anmartinez/RAPS20/,CURRENT_ARCH=LUMI,CHUNKSIZE=60,CHUNKSIZEUNIT="d",INPROOT=/project/project_462000048/sidorenko/inputs/,RAPS_SCRIPT=fesom_tco79.lumi.slurm sim.sh
#
# Note: I have not used the #SBATCH headers here because those headers are added automatically by Autosubmit


set -xuve

# Interface
HPCROOTDIR=${HPCROOTDIR:-%HPCROOTDIR%}
PROJDEST=${PROJDEST:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${CURRENT_ARCH:-%CURRENT_ARCH%}
CHUNKSIZE=${CHUNKSIZE:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${CHUNKSIZEUNIT:-%EXPERIMENT.CHUNKSIZEUNIT%}
MODEL_NAME=${MODEL:-%MODEL.NAME%}
ENVIRONMENT=${6:-%RUN.ENVIRONMENT%}
HPCARCH=${7:-%HPCARCH%}
MODEL_VERSION=${8:-%RUN.MODEL_VERSION%}
export MODEL_VERSION
export ENVIRONMENT
export HPCARCH

export expver=%CONFIGURATION.IFS.EXPVER%
export label=%CONFIGURATION.IFS.LABEL%

export gtype=%CONFIGURATION.IFS.GTYPE%
export resol=%CONFIGURATION.IFS.RESOL%
export levels=%CONFIGURATION.IFS.LEVELS%

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo "${CURRENT_ARCH}" | cut -d- -f1 )

# take date from autosubmit and add 00 at the end, because autosubmit does not go further than day
yyyymmddzz=%SDATE%00

RESTART_DIR=${HPCROOTDIR}/restarts
OUTROOT=${HPCROOTDIR}/rundir

. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/"${HPC}"/config.sh

load_model_dir
load_inproot_precomp_path

export INPROOT=${INPROOT} 
export OUTROOT=${OUTROOT}

ATM_MODEL=${MODEL_NAME%%-*}

# Directory definition
if [ ! -d "${PRECOMP_MODEL_PATH}" ]; then
    MODEL_DIR=${HPCROOTDIR}/${PROJDEST}/ifs-source
else
    MODEL_DIR=${PRECOMP_MODEL_PATH}
fi

RAPS_DIR=${MODEL_DIR}/flexbuild/bin/SLURM/${CURRENT_ARCH,,}

# compute fclen
# this needs to be increased for each chunk. So, if you want to run 5 days in 1 day chunks
# your need to run first run with fclen=d1, second run with fclen=d2, third run with fclen=d3 etc.

runlength=$((%CHUNK%*${CHUNKSIZE}))
fclen=${CHUNKSIZEUNIT:0:1}${runlength}

. "${LIBDIR}"/"${HPC}"/config.sh
#the host variable is set here
load_SIM_env_"${ATM_MODEL}"

echo "${ATM_MODEL}"
#model variables are set here
source "${LIBDIR}"/common/util.sh
load_variables_"${ATM_MODEL}"

# Equivalent to the sbatch single liner from RAPS documentation
#export fclen=${CHUNKSIZEUNIT:0:1}${CHUNKSIZE}

other="--icmcl=ICMCL_79_2020 --nemo --restartdirectory=${RESTART_DIR} --nonemopart --keeprestart --nextgemsout=6 --keepfdb --no-fdb --keepnetcdf"
export other


# The RAPS scripts assumes that you are submitting the job from
# <ifs_path>/flexbuild/bin/<scheduler>/<hpc>/. As this is not the case in the case
# of the workflow, it cannot find the ``.again`` script and a crash happens. The two
# following lines solve the problem
cd "${RAPS_DIR}"
source ../../../.again

# Run the RAPS script
# the lines below are copied from the submission script
# because than we can use autosubmit variables there to set starttime etc.
#./${RAPS_SCRIPT}

set -eux

ifsMASTER=$(which.pl ifsMASTER.*)

export COUPFREQ=10800 # 3hourly coupling (RAPS sets tstep to 3600 for TCo79; CORE2 oce runs with 45min timestep)

nproma=${nproma:-16}
depth=${depth:-$omp}
ht=${ht:-$(htset.pl "$SLURM_NTASKS_PER_NODE" "$SLURM_CPUS_PER_TASK")}

hres \
    -p "$mpi" -t "$omp" -h "$ht" \
    -j "$jobid" -J "$jobname" \
    -d "$yyyymmddzz" -e "$expver" -L "$label" \
    -T "$gtype" -r "$resol" -l "$levels" -f "$fclen" \
    -x "$ifsMASTER" \
    -N "$nproma" \
    -H "$host" -n "$nodes" -C "$compiler" --nemo-ver V40 --nemo-grid eORCA1_Z75 ${other:-}
