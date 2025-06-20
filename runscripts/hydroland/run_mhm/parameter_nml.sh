#!/bin/bash

# Passing arguments needed
out_dir=${1}

# Create the mhm_parameter.nml file
cat <</MHM_PARAMETER >"${out_dir}/mhm_parameter.nml"
!> \file mhm_parameter.nml
!> \brief Parameters for mHM.
!> \details This files sets all parameters (value, bounds, optimization selection).
!!
!! PARAMETER =                    lower_bound, upper_bound,         value,  FLAG, SCALING
! interception
&interception1
! multiplier to relate LAI to interception storage [-]
canopyInterceptionFactor           =  0.1500,      0.4000,          0.15,     1,       1
/

! snow
&snow1
! Threshold for rain/snow partitioning [degC]
snowTreshholdTemperature           = -2.0000,      2.0000,           1.0,     1,       1
! deg day factors to determine melting flux [m degC-1]
degreeDayFactor_forest             =  0.0001,      4.0000,           1.5,     1,       1
degreeDayFactor_impervious         =  0.0000,      1.0000,           0.5,     1,       1
degreeDayFactor_pervious           =  0.0000,      2.0000,           0.5,     1,       1
! increase of deg day factor if there is precipitation [degC-1]
increaseDegreeDayFactorByPrecip    =  0.1000,      0.9000,           0.5,     1,       1
! maximum values for degree day factor [m degC-1]
maxDegreeDayFactor_forest          =  0.0000,      8.0000,           3.0,     1,       1
maxDegreeDayFactor_impervious      =  0.0000,      8.0000,           3.5,     1,       1
maxDegreeDayFactor_pervious        =  0.0000,      8.0000,           4.0,     1,       1
/

! soilmoisture
&soilmoisture1
! organic matter content [%] for forest, impervious and pervious
orgMatterContent_forest            =  0.0000,      20.000,           3.4,     1,       1
orgMatterContent_impervious        =  0.0000,      1.0000,           0.1,     1,       1
orgMatterContent_pervious          =  0.0000,      4.0000,           0.6,     1,       1
! Zacharias PTF parameters below and above 66.5 % sand content (Zacharias et al., 2007, doi:10.2136/sssaj2006.0098)
! constant
PTF_lower66_5_constant             =  0.6462,      0.9506,          0.76,     1,       1
! multiplier for clay constant
PTF_lower66_5_clay                 =  0.0001,      0.0029,        0.0009,     1,       1
! multiplier for mineral bulk density
PTF_lower66_5_Db                   = -0.3727,     -0.1871,        -0.264,     1,       1
! same as lower
PTF_higher66_5_constant            =  0.5358,      1.1232,          0.89,     1,       1
PTF_higher66_5_clay                = -0.0055,      0.0049,        -0.001,     1,       1
PTF_higher66_5_Db                  = -0.5513,     -0.0913,        -0.324,     1,       1
! PTF parameters for saturated hydraulic conductivity after Cosby et al. (1984)
! constant
PTF_Ks_constant                    = -1.2000,     -0.2850,        -0.585,     1,       1
! multiplier for sand
PTF_Ks_sand                        =  0.0060,      0.0260,        0.0125,     1,       1
! multiplier for clay
PTF_Ks_clay                        =  0.0030,      0.0130,        0.0063,     1,       1
! unit conversion factor from inch/h to cm/d -> should not be here
PTF_Ks_curveSlope                  =  60.960,      60.960,        60.960,     0,       1
! shape factor for root distribution with depth, which follows an exponential function [-]
rootFractionCoefficient_forest     =  0.9000,      0.9990,          0.97,     1,       1
rootFractionCoefficient_impervious =  0.9000,      0.9500,          0.93,     1,       1
rootFractionCoefficient_pervious   =  0.0010,      0.0900,          0.02,     1,       1
! shape factor for partitioning effective precipitation into runoff and infiltration based on soil wetness [-]
infiltrationShapeFactor            =  1.0000,      4.0000,          1.75,     1,       1
/

