# Shared loader for Autosubmit on the Jacamar runner.  Sourced -- do not
# execute -- so the module changes persist in the caller's shell.
#
# Callers: .gitlab/ci/jacamar-tsuite.yml `.tsuite-defaults` (parent-side),
# and wftools/tsuite_pipeline/templates/before_script.sh (child pipeline).
# The .tsuite-required-defaults + jacamar-smoke callers do NOT source this --
# they don't touch the HPC scheduler.
#
# Respects `$AUTOSUBMIT_VERSION`: unset -> load default `autosubmit` module.

# Jacamar sanitises the environment -- re-add site module trees.
module use /appl/AS/modules

if [ -n "$AUTOSUBMIT_VERSION" ]; then
  if ! module load "$AUTOSUBMIT_VERSION"; then
    echo "ERROR: Failed to load module $AUTOSUBMIT_VERSION"
    exit 1
  fi
else
  if ! module load autosubmit; then
    echo "ERROR: Failed to load module autosubmit"
    exit 1
  fi
fi
echo "Autosubmit: $(autosubmit --version 2>&1)"
