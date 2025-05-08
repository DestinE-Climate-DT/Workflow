#!/bin/bash

# Input data
ini_year=${1}
ini_month=${2}
ini_day=${3}
end_year=${4}
end_month=${5}
end_day=${6}
CURRENT_MRM_DIR=${7}
MRM_RESTART_DIR=${8}
MHM_OUTFILE=${9}
MRM_ARG_PATH=${10}
MRM_NETWORK_DIR=${11}
MRM_ID_GAUGES_FILE=${12}
STAT_FREQ=${13}
FORCINGS_DIR=${14}
NEXT_DATE=${15}
RESOLUTION=${16}

INI_DATE="${ini_year}_${ini_month}_${ini_day}"
END_DATE="${end_year}_${end_month}_${end_day}"

# setting up daily or hourly simulation
if [ "$STAT_FREQ" == "daily" ]; then
    time_step=24
    timestep_model_outputs_mrm=-1
elif [ "$STAT_FREQ" == "hourly" ]; then
    time_step=1
    timestep_model_outputs_mrm=1
fi

# Generate mrm nml content
cat - <<MRMPARALLEL >${CURRENT_MRM_DIR}/run_parallel_mrm.sh
#!/bin/bash
subdomain_id=\${1?The subdomain ID must be specified}
n_gauges=\${2?The number of gauges must be specified}
grdc_fpaths="\${3-:XXX}"
grdc_ids="\${4-:0}"

subdomain="subdomain_\${subdomain_id}"
restartFile="${MRM_RESTART_DIR}/\${subdomain}/${INI_DATE}_mRM_restart.nc"
networkFile="${MRM_NETWORK_DIR}/subdomain_river_network_\${subdomain_id}.nc"

    #  -- make workdir subdomains ----------------------
    mkdir -p ${CURRENT_MRM_DIR}/\${subdomain}

    #  -- link files -----------------------------------
    cd ${CURRENT_MRM_DIR}/\${subdomain}

    #  -- total runoff file ----------------------------
    mkdir -p input
    target_mhm_outfile=${MHM_OUTFILE}
    ln -fs \${target_mhm_outfile} input/total_runoff.nc

    #  -- morph files --------------------------------
    mkdir -p input/morph
    ln -fs \${networkFile} input/morph/river_network.nc
    ln -fs ${MRM_ID_GAUGES_DIR}/idgauges.asc input/morph/idgauges.asc # this is completely stupid but mRM will search for this file name

    #  -- meteo files --------------------------------
    mkdir -p input
    # linking input forcings
    ln -fs ${FORCINGS_DIR}/mHM_${INI_DATE}_to_${END_DATE}_pre.nc input/pre.nc
    ln -fs ${FORCINGS_DIR}/mHM_${INI_DATE}_to_${END_DATE}_pet.nc input/pet.nc
    mkdir -p input/restart
    cd input/restart
    ln -fs \${restartFile}
    cd -
    mkdir -p output

    #  -- set eval variables for namelist -------------
    ystart=${ini_year}
    yend=${end_year}
    mstart=${ini_month}
    mend=${end_month}
    dstart=${ini_day}
    dend=${end_day}

    #  -- make mrm nam -----------------------------
    cat > ${CURRENT_MRM_DIR}/\${subdomain}/mrm.nml << MRMNML
&directories_general
    dir_lcover = '../data/input/test_domain/input/'
    dir_morpho = 'input/morph/river_network.nc'
    dir_out = 'output/'
    dircommonfiles = 'output/'
    dirconfigout = 'output/'
    file_latlon = '\${networkFile}'
    mhm_file_restartout = 'output/mHM_restart_001.nc'
    mrm_file_restartout = 'output/mRM_restart_${NEXT_DATE}.nc'
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
    mrm_file_restartin = 'input/restart/${INI_DATE}_mRM_restart.nc'
    opti_function = 3
    opti_method = 1
    optimize = .FALSE.
    optimize_restart = .FALSE.
    read_restart = True
    resolution_routing = ${RESOLUTION}
    timestep = ${time_step}
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
    mhm_details = 'Helmholtz Center for Environmental Research - UFZ, Department Computational Hydrosystems'
    project_details = 'Climate DT project'
    setup_description = 'model run for Climate DT project'
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

    cat > ${CURRENT_MRM_DIR}/\${subdomain}/mrm_outputs.nml << MRMOUTPUT
&nloutputresults
    outputflxstate_mrm = .True.
    timestep_model_outputs_mrm = ${timestep_model_outputs_mrm}
/
MRMOUTPUT

    cat > ${CURRENT_MRM_DIR}/\${subdomain}/mrm_parameter.nml << MRMPARAMETER
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

  time mrm > mrm_${INI_DATE}_to_${END_DATE}.log 2>&1

MRMPARALLEL
