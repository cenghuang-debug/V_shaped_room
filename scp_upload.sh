#!/bin/bash

# ===================================================================
# Upload script: Upload a local case to Dardel cluster
# Usage: ./upload_case.sh <case_number>
# Example: ./upload_case.sh 09
# ===================================================================

if [ $# -ne 1 ]; then
    echo "Error: Please provide the case number."
    echo "Usage: $0 <case_number>"
    echo "Example: $0 09"
    exit 1
fi

CASE_NUM=$1
BASE_DIR="case_up_half_cube_0${CASE_NUM}"

LOCAL_PATH="./${BASE_DIR}"
REMOTE_PATH="dardel-ft:~/naiss2024-5-347/OpenFOAM/chhua-v2406/run/V_house/"

# Check if the local case directory exists
if [ ! -d "$LOCAL_PATH" ]; then
    echo "Error: Local case directory '$LOCAL_PATH' does not exist!"
    exit 1
fi

echo "Uploading case ${CASE_NUM} to Dardel..."
echo "Local path : $LOCAL_PATH"
echo "Remote path: $REMOTE_PATH"

# Upload the entire case directory
scp -r "$LOCAL_PATH" "$REMOTE_PATH"

if [ $? -eq 0 ]; then
    echo "Upload completed successfully!"
    echo "Case is now at: ${REMOTE_PATH}${BASE_DIR}"
else
    echo "Error: Upload failed!"
    exit 1
fi
