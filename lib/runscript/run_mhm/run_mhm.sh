#!/bin/bash

# run mHM
./mhm .

# fix lat/lon values
ncks -A -v lat,lon mHM_lat_lon.nc ./output/mHM_Fluxes_States.nc