&soilmoisture2
! same as soil moisture 1
orgMatterContent_forest            =  0.0000,      20.000,           3.4,     1,       1
orgMatterContent_impervious        =  0.0000,      1.0000,           0.1,     1,       1
orgMatterContent_pervious          =  0.0000,      4.0000,           0.6,     1,       1
PTF_lower66_5_constant             =  0.6462,      0.9506,          0.76,     1,       1
PTF_lower66_5_clay                 =  0.0001,      0.0029,        0.0009,     1,       1
PTF_lower66_5_Db                   = -0.3727,     -0.1871,        -0.264,     1,       1
PTF_higher66_5_constant            =  0.5358,      1.1232,          0.89,     1,       1
PTF_higher66_5_clay                = -0.0055,      0.0049,        -0.001,     1,       1
PTF_higher66_5_Db                  = -0.5513,     -0.0913,        -0.324,     1,       1
PTF_Ks_constant                    = -1.2000,     -0.2850,        -0.585,     1,       1
PTF_Ks_sand                        =  0.0060,      0.0260,        0.0125,     1,       1
PTF_Ks_clay                        =  0.0030,      0.0130,        0.0063,     1,       1
PTF_Ks_curveSlope                  =  60.960,      60.960,        60.960,     0,       1
rootFractionCoefficient_forest     =  0.9000,      0.9990,          0.97,     1,       1
rootFractionCoefficient_impervious =  0.9000,      0.9500,          0.93,     1,       1
rootFractionCoefficient_pervious   =  0.0010,      0.0900,          0.02,     1,       1
infiltrationShapeFactor            =  1.0000,      4.0000,          1.75,     1,       1
jarvis_sm_threshold_c1             =  0.0000,      1.0000,          0.50,     1,       1
/

&soilmoisture3
orgMatterContent_forest            =  0.0000,      20.000,           3.4,     1,       1
orgMatterContent_impervious        =  0.0000,      1.0000,           0.1,     1,       1
orgMatterContent_pervious          =  0.0000,      4.0000,           0.6,     1,       1
PTF_lower66_5_constant             =  0.6462,      0.9506,          0.76,     1,       1
PTF_lower66_5_clay                 =  0.0001,      0.0029,        0.0009,     1,       1
PTF_lower66_5_Db                   = -0.3727,     -0.1871,        -0.264,     1,       1
PTF_higher66_5_constant            =  0.5358,      1.1232,          0.89,     1,       1
PTF_higher66_5_clay                = -0.0055,      0.0049,        -0.001,     1,       1
PTF_higher66_5_Db                  = -0.5513,     -0.0913,        -0.324,     1,       1
PTF_Ks_constant                    = -1.2000,     -0.2850,        -0.585,     1,       1
PTF_Ks_sand                        =  0.0060,      0.0260,        0.0125,     1,       1
PTF_Ks_clay                        =  0.0030,      0.0130,        0.0063,     1,       1
PTF_Ks_curveSlope                  =  60.960,      60.960,        60.960,     0,       1
rootFractionCoefficient_forest     =  0.9700,      0.9850,         0.9750,    1,       1
rootFractionCoefficient_impervious =  0.9700,      0.9850,         0.9750,    1,       1
rootFractionCoefficient_pervious   =  0.9700,      0.9850,         0.9750,    1,       1
infiltrationShapeFactor            =  1.0000,      4.0000,          1.75,     1,       1
rootFractionCoefficient_sand       =  0.0010,      0.0900,          0.09,     1,       1
rootFractionCoefficient_clay       =  0.9000,      0.9990,          0.98,     1,       1
FCmin_glob                         =  0.1000,      0.2000,          0.15,     0,       1
FCdelta_glob                       =  0.1000,      0.4000,          0.25,     0,       1
jarvis_sm_threshold_c1             =  0.0000,      1.0000,          0.50,     1,       1
/

