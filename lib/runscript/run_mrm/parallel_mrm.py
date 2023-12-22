#!/usr/bin/env python

from subprocess import Popen, PIPE
import multiprocessing as mp
import os
import argparse

def parse_args():
    parser = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter,
                                     description='''\
              Description:
                Parallel runner

              Created:
                Nov 2020

              Example:
                python3 parallel.py -e './run_mrm' --arg_list 'subdomain_1' 'subdomain_2'

              Note:
              ''')
    parser.add_argument('-e', '--exe', action='store',
                        default='', dest='exe', metavar='exe',
                        help='exectabale bash command e.g. ./mrm (default: "")')
    parser.add_argument('-o', action='store',
                        default='', dest='outputdir', metavar='outputdir',
                        help='path to directory where the ouput will be written (default: "")')
    parser.add_argument('--thr_glob', action='store', type=int,
                        default=1, dest='thr_glob', metavar='thr_glob',
                        help='n threads for program (default: 1)')
    parser.add_argument('--thr_prog', action='store', type=int,
                        default=1, dest='thr_prog', metavar='thr_prog',
                        help='n threads for program (default: 1)')
    parser.add_argument(
        "--arg_list",  # name on the CLI - drop the `--` for positional/required parameters
        nargs="*",  # 0 or more values expected => creates a list
        type=str,
        default=[''],  # default if nothing is provided
        help='list of arguments to the exectabale for each task (default: "")')
    args = parser.parse_args()
    return [args.exe, args.outputdir, args.thr_glob, args.thr_prog, args.arg_list]

class parallelRun:
    def __init__(self, prog, prog_args, outdir, threads_global, threads_exe):
        self.prog           = prog
        self.prog_args      = prog_args
        self.outdir         = outdir
        self.threads_global = threads_global
        self.threads_exe    = threads_exe

    def is_empty(file_name):
        return os.path.getsize(file_name) == 0

    def run_program(self, exe_args):
        # run_path=os.path.join('/scratch/mo/nemk/parallel_mrm',folder)
        print('Starting program {} with args: {}'.format(self.prog, exe_args))
        os.makedirs(self.outdir, exist_ok = True)
        my_env = os.environ.copy()
        my_env['OMP_NUM_THREADS'] = str(self.threads_exe)
        p = Popen(['{} {}'.format(self.prog, exe_args)], shell=True,
                  # stdout=open(os.path.join(self.outdir, 'output'), 'w'),
                  # stderr=open(os.path.join(self.outdir, 'error'), 'w'),
                  env=my_env).communicate()

    def run(self):
        startup='''
        Starting parallel run of: {}
        with global n threads:    {}
        and threads per exe:      {}

        Runs will be issued for the following list:
        '''
        for xx in self.prog_args:
            startup += '{}\n'.format(xx)
        print('setup pool of workers ...')
        pool = mp.Pool(processes=pRun.threads_global)
        print('start parallel run ...')
        pool.map(self.run_program, self.prog_args)


if __name__=='__main__':
    exe_command, outpath, nthr_gl, nthr_prog, args_list = parse_args()
    pRun = parallelRun(exe_command, args_list, outpath, nthr_gl, nthr_prog)
    pRun.run()

