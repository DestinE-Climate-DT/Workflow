import argparse
import f90nml

parser = argparse.ArgumentParser(
    description="Script to process modify a namelist with a patch"
)
parser.add_argument("-n", "--namelist", help="Path to the namelist file")
parser.add_argument("-p", "--patch", help="Path to the patch file")

# Parse the command-line arguments
args = parser.parse_args()

# Process the namelists
if args.namelist:
    print(args.namelist)
    namelist = f90nml.read(args.namelist)

# Process the patch
if args.patch:
    patch = f90nml.read(args.patch)
    namelist.patch(patch)  # Overwrite namelist with patch
    output_file = str(args.namelist) + "_mod"  # Specify the output file name
    namelist.write(output_file)  # Write the namelist to the output file
