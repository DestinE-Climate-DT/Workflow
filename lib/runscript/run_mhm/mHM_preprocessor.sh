EXPID=$1
day=$2
#----------------- MODIFY ME ------------------------------------
# Hard-coded directories for reading and writing # TODO: remove this hardcoded path by HPCROOTDIR # TODO: add month and year as imputs 
input_directory_path="/scratch/project_465000454/tmp/$EXPID/"
output_directory_path="input/meteo/"

# variables names in the original NC file
pre_var="tp"
temp_var="2t"
#-------------------------------------------------------------------------------


# Get the first NC file in the current folder (assuming there's only one file for tp and 2t)
pre_file=$(find "$input_directory_path" -maxdepth 1 -type f -name "*${day}_tp_daily_mean.nc" | head -n 1)
tavg_file=$(find "$input_directory_path" -maxdepth 1 -type f -name "*${day}_2t_daily_mean.nc" | head -n 1)

# Check if a NC file was found
if [ -z "$pre_file" ]; then
  echo "No precipitation file found."
else
  # Remove './' from the beginning of the filename
  pre_file=${pre_file#./}
fi
if [ -z "$tavg_file" ]; then
  echo "No temperature file found."
else
  # Remove './' from the beginning of the filename
  tavg_file=${tavg_file#./}
fi

# Exeption variables for cases where NetCDF file has just one time step
# Extract the first standalone numeric value using grep and head
time_str_pre=$(cdo ntime $pre_file | grep -o -E '[0-9]+' | head -n 1)
time_str_tavg=$(cdo ntime $tavg_file | grep -o -E '[0-9]+' | head -n 1)
# converting to int
time_len_pre=$((time_str_pre))
time_len_tavg=$((time_str_tavg))
# Shiftting
shift="1day"


# Safe to assume that tavg and pre will have the same time length
if (($time_len_pre < 2)) && (($time_len_tavg < 2)); then
  cdo copy "$pre_file" temp_copy_pre.nc
  cdo -shifttime,${shift} temp_copy_pre.nc temp_copy_pre1.nc
  cdo -cat temp_copy_pre.nc temp_copy_pre1.nc temp_copy_pre2.nc

  cdo copy "$tavg_file" temp_copy_tavg.nc
  cdo -shifttime,${shift} temp_copy_tavg.nc temp_copy_tavg1.nc
  cdo -cat temp_copy_tavg.nc temp_copy_tavg1.nc temp_copy_tavg2.nc

  # Remapping
  cdo gennn,tgt_grid.txt temp_copy_pre2.nc nn_weights.nc # either pre or tavg can be used here
  cdo remap,tgt_grid.txt,nn_weights.nc temp_copy_pre2.nc temp_pre.nc
  cdo remap,tgt_grid.txt,nn_weights.nc temp_copy_tavg2.nc temp_tavg.nc

else
  # When there is more than one time step remapping is applied derectly to NetCDF files
  cdo gennn,tgt_grid.txt $pre_file nn_weights.nc # either $pre_file or $tavg_file can be used here
  cdo remap,tgt_grid.txt,nn_weights.nc $pre_file temp_pre.nc
  cdo remap,tgt_grid.txt,nn_weights.nc $tavg_file temp_tavg.nc
fi

# CDO processes # MAKE SURE UNITS ARE REALLY K AND m | for pre could be kg m-2 == mm
# Creating several temporal files speeds up run time

# commands for precipitation
cdo -chname,${pre_var},pre temp_pre.nc temp_pre1.nc
cdo -b F64 selname,pre temp_pre1.nc temp_pre2.nc
cdo -mulc,1000 temp_pre2.nc temp_pre3.nc
cdo -setattribute,pre@units="mm d-1" temp_pre3.nc temp_pre4.nc
cdo -settime,00:00:00  temp_pre4.nc temp_pre5.nc

# commands for temperature
cdo -chname,${temp_var},tavg temp_tavg.nc temp_tavg1.nc
cdo -b F64 selname,tavg temp_tavg1.nc temp_tavg2.nc
cdo -subc,273.1 temp_tavg2.nc temp_tavg3.nc
cdo -setattribute,tavg@units="degC" temp_tavg3.nc temp_tavg4.nc
cdo -settime,00:00:00  temp_tavg4.nc temp_tavg5.nc
#-----------------------------------------------------------------------


# NCO processes
ncatted -O -a missing_value,pre,o,f,-9999. -a _FillValue,pre,o,f,-9999. temp_pre5.nc $output_directory_path/pre.nc
ncatted -O -a missing_value,tavg,o,f,-9999. -a _FillValue,tavg,o,f,-9999 temp_tavg5.nc $output_directory_path/tavg.nc


# removing temporal NC files
rm temp*

