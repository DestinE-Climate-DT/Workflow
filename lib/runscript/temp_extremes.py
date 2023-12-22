#!/usr/bin/env python3

#Destination Earth: Urban Environments application
#Author: Aleks Lacima

# Load libraries                                                                                                     
import xarray as xr
import numpy as np
import scipy as sc
from scipy import stats
import pandas as pd
import os
import copy
import time
import sys
from datetime import datetime as dt
import warnings

#Development of temperature extreme indicators for the Urban Environments application.

#import thermofeel as thf

#class TempXtremes:

#def __init__(self,var):
#    """
#    Initialize variables.
#    """
#    self.var = var

def temp_max(var):
    """
    Compute the maximum temperature.

    Input   
    -------
    var: xarray.DataArray ; (time,lat,lon)

    Output
    -------
    tx: xarray.DataArray ; (lat,lon)
        Maximum temperature.
    """
    tx = var.max(dim='time')

    return tx

def temp_mean(var):
    """
    Compute the mean temperature.

    Input
    -------
    var: xarray.DataArray ; (time,lat,lon)

    Output
    -------
    tm: xarray.DataArray ; (lat,lon)
        Mean temperature.
    """
    tm = var.mean(dim='time')

    return tm

def temp_min(var):
    """
    Compute the minimum temperature.

    Input
    -------
    var: xarray.DataArray ; (time,lat,lon)

    Output
    -------
    tn: xarray.DataArray ; (lat,lon)
        Minimum temperature.
    """
    tn = var.min(dim='time')

    return tn

def temp_per(var,percentile,axis=0):
    """
    Compute the temperature percentile.

    Input
    -------
    var: xarray.DataArray / numpy array ; (time,lat,lon)
        Temperature variable.
    percentile: float
        Percentile to compute (0 to 100).
    axis: int/tuple
        Axis along which to compute the percentile (default: 0).
    
    Output
    -------
    tper: numpy array
        Temperature percentile.
    """
    # Com
    tper = np.percentile(var,percentile,axis)

    return tper

def tropical_nights(tn,threshold=20.0):
    """
    Compute the number of tropical nights. Requires daily minimum temperature.

    Input
    -------
    tn: xarray.DataArray ; (time,lat,lon)
        Minimum temperature.
    threshold: float
        Threshold temperature (default: 20°C).

    Output
    -------
    tropic_nights: xarray.DataArray ; (lat,lon)
        Number of tropical nights.
    """
    # Count the number of tropical nights.
    tr_nights = np.sum(tn['2t'] > threshold,axis=0)

    # Add metadata to the output variable.
    attrs = {'long_name': 'Number of tropical nights', 'units': 'count'}
    tr_nights = xr.DataArray(tr_nights, dims=('lat', 'lon'), attrs=attrs)

    return tr_nights

def summer_days(tx,threshold=25.0):
    """
    Compute the number of summer days. Requires daily maximum temperature.

    Input
    -------
    tx: xarray.DataArray ; (time,lat,lon)
        Maximum temperature.
    threshold: float
        Threshold temperature (default: 25°C).

    Output
    -------
    sum_days: xarray.DataArray ; (lat,lon)
        Number of summer days.
    """
    # Count the number of summer days.
    sum_days = np.sum(tx > threshold,axis=0)

    # Add metadata to the output variable.
    attrs = {'long_name': 'Number of summer days', 'units': 'count'}
    sum_days = xr.DataArray(sum_days, dims=('lat', 'lon'), attrs=attrs)

    return sum_days

def equatorial_nights(tn,threshold=25.0):
    """
    Compute the number of equatorial nights. Requires daily minimum temperature.

    Input
    -------
    tn: xarray.DataArray ; (time,lat,lon)
        Minimum temperature.
    threshold: float
        Threshold temperature (default: 25°C).
    
    Output
    -------
    eq_nights: xarray.DataArray ; (lat,lon)
        Number of equatorial nights.
    """
    # Count the number of equatorial nights.
    eq_nights = np.sum(tn > threshold,axis=0)

    # Add metadata to the output variable.
    attrs = {'long_name': 'Number of equatorial nights', 'units': 'count'}
    eq_nights = xr.DataArray(eq_nights, dims=('lat', 'lon'), attrs=attrs)

    return eq_nights

def warm_nights(tn):
    """
    Compute the number of warm nights. Requires daily minimum temperature.

    Input
    -------
    tn: xarray.DataArray ; (time,lat,lon)
        Minimum temperature.
    
    Output
    -------
    wm_nights: xarray.DataArray ; (lat,lon)
        Number of warm nights.
    """
    # Calculate the 90th percentile of daily minimum temperature for each lat-lon pair.
    tn90p = temp_per(tn, 90.0, axis=(1,2))

    # Count the number of warm nights.
    wm_nights = np.sum(tn > tn90p[:,np.newaxis,np.newaxis], axis=0)

    # Add metadata to the output variable.
    attrs = {'long_name': 'Number of warm nights', 'units': 'count'}
    wm_nights = xr.DataArray(wm_nights, dims=('lat', 'lon'), attrs=attrs)

    return wm_nights

