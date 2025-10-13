#!/bin/bash
# Number of files to archive
size=5

# # Get list of files sorted by modification date (oldest files first)
files=()
while IFS= read -r line; do
    # Skip line with total
    if [[ "$line" == total* ]]; then
        continue
    fi
    
    # Split string into fields and take the last field
    filename=$(echo "$line" | awk '{for(i=9;i<=NF;i++) printf "%s%s", $i, (i<NF?OFS:ORS)}')
    if [[ -n "$filename" ]]; then
        files+=("$filename")
    fi
done < <(ls -lt)

# Number of files on directory
sizeFiles=${#files[@]}

# We take the minimum size to protect from indexOutOfRange error
if ((sizeFiles < size)); then
    size=$sizeFiles
fi

# Create line with file names to delete
fileNames=""
for ((i=0; i<size; i++)); do
    fileNames+="${files[i]} "
done