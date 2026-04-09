#!/bin/bash

# Usage: ./scp_results.sh <case_number> [options]
# Examples:
#   ./scp_results.sh 5                      # download all time dirs + log
#   ./scp_results.sh 5 0.005                # download only 0.005 + log
#   ./scp_results.sh 5 0.005 0.01 0.02      # download specific folders + log
#   ./scp_results.sh 5 --last 3             # download 3 latest time dirs + log
#   ./scp_results.sh 5 --from 0.001 --to 0.01  # download time range + log

if [ $# -lt 1 ]; then
    echo "Usage: $0 <case_number> [0.005 0.01 ...] | [--last N] | [--from T1 --to T2]"
    exit 1
fi

CASE_NUM=$1
shift
BASE_DIR="case_up_half_cube_0${CASE_NUM}"
REMOTE_HOST="dardel-ft"
REMOTE_DIR="~/naiss2024-5-347/OpenFOAM/chhua-v2406/run/V_house/${BASE_DIR}"
REMOTE_BASE="${REMOTE_HOST}:${REMOTE_DIR}"

# Helper: list remote time directories (numeric, excluding 0.orig)
list_remote_times() {
    ssh "$REMOTE_HOST" "ls -d ${REMOTE_DIR}/[0-9]* 2>/dev/null | xargs -I{} basename {} | grep -v '\.orig$' | sort -g"
}

# Parse options
if [ $# -eq 0 ]; then
    # No extra args — download all
    echo "Downloading all time directories from ${BASE_DIR}..."
    scp -r "${REMOTE_BASE}/[0-9]*" "${BASE_DIR}/"

elif [ "$1" == "--last" ]; then
    N=${2:?'--last requires a number, e.g. --last 3'}
    echo "Fetching list of remote time directories..."
    TIMES=$(list_remote_times | tail -n "$N")
    echo "Downloading last $N time dirs: $(echo $TIMES | tr '\n' ' ')"
    for T in $TIMES; do
        scp -r "${REMOTE_BASE}/${T}" "${BASE_DIR}/"
    done

elif [ "$1" == "--from" ]; then
    T_FROM=${2:?'--from requires a start time'}
    T_TO=${4:?'--to requires an end time'}
    echo "Fetching list of remote time directories..."
    TIMES=$(list_remote_times | awk -v a="$T_FROM" -v b="$T_TO" '$1+0 >= a+0 && $1+0 <= b+0')
    echo "Downloading time range [${T_FROM}, ${T_TO}]: $(echo $TIMES | tr '\n' ' ')"
    for T in $TIMES; do
        scp -r "${REMOTE_BASE}/${T}" "${BASE_DIR}/"
    done

else
    # Explicit list of time folders
    for T in "$@"; do
        echo "Downloading ${BASE_DIR}/${T}..."
        scp -r "${REMOTE_BASE}/${T}" "${BASE_DIR}/"
    done
fi

# Always download the log file
echo "Downloading log.reactingFoam..."
scp "${REMOTE_BASE}/log.reactingFoam" "${BASE_DIR}/"
