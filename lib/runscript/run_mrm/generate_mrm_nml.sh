#!/bin/bash

# Input data
start_year=${1}
start_month=${2}
start_day=${3}
end_year=${4}
end_month=${5}
end_day=${6}
WORK_DIR=${7}
RESTART_DIR=${8}
HM_WORK=${9}
HM_OUTFILE=${10}
MRM_METEO_INPUT=${11}
MRM_EXE=${12}
MRM_ARG_PATH=${13}
MRM_NETWORK_DIR=${14}
MRM_ID_GAUGES_FILE=${15}

# Generate mrm nml content
cat - <<MRMPARALLEL >${WORK_DIR}/run_parallel_mrm.sh
#!/bin/bash
#set -e
#set -u
#set -x
subdomain_id=\${1?The subdomain ID must be specified}
n_gauges=\${2?The number of gauges must be specified}
grdc_fpaths="\${3-:XXX}"
grdc_ids="\${4-:0}"

subdomain="subdomain_\${subdomain_id}"
restartFile="${RESTART_DIR}/\${subdomain}/mRM_restart_001.nc" 
networkFile="${MRM_NETWORK_DIR}/subdomain_river_network_\${subdomain_id}.nc"

    #  -- make workdir ---------------------------------
    mkdir -p ${WORK_DIR}/\${subdomain}

    #  -- link files -----------------------------------
    cd ${WORK_DIR}/\${subdomain}

    #  -- total runoff file --------------------------
    mkdir -p input/total_runoff
    target_hm_outfile=${HM_WORK}/${HM_OUTFILE}
    if [ ! -f \${target_hm_outfile} ]; then
        echo '***ERROR: unknown file ${HM_OUTFILE}, cannot run mrm'
        exit 1
    fi
    if [[ '${MRM_FLIP_INPUT}' == 'yes' ]]; then
        ncpdq -O -a -northing \${target_hm_outfile} input/total_runoff.nc
    else
        ln -fs \${target_hm_outfile} input/total_runoff.nc
    fi

    #  -- morph files --------------------------------
    mkdir -p input/morph
    ln -fs \${networkFile} input/morph/river_network.nc
    ln -fs ${MRM_ID_GAUGES_FILE} input/morph/river_network.ncidgauges.asc # this is completely stupid but mRM will search for this file name

    #  -- meteo files --------------------------------
    mkdir -p input/meteo
    ln -fs ${MRM_METEO_INPUT}/pre.nc input/pre.nc
    ln -fs ${MRM_METEO_INPUT}/pet.nc input/pet.nc
    mkdir -p input/restart
    cd input/restart
    ln -fs \${restartFile}
    cd -
    mkdir -p output
    ln -fs ${MRM_EXE} ./mrm

    #  -- set eval variables for namelist -------------
    ystart=${start_year}
    yend=${end_year}
    mstart=${start_month}
    mend=${end_month}
    dstart=${start_day}
    dend=${end_day}

    #  -- make mrm nam -----------------------------
    cat > ${WORK_DIR}/\${subdomain}/mrm.nml << MRMNML
&directories_general
    dir_lcover = '../data/input/test_domain/input/'
    dir_morpho = 'input/morph/river_network.nc'
    dir_out = 'output/'
    dircommonfiles = 'output/'
    dirconfigout = 'output/'
    file_latlon = '\${networkFile}'
    mhm_file_restartout = 'output/mHM_restart_001.nc'
    mrm_file_restartout = 'output/mRM_restart_001.nc'
/

&directories_mrm
    dir_bankfull_runoff = 'test_basin/input/optional_data/'
    dir_gauges = ''
    dir_total_runoff = 'input/'
/

&evaluation_gauges
    gauge_filename(1,:) = \${grdc_fpaths}
    gauge_id(1,:) = \${grdc_ids}
    ngaugestotal = \${n_gauges}
    nogauges_domain = \${n_gauges}
/

