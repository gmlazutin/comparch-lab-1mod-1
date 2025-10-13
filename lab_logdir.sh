if [ $# -lt 2 ]; then
	echo "Usage: $0 <log_directory_path> <size>"
	exit 1
fi

log_dir="$1"
size="$2"
N=70

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

dir_size=$(du -sb "$log_dir" | awk '{print $1}')
perc=$(( dir_size * 100 / size))
threshold=$(( N * 100 / size))

echo "Directory $log_dir takes $perc% of the given size."

if [ "$dir_size" -ge "$threshold" ]; then
	echo "The usage exceeds the threshold($threshold). Archivation needed."
else
	echo "The usage is less then threshold($threshold). No archivation needed."
fi
