#!/bin/bash

# Passing arguments needed
out_dir=${1}

# Create the mhm.nml file
cat <</MHM_NML >"${out_dir}/mhm.nml"
!> \file mhm.nml
!> \brief General Namelists of mHM, MPR, mRM.
!> \details This files provides all namelists for mHM, MPR, mRM.
!> \authors Matthias Zink, Matthias Cuntz
!> \date Jan 2013
! Modified,
! Rohini Kumar,            Aug 2013  - added "fracSealed_cityArea" in the LCover namelist
!                                    - added new namelist "LAI_data_information"
!                                    - added new directory paths for soil and geology LUTs
!                                      which are common to all modeled domains
! Luis Samaniego,          Nov 2013  - process description
! Matthias  Zink,          Mar 2014  - added evaluation and inflow gauge namelists
! Rohini Kumar,            May 2014  - options for different cordinate system for the model run
! Stephan Thober,          May 2014  - added switch for chunk read in
! Stephan Thober,          Jun 2014  - reorganized restart flags, added flag for performing mpr
! Kumar R., Rakovec O.     Sep 2014  - added KGE estimator (OF number 9)
! Matthias Zink,           Nov 2014  - added multiple options for process 5 - PET
! Matthias Zink,           Dec 2014  - adopted inflow gauges to ignore headwater cells
! Matthias Zink,           Mar 2015  - added optional soil mositure read in for calibration
! Stephan Thober,          Nov 2016  - added adaptive timestep scheme for routing
! Rohini  Kumar,           Dec 2017  - added LAI option to read long term mean monthly fields
! Zink M. Demirel M.C.,    Mar 2017  - added Jarvis soil water stress function at SM process(3)=2
! Demirel M.C., Stisen S., May 2017  - added FC dependency on root fraction coef. at SM process(3)=3
! Demirel M.C., Stisen S., Jun 2017  - added PET correction based on LAI at PET process(5)=-1
! O. Rakovec, R. Kumar     Nov 2017  - added project description for the netcdf outputs
! Robert Schweppe          Apr 2018  - reorganized namelists depending on relation to processes (MPR, mHM, mRM)
! S. Thober, B. Guse       May 2018  - added weighted NSE
! Lennart Schueler         May 2018  - added new paths for bankfull discharge for gw coupling
! Lennart Schueler         Jun 2018  - added flag for writing river head output
! Stephan Thober           May 2019  - added adaptive timestep scheme for routing with varying celerity
! Demirel M.C., Stisen S., Jun 2020  - added Feddes and global FC dependency on root fraction coef. at SM process(3)=4

!******************************************************************************************
! PROJECT DESCRIPTION (mandatory)
!******************************************************************************************
!-----------------------------------------------------------------------------
!> Provide details on the model simulations, to appear in the netcdf output attributes
!-----------------------------------------------------------------------------
&project_description
!> project name
project_details="mHM Levatnte run 2005"
!> any specific description of simulation
setup_description="global model run - 5 days data"
!> e.g. hindcast simulation, seasonal forecast, climate projection
simulation_type="historical simulation"
!> convention used for dataset
Conventions="XXX"
!> contact details, incl. PI name, modellers
contact="mHM developers (email:mhm-developers@ufz.de)"
!> developing institution, specific mHM revision, latest release version (automatically included)
mHM_details="Helmholtz Center for Environmental Research - UFZ, Department Computational Hydrosystems, Stochastic Hydrology Group"
!> some details on data/model run version (creation date is included automatically)
history="model run version 1"
/

!******************************************************************************************
!
!******************************************************************************************
! MAIN (mandatory)
!******************************************************************************************
!> Main namelist
!> Most of the variables (if not all) given in this namelist are common
!> to all domains to be modeled.
&mainconfig
!-----------------------------------------------------------------------------
!> input data & model run cordinate system
!> 0 -> regular   X & Y   coordinate system (e.g., GK-4 or Lambert equal area system)
!> 1 -> regular lat & lon coordinate system
!-----------------------------------------------------------------------------
iFlag_cordinate_sys = 1
!-----------------------------------------------------------------------------
!> Number of domains to be modeled.
!> Number given here should correspond to one given in "gaugeinfo.txt" file.
!> All gauging stations within those domains will be taken for the optimization.
!> IF routing process is ON then give nDomains = 1, for this case, mHM will internally
!> discard gauging station information.
!-----------------------------------------------------------------------------
nDomains             = 1
!-----------------------------------------------------------------------------
!> resolution of Level-1 hydrological simulations in mHM [m or degree] per domain
!> NOTE: if iFlag_cordinate_sys = 0, then resolution_Hydrology is in [m]
!>       if iFlag_cordinate_sys = 1, then resolution_Hydrology is in [degree-decimal]
!-----------------------------------------------------------------------------
resolution_Hydrology(1) = 0.1
!----------------------------------------------------------------------------
!> specify same index for domains to share L0_data to save memory
!> the index must MONOTONICALLY increase. Index can be repeated. e.g., 1,1,2,2,3
!> but not 1,2,1. The correct way should be: 1,1,2.
!-----------------------------------------------------------------------------
L0Domain(1) = 1
!-----------------------------------------------------------------------------
!> flag for writing restart output
!-----------------------------------------------------------------------------
write_restart = .TRUE.
!-----------------------------------------------------------------------------
!> read domain specific optional data
!-----------------------------------------------------------------------------
!> (0) default: the program decides. If you are confused, choose 0
!> (1) runoff
!> (2) sm
!> (3) tws
!> (4) neutons
!> (5) et
!> (6) et & tws
read_opt_domain_data(1) = 0
/

