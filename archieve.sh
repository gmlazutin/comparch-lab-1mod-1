#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 archive_name file1 [file2 ...]"
    exit 1
fi

name=$1
shift
dir="backup"
path="$dir/${name}.tar.gz"

if ! mkdir -p "$dir"; then
    echo "Failed to create directory: $dir"
    exit 2
fi

if tar -czf "$path" "$@"; then
    echo "Archive saved to $path"
else
    echo "Failed to create archive"
    exit 3
fi
