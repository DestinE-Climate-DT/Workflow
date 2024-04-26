#!/bin/bash

#TODO: incorporate different compilers (?)
function compile_mhm() {
    echo "Compiling mHM ... "
    # Compile mhm using default compiler
    cd ${HPCROOTDIR}/${PROJDEST}/mhm
    source CI-scripts/compile

    # Compile mhm using MPI
    #source CI-scripts/compile_MPI

    # Compile mhm using OpenMP
    #source CI-scripts/compile_OpenMP
}