!******************************************************************************************
! main config for mHM and mRM (mHM and mRM-related)
!******************************************************************************************
&mainconfig_mhm_mrm
!-----------------------------------------------------------------------------
! DIRECTORIES
!-----------------------------------------------------------------------------
!> Number in brackets indicates domain number.
!> directory where restart input is located
mhm_file_RestartIn(1)     = "input/restart/mHM_restart_001.nc"
mrm_file_RestartIn(1)     = "input/restart/mRM_restart_001.nc"
!-----------------------------------------------------------------------------
!> resolution of Level-11 discharge routing [m or degree] per domain
!> this  level-11 discharge routing resolution must be >= and multiple of the
!> level-1 hydrological simulations resolution
!> NOTE: if iFlag_cordinate_sys = 0, then resolution_Routing is in [m]
!>       if iFlag_cordinate_sys = 1, then resolution_Routing is in [degree-decimal]
!-----------------------------------------------------------------------------
resolution_Routing(1) = 0.1
!-----------------------------------------------------------------------------
!> model run timestep [h] either 1 or 24
!-----------------------------------------------------------------------------
timestep = 1
!-----------------------------------------------------------------------------
!> flags for reading restart output
!> mrm_read_river_network is an optional flag
!> mrm_read_river_network = .True. allows to read the river network for mRM
!> read_restart = .True. forces mrm_read_river_network = .True.
!> read_old_style_restart_bounds = .True. if you want to use an old-style restart file created by mhm<=v5.11
!-----------------------------------------------------------------------------
read_restart  = .True.
mrm_read_river_network = .False.
read_old_style_restart_bounds = .False.
!----------------------------------------------------------------------------
!> flag for optimization: .TRUE.: optimization
!>                    or .FALSE.: no optimazition
!-----------------------------------------------------------------------------
optimize = .FALSE.
!> Optimization shall be restarted from ./mo_<opti_method>.restart file, which
!> should be located next to the mhm executable (mhm)
optimize_restart = .FALSE.
!> (0) MCMC                (requires single-objective (SO) function)
!> (1) DDS                 (requires single-objective (SO) function)
!> (2) Simulated Annealing (requires single-objective (SO) function)
!> (3) SCE                 (requires single-objective (SO) function)
!> additional settings for the different methods can be provided below in namelist Optimization
opti_method = 1
!> (1)  SO: Q:   1.0 - NSE
!> (2)  SO: Q:   1.0 - lnNSE
!> (3)  SO: Q:   1.0 - 0.5*(NSE+lnNSE)
!> (4)  SO: Q:  -1.0 * loglikelihood with trend removed from absolute errors and then lag(1)-autocorrelation removed
!> (5)  SO: Q:   ((1-NSE)**6+(1-lnNSE)**6)**(1/6)
!> (6)  SO: Q:   SSE
!> (7)  SO: Q:  -1.0 * loglikelihood with trend removed from absolute errors
!> (8)  SO: Q:  -1.0 * loglikelihood with trend removed from the relative errors and then lag(1)-autocorrelation removed
!> (9)  SO: Q:  1.0 - KGE (Kling-Gupta efficiency measure)
!> (10) SO: SM: 1.0 - KGE of catchment average soilmoisture
!> (11) SO: SM: 1.0 - Pattern dissimilarity (PD) of spatially distributed soil moisture
!> (12) SO: SM: Sum of squared errors (SSE) of spatially distributed standard score (normalization) of soil moisture
!> (13) SO: SM: 1.0 - average temporal correlation of spatially distributed soil moisture
!> (14) SO: Q:  sum[((1.0-KGE_i)/ nGauges)**6]**(1/6) > combination of KGE of every gauging station based on a power-6 norm
!> (15) SO: Q + domain_avg_TWS: [1.0-KGE(Q)]*RMSE(domain_avg_TWS) - objective function using Q and domain average (standard score) TWS
!> (16) (reserved) please use the next number when implementing a new one
!>      MO: Q:  1st objective: (1) = 1.0 - NSE
!>          Q:  2nd objective: (2) = 1.0 - lnNSE
!> (17) SO: N:  1.0 - KGE of spatio-temporal neutron data, catchment-average
!> (18) (reserved) please use the next number when implementing a new one
!>      MO: Q:  1st objective: 1.0 - lnNSE(Q_highflow)  (95% percentile)
!>          Q:  2nd objective: 1.0 - lnNSE(Q_lowflow)   (5% of data range)
!> (19) (reserved) please use the next number when implementing a new one
!>      MO: Q:  1st objective: 1.0 - lnNSE(Q_highflow)  (non-low flow)
!>          Q:  2nd objective: 1.0 - lnNSE(Q_lowflow)   (5% of data range)
!> (20) (reserved) please use the next number when implementing a new one
!>      MO: Q:  1st objective: absolute difference in FDC's low-segment volume
!>          Q:  2nd objective: 1.0 - NSE of discharge of months DJF
!> (21) (reserved) please use the next number when implementing a new one
!>      SO: Q:  ( (1.0-lnNSE(Q_highflow))**6 + (1.0-lnNSE(Q_lowflow))**6 )**(1/6)
!>              where Q_highflow and Q_lowflow are calculated like in objective (19)
!> (22-26) (reserved MC/JM/ST) please use the next number when implementing a new one
!> (27) SO: ET: 1.0 - KGE of catchment average evapotranspiration
!> (28) SO: Q + SM: weighted OF using SM (OF12) and Q (OF14) equally weighted
!> further functions can be implemented in mo_objective_function and mo_mrm_objective_function
!> (29) SO: Q + ET: weighted OF using ET (OF27) and Q (OF14) equally weighted
!> (30) SO: Q + domain_avg_ET: [1.0-KGE(Q)]*RMSE(domain_avg_ET) - objective function using Q and domain average ET (standard score)$
!> (31) SO: Q: 1  - weighted NSE (NSE is weighted with observed discharge)
!> (32) SO: objective_sse_boxcox
!> (33) MO: objective_q_et_tws_kge_catchment_avg
!> (34) SO: Q: (1 + |BFI_o - BFI_s|)(1 - KGE)
!>             BFI_s = mean_t(<q_2>) / mean_t(<q_total>)
!>             BFI_o = given in separate namelist per domain
!>             <.> is a spatial average

