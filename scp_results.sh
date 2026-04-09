#!/bin/bash

# Check if case number is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <case_number>"
    exit 1
fi

CASE_NUM=$1
BASE_DIR="case_up_half_cube_0${CASE_NUM}"
REMOTE_BASE="dardel-ft:~/naiss2024-5-347/OpenFOAM/chhua-v2406/run/V_house/${BASE_DIR}"

# Download time directories and log file
scp -r "${REMOTE_BASE}/[0-9]*" "$BASE_DIR"
scp "${REMOTE_BASE}/log.reactingFoam" "$BASE_DIR/"
