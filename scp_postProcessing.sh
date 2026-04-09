#!/bin/bash

# Check if case number is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <case_number>"
    exit 1
fi

CASE_NUM=$1
BASE_DIR="case_up_half_cube_0${CASE_NUM}"
REMOTE="dardel-ft:~/naiss2024-5-347/OpenFOAM/chhua-v2406/run/V_house/${BASE_DIR}/postProcessing"

# Download using scp
scp -r "$REMOTE" "$BASE_DIR"
