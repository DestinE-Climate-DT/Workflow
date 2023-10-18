#/bin/bash
#

set -xuve

# Interface
HPCROOTDIR=%HPCROOTDIR%
PROJDEST=%PROJECT.PROJECT_DESTINATION%
CURRENT_ARCH=${3:-%CURRENT_ARCH%}
CHUNKSIZE=${4:-%EXPERIMENT.CHUNKSIZE%}
CHUNKSIZEUNIT=${5:-%EXPERIMENT.CHUNKSIZEUNIT%}
MODEL_NAME=${6:-%RUN.MODEL%}
ENVIRONMENT=${7:-%RUN.ENVIRONMENT%}
HPCARCH=${8:-%HPCARCH%}
MODEL_VERSION=${9:-%RUN.MODEL_VERSION%}
OCEAN_GRID=${10:-%RUN.GRID_OCEAN%}
EXPID=${11:-%DEFAULT.EXPID%}
ATM_GRID=${12:-%RUN.GRID_ATM%}
CHUNK=${13:-%CHUNK%}
TOTAL_RETRIALS=${14:-%CONFIG.RETRIALS%}
ICMCL=${15:-ICMCL_%CONFIGURATION.IFS.RESOL%_%CHUNK_START_YEAR%_extra}
START_DATE=${16:-%CHUNK_START_DATE%}
END_DATE=${17:-%CHUNK_END_DATE%}
END_IN_DAYS=${18:-%CHUNK_END_IN_DAYS%}
PREV=${19:-%PREV%}
RUN_DAYS=${20:-%RUN_DAYS%}
NEMO_XPROC=${21:-%CONFIGURATION.NEMO.NEMO_XPROC%}
NEMO_YPROC=${22:-%CONFIGURATION.NEMO.NEMO_YPROC%}
IO_TASKS=${23:-%CONFIGURATION.IFS.IO_TASKS%}
ATM_MODEL=${MODEL_NAME%%-*}
MULTIO_ATM_PLANS=%CONFIGURATION.IFS.MULTIO_PLANS%
MULTIO_OCEAN_PLANS=%CONFIGURATION.NEMO.MULTIO_PLANS%
PU=%RUN.PROCESSOR_UNIT%
RAPS_USER_FLAGS=%CONFIGURATION.RAPS_USER_FLAGS%

LIBDIR="${HPCROOTDIR}"/"${PROJDEST}"/lib
HPC=$( echo "${CURRENT_ARCH}" | cut -d- -f1 )

# Source libraries
. "${LIBDIR}"/common/util.sh
. "${LIBDIR}"/"${HPC}"/config.sh

export MODEL_VERSION
export ENVIRONMENT
export HPCARCH

load_model_dir
load_inproot_precomp_path

# Directory definition
if [ -z "${MODEL_VERSION}" ]; then
    RAPS_BIN=${HPCROOTDIR}/${PROJDEST}/raps/bin
else
    RAPS_BIN=${PRECOMP_MODEL_PATH}/RAPS_DE340/bin
fi

OUTROOT=${HPCROOTDIR}/rundir
PRE_RESTART_DIR=${HPCROOTDIR}/restarts
RESTART_DIR=${PRE_RESTART_DIR}/current

mkdir -p ${PRE_RESTART_DIR}
cd ${PRE_RESTART_DIR}
mkdir -p "${CHUNK}"
rm -f current
ln -s "${CHUNK}" current
cd current

#waminfo, rcf, nemorcf backups
if [ -f "waminfo" ]; then
        cp "waminfo" "waminfo-backup"
fi

if [ -f "rcf" ]; then
        cp "rcf" "rcf-backup"
fi

if [ -f "nemorcf" ]; then
        cp "nemorcf" "nemorcf-backup"
fi

if [ -f "nemorcf.${START_DATE}_000000" ]; then
        cp "nemorcf.${START_DATE}_000000" "nemorcf.${START_DATE}-backup"
fi

export INPROOT=${INPROOT}
export OUTROOT=${OUTROOT}

if [ -z "${MODEL_VERSION}" ]; then
    BUNDLE_BUILD_DIR=${HPCROOTDIR}/${PROJDEST}/${MODEL_NAME}/build
else
    BUNDLE_BUILD_DIR=${PRECOMP_MODEL_PATH}/build
fi

