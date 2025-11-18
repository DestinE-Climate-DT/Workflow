#!/bin/bash

# HEADER

HPCROOTDIR=${1:-%HPCROOTDIR%}
CHUNK_START_DATE=${2:-%CHUNK_START_DATE%}
END_DATE=${3:-%CHUNK_END_DATE%}
CHUNK=${4:-%CHUNK%}
CHUNK_END_IN_DAYS=${5:-%CHUNK_END_IN_DAYS%}
CHUNK_FIRST=${6:-%CHUNK_FIRST%}
PROJDEST=${7:-%PROJECT.PROJECT_DESTINATION%}
CURRENT_ARCH=${8:-%CURRENT_ARCH%}
EXPID=${9:-%DEFAULT.EXPID%}
PREV=${10:-%PREV%}
TOTAL_RETRIALS=${11:-%CONFIG.RETRIALS%}
MEMBER=${12:-%MEMBER%}
OCEAN_GRID=${13:-%MODEL.GRID_OCE%}
SIM_START_DATE=${14:-%SDATE%}
MODEL_NAME=${15:-%MODEL.NAME%}
PU=${16:-%RUN.PROCESSOR_UNIT%}
CHUNK_START_YEAR=${17:-%CHUNK_START_YEAR%}
CHUNK_END_YEAR=${18:-%CHUNK_END_YEAR%}
LIBDIR=${19:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${20:-%CONFIGURATION.SCRIPTDIR%}
MODEL_PATH=${21:-%MODEL.PATH%}
NEMO_IO_NODES=${22:-%CONFIGURATION.NEMO.IO_NODES%}
NEMO_TPN=${23:-%CONFIGURATION.NEMO_TPN%}
XIOS_TPN=${24:-%CONFIGURATION.XIOS_TPN%}
DATA_DIR=${25:-%CURRENT_DATA_DIR%}
HPC_CONTAINER_DIR=${26:-%CURRENT_CONTAINER_DIR%}
TOOLS_VERSION=${27:-%TOOLS.VERSION%}
HPC_PROJECT_ROOT=${28:-%CURRENT_HPC_PROJECT_ROOT%}
SCRATCH_DIR=${29:-%CURRENT_SCRATCH_DIR%}
LOCAL_DIR=${30:-%CURRENT_LOCAL_DIR%}

# END_HEADER

set -xuve

CHUNK_RUNDIR="$HPCROOTDIR/rundir/${CHUNK_START_DATE}-${END_DATE}-${SLURM_JOB_ID}"
RESTART_DIR="$HPCROOTDIR/restarts/${SIM_START_DATE}"
CHUNK_RESTART_DIR="${RESTART_DIR}/${CHUNK}"
CHUNK_NEXT_RESTART_DIR="${RESTART_DIR}/$(($CHUNK + 1))"

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/common/utils/sim_utils.sh

INSTALL_DIR="${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}"

# lib/common/utils/sim_utils.sh (check_rundir_name) (auto generated comment)
check_rundir_name

mkdir -p $CHUNK_RUNDIR
mkdir -p $CHUNK_RESTART_DIR
mkdir -p $CHUNK_NEXT_RESTART_DIR

cd $CHUNK_RUNDIR

INIDIR="$HPCROOTDIR/inipath/${SIM_START_DATE}/$MEMBER/nemo/V40/$OCEAN_GRID"

ICDIR="$INIDIR/restarts/${SIM_START_DATE}"
COMMONDIR="$INIDIR/common"
XIOSDIR="$INIDIR/xios"
FORCINGDIR="$INIDIR/SBC/ERA5_HRES"
NAMELISTSDIR="$INIDIR/namelists"
SCRIPTSDIR="$HPCROOTDIR/inipath/${SIM_START_DATE}/$MEMBER/scripts"

# lib/LUMI/config.sh (load_singularity) (manually generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (manually generated comment)
load_compile_env_"${MODEL_NAME,,}"_"${PU}"

cp -s $NAMELISTSDIR/* $CHUNK_RUNDIR
cp -s $ICDIR/* $CHUNK_RUNDIR
cp -s $COMMONDIR/* $CHUNK_RUNDIR
cp -s $XIOSDIR/* $CHUNK_RUNDIR
cp -s $SCRIPTSDIR/* $CHUNK_RUNDIR

#### GENERATE PATCH

# Read the value of rn_rdt from namelist_cfg
#rn_rdt=$(grep "rn_rdt" $CHUNK_RUNDIR/namelist_cfg | cut -d= -f2)
rn_rdt=$(awk '/^\s*rn_rdt/ { sub(/!.*$/, ""); sub(/.*=/, ""); gsub(/ /, "", $0); print; exit }' "$CHUNK_RUNDIR/namelist_cfg")

nn_itend=$(($CHUNK_END_IN_DAYS * 24 * 3600 / $rn_rdt))
cn_ocerst_outdir="${CHUNK_NEXT_RESTART_DIR}"

PREV_nn_itend=$(($PREV * 24))
padded_PREV_nn_itend=$(printf "%08d" "$PREV_nn_itend")

ln_rsttime=.true.
nn_write=-1
ln_rcf_write=.true.

if [ ${CHUNK_FIRST,,} = "true" ]; then
    cn_ocerst_indir="."
    cn_icerst_indir="."
    ln_rcf_read=.false.
else
    cn_ocerst_indir="${CHUNK_RESTART_DIR}"
    cn_icerst_indir="${CHUNK_RESTART_DIR}"
    ln_rcf_read=.true.
    cp ${CHUNK_RESTART_DIR}/nemorcf* ${CHUNK_NEXT_RESTART_DIR}
fi

nn_stock=$(($CHUNK_END_IN_DAYS * 24))

cn_icerst_outdir="${CHUNK_NEXT_RESTART_DIR}"

cat <<EOL >"namelist_cfg_patch_$CHUNK"
&namrun
cn_exp="$EXPID"
nn_itend=$nn_itend
nn_date0=$SIM_START_DATE
cn_ocerst_indir ='$cn_ocerst_indir'
cn_ocerst_outdir='$cn_ocerst_outdir'
nn_stock=$nn_stock
ln_rsttime=$ln_rsttime
nn_write=$nn_write
ln_rcf_read=$ln_rcf_read
ln_rcf_write=$ln_rcf_write
/
EOL

cat <<EOL >"namelist_ice_cfg_patch_$CHUNK"
&nampar
cn_icerst_outdir='$cn_ocerst_outdir'
cn_icerst_indir='$cn_ocerst_indir'
/
EOL

# lib/LUMI/config.sh (load_singularity) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_singularity) (auto generated comment)
load_singularity

singularity exec --cleanenv --no-home \
    --env SCRIPTDIR="${SCRIPTDIR}" \
    --env CHUNK_RUNDIR="${CHUNK_RUNDIR}" \
    --env CHUNK="${CHUNK}" \
    --env HPC_CONTAINER_DIR="${HPC_CONTAINER_DIR}" \
    --bind "$(realpath ${SCRIPTDIR})" \
    --bind "$(realpath ${CHUNK_RUNDIR})" \
    --bind "$(realpath ${HPC_CONTAINER_DIR})" \
    "${HPC_CONTAINER_DIR}/tools/tools_${TOOLS_VERSION}.sif" \
    bash -c \
    '
    python3 $SCRIPTDIR/namelists/mod_namelists.py -n "${CHUNK_RUNDIR}/namelist_cfg" -p "${CHUNK_RUNDIR}/namelist_cfg_patch_$CHUNK"
    mv "${CHUNK_RUNDIR}/namelist_cfg_mod" "${CHUNK_RUNDIR}/namelist_cfg"
    python3 $SCRIPTDIR/namelists/mod_namelists.py -n "${CHUNK_RUNDIR}/namelist_ice_cfg" -p "${CHUNK_RUNDIR}/namelist_ice_cfg_patch_$CHUNK"
    mv "${CHUNK_RUNDIR}/namelist_ice_cfg_mod" "${CHUNK_RUNDIR}/namelist_ice_cfg"
    '

# Replace OCEAN_GRID with the desired shortcut
OCEAN_GRID_SHORT=$(echo "$OCEAN_GRID" | sed 's/_.*//' | sed 's/eORCA1/eO1/; s/eORCA12/eO12/; s/eORCA025/eO25/')

YYYY="${SIM_START_DATE:0:4}"

for var in precip q10 qlw qsw slp snow t10 u10 v10; do
    for ((year = YYYY; year <= CHUNK_END_YEAR; year++)); do
        ln -s ${FORCINGDIR}/${var}_fc00_ERA5_HRES_${OCEAN_GRID_SHORT}_${year}.nc ${CHUNK_RUNDIR}/${var}_y${year}.nc
    done
done

ln -s $MODEL_PATH/nemo nemo
ln -s $MODEL_PATH/xios_server.exe xios_server.exe

## Using Victor's (in gitlab @vcorreal) slurm script
export nodes=${SLURM_JOB_NUM_NODES}
export NEMO_NODES=$((nodes - NEMO_IO_NODES))
export XIOS_NODES=$NEMO_IO_NODES
echo "info: Using $NEMO_NODES and $XIOS_NODES"

# CHECK NEMO AND XIOS GEOMETRY IS SET && GENERATE RANKFILE:
if [ -z "$NEMO_NODES" ] || [ -z "$XIOS_NODES" ]; then
    echo "Error: NEMO_NODES and XIOS_NODES must be set."
    exit 1
fi
export NEMO_TPN=$NEMO_TPN
export XIOS_TPN=$XIOS_TPN

export NEMO_TASKS=$(($NEMO_NODES * $NEMO_TPN))
export XIOS_TASKS=$(($XIOS_NODES * $XIOS_TPN))

export RF_NAME="rankfile_autogen_${SLURM_JOB_ID}"
source generate_rankfile.sh
rankfile_generation_intel_mpi

sleep 2

# LOAD ENV:
source env.sh
export SLURM_CPU_BIND=none
printenv &>env.log

# CHANGE LIMIT:
ulimit -s unlimited
ulimit -a unlimited

mpirun -machine $RF_NAME -print-rank-map -launcher slurm \
    -np $NEMO_TASKS ./nemo : -np $XIOS_TASKS ./xios_server.exe