!> further functions can be implemented in mo_objective_function and mo_mrm_objective_function
opti_function = 10
/

!******************************************************************************************
! main config for mRM (mRM-related)
!******************************************************************************************
&mainconfig_mrm
!-----------------------------------------------------------------------------
!> use ALMA convention for input and output variables
!> see http://www.lmd.jussieu.fr/~polcher/ALMA/convention_3.html
!> .False. -> default mHM units
!> .True.  -> ALMA convention
!> CAUTION: at the moment, only Qall as input for mRM is affected
!-----------------------------------------------------------------------------
ALMA_convention = .TRUE.
!-----------------------------------------------------------------------------
!> for using mRM as the routing module for input other than from mHM
!> additional specifications for filename and netCDF variable can be made
!> default behaviour:
!> none given: get variable 'total_runoff' from file 'total_runoff.nc'
!> varnametotalrunoff given: get variable '${varnametotalrunoff}' from file '${varnametotalrunoff}.nc'
!> filenametotalrunoff given: get variable 'total_runoff' from file '${filenametotalrunoff}.nc'
!> both given: get variable '${varnametotalrunoff}' from file '${filenametotalrunoff}.nc'
!-----------------------------------------------------------------------------
varnametotalrunoff = 'total_runoff'
filenametotalrunoff = 'total_runoff'
!> couple mRM to a groundwater model
gw_coupling = .false.
/

!******************************************************************************************
! main config for river temperature routing
!******************************************************************************************
&config_riv_temp
!-----------------------------------------------------------------------------
!> calculate river temperature
!-----------------------------------------------------------------------------
!> albedo of open water (0.15 for tilt angle between 10 and 20 degrees -> Wanders et.al. 2019)
albedo_water = 0.15
!> priestley taylor alpha parameter for PET on open water (1.26 -> Gordon Bonan 2015)
pt_a_water = 1.26
!> emissivity of water (0.96 -> Wanders et.al. 2019)
emissivity_water = 0.96
!> emissivity of water (20.0 -> Wanders et.al. 2019)
turb_heat_ex_coeff = 20.0
!> max number of iterations for resulting river temperature
max_iter = 50
!> convergence criteria for interative solver for resulting river temperature
!> given as difference for iteratively estimated temperature in K
delta_iter = 1.0e-02
!> maximal step allowed in iteration in K
step_iter = 5.0
!> file name for river widths
riv_widths_file = 'Q_bkfl'
!> variable name for river widths
riv_widths_name = 'P_bkfl'
!> directory where river widths can be found (only for river temperature routing)
dir_riv_widths(1) = 'test_domain/input/optional_data/'
dir_riv_widths(2) = 'test_domain_2/input/optional_data/'
/

