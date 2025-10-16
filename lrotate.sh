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
if [ ! -d "$log_dir" ]; then
    echo "Path does not exist or it is not a directory"
    exit 1
fi

dir_size=$(find "$log_dir" -maxdepth 1 -type f -printf "%s\n" | awk 'BEGIN {sum=0} {sum+=$1} END {print sum}')
perc=$(( dir_size * 100 / size))
threshold=$(( N * size / 100))

echo "Directory $log_dir takes $perc% of the given size."

if [ "$dir_size" -eq 0 ]; then
    echo "The folder is empty. No archivation needed."
elif [ "$dir_size" -ge "$threshold" ]; then
    echo "The usage exceeds the threshold($threshold). Archivation needed."

    tmp_sz="$dir_size"
    files=""
    current_wd=$(pwd)
    if ! mkdir -p "backup"; then
        echo "unable to create backup folder"
        exit 1
    fi
    cd "$log_dir"
    for file in $(ls -tr); do
        if [ ! -f "$file" ]; then
            extended_log "\"$file\" is not a file. Skipping..."
            continue
        fi
        files="$files$file "
        tmp_sz=$((tmp_sz - $(stat --printf="%s" "$file")))
        if [ "$tmp_sz" -lt "$threshold" ]; then
            break
        fi
    done

    extended_log "files to be archived: $files"
    backup_name="backup_$(date "+%Y%m%d_%H%M%S").tar.gz"
    if tar -czf "$current_wd/backup/$backup_name" $files; then
        extended_log "files archived. Removing originals..."
        if ! rm $files; then
            echo "unable to remove original files"
            exit 1
        fi
    else
        echo "unable to create archive"
        exit 1
    fi
    echo "Backup \"$backup_name\" created."
    cd "$current_wd"
else
    echo "The usage is less than threshold($threshold). No archivation needed."
fi
