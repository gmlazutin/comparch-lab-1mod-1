#!/bin/bash

is_positive_int() {
	echo "$1" | grep -qE '^[1-9][0-9]*$'
}

extended_log() {
	if [ "${LROTATE_EXTENDED_LOG:-}" = "true" ]; then
		echo "extendedlog: $1"
	fi
}

if [ $# -lt 2 ]; then
	echo "Usage: $0 <log_directory_path> <size>"
	exit 1
fi

log_dir="$1"
size="$2"
N="${LROTATE_NEEDED_PERCENTAGE:-70}"

if [ -z "${LROTATE_NEEDED_PERCENTAGE:-}" ]; then
	extended_log "LROTATE_NEEDED_PERCENTAGE is empty, using default percentage!"
fi
if ! is_positive_int "$N"; then
	echo "LROTATE_NEEDED_PERCENTAGE must be a positive integer"
	exit 1
fi

if ! is_positive_int "$size"; then
	echo "Size must be positive integer"
	exit 1
fi

if [ -z "$log_dir" ]; then
    	echo "Path is empty"
    	exit 1
fi
if [ ! -e "$log_dir" ]; then
    	echo "Path does not exist"
    	exit 1
fi
if [ ! -d "$log_dir" ]; then
    	echo "Path is not a directory"
    	exit 1
fi

dir_size=$(du -sb "$log_dir" | awk '{print $1}')
perc=$(( dir_size * 100 / size))
threshold=$(( N * size / 100))

echo "Directory $log_dir takes $perc% of the given size."

if [ "$dir_size" -ge "$threshold" ]; then
	echo "The usage exceeds the threshold($threshold). Archivation needed."
else
	echo "The usage is less then threshold($threshold). No archivation needed."
fi