!******************************************************************************************
! DIRECTORIES
!******************************************************************************************
!> Namelist with all directories for common file as well as separate file for every domain.
!> Number in brackets indicates domain number.
!> This number HAS TO correspond with the number of domain given in the "mainconfig"
!> namelist as well as the indices given in "evaluation_gauges" namelist.
!******************************************************************************************
! directories (mandatory)
!******************************************************************************************
&directories_general
!> all directories are common to all domains
!> config run out file common to all modeled domains should be written to directory
dirConfigOut = "output/"
!
!> directory where common input files should be located for all modeled domains
!> (only for *_classdefinition files)
dirCommonFiles = "test_domain/input/morph_test/"
!
!**** for Domain 1
!> directory where morphological files are located
dir_Morpho(1)        = "test_domain/input/morph_test/"
!> directory where land cover files are located
dir_LCover(1)        = "test_domain/input/luse/"
!> directory where restart output should be written
mhm_file_RestartOut(1)    = "output/mHM_restart_001.nc"
mrm_file_RestartOut(1)    = "output/mRM_restart_001.nc"
!> directory where output should be written
dir_Out(1)           = "output/"
!> file containing latitude and longitude on the resolution_Hydrology
file_LatLon(1)       = "input/latlon_1.nc"
/
!******************************************************************************************
! directories (mHM-related)
!******************************************************************************************
&directories_mHM
!
!> input format specification for the meteorological forcings: 'nc' only possible
!> this format is common to all domains to be modeled
inputFormat_meteo_forcings = "nc"
bound_error = .FALSE.
!
!-----------------------------------------------------
!> domain wise directory paths
!-----------------------------------------------------
!
!**** for Domain 1
!> directory where meteorological input is located
dir_Precipitation(1) = "input/meteo/"
dir_Temperature(1)   = "input/meteo/"
!> paths depending on PET process (processCase(5))
!>  -1 - PET is input, LAI driven correction
!>   0 - PET is input, aspect driven correction
!>   1 - Hargreaves-Sammani method
!>   2 - Priestley-Taylor mehtod
!>   3 - Penman-Monteith method
!> if processCase(5) == 0  input directory of pet has to be specified
dir_ReferenceET(1)     = "input/meteo/"
!> if processCase(5) == 1  input directory of minimum and maximum temperature has to be specified
dir_MinTemperature(1)  = "test_domain/input/meteo/"
dir_MaxTemperature(1)  = "test_domain/input/meteo/"
!> if processCase(5) == 2  input directory of net-radiation has to be specified
dir_NetRadiation(1)    = "test_domain/input/meteo/"
!> if processCase(5) == 3  input directory of absolute vapour pressure (eabs) and windspeed has to be specified
dir_absVapPressure(1)  = "test_domain/input/meteo/"
dir_windspeed(1)       = "test_domain/input/meteo/"
!> if processCase(11) == 1  input directory of (long/short-wave)radiation has to be specified
dir_Radiation(1)    = "test_domain/input/meteo/"
!
!> switch to control read input frequency of the gridded meteo input,
!> i.e. precipitation, potential evapotransiration, and temperature
!>      >0: after each <timeStep_model_inputs> days
!>       0: only at beginning of the run
!>      -1: daily
!>      -2: monthly
!>      -3: yearly
!> if timestep_model_inputs is non-zero, than it has to be non-zero
!> for all domains
time_step_model_inputs(1) = 0
/
!******************************************************************************************
! directories (mRM-related)
!******************************************************************************************
&directories_mRM
!
!-----------------------------------------------------
!> domain wise directory paths
!-----------------------------------------------------
!
!> directory where discharge files are located
dir_Gauges(1)        = "test_domain/input/gauge/"
dir_Gauges(2)        = "test_domain_2/input/gauge/"
!> directory where simulated runoff can be found (only required if coupling mode equals 0)
dir_Total_Runoff(1) = 'test_domain/output_b1/'
dir_Total_Runoff(2) = 'test_domain_2/output/'
!> directory where runoff at bankfull conditions can be found (only for coupling to groundwater model)
dir_Bankfull_Runoff(1) = 'test_domain/input/optional_data/'
dir_Bankfull_Runoff(2) = 'test_domain_2/input/optional_data/'
/

