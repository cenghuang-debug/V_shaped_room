#!/bin/bash

# Usage: ./create_new_case.sh <old_number> <new_number>
# Example: ./create_new_case.sh 05 06

if [ $# -ne 2 ]; then
    echo "Error: Please provide old and new case numbers."
    echo "Usage: $0 <old_number> <new_number>"
    echo "Example: $0 05 06"
    exit 1
fi

OLD=$1
NEW=$2

BASE_NAME="case_up_half_cube_"

# Zero-pad single-digit numbers (e.g. 9 → 09), leave two-digit numbers as-is
pad() {
    local n=$1
    if [ "${#n}" -eq 1 ]; then
        echo "0${n}"
    else
        echo "${n}"
    fi
}

OLD_CASE="${BASE_NAME}$(pad $OLD)"
NEW_CASE="${BASE_NAME}$(pad $NEW)"

# Check if we're in the correct directory
if [[ ! "$(basename $(pwd))" == "V_house" ]]; then
    echo "Warning: This script should be run from inside the V_house directory."
    echo "Current directory: $(pwd)"
fi

# Check if old case exists
if [ ! -d "$OLD_CASE" ]; then
    echo "Error: Source case '$OLD_CASE' does not exist!"
    exit 1
fi

# Check if new case already exists
if [ -d "$NEW_CASE" ]; then
    echo "Error: Target case '$NEW_CASE' already exists!"
    exit 1
fi

echo "Creating new case: $NEW_CASE (from $OLD_CASE)"

# Create and enter the new case directory
mkdir -p "$NEW_CASE" || { echo "Failed to create $NEW_CASE"; exit 1; }
cd "$NEW_CASE" || { echo "Failed to cd into $NEW_CASE"; exit 1; }

# Copy the required folders and files from the old case
cp -r "../${OLD_CASE}/0.orig" .           || echo "Warning: 0.orig not copied"
cp -r "../${OLD_CASE}/constant" .         || echo "Warning: constant not copied"
cp -r "../${OLD_CASE}/system" .           || echo "Warning: system not copied"
cp -r "../${OLD_CASE}/All"* . 2>/dev/null || echo "Warning: All* files not copied"

# Copy the Dardel sbatch monitor script
if [ -f "../${OLD_CASE}/sbatch_OF_dardel_monitor" ]; then
    cp "../${OLD_CASE}/sbatch_OF_dardel_monitor" .
    # Update case number references inside the script
    sed -i "s/${BASE_NAME}${OLD}/${BASE_NAME}${NEW}/g" sbatch_OF_dardel_monitor
    # Update the SBATCH job name (e.g. #SBATCH -J V_05 → V_06)
    # Use [0-9]* to match any digit sequence regardless of zero-padding
    sed -i "s/#SBATCH -J V_[0-9]*/#SBATCH -J V_$(pad $NEW)/g" sbatch_OF_dardel_monitor
else
    echo "Warning: sbatch_OF_dardel_monitor not found in $OLD_CASE"
fi

echo "Success! New case $NEW_CASE created."
echo "Location: $(pwd)"
