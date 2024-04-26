#!/usr/bin/env python
###############################################################################
#              PERTURB field in an ecmwf grib file  
###############################################################################
# -----------------------------------------------------------------
# Description: Short script to that perturbs a field in a GRIB file while
#              mainting the headers unchanges. This is required for initial 
#              conditions of IFS
#
# Author: Omar Bellprat (omar.bellprat@bsc.es)
#
#-------------------------------------------------------------------

import sys
from gribapi import *
import argparse
import numpy as np

def main():
    parser = argparse.ArgumentParser(description='Replace field in IFS initial conditions.')
    parser.add_argument('-s','--shortname',help='Parameter to replace.')
    parser.add_argument('-d','--seed',help='Optional random generator seed.')
    parser.add_argument('input',help='Input file IFS' )
    parser.add_argument('output',help='New IFS output file' )
    args = parser.parse_args()

    fin = open(args.input)
    fout = open(args.output,'w')

    if args.seed != None:
        print("Initializing random number generator with seed "+str(args.seed)+" ...")
        np.random.seed(int(args.seed))

    print("Perturbing fields...")
 
    while True:
	gid = grib_new_from_file(fin)
        if not gid: break
	if args.shortname and args.shortname == grib_get(gid,'shortName') or not args.shortname:
            dt = np.array(grib_get_values(gid))
            d1 = dt.size
            pt = np.random.rand(d1)*0.00001-0.000005
            pdt = dt + pt
            grib_set_values(gid,pdt)
        grib_write(gid,fout)
        grib_release(gid)
    fin.close()
    fout.close()

if __name__ == '__main__':
    sys.exit(main())