export BUNDLE_BUILD_DIR
export PATH=${RAPS_BIN}:$PATH

export MULTIO_RAPS_PLANS_PATH=${RAPS_BIN}/../multio_yaml

if [ ! -z $MULTIO_ATM_PLANS ]; then
	export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config-${MULTIO_ATM_PLANS}.yaml
else 
	export MULTIO_IFSIO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ifsio-config.yaml
fi

if [ ! -z $MULTIO_OCEAN_PLANS ]; then
	export MULTIO_NEMO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ocean-client-skeleton-${MULTIO_OCEAN_PLANS}.yaml
else
	export MULTIO_NEMO_CONFIG_FILE=${MULTIO_RAPS_PLANS_PATH}/multio-ocean-client-skeleton.yaml
fi

export fdb_dir=${HPCROOTDIR}/fdb


#####################################################
# Sets experiment dependent variables for RAPS
# Globals:
#	IO_NODES
#	SLURM_CPUS_ON_NODE
#	SLURM_CPUS_PER_TASK
#	CHUNKSIZEUNIT
# Arguments:
#  
######################################################
function load_experiment_ifs(){

	export expver=%CONFIGURATION.IFS.EXPVER%
	export label=%CONFIGURATION.IFS.LABEL%

	export gtype=%CONFIGURATION.IFS.GTYPE%
	export resol=%CONFIGURATION.IFS.RESOL%
	export levels=%CONFIGURATION.IFS.LEVELS%

	SDATE=%SDATE%
	yyyymmdd=${SDATE::8}
	export yyyymmddzz=${yyyymmdd}00

	IO_NODES=%CONFIGURATION.IFS.IO_NODES%
	
	if [ -z ${IO_TASKS} ]; then
        	IO_TASKS=$(( ${IO_NODES} * ${SLURM_CPUS_ON_NODE} / ${SLURM_CPUS_PER_TASK} / 2 ))
	fi


	# compute fclen

	if [ "${CHUNKSIZEUNIT}" == "month" ] || [ "${CHUNKSIZEUNIT}" == "year" ] ; then
		runlength=%CHUNK_END_IN_DAYS%	
		CHUNKSIZEUNIT=day
	else
		runlength=$((%CHUNK%*${CHUNKSIZE}))
	fi
	fclen=${CHUNKSIZEUNIT:0:1}${runlength}


	load_variables_"${ATM_MODEL}"

}


#####################################################
# Runs an hres simulation
# Globals:
#	RAPS_BIN
#	bin_hpc_name
#	BUNDLE_BUILD_DIR
#	ICMCL
#	OCEAN_GRID
#	nemox
#	nemoy
#	IO_TASKS
#	PREV
#	RUN_DAYS
#	EXPID
#	RESTART_DIR
#	fdb_dir
#	nproma
#	depth
#	ht
#	RAPS_ROOTDIR
# Arguments:
######################################################



function run_experiment_ifs(){

	cd ${RAPS_BIN}/SLURM/${bin_hpc_name}

	other="--ifs-bundle-build-dir=$BUNDLE_BUILD_DIR --icmcl ${ICMCL} -R --nemo --nemo-ver=V40 --nemo-grid=${OCEAN_GRID} --nemo-xproc=${nemox} --nemo-yproc=${nemoy} --deep --keepfdb --iotasks=${IO_TASKS} --nonemopart --keepnetcdf --nextgemsout=6 --wam-multio --ifs-multio --nemo-multio-server-num=${IO_TASKS} --outexp=${EXPID} --restartdirectory=${RESTART_DIR} --fdbdirectory=${fdb_dir} --keeprestart $RAPS_USER_FLAGS"

	export other

	set +e
	source ../../../.again
	set -e

	# Run the RAPS script

	set -eux

	ifsMASTER=""

	nproma=${nproma:-16}
	depth=${depth:-$omp}
	ht=${ht:-$(htset.pl "$SLURM_NTASKS_PER_NODE" "$SLURM_CPUS_PER_TASK")}

	export FDB5_CONFIG_FILE=${RAPS_ROOTDIR}/fdb5/config.yaml

	echo "Model run starts"

	hres \
    	-p "$mpi" -t "$omp" -h "$ht" \
    	-j "$jobid" -J "$jobname" \
    	-d "$yyyymmddzz" -e "$expver" -L "$label" \
    	-T "$gtype" -r "$resol" -l "$levels" -f "$fclen" \
    	-x "$ifsMASTER" \
    	-N "$nproma" \
    	-H "$host" -n "$nodes" -C "$compiler" ${other:-}

}


