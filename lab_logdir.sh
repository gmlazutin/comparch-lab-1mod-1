echo "Enter /log directory path: "
read log_dir
echo "Enter Enter threshold(N): "
read N

if [ -z "$log_dir" ]; then
    echo "Path is empty"
    exit 2
fi

if [ ! -e "$log_dir" ]; then
    echo "Path does not exist"
    exit 3
fi

if [ ! -d "$log_dir" ]; then
    echo "Path is not a directory"
    exit 4
fi

if ! [[ "$N" =~ ^[0-9]+$ ]]; then
        echo "Error: threshold must be an integer"
        exit 1
fi

dir_size=$(du -s "$log_dir" | awk '{print $1}')

filesys_size=$(df "$log_dir" | tail -1 | awk '{print $2}')

perc=$(( dir_size * 100 / filesys_size ))

echo "Directory $log_dir takes $perc% of the filesystem."

if [ "$perc" -ge "$N" ]; then
	echo "The usage exceeds the threshold($N%). Starting archivation.."
	init_time=$(date +%Y%m%d_%H%M%S)
	archive="${log_dir%/}_backup_$init_time.tar.gz"
	tar -czf "$archive" -C "$(dirname "$log_dir")" "$(basename "$log_dir")"
	echo "Directory $log_dir archived into $archive"
else
	echo "The usage is less then threshold($N%). No archivation needed."
fi
