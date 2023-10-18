#####################################################
# In platforms where internet connection is not 
# available, we need to download raps dependencies
# in the local setup
# This function will be overwritten in platforms
# without internet access.
# Globals:
# Arguments:
# 
#####################################################

function pre-configuration-ifs(){
	true
}


#####################################################
# Function used as a default. Overloaded 
# by platform dependent functions in lib/HPCARCH
# Globals:
# Arguments:
# 
#####################################################
function pre-configuration-icon(){
  true
}

#####################################################
# Passes the SLURM variables onto variables used
# in hres for IFS-based models.
function load_variables_ifs() {
  export nodes=${SLURM_JOB_NUM_NODES}
  export mpi=${SLURM_NPROCS}
  export omp=${SLURM_CPUS_PER_TASK}

  export jobid=${SLURM_JOB_ID}
  export jobname=${SLURM_JOB_NAME}
}

#####################################################
# Default paths for the INPROOT and the PRECOMP_MODEL_PATH
# for all the models.
#
# Globals: HPC_MODEL_DIR, MODEL_VERSION, HPCARCH, ENVIRONMENT
# Arguments:
#
#####################################################
function load_inproot_precomp_path() {
  # If pre-compiled version used load specific input files and binaries
  # Otherwise load default input data
  if [ -z "${MODEL_VERSION}" ]; then
    # Default inidata
    export INPROOT=${HPC_MODEL_DIR}/inidata
  else
    export INPROOT=${HPC_MODEL_DIR}/${MODEL_VERSION}/inidata
    export PRECOMP_MODEL_PATH=${HPC_MODEL_DIR}/${MODEL_VERSION}/make/${HPCARCH,,}-${ENVIRONMENT}
  fi
}

