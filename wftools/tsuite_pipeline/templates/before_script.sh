# shellcheck shell=bash
source .gitlab/ci/load-autosubmit.sh
source .gitlab/ci/install-destine.sh

# Prepare reports directory (report clean is idempotent -- no-op if dir missing).
mkdir -p reports
destine report clean

# CI output helpers
start_section() {
    local id="$1" header="$2" collapsed="${3:-false}"
    if [ "$collapsed" = "true" ]; then
        echo -e "\e[0Ksection_start:$(date +%s):${id}[collapsed=true]\r\e[0K\e[1;36m${header}\e[0m"
    else
        echo -e "\e[0Ksection_start:$(date +%s):${id}\r\e[0K\e[1;36m${header}\e[0m"
    fi
}
end_section() {
    echo -e "\e[0Ksection_end:$(date +%s):${1}\r\e[0K"
}
RED='\e[1;31m'
GREEN='\e[1;32m'
NC='\e[0m'

# Where results are handed to the parent's tsuite-collect, and the receipt it
# leaves once it has published them.
RESULTS_ROOT="/tmp/$(whoami)-tsuite_results"
RESULTS_ID="${PARENT_PIPELINE_ID:-$CI_PIPELINE_ID}"
SHARED_DIR="$RESULTS_ROOT/$RESULTS_ID"
COLLECT_RECEIPT="$RESULTS_ROOT/collected-$RESULTS_ID.txt"

# Record which child job produced a result, so the parent can name its sources.
# A receipt means the parent already published: it cannot re-fire itself, so
# these results stay invisible until someone retries tsuite-collect.
stamp_provenance() {
    local expid="$1" type_name="$2" phase="$3"
    mkdir -p "$SHARED_DIR" || return 1
    echo "expid=$expid type=$type_name phase=$phase job=${CI_JOB_ID:-}" \
        "url=${CI_JOB_URL:-} at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        >>"$SHARED_DIR/provenance.txt" || return 1
    [ -f "$COLLECT_RECEIPT" ] || return 0
    echo -e "${RED}=======================================================${NC}"
    echo -e "${RED}  PARENT REPORT IS STALE${NC}"
    echo -e "${RED}  Pipeline $RESULTS_ID was already collected:${NC}"
    sed 's/^/    /' "$COLLECT_RECEIPT"
    echo -e "${RED}  Retry tsuite-collect (then tsuite-required) in the${NC}"
    echo -e "${RED}  parent pipeline, or these results stay unpublished.${NC}"
    echo -e "${RED}=======================================================${NC}"
}
