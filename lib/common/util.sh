# Functions to clone IFS or initialize the submodule. The cloning functions will still
# be supported for compatibility with ecFlow (it won't be able to `git init
# <submodule>`?)

# Cloning functions
# =================

function clone_ifs() {
  local SOURCE_NAME
  local OCEAN_MODEL

  SOURCE_NAME=$(basename ${MODEL_SOURCE} .git)
  # If the source code is not yet cloned, clone it
  if [ ! -d $SOURCE_NAME ]; then
    echo "Cloning IFS"
    git clone --depth 1 -b $MODEL_BRANCH $MODEL_SOURCE

    # Special actions for ocean components
    OCEAN_MODEL=${MODEL##*-}
    clone_${OCEAN_MODEL}
  else
    echo "Folder '${SOURCE_NAME}' already exists, not cloning"
  fi
}

function clone_fesom() {
  local BUILDING_FOLDER
  local FESOM_BUILD_SCRIPT
  local FESOM_VERSION
  local FESOM_COMMIT
  local FESOM_REPO
  local FESOM_MYROOT
  local FESOM_DIR

  # This is needed because MareNostrum does not support cloning from a remote repository, but RAPS tries to clone FESOM during building
  BUILDING_FOLDER=$( echo ${IFS_COMPILING_SCRIPT} | sed 's/[^.]*.//' )
  FESOM_BUILD_SCRIPT=${ROOTDIR}/proj/${PROJDEST}/ifs-source/flexbuild/external/${BUILDING_FOLDER}/build_fesom
  FESOM_VERSION=$(grep -m 1 vers ${FESOM_BUILD_SCRIPT} | sed 's/[^=]*=//g' | sed 's/#.*$//' | tr -d " ")
  FESOM_COMMIT=$(grep -m 1 commit ${FESOM_BUILD_SCRIPT} | sed 's/#.*$//' | sed 's/[^=]*=//g' | sed 's/#.*$//')
  FESOM_COMMIT=${FESOM_COMMIT:-$(grep -m 1 "git checkout " ${FESOM_BUILD_SCRIPT} | sed 's/[^-]*-//g' | sed 's/}.*$//' )}
  FESOM_REPO=$(grep -m 1 repo ${FESOM_BUILD_SCRIPT} | sed 's/[^=]*=//g' | sed 's/#.*$//' | sed 's/"//g')
  FESOM_MYROOT=${ROOTDIR}/proj/${PROJDEST}/ifs-source/flexbuild/external/src
  FESOM_DIR=${FESOM_MYROOT}/$(grep -m 1 fesomdir ${FESOM_BUILD_SCRIPT} | sed 's/[^\/]*\///g' | sed 's/#.*$//')
  if [ ! -d ${FESOM_DIR} ]; then
    echo "Cloning FESOM in ${FESOM_DIR}"
    git clone -b ${FESOM_VERSION} ${FESOM_REPO} ${FESOM_DIR}
    pushd ${FESOM_DIR}
    git checkout ${FESOM_COMMIT}
    popd
  else
    echo "Folder '${FESOM_DIR}' already exists, not cloning"
  fi
}

function clone_nemo() {
  true
}

#####################################################
# Clones ClimateDT branch from ICON model including 
# all the submodels the model uses
# Globals:
# Arguments:
# 
#####################################################
function clone_icon() {

  if [ ! -d icon-mpim ]; then
          echo "Cloning ICON-MPIM Model"
          git clone --recurse-submodules -b $MODEL_BRANCH $MODEL_SOURCE
  else
          echo "Folder icon-mpim already exists, not cloning"
  fi
}




function load_variables_ifs() {
  #export expver=${%CONFIGURATION.IFS.EXPVER%}
  #export label=${%CONFIGURATION.IFS.LABEL%}

  #export gtype=${%CONFIGURATION.IFS.GTYPE%}
  #export resol=${%CONFIGURATION.IFS.RESOL%}
  #export levels=${%CONFIGURATION.IFS.LEVELS%}

  export nodes=${SLURM_JOB_NUM_NODES}
  export mpi=${SLURM_NPROCS}
  export omp=${SLURM_CPUS_PER_TASK}

  export jobid=${SLURM_JOB_ID}
  export jobname=${SLURM_JOB_NAME}
}


function load_inproot_precomp_path() {
	export INPROOT=${HPC_MODEL_DIR}/inidata
	export PRECOMP_MODEL_PATH=${HPC_MODEL_DIR}/${MODEL_VERSION}/make/${HPCARCH}-${ENVIRONMENT}

}