!******************************************************************************************
! Optional input (mHM-related)
!******************************************************************************************
!> data which are optionally needed for optimization
&optional_data
!> soil moisture data
!> currently mhm can be calibrated against the fraction of moisture
!> down to a specific mhm soil layer (integral over the layers)
!> here soil moisture is defined as fraction between water content within the
!> soil column and saturated water content (porosity).
!
!> directory to soil moisture data
! expected file name: sm.nc, expected variable name: sm
dir_soil_moisture(1)   = "test_domain/input/optional_data/"
!> number of mHM soil layers (nSoilHorizons_mHM) which the soil moisture
!> input is representative for (counted top to down)
nSoilHorizons_sm_input = 1
!> time stepping of the soil moisture input
!>     -1: daily   SM values
!>     -2: monthly SM values
!>     -3: yearly  SM values
!-----------------------------
timeStep_sm_input = -2
!
!> directory to neutron data
! expected file name: neutrons.nc, expected variable name: neutrons
dir_neutrons(1)        = "test_domain/input/optional_data/"

!> evapotranspiration data
!
!> directory to evapotranspiration data
! expected file name: et.nc, expected variable name: et
dir_evapotranspiration(1)   = "test_domain/input/optional_data/"

!> time stepping of the et input
!>     -1: daily   ET values
!>     -2: monthly ET values
!>     -3: yearly  ET values
!-----------------------------
timeStep_et_input = -2

!> domain average total water storage (tws)
!> file name including path with timeseries of GRACE-based data
! expected file name: twsa.nc, expected variable name: twsa
dir_tws(1)   = "test_domain/input/optional_data/"

!> time stepping of the tws input
!>     -1: daily   TWS values
!>     -2: monthly TWS values
!>     -3: yearly  TWS values
!-----------------------------
timeStep_tws_input = -2
/

!******************************************************************************************
! PROCESSES (mandatory)
!******************************************************************************************
!> This matrix manages which processes and process descriptions are used for simulation.
!> The number of processes and its corresponding numbering are fixed. The process description can be
!> chosen from the options listed above the name of the particular process case. This number has to be
!> given for processCase(*).
!
&processSelection
!> interception
!> 1 - maximum Interception
processCase(1) = 1
!> snow
!> 1 - degree-day approach
processCase(2) = 1
!> soil moisture
!> 1 - Feddes equation for ET reduction, multi-layer infiltration capacity approach, Brooks-Corey like
!> 2 - Jarvis equation for ET reduction, multi-layer infiltration capacity approach, Brooks-Corey like
!> 3 - Jarvis equation for ET reduction and global FC dependency on root fraction coefficient
!> 4 - Feddes equation for ET reduction and global FC dependency on root fraction coefficient
processCase(3) = 1
!> directRunoff
!> 1 - linear reservoir exceedance approach
processCase(4) = 1
!> potential evapotranspiration (PET)
!>  -1 - PET is input, LAI driven correction
!>   0 - PET is input, aspect driven correction
!>   1 - Hargreaves-Sammani method
!>   2 - Priestley-Taylor mehtod
!>   3 - Penman-Monteith method
processCase(5) = 0
!> interflow
!> 1 - storage reservoir with one outflow threshold and nonlinear response
processCase(6) = 1
!> percolation
!> 1 - GW  assumed as linear reservoir
processCase(7) = 1
!> routing
!> 0 - deactivated
!> 1 - Muskingum approach
!> 2 - adaptive timestep, constant celerity
!> 3 - adaptive timestep, spatially varying celerity
processCase(8) = 0
!> baseflow
!> 1 - recession parameters (not regionalized yet)
processCase(9) = 1
!> ground albedo of cosmic-ray neutrons
!> THIS IS WORK IN PROGRESS, DO NOT USE FOR RESEARCH
!> 0 - deactivated
!> 1 - inverse N0 based on Desilets et al. 2010
!> 2 - COSMIC forward operator by Shuttleworth et al. 2013
processCase(10) = 0
!> river temperature routing (needs routing)
!> 0 - deactivated
!> 1 - following: Beek et al., 2012
processCase(11) = 0
/

!******************************************************************************************
! LAND COVER (mandatory)
!******************************************************************************************
&LCover
!> Variables given in this namelist are common to all domains to be modeled.
!> Please make sure that the land cover periods are covering the simulation period.
!> number of land cover scenes to be used
!> The land cover scene periods are shared by all catchments.
!> The names should be equal for all domains. The land cover scnes have to be ordered
!> chronologically
  nLCoverScene = 1
  LCoverYearStart(1) = 1900
  LCoverYearEnd(1)   = 2098
  LCoverfName(1)     = 'lc.asc' ! doesn't matter
/