&inflow_gauges
    inflowgauge_filename(1,:) = ''
    inflowgauge_headwater = .FALSE.
    inflowgauge_id = -9
    ninflowgaugestotal = 0
    noinflowgauges_domain = 0
/

&lcover
    lcoveryearend = 2100
    lcoveryearstart = 1900
    lcoverfname = 'XXX'
    nlcoverscene = 1
/

&mainconfig
    iflag_cordinate_sys = 1
    l0domain = 1
    ndomains = 1
    read_opt_domain_data = 0
    resolution_hydrology = 0.1
    write_restart = .TRUE.
/

&mainconfig_mhm_mrm
    mrm_file_restartin = 'input/restart/mRM_restart_001.nc'
    opti_function = 3
    opti_method = 1
    optimize = .FALSE.
    optimize_restart = .FALSE.
    read_restart = True
    resolution_routing = 0.1
    timestep = 24
/

&mainconfig_mrm
    alma_convention = .FALSE.
    filenamepetrunoff = 'pet'
    filenameprerunoff = 'pre'
    filenametotalrunoff = 'total_runoff'
    gw_coupling = .FALSE.
    varnamepetrunoff = 'pet'
    varnameprerunoff = 'pre'
    varnametotalrunoff = 'Q'
/

&optimization
    dds_r = 0.2
    mcmc_error_params = 0.01,
                        0.6
    mcmc_opti = .FALSE.
    niterations = 7
    sa_temp = -9.0
    sce_ngs = 2
    sce_npg = -9
    sce_nps = -9
    seed = 1235876
/

&optional_data
    dir_evapotranspiration = 'test_basin/input/optional_data/'
    dir_neutrons = 'test_basin/input/optional_data/'
    dir_soil_moisture = 'test_basin/input/optional_data/'
    file_tws = 'test_basin/input/optional_data/tws_basin_1.txt'
    nsoilhorizons_sm_input = 1
    timestep_et_input = -2
    timestep_sm_input = -2
/

&processselection
    processcase = 1, 1,
                1, 1,
                0, 1,
                1, 2,
                1, 0
/

&project_description
    contact = 'Stephan Thober (email: stephan.thober@ufz.de'
    conventions = 'tbd'
    history = ''
    mhm_details = 'Helmholtz Center for Environmental Research - UFZ, Department Computational Hydrosystems, Stochastic Hydrology Group'
    project_details = 'DestinE project'
    setup_description = 'model run for DestinE project'
    simulation_type = 'simulation'
/

&time_periods
    eval_per%dend = \${dend}
    eval_per%dstart = \${dstart}
    eval_per%mend = \${mend}
    eval_per%mstart = \${mstart}
    eval_per%yend = \${yend}
    eval_per%ystart = \${ystart}
    warming_days = 0
/
MRMNML

    cat > ${WORK_DIR}/\${subdomain}/mrm_outputs.nml << MRMOUTPUT
&nloutputresults
    outputflxstate_mrm = .True.
    timestep_model_outputs_mrm = -1
/
MRMOUTPUT

    cat > ${WORK_DIR}/\${subdomain}/mrm_parameter.nml << MRMPARAMETER
&routing1
    muskingumattenuation_riverslope = 0.01, 0.5, 0.3, 1.0, 1.0
    muskingumtraveltime_constant = 0.31, 0.35, 0.325, 1.0, 1.0
    muskingumtraveltime_impervious = 0.09, 0.11, 0.1, 1.0, 1.0
    muskingumtraveltime_riverlength = 0.07, 0.08, 0.075, 1.0, 1.0
    muskingumtraveltime_riverslope = 1.95, 2.1, 2.0, 1.0, 1.0
/

&routing2
    streamflow_celerity = 0.1, 15.0, 1.5, 0.0, 1.0
/

&routing3
    g1 = 0.1, 100.0, 30.0, 0.0, 1.0
    g2 = 0.1, 0.9, 0.6, 0.0, 1.0
/
MRMPARAMETER

  cd ${WORK_DIR}/\${subdomain}
  time ./mrm > mrm.log 2>&1
  
MRMPARALLEL
