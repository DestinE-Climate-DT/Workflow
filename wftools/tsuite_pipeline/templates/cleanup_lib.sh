# shellcheck shell=bash
# Path resolvers for the remote cleanup.  Side-effect free, so they can be
# unit-tested against a captured `autosubmit report -all` parameter list.

# CI expids come from the testcase namespace and are allocated sequentially
# from t400.  Every path the cleanup touches is built from the expid, so this
# one pattern -- not a path prefix -- is the guard for every deletion.  Widen
# the second character when the allocator rolls past the range.
CI_EXPID_PATTERN='t[4-7][0-9a-z][0-9a-z]'

is_ci_expid() {
    case "$1" in
    $CI_EXPID_PATTERN) return 0 ;;
    *) return 1 ;;
    esac
}

# Drop unresolved (%CURRENT_*%), empty ('-') and VM-local values, then dedupe.
_resolved_values() {
    grep -vE '%|^-?$' | grep -Fv /appl/AS/AUTOSUBMIT_DATA | sort -u
}

# Every per-expid root the experiment touched.  Autosubmit gives each platform
# its own root, so an experiment that transfers or syncs LRA also has one on
# the datamover node and one on the *other* HPC, besides HPCROOTDIR.
resolve_roots() {
    grep -hE '^JOBS\.[A-Z0-9_-]+\.CURRENT_ROOTDIR=' "$1" | sed 's/^[^=]*=//' | _resolved_values
}

# The FDB store, from the per-job rows of the sections that ran on the
# experiment's own HPC ($2 = HPCROOTDIR).  The global row is never substituted
# (%CURRENT_*% is injected per job), and a section on another platform resolves
# to a store this experiment never wrote to -- SYNC_LRA to the other HPC's
# root, TRANSFER to the datamover's gateway.
resolve_fdb_stores() {
    awk -v root="$2" '
        { eq = index($0, "="); key = substr($0, 1, eq - 1); val = substr($0, eq + 1) }
        key ~ /^JOBS\.[A-Z0-9_-]+\.CURRENT_ROOTDIR$/ && val == root { split(key, k, "."); own[k[2]] = 1 }
        key ~ /^JOBS\.[A-Z0-9_-]+\.(.*\.)?FDB_HOME$/ { split(key, k, "."); store[k[2]] = val }
        END { for (section in store) if (section in own) print store[section] }
    ' "$1" | _resolved_values
}

# Value of a global (non job-scoped) parameter row.
resolve_param() {
    awk -F= -v key="$2" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "$1"
}

# Which SSH alias reaches a given root.  /staging is the datamover node's
# scratch on MN5; LUMI's transfer platform shares LUMI's own scratch.
alias_for_root() {
    case "$1" in
    /scratch/*) echo "${LUMI_ALIAS:-}" ;;
    /gpfs/scratch/*) echo "${MN5_ALIAS:-}" ;;
    /staging/*) echo "${TRANSFER_ALIAS:-}" ;;
    *) echo "" ;;
    esac
}