!******************************************************************************************
! Time periods (mHM and mRM-related)
!******************************************************************************************
&time_periods
!-----------------------------------------------------------------------------
!> specification of number of warming days [d] and the simulation period.
!> All dynamic data sets(e.g., meteo. forcings, landcover scenes) should start
!> from warming days and ends at the last day of the evaluation period.
!
!>     1---------2-------------------3
!>
!>     1-> Starting of the effective modeling period (including the warming days)
!>     2-> Starting of the given simulation period
!>     3-> Ending   of the given simulation period   (= end of the effective modeling period)
!
!> IF you want to run the model from 2002/01/01 (Starting of the given simulation
!>    period=2) to 2003/12/31 (End of the given simulation period=3) with 365 warming
!>    day, which is 2001/01/01 = 1), THEN all dynamic datasets should be given for
!>    the effective modeling period of 2001/01/01 to 2003/12/31.
!-----------------------------------------------------------------------------
warming_Days(1)    = 0
!> first year of wanted simulation period
eval_Per(1)%yStart = 1992
!> first month of wanted simulation period
eval_Per(1)%mStart = 01
!> first day   of wanted simulation period
eval_Per(1)%dStart = 01
!> last year   of wanted simulation period
eval_Per(1)%yEnd   = 1991
!> last month  of wanted simulation period
eval_Per(1)%mEnd   = 01
!> last day    of wanted simulation period
eval_Per(1)%dEnd   = 31
/

!******************************************************************************************
! INPUT SOIL DATABASE AND mHM LAYERING (MPR-related)
!******************************************************************************************
!> Namelist controlling the layer information of the soil database
!> Variables given in this namelist are common to all domains to be modeled.
&soildata
!----------------------------------------------------------------------------------------------------------
!> iFlag_soilDB:
!>            flag to handle multiple types of soil databases and their processing within the mHM.
!>            This flag is unique and valid for all domains.
!>            Depending on the choice of this flag you need to process your soil database differently.
!
!> iFlag_soilDB = 0:
!>            Read and process the soil database in a classical mHM format which requires:
!>               i) a single gridded ASCII file of soil-id (soil_class.asc - hard coded file name)
!>              ii) a single soil look-up-table file (soil_classdefinition.txt) with information of
!>                  soil textural properties for every horizon.
!
!>            Here mHM is quite flexible to handle multiple soil layers as specified in "nSoilHorizons_mHM"
!>            and depths provided in "soil_Depth(:)".
!
!>            The tillage depth is flexible in this case.
!
!>            The depth of last mHM modeling layer is determined according the information given in the
!>            input soil database, which could vary spatially depending on the soil type. Therefore the
!>            user should not provide the depth of the last modeling layer. For example if you choose
!>            nSoilHorizons_mHM = 3, then soil_Depth should be given for only soil_Depth(1) and soil_Depth(2).
!>            Any additional depth related information would be discarded
!
!> iFlag_soilDB = 1:
!>            Handle the harmonised horizon specific soil information, requires
!>               i) multiple (horizon specific) gridded ASCII files containing info of soil-ids.
!>                 (e.g., soil_class_horizon001.asc, soil_class_horizon002.asc, ....)
!>                 File names are automatically generated within mHM as per the given soil_Depth(:).
!>                 The format follows the FORTRAN coding style: "soil_class_horizon_"XX".asc"
!>                 where XX represents the horizon id with 2 spaces allocated for this number
!>                 and the empty spaces are (trailed) filled with Zeros. FORTRAN CODE I2.2
!>                 The horizon is numbered sequentially from top to bottom soil layers.
!>                 E.g., for 1st horizon it is soil_class_horizon_01.asc,
!>                 for 2nd it is soil_class_horizon_02.asc, ... and so on.
!
!>              ii) a single soil look-up-table file with information of soil textural properties for each soil type.
!>                  Note that there should be no horizon specific information in this LUT file
!>                  (soil_classdefinition_iFlag_soilDB_1.txt - filename is hard coded).
!
!>            The modeling soil horizons is as per the input data (i.e. for which the gridded ASCII files are available).
!
!>            The depth of the last mHM horizon should be specified. It is fixed and uniform across the entire modeling domain.
!
!>            The tillage depth should conform with one of the horizon (lower) layer depths.
!
!>            There is an overhead cost of reading and storing multiple (horizon specific) gridded ASCII files
!
!> Note: For both cases: The present model code mHM can handle maximum of 10 soil horizons (hard coded).
!>        To increase this number, edit the variable "maxNoSoilHorizons" in the "/src/mhm/mo_mhm_constants.f90" file
!
!----------------------------------------------------------------------------------------------------------
iFlag_soilDB = 1
!
!> [mm] soil depth down to which organic matter is possible
tillageDepth =300.00
!
!> No. of soil horizons to be modeled
nSoilHorizons_mHM = 3
!
! soil depth information
!> IF (iFlag_soilDB = 0)
!>    Provide below the soil_Depth() for 1,2,..,*n-1* soil horizons. Depth of the last layer(n) is taken from the soil LUT
!> IF (iFlag_soilDB = 1)
!>    Provide below the soil_Depth() for every 1,2..n-1,*n* soil horizons. You must have soil_class-id gridded file for each layer
!>    Also check your tillage layer depth. It should conform with one of the below specified soil_Depth.
!
!> Soil_Horizon   Depth[mm]      ! bottom depth of soil horizons w.r.t. ground surface (positive downwards)
soil_Depth(1) = 300.00
soil_Depth(2) = 1000.00
soil_Depth(3) = 2000.00
/