&soilmoisture4
orgMatterContent_forest            =  0.0000,      20.000,           3.4,     1,       1
orgMatterContent_impervious        =  0.0000,      1.0000,           0.1,     1,       1
orgMatterContent_pervious          =  0.0000,      4.0000,           0.6,     1,       1
PTF_lower66_5_constant             =  0.6462,      0.9506,          0.76,     1,       1
PTF_lower66_5_clay                 =  0.0001,      0.0029,        0.0009,     1,       1
PTF_lower66_5_Db                   = -0.3727,     -0.1871,        -0.264,     1,       1
PTF_higher66_5_constant            =  0.5358,      1.1232,          0.89,     1,       1
PTF_higher66_5_clay                = -0.0055,      0.0049,        -0.001,     1,       1
PTF_higher66_5_Db                  = -0.5513,     -0.0913,        -0.324,     1,       1
PTF_Ks_constant                    = -1.2000,     -0.2850,        -0.585,     1,       1
PTF_Ks_sand                        =  0.0060,      0.0260,        0.0125,     1,       1
PTF_Ks_clay                        =  0.0030,      0.0130,        0.0063,     1,       1
PTF_Ks_curveSlope                  =  60.960,      60.960,        60.960,     0,       1
rootFractionCoefficient_forest     =  0.9700,      0.9850,         0.9750,    1,       1
rootFractionCoefficient_impervious =  0.9700,      0.9850,         0.9750,    1,       1
rootFractionCoefficient_pervious   =  0.9700,      0.9850,         0.9750,    1,       1
infiltrationShapeFactor            =  1.0000,      4.0000,          1.75,     1,       1
rootFractionCoefficient_sand       =  0.0010,      0.0900,          0.09,     1,       1
rootFractionCoefficient_clay       =  0.9000,      0.9990,          0.98,     1,       1
FCmin_glob                         =  0.1000,      0.2000,          0.15,     0,       1
FCdelta_glob                       =  0.1000,      0.4000,          0.25,     0,       1
/

! directSealedAreaRunoff
&directRunoff1
imperviousStorageCapacity          =  0.0000,      5.0000,           0.5,     1,       1
/

! potential evapotranspiration
&PETminus1 ! PET is input, LAI driven correction
PET_a_forest                       =  0.3000,      1.3000,         0.3000,     1,       1
PET_a_impervious                   =  0.3000,      1.3000,         0.8000,     1,       1
PET_a_pervious                     =  0.3000,      1.3000,         1.3000,     1,       1
PET_b                              =  0.0000,      1.5000,         1.5000,     1,       1
PET_c                              =  -2.000,      0.0000,         -0.700,     1,       1
/
&PET0 ! PET is input, aspect driven correction
! minimum factor for PET correction with aspect
minCorrectionFactorPET             =  0.7000,      1.3000,           0.9,     1,       1
maxCorrectionFactorPET             =  0.0000,      0.2000,           0.1,     1,       1
aspectTresholdPET                  =  160.00,      200.00,         180.0,     1,       1
/
&PET1 ! PET - Hargreaves Samani
minCorrectionFactorPET             =  0.7000,      1.3000,        0.9300,     1,       1
maxCorrectionFactorPET             =  0.0000,      0.2000,        0.1900,     1,       1
aspectTresholdPET                  =  160.00,      200.00,        171.00,     1,       1
HargreavesSamaniCoeff              =  0.0016,      0.0030,        0.0023,     1,       1
/
&PET2 ! PET - Priestley Taylor
PriestleyTaylorCoeff               =    0.75,        1.75,        1.1900,     1,       1
PriestleyTaylorLAIcorr             =   -0.50,        0.20,        0.0580,     1,       1
/
&PET3 ! PET - Penman Monteith
canopyheigth_forest                =   15.00,       40.00,        15.000,     1,       1
canopyheigth_impervious            =    0.01,        0.50,        0.0200,     1,       1
canopyheigth_pervious              =    0.10,        5.00,        0.1100,     1,       1
displacementheight_coeff           =    0.50,        0.85,        0.6400,     1,       1
roughnesslength_momentum_coeff     =    0.09,        0.16,        0.0950,     1,       1
roughnesslength_heat_coeff         =    0.07,        0.13,        0.0750,     1,       1
stomatal_resistance                =   10.00,      200.00,        56.000,     1,       1
/

