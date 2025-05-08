#!/bin/bash

# HEADER

HPCROOTDIR=%HPCROOTDIR%
START_DATE=%CHUNK_START_DATE%
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
SDATE=${14:-%SDATE%}
MODEL_NAME=${15:-%MODEL.NAME%}
PU=${16:-%RUN.PROCESSOR_UNIT%}
CHUNK_START_YEAR=${17:-%CHUNK_START_YEAR%}
CHUNK_END_YEAR=${18:-%CHUNK_END_YEAR%}
LIBDIR=${19:-%CONFIGURATION.LIBDIR%}
SCRIPTDIR=${20:-%CONFIGURATION.SCRIPTDIR%}

# END_HEADER

SDATE=${SDATE}00

set -xuve

###################################################
# Checking, before the actual model run, if there
# was a previous directory with the same chunk number
# (so the same runlength and jobname) in the wrapper
# (same jobid), and in case it exists, renaming
# it with the RETRIAL number.
####################################################

function check_rundir_name() {
    jobname=$SLURM_JOB_NAME
    jobid=$SLURM_JOB_ID

    rundir=$(find "${HPCROOTDIR}" -type d -name "${CHUNK_RUNDIR}" -print -quit)

    if [ -z ${rundir} ]; then
        echo "Rundir variable is empty. No previous rundir found. "
    else
        echo "Previous rundir found. This is a retrial inside a wrapper"
        echo "The previous rundir was: ${rundir}"

    fi

    if [ -d "$rundir" ]; then
        retrial_number=0
        for i in $(seq 0 $TOTAL_RETRIALS); do
            if [ -d ${rundir}.$i ]; then
                echo "Found the $i attempt to run this chunk inside the wrapper"
                retrial_number=$((i + 1))
            fi
        done
        mv $rundir ${rundir}.$retrial_number
        echo "The previous rundir: ${rundir} has been renamed"
        echo "It can be found in: ${rundir}.${retrial_number}"
    fi
}

CHUNK_RUNDIR="$HPCROOTDIR/rundir/${START_DATE}-${END_DATE}-${SLURM_JOB_ID}"
RESTART_DIR="$HPCROOTDIR/restarts"
CHUNK_RESTART_DIR="${RESTART_DIR}/${CHUNK}"
CHUNK_NEXT_RESTART_DIR="${RESTART_DIR}/$(($CHUNK + 1))"

HPC=$(echo "${CURRENT_ARCH}" | cut -d- -f1)

# Source libraries
. "${LIBDIR}"/"${HPC}"/config.sh
. "${LIBDIR}"/common/util.sh

INSTALL_DIR="${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}"

check_rundir_name

mkdir -p $CHUNK_RUNDIR
mkdir -p $CHUNK_RESTART_DIR
mkdir -p $CHUNK_NEXT_RESTART_DIR

cd $CHUNK_RUNDIR

INIDIR="$HPCROOTDIR/inipath/$MEMBER/nemo/V40/$OCEAN_GRID"

ICDIR="$INIDIR/$SDATE"
COMMONDIR="$INIDIR/common"
XIOSDIR="$INIDIR/xios"
FORCINGDIR="$HPCROOTDIR/inipath/$MEMBER/nemo_forcing"

load_compile_env_"${MODEL_NAME,,}"_"${PU}"

#ENVFILE=$HPCROOTDIR/$PROJDEST/nemo/arch/arch-${ARCH_NAME}.fcm

cp -s $ICDIR/* $CHUNK_RUNDIR
cp -s $COMMONDIR/* $CHUNK_RUNDIR
cp -s $XIOSDIR/* $CHUNK_RUNDIR

#ln -s $ENVFILE $CHUNK_RUNDIR/env.sh

#### GENERATE PATCH

# Read the value of rn_rdt from namelist_cfg
rn_rdt=$(grep "rn_rdt" $CHUNK_RUNDIR/namelist_cfg | cut -d= -f2)

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

#### APPLY DATE PATCH
#for namelist in namelist_cfg namelist_ice_cfg; do #add a list? in a configuration file?
#    python3 $SCRIPTDIR/nemo/mod_namelists.py -n "${CHUNK_RUNDIR}/${namelist}" -p "${CHUNK_RUNDIR}/${namelist}_patch_$CHUNK"
#done

# lib/LUMI/config.sh (load_environment_namelists) (auto generated comment)
# lib/MARENOSTRUM5/config.sh (load_environment_namelists) (auto generated comment)
load_environment_namelists

python3 $SCRIPTDIR/namelists/mod_namelists.py -n "${CHUNK_RUNDIR}/namelist_cfg" -p "${CHUNK_RUNDIR}/namelist_cfg_patch_$CHUNK"
mv "${CHUNK_RUNDIR}/namelist_cfg_mod" "${CHUNK_RUNDIR}/namelist_cfg"
python3 $SCRIPTDIR/namelists/mod_namelists.py -n "${CHUNK_RUNDIR}/namelist_ice_cfg" -p "${CHUNK_RUNDIR}/namelist_ice_cfg_patch_$CHUNK"
mv "${CHUNK_RUNDIR}/namelist_ice_cfg_mod" "${CHUNK_RUNDIR}/namelist_ice_cfg"

# Replace OCEAN_GRID with the desired shortcut
OCEAN_GRID_SHORT=$(echo "$OCEAN_GRID" | sed 's/_.*//' | sed 's/eORCA1/eO1/; s/eORCA12/eO12/; s/eORCA025/eO25/')

YYYY="${SDATE:0:4}"

for var in precip q10 qlw qsw slp snow t10 u10 v10; do
    for ((year = YYYY; year < CHUNK_END_YEAR; year++)); do
        ln -s ${FORCINGDIR}/${var}_fc00_ERA5_HRES_${OCEAN_GRID_SHORT}_${year}.nc ${CHUNK_RUNDIR}/${var}_y${year}.nc
    done
done

#. env.sh
## Is this binary ok?
ln -s ${INSTALL_DIR}/cfgs/ORCA2/BLD/bin/nemo.exe nemo
srun ./nemo