#Need to find an accurate description of this indicator.
def heatwave_index(tx,threshold=35.0):
    """
    Compute the heatwave index. Requires daily maximum temperature.

    Input
    -------
    tx: xarray.DataArray ; (time,lat,lon)
        Maximum temperature.
    threshold: float
        Threshold temperature (default: 35°C).
    """

    return None

def cooling_degree_days(tm,threshold=24.0):
    """
    Compute the average cooling degree days. Requires daily minimum temperature.

    Input
    -------
    tm: xarray.DataArray ; (time,lat,lon)
        Mean temperature.
    threshold: float
        Threshold temperature (default: 24°C).

    Output
    -------
    cdd: xarray.DataArray ; (lat,lon)
        Cooling degree days.
    """
    from auto_tqdm import tqdm
    #Initialize the cooling degree days array.
    cdd = np.zeros((tm.shape[1],tm.shape[2]))

    for t in tqdm(range(tm.shape[0])):
        for i in range(tm.shape[1]):
            for j in range(tm.shape[2]):
                if tm[t,i,j] >= threshold:
                    cdd[i,j] += tm[t,i,j] - 21.0
                else:
                    cdd[i,j] += 0

    cdd_daily = cdd / tm.shape[0]

    return cdd,cdd_daily

def excess_heat_factor(tm,t30day):
    """
    Compute the excess heat factor. Requires daily maximum temperature.

    Input
    -------
    tm: xarray.DataArray ; (time, lat, lon)
        Daily mean temperature.
    t30day: xarray.DataArray ; (lat, lon)
        30-day average of daily mean temperature for previous month.
    
    Output
    -------
    ehf: xarray.DataArray ; (time, lat, lon)
        Excess heat factor.
    """
    from auto_tqdm import tqdm
    #Compute the 95th percentile of the daily mean temperature.
    tm95p = np.percentile(tm, 95.0, axis=0)

    ehi_sig = np.zeros((tm.shape[0], tm.shape[1], tm.shape[2]))
    ehi_acc = np.zeros((tm.shape[0], tm.shape[1], tm.shape[2]))
    ehf = np.zeros((tm.shape[0], tm.shape[1], tm.shape[2]))

    for t in tqdm(range(tm.shape[0]-2)):
        for i in range(tm.shape[1]):
            for j in range(tm.shape[2]):
                t3d = (tm[t,i,j]+tm[t+1,i,j]+tm[t+2,i,j])/3
    #Significant excess heat index
                if t3d > tm95p[i,j]:
                    ehi_sig[t,i,j] = t3d - tm95p[i,j]
                else:
                    ehi_sig[t,i,j] = 0.0
    #Acclimatisation excess heat index
                if t3d > t30day[i,j]:
                    ehi_acc[t,i,j] = t3d - t30day[i,j]
                else:
                    ehi_acc[t,i,j] = 0.0
    #Excess Heat Factor
                ehf[t,i,j] = ehi_sig[t,i,j]*np.maximum(ehi_acc[t,i,j],1.0)

    return ehf

#The following indicators are defined for the 90th percentile of maximum temperature.
def temp_max90per(tx):
    """
    Compute the 90th percentile of daily maximum temperature.

    Input
    -------
    tx: xarray.DataArray ; (time,lat,lon)
        Maximum temperature.
    
    Output
    -------
    tx90p: xarray.DataArray ; (lat,lon)
        90th percentile of maximum temperature.
    """
    tx90p = tx.temp_per(90)

    return tx90p

def temp_mean90per(tm):
    """
    Compute the 90th percentile of mean temperature.

    Input
    -------
    tm: xarray.DataArray ; (time,lat,lon)
        Mean temperature.

    Output
    -------
    tm90p: xarray.DataArray ; (lat,lon)
        90th percentile of mean temperature.
    """
    tm90p = tm.temp_per(90)

    return tm90p

def temp_min90per(tn):
    """
    Compute the 90th percentile of minimum temperature.

    Input
    -------
    tn: xarray.DataArray ; (time,lat,lon)
        Minimum temperature.

    Output
    -------
    tn90p: xarray.DataArray ; (lat,lon)
        90th percentile of minimum temperature.
    """
    tn90p = tn.temp_per(90)

    return tn90p
    
#I don't really know if it is useful to implement these indicators as they could be easily
#computed by combining the functions temp_max, temp_mean and temp_min with the function
#temp_per.