! interflow
&interflow1
interflowStorageCapacityFactor     =  75.000,      200.00,          85.0,     1,       1
! multiplier for slope to derive interflow recession constant
interflowRecession_slope           =  0.0000,      10.000,           7.0,     1,       1
fastInterflowRecession_forest      =  1.0000,      3.0000,           1.5,     1,       1
! multiplier for variability of saturated hydraulic conductivity to derive slow interflow recession constant
slowInterflowRecession_Ks          =  1.0000,      30.000,          15.0,     1,       1
! multiplier for variability of saturated hydraulic conductivity to derive slow interflow exponent
exponentSlowInterflow              =  0.0500,      0.3000,         0.125,     1,       1
/


! percolation
&percolation1
rechargeCoefficient                =  0.0000,      50.000,          35.0,     1,       1
rechargeFactor_karstic             = -5.0000,      5.0000,          -1.0,     1,       1
gain_loss_GWreservoir_karstic      =  1.0000,      1.0000,           1.0,     0,       1
/

! Muskingum routing parameters with MPR
&routing1
muskingumTravelTime_constant       =  0.3100,      0.3500,         0.325,     1,       1
muskingumTravelTime_riverLength    =  0.0700,      0.0800,         0.075,     1,       1
muskingumTravelTime_riverSlope     =  1.9500,      2.1000,           2.0,     1,       1
muskingumTravelTime_impervious     =  0.0900,      0.1100,           0.1,     1,       1
muskingumAttenuation_riverSlope    =  0.0100,      0.5000,           0.3,     1,       1
/

! adaptive timestep routing
&routing2
streamflow_celerity                =     0.1,         15.,           1.5,     0,       1
/

! adaptive timestep routing - varying celerity
&routing3
slope_factor                       =     0.1,        100.,           30.,     0,       1
/

! ground albedo neutrons
! DESILET version
! THIS IS WORK IN PROGRESS, DO NOT USE FOR RESEARCH
&neutrons1
Desilets_N0                 =  300.0,       2000.0,        1500.0,    0,       1
Desilets_LW0                =    0.0,          0.2,       0.1783,     0,       1
Desilets_LW1                =    0.0,         0.05,          0.0,     0,       1
/

! ground albedo neutrons
! COSMIC version
! THIS IS WORK IN PROGRESS, DO NOT USE FOR RESEARCH
&neutrons2
COSMIC_N0                          =  300.0,       2000.0,        1500.0,     0,       1
COSMIC_N1                          =    0.01,        10.0,           1.0,     0,       1
COSMIC_N2                          =    0.01,        10.0,           1.0,     0,       1
COSMIC_alpha0                      =    0.01,        10.0,           1.0,     0,       1
COSMIC_alpha1                      =    0.01,        10.0,           1.0,     0,       1
COSMIC_L30                         =   26.56,       424.78,     106.1942,     0,       1
COSMIC_L31                         =  -118.3,       200.28,      40.9879,     0,       1
COSMIC_LW0                         =     0.0,          0.2,       0.1783,     0,       1
COSMIC_LW1                         =     0.0,         0.05,          0.0,     0,       1
/



! geological parameters (ordering according to file 'geology_classdefinition.txt')
! this parameters are NOT REGIONALIZED yet, i.e. these are <beta> and not <gamma>
&geoparameter
GeoParam(1,:)                      =  1.000,      1000.00,     100.0,     1,       1
! GeoParam(2,:)                      =  1.000,      1000.00,     100.0,     1,       1
! GeoParam(3,:)                      =  1.000,      1000.00,     100.0,     1,       1
! GeoParam(4,:)                      =  1.000,      1000.00,     100.0,     1,       1
! GeoParam(5,:)                      =  1.000,      1000.00,     100.0,     0,       1
! GeoParam(6,:)                      =  1.000,      1000.00,     100.0,     0,       1
! GeoParam(7,:)                      =  1.000,      1000.00,     100.0,     1,       1
! GeoParam(8,:)                      =  1.000,      1000.00,     100.0,     0,       1
! GeoParam(9,:)                      =  1.000,      1000.00,     100.0,     1,       1
! GeoParam(10,:)                     =  1.000,      1000.00,     100.0,     1,       1
/

/MHM_PARAMETER
