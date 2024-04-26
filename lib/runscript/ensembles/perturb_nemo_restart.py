#!/usr/bin/env python
#
#=======================================================================================================================
#
#   DESCRIPTION:    Introduces perturbations to the 3D temperature field ('tn')
#                   of a NEMO restart file. The perturbed restart is stored into 
#                   a copy of the original file.  
# 
#         USAGE:    perturb_nemo_restart.py [-h] [--version] -f PATH -r INTEGER [-s NUMBER] [-p FLOAT] [--dryrun]  
#                    
#       OPTIONS:    -h, --help            show this help message and exit
#                   --version             show program's version number and exit
#                   -f PATH, --restart-file PATH
#                                         NEMO restart file
#                   -r INTEGER, --realization INTEGER
#                                         Member ID
#                   -s NUMBER, --seed NUMBER
#                                         static seed for the random engine
#                   -p FLOAT, --perturbation FLOAT
#                                         perturbation (sigma for normal-distribution) [default = 0.0002 K]
#                   --dryrun              show summary and exit
#                
#  REQUIREMENTS:    ---
#          BUGS:    ---
#         NOTES:    ---
#        AUTHOR:    Kai Keller (kai.keller@bsc.es) 
#       COMPANY:  
#       VERSION:    0.1
#       CREATED:    11/01/24 13:12:27 EET
#      REVISION:    ---
#=======================================================================================================================

import numpy as np
import argparse
import os
import sys
import netCDF4
import shutil

PERTURBATION_DEFAULT = 0.0002

def is_float(string):
    try:
        float(string)
        return True
    except ValueError:
        return False

parser = argparse.ArgumentParser(
                    prog=os.path.basename(__file__),
                    description='Perturbs the tn (3d temperature) field on all levels',
                    epilog='questions: kai.keller@bsc.es')

parser.add_argument('--version', action='version', version='%(prog)s 0.1')
parser.add_argument('-f','--restart-file', action='store', required=True, metavar='PATH', help = "NEMO restart file")
parser.add_argument('-r','--realization', action='store', required=True, metavar='INTEGER', help = "Member ID")
parser.add_argument('-s','--seed', action='store', metavar='NUMBER', help = "static seed for the random engine")
parser.add_argument('-p','--perturbation', action='store', metavar='FLOAT', help = "perturbation (sigma for normal-distribution) [default = 0.0002 K]")
parser.add_argument('--dryrun', action='store_true', help = "show summary and exit")

args = parser.parse_args()

if not os.path.isfile(args.restart_file):
    sys.exit(f'(error) {args.restart_file} is not a file')

if not args.realization.isdecimal():
    sys.exit(f'(error) realization -> {args.realization} is not a valid integer value')

if args.perturbation is not None:
    if not is_float(args.perturbation):
        sys.exit(f'(error) perturbation -> {args.perturbation} is not a valid integer number')
    perturbation = args.perturbation
else:
    perturbation = PERTURBATION_DEFAULT

if args.seed is not None:
    if not args.seed.isdecimal():
        sys.exit(f'(error) seed -> {args.seed} is not a valid integer number')
    seed = int(args.seed)
else:
    seed = int(args.realization)

realization = int(args.realization)
fn_in = args.restart_file
fn_stem = os.path.splitext(fn_in)[0]
fn_out = f'{fn_stem}_{realization}_{perturbation}.nc'

print(
f"""
SUMMARY

    - realization:      {realization}
    - perturbation:     {perturbation}
    - seed:             {seed}
    - restart file in:  {fn_in}
    - restart file out: {fn_out}
    
generate perturbed restart

...

"""
)

if args.dryrun:
    sys.exit("(warning) this is only a dry run")

shutil.copyfile(fn_in, fn_out)

dset = netCDF4.Dataset(fn_out, 'r+')

np.random.seed(seed)

dset['tn'][:] = np.where(dset['tn'][:] == 0, 0, np.random.normal(dset['tn'][:],0.0002))

dset.close()

print('[done]\n')
