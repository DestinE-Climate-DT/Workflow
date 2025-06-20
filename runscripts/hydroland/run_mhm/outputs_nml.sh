#!/bin/bash

# Passing arguments needed
out_dir=${1}

# Create the mhm_outputs.nml file
cat <</MHM_OUTPUTS >"${out_dir}/mhm_outputs.nml"
!> \file mhm_outputs.nml
!> \brief Namelist for mHM output configuration
!> \details This file contains the namelist for mHM outputs.
!! 1. First give the timestep for writing gridded model outputs
!!    It should be integer and has to be perfectly divisible
!!    by the number of total modeling time steps
!! 2. Define main outputs of the model as namelist
!!    the particular output flag is specified as .TRUE. / .FALSE
!!    for writing /not writing the output to a file
!!
!! SYNTAX = ".TRUE." or ".FALSE."
&NLoutputResults
!
! NetCDF output settings
output_deflate_level = 0
output_double_precision = .false.
!
! switch to control write out frequency of the gridded model outputs below
! >0: after each <timeStep_model_outputs> time steps
!  0: only at end of run
! -1: daily
! -2: monthly
! -3: yearly
timeStep_model_outputs = -1
!
!----------------
! 1. states
!----------------
!
! interceptional storage                      (L1_inter)     [mm]    -- case  1
outputFlxState(1)=.FALSE.
!
! height of snowpack                          (L1_snowpack)  [mm]    -- case  2
outputFlxState(2)=.FALSE.
!
! soil water content in the single layers     (L1_soilMoist)         -- case  3
outputFlxState(3)=.TRUE.
!
! volumetric soil moisture in the single
! layers                                      (L1_soilMoist / L1_soilMoistSat )
!                                                            [mm/mm] -- case  4
!
outputFlxState(4)=.FALSE.
!
! mean volumetric soil moisture averaged
! over all soil layers                        (L1_soilMoist / L1_soilMoistSat )
!                                                            [mm/mm] -- case  5
outputFlxState(5)=.FALSE.
!
! waterdepth in reservoir of sealed areas     (L1_sealSTW)   [mm]    -- case  6
outputFlxState(6)=.FALSE.
!
! waterdepth in reservoir of unsat. soil zone (L1_unsatSTW)  [mm]    -- case  7
outputFlxState(7)=.FALSE.
!
! waterdepth in reservoir of sat. soil zone   (L1_satSTW)    [mm]    -- case  8
! --> level of GW reservoir
outputFlxState(8)=.FALSE.
! Ground albedo neutrons related to soil moisture
! THIS IS WORK IN PROGRESS, DO NOT USE FOR RESEARCH
outputFlxState(18)=.FALSE.
!
!----------------
! 2. fluxes
!----------------
!
! potential evapotranspiration PET [mm/T]                             -- case  9
outputFlxState(9)=.FALSE.
!
! actual evapotranspiration aET [mm/T]                                -- case 10
outputFlxState(10)=.TRUE.
!
! total discharge generated per cell (L1_total_runoff) [mm/T]         -- case 11
outputFlxState(11)=.TRUE.
!
! direct runoff generated per cell   (L1_runoffSeal)   [mm/T]         -- case 12
outputFlxState(12)=.FALSE.
!
! fast interflow generated per cell  (L1_fastRunoff)   [mm/T]         -- case 13
outputFlxState(13)=.FALSE.
!
! slow interflow generated per cell  (L1_slowRunoff)   [mm/T]         -- case 14
outputFlxState(14)=.FALSE.
!
! baseflow generated per cell        (L1_baseflow)     [mm/T]         -- case 15
outputFlxState(15)=.FALSE.
!
! groundwater recharge               (L1_percol)       [mm/T]         -- case 16
outputFlxState(16)=.FALSE.
!
! infiltration                       (L1_infilSoil)    [mm/T]         -- case 17
outputFlxState(17)=.FALSE.
!
! actual evapotranspiration from the soil layers       [mm/T]         -- case 19
outputFlxState(19)=.FALSE.
!
! effective precipitation            (L1_preEffect)    [mm/T]         -- case 20
outputFlxState(20)=.FALSE.
!
! snow melt                               (L1_melt)    [mm/T]         -- case 21
outputFlxState(21)=.FALSE.
/

/MHM_OUTPUTS