!******************************************************************************************
! INFORMATION RELATED TO LAI DATA (MPR-related)
!******************************************************************************************
&LAI_data_information
!
!-----------------------------------------------------------------------------------
!> Flag timeStep_LAI_input identifies how LAI is read in mHM.
!> This flag is unique and valid for all domains.
!
!> timeStep_LAI_input
!>
!>  0: read LAI from long term monthly mean lookup table (related to land cover file).
!>     The filename (LAI_classdefinition.txt) for the LUT is hard coded in mo_file.f90
!>         Information regarding long-term monthly mean LAI for land cover classes
!>         appearing in all modeled domains should be included in this LUT file.
!>         This is an unique file applicable to all domains to be modeled.
!>     The respective plant functional type is in LAI_class.asc, which must be also given
!>         and should be located in each domain's morph directory.
!>
!>  < 0: Read gridded LAI files.
!>     -1: gridded LAI are daily values
!>     -2: gridded LAI are monthly values
!>     -3: gridded LAI are yearly values
!
!>  1: read mean monthly gridded LAI values.
!>     must be a separate *.nc file for every (modeled) domains.
!-----------------------------------------------------------------------------------
timeStep_LAI_input = 0
!> input file format of gridded file (if timeStep_LAI_input < 0)
!>     nc  - assume one file with name lai.nc
!> input file format of gridded file (if timeStep_LAI_input == 1)
!>     nc  - assume one file with name lai.nc with 12 monthly grids of mean LAI estimates
inputFormat_gridded_LAI = "nc"
/

!
!******************************************************************************************
! LCover information (MPR-related)
!******************************************************************************************
&LCover_MPR
!>fraction of area within city assumed to be fully sealed [0.0-1.0]
fracSealed_cityArea = 0.6
/

!******************************************************************************************
! LAI gridded time series folder definition (optional, MPR-related)
!******************************************************************************************
! this is only needed for timeStep_LAI_input != 0
&directories_MPR
!> directory where gridded LAI files are located
dir_gridded_LAI(1)   = "test_domain/input/lai/"
!> directory where gridded LAI files are located
dir_gridded_LAI(2)   = "test_domain/input/lai/"
/

!******************************************************************************************
! Specifcation of evaluation and inflow gauges (mRM-related)
!******************************************************************************************
!> namelist controlling the gauging station information
!> The ID has to correspond to the ID's given in the 'gaugelocation.asc' and
!> to the filename containing the time series
&evaluation_gauges
!> Gauges for model evaluation
!
!> Total number of gauges (sum of all gauges in all subbains)
nGaugesTotal = 2
!> structure of gauge_id(i,j) & gauge_filename(i,j):
!> 1st dimension is the number of the subdomain i
!> 2nd dimension is the number of the gauge j within the subdomain i
!> numbering has to be consecutive
!
!> domain 1
!> number of gauges for subdomain (1)
NoGauges_domain(1)   = 1
!> in subdomain(1), this is the id of gauge(1)  --> (1,1)
Gauge_id(1,1)       = 398
!> name of file with timeseries for subdomain(1) at gauge(1) --> (1,1)
gauge_filename(1,1) = "00398.txt"
!
!> domain 2
!> number of gauges for subdomain (2)
NoGauges_domain(2)       = 1
!> in subdomain(2), this is the id of gauge(1) --> (2,1)
Gauge_id(2,1)           = 45
!> name of file with timeseries for subdomain(2) at gauge(1) --> (2,1)
Gauge_filename(2,1)     = "45.txt"
/

&inflow_gauges
!> Gauges / gridpoints used for inflow to the model domain
!> e.g. in the case of upstream/headwater areas which are
!>      not included in the model domain
!
!> Total number of inflow gauges (sum of all gauges in all subdomains)
nInflowGaugesTotal = 0
!> structure of gauge_id(i,j) & gauge_filename(i,j):
!> 1st dimension is the number of the subdomain i
!> 2nd dimension is the number of the gauge j within the subdomain i
!> numbering has to be consecutive
!
!> domain 1
!> number of gauges for subdomain (1)
NoInflowGauges_domain(1)   = 0
!> id of inflow gauge(1) for subdomain(1) --> (1,1)
InflowGauge_id(1,1)       = -9
!> name of file with timeseries of inflow gauge(1) for subdomain(1) --> (1,1)
InflowGauge_filename(1,1) = ""
!> consider flows from upstream/headwater cells of inflow gauge(1) for subdomain(1) --> (1,1)
InflowGauge_Headwater(1,1) = .FALSE.
/

