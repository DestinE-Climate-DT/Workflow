# Shared installer for the destine CLI (from wftools).  Sourced -- do not
# execute -- so the venv activation persists in the caller's shell.
#
# Callers: .gitlab/ci/jacamar-{smoke,tsuite}.yml before_script blocks,
# and wftools/tsuite_pipeline/templates/before_script.sh (child pipeline).
# All callers run from CI_PROJECT_DIR (repo root), where pyproject.toml lives.

python3 -m venv --system-site-packages .venv
source .venv/bin/activate

# Runner's system pip (21.3.1) has broken PEP 517 handling for
# pyproject.toml-only projects -- produces UNKNOWN-0.0.0 wheels when no
# setup.py is present.  Upgrade pip + setuptools + wheel first so the
# project install goes through modern tooling.
pip install --quiet --upgrade 'pip>=23' 'setuptools>=61' wheel

# --no-cache-dir avoids reusing older cached setuptools in the isolated
# build env.
pip install --no-cache-dir .

export PATH="$PWD/.venv/bin:$PATH"
if ! command -v destine &>/dev/null; then
  echo "ERROR: destine CLI not found after install"; exit 1
fi
# Guard: make sure we're using the venv's destine, not a stale user-site
# leftover.  When the wheel builds empty (UNKNOWN-0.0.0), the venv has no
# destine and PATH search silently falls through to ~/.local/bin/destine,
# which then points at a wftools install that may be gone.
case "$(command -v destine)" in
  "$PWD/.venv/"*) ;;
  *) echo "ERROR: destine is $(command -v destine) -- expected $PWD/.venv/bin/destine"
     echo "       (project wheel likely built empty; check the pip log above)"
     exit 1 ;;
esac
echo "destine CLI: $(which destine)"