load_SIM_env_"${ATM_MODEL}"_"${PU}"
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

	rundir=$(find "${HPCROOTDIR}" -type d -name "h$(($runlength*24))*${jobname}-${jobid}" -print -quit)

	if [ -z ${rundir} ]; then
        	echo "Rundir variable is empty. No previous rundir found. "
	else
        	echo "Previous rundir found. This is a retrial inside a wrapper"
        	echo "The previous rundir was: ${rundir}"

	fi

	if [ -d "$rundir" ]; then
        	retrial_number=0
        	for i in $(seq 0 $TOTAL_RETRIALS)
        	do
                	if [ -d ${rundir}.$i ]; then
                        	echo "Found the $i attempt to run this chunk inside the wrapper"
                        	retrial_number=$(( i + 1 ))
                	fi
        	done
        	mv $rundir ${rundir}.$retrial_number
        	echo "The previous rundir: ${rundir} has been renamed"
        	echo "It can be found in: ${rundir}.${retrial_number}"
	fi
}


#################################################
# Indentifying the new restart files generated
# and moving them to the next chunk's folder
# in order to use them in the following
# chunk.
################################################
function restarts_moving() {

	cd ${PRE_RESTART_DIR}

	SDATE=%SDATE%
	SDATE_LONG=%SDATE%000000
	CHUNK_END_IN_DAYS=%CHUNK_END_IN_DAYS%

	formatted_days=$(printf "%06d" "$CHUNK_END_IN_DAYS")0000

	CHUNK_END_IN_DAYS_1=$((CHUNK_END_IN_DAYS - 1))
	formatted_days_1=$(printf "%06d" "$CHUNK_END_IN_DAYS_1")

	mkdir -p $((CHUNK + 1))/

	mv $CHUNK/"LAW${SDATE_LONG}_${formatted_days_1}"* $((CHUNK + 1))/
	mv $CHUNK/"srf${formatted_days}"* $((CHUNK + 1))/
	mv $CHUNK/"BLS"${SDATE_LONG}_${formatted_days_1}* $((CHUNK + 1))/
	mv $CHUNK/"${EXPID}_%CHUNK_END_DATE%"* $((CHUNK + 1))/


	mv $CHUNK/waminfo $((CHUNK + 1))/
	mv $CHUNK/rcf $((CHUNK + 1))/
	mv $CHUNK/nemorcf $((CHUNK + 1))/
	mv $CHUNK/nemorcf.%CHUNK_END_DATE%* $((CHUNK + 1))/
	sed -i "s#${PRE_RESTART_DIR}/${CHUNK}#${PRE_RESTART_DIR}/$(( CHUNK + 1 ))#" ${RESTART_DIR}/../$(( CHUNK + 1 ))/nemorcf


	if [ -f "$CHUNK/nemorcf-backup" ]; then
        	mv $CHUNK/"nemorcf-backup" "$CHUNK/nemorcf"
	fi

	if [ -f "$CHUNK/rcf-backup" ]; then
        	mv $CHUNK/"rcf-backup" "$CHUNK/rcf"
	fi

	if [ -f "$CHUNK/waminfo-backup" ]; then
        	mv $CHUNK/"waminfo-backup" "$CHUNK/waminfo"
	fi

	if [ -f "$CHUNK/nemorcf.${START_DATE}-backup" ]; then
		mv $CHUNK/"nemorcf.${START_DATE}-backup" "$CHUNK/nemorcf.${START_DATE}_000000"
	fi

	rm -rf current

}

load_experiment_"${ATM_MODEL}"

check_rundir_name

total_number_of_ifs_procs=$(( (${SLURM_JOB_NUM_NODES} - ${IO_NODES}) * ${SLURM_CPUS_ON_NODE} / ${SLURM_CPUS_PER_TASK} ))

nemox=-1
nemoy=-1

export LD_LIBRARY_PATH=$BUNDLE_BUILD_DIR/ifs_sp:$LD_LIBRARY_PATH

run_experiment_"${ATM_MODEL}"


echo "The model ran successfully."
echo "Moving the restart files to the next chunk folder to use them in the following chunk"

restarts_moving