!******************************************************************************************
! ANNUAL CYCLE PAN EVAPORATION (mHM-related)
!******************************************************************************************
&panEvapo
! MONTH       Jan     Feb     Mar     Apr    May    Jun    Jul    Aug    Sep    Oct    Nov    Dec
!> monthly free pan evaporation
evap_coeff =  1.30,   1.20,   0.72,   0.75,  1.00,  1.00,  1.00,  1.00,  1.00,  1.00,  1.00,  1.50
/

!******************************************************************************************
! ANNUAL CYCLE METEOROLOGICAL FORCINGS (mHM-related)
!******************************************************************************************
&nightDayRatio
!> Alternatively to night day ratios, explicit weights for pet and average temperature can
!> be read. The dimension for the weights are in FORTRAN-notation (rows, colums, months=12, hours=24)
!> and in C-notation (hours=24, months=12, colums, rows).
!> The array for temperature weights is called tavg_weight in the file: <dir_Temperature>/tavg_weight.nc
!> The array for pet weights is called pet_weight in the file: <dir_ReferenceET>/pet_weight.nc
!> The array for precipitation weights is called pet_weight in the file: <dir_Precipitation>/pre_weight.nc
!> If read_meteo_weights is False than night fractions below are used
read_meteo_weights = .FALSE.
!> night ratio for precipitation
!> only night values required because day values are the opposite
fnight_prec  =  0.46,   0.50,   0.52,   0.51,  0.48,  0.50,  0.49,  0.48,  0.52,  0.56,  0.50,  0.47
!> night ratio for PET
fnight_pet   =  0.10,   0.10,   0.10,   0.10,  0.10,  0.10,  0.10,  0.10,  0.10,  0.10,  0.10,  0.10
!> night correction factor for temperature
fnight_temp  = -0.76,  -1.30,  -1.88,  -2.38, -2.72, -2.75, -2.74, -3.04, -2.44, -1.60, -0.94, -0.53
!> night ratio for ssrd (shortwave rad. for river temperature)
fnight_ssrd   =  0.0,   0.0,   0.0,   0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0,  0.0
!> night ratio for strd (longwave rad. for river temperature)
fnight_strd   =  0.45,   0.45,   0.45,   0.45,  0.45,  0.45,  0.45,  0.45,  0.45,  0.45,  0.45,  0.45
/

!******************************************************************************************
! SETTINGS FOR OPTIMIZATION (mHM and mRM-related)
!******************************************************************************************
&Optimization
!  -------------------------------------
!> General:
!  -------------------------------------
!> number of iteration steps by parameterset
nIterations = 7
!> seed of random number gemerator (default: -9)
!> if default: seed is obtained from system clock
seed = 1235876
!  -------------------------------------
!> DDS specific:
!  -------------------------------------
!> perturbation rate r (default: 0.2)
dds_r = 0.2
!  -------------------------------------
!> SA specific:
!  -------------------------------------
!> Initial Temperature (default: -9.0)
!> if default: temperature is determined by algorithm of Ben-Ameur (2004)
sa_temp = -9.0
!  -------------------------------------
!> SCE specific:
!  -------------------------------------
!> Number of Complexes (default: -9)
!> if default: ngs = 2
sce_ngs = 2
!> Points per Complex (default: -9)
!> if default: npg = 2n+1
sce_npg = -9
!> Points per Sub-Complex (default: -9)
!> if default: nps = n+1
sce_nps = -9
!  -------------------------------------
!> MCMC specific:
!  -------------------------------------
!> .true.:  use MCMC for optimisation and estimation of parameter uncertainty
!> .false.: use MCMC for estimation of parameter uncertainty
mcmc_opti = .false.
!> Parameters of error model if mcmc_opti=.false.
!> e.g. for opti_function=8: two parameters a and b: err = a + b*Q
mcmc_error_params = 0.01, 0.6
/

!******************************************************************************************
! SETTINGS FOR OPTIMIZATION for baseflow-index (opti_function = 34)
!******************************************************************************************
&baseflow_config
!> Calculate BFI from discharge time series with the Eckhardt filter
!> Eckhardt et al. (2008, doi: 10.1016/j.jhydrol.2008.01.005)
!> This option **requires** one gauge per domain at the outlet of the basin.
BFI_calc = .true.
!> baseflow index per domain. Only needed if not calculated (BFI_calc = .false.)
!> You can overwrite single BFI values to not calculate them internally (if BFI_calc = .true.).
! BFI_obs(1) = 0.124
! BFI_obs(2) = 0.256
/

/MHM_NML
