'''
Script to calculate daily PET as input for mHM

dimensions in the temperature nc file must be "time" "lat" and "lon"
This process need to be carried out after "mHM_preprocessor.sh"
'''
import numpy as np
import pandas as pd
import xarray as xr
from datetime import datetime


def pet_calculator(tavg, lat, time, l_heat=2.26, w_density=977):
    """
    calculation of Potential Evapotranspiration (PET)
    according to Oudin (2005).

    Parameters
    ----------

    t_avg : numpy.ndarray, optional
        average temperature data set in °C.
    lat : numpy.ndarray
        latitude for the data set in radians.
    time : datetime.datatime
        timestamp for the data.
    l_heat: float, optional
        latent heat of water vaporization in MJ/kg.
        default is 2.26.
    w_density: float, optional
        water density in kg/m3.
        default is 977.


    Returns
    -------
    numpy.ndarray
        Potential Evapotranspiration (PET) data in mm/day.
    """
    e_rad = e_rad_calculator(time, lat)
    pet = (e_rad / (l_heat * w_density)) * ((tavg + 5) / 100)
    pet= pet*1000
    pet[tavg < -5] = 0
    return pet


def e_rad_calculator(time, lat):
    """
    calculation of Potential Evapotranspiration (PET)
    according to John A. Duffie (Deceased) and William A. Beckman (2013).

    Parameters
    ----------
    time : datetime.datatime
        timestamp for the data.
    lat : numpy.ndarray
        latitude for the data set in radians.

    Returns
    -------
    numpy.ndarray
        Extraterrestrial radiation data in mm/day.
    """

    # converting current time to Day-of-year(doy)
    doy = (pd.Timestamp(time).day_of_year - 1)
    
    # relative distance between sun and earth
    dist = 1 + (0.033 * np.cos(((2 * np.pi * doy) / 365)))
    
    # dec = np.radians(23.45 * np.cos((2 * np.pi * (doy - 172)) / 365))
    dec = np.radians(-23.44 * np.cos(np.radians((360 / 365) * (doy + 10))))
    
    # sunset hour angle
    ang = np.arccos(np.maximum(-1, np.minimum(1, -np.tan(lat) * np.tan(dec))))
    
    # extraterrestrial radiation
    e_rad = (ang * np.sin(lat) * np.sin(dec)) + (np.cos(lat) * np.cos(dec) * np.sin(ang))
    
    # units (MJ/m2/day)
    return 37.5 * dist * e_rad

#input NetCDF file
dataset = xr.open_dataset("input/meteo/tavg.nc") # input file path to tavg.nc

tavg = dataset.tavg     # temp units: degC
lat = dataset.lat       # lat units: degrees
lon = dataset.lon       # lon units: degrees
time = dataset.time     # time given in days
              
# converting to radians & getting the data as numpy array
lat_array = np.radians(lat.data) 
# Repeat lat 1D array along a new axis to get the shape of tavg
lat_array = np.repeat(lat_array[:, np.newaxis], 3600, axis=1)
lat_array = lat_array[np.newaxis, :, :]
# Reverse the order of elements along the third axis (axis=2)
lat_array = lat_array[:, :, ::-1]

# Create an empty pet numpy array with the right shape
pet = np.empty((tavg.shape))

for day, data in enumerate(tavg):
    # getting day time & converting to datetime
    np_time = data.time.values
    current_time = datetime.utcfromtimestamp(int(np_time)/1e9)

    # getting data for each day as an array
    tavg_array = tavg.values[day:day+1,:,:]

    # Reverse the order of elements along the third axis (axis=2)
    tavg_array = tavg_array[:, :, ::-1]

    # calculating pet
    pet_data = pet_calculator(tavg_array, lat_array, current_time)

    # Add the data to pet
    pet[day] = pet_data


# units and missing_value attribute for the pet DataArray
pet_attrs = {
    'units': 'mm d-1',
    'missing_value': -9999.0,
    "_FillValue" : -9999.0,
}

# creating output pet NetCDF file
pet = pet[:, ::-1, ::-1]
lat = lat[::-1]
pet = xr.DataArray(pet, coords=[time, lat, lon], dims=['time', 'lat', 'lon'], attrs=pet_attrs)
pet_dataset = xr.Dataset({"pet": pet})
pet_dataset.to_netcdf("input/meteo/pet.nc")
