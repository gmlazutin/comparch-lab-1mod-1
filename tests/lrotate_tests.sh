#!/bin/bash

SCRIPT="$(pwd)/lrotate.sh"
WORKDIR="$(pwd)/.test_lrotate"
TESTDIR="$WORKDIR/test_dir"

if [ ! -f "$SCRIPT" ]; then
  echo "$SCRIPT not found"
  exit 2
fi

mkdir -p "$WORKDIR"
cd "$WORKDIR"

run_test() {
  expected="$1"
  desc="$2"
  shift 2
  echo ">>> $desc"
  output=$("$SCRIPT" "$@" 2>&1)
  if [ -n "$expected" ]; then
    if echo "$output" | grep -q -- "$expected"; then
      echo "PASSED"
    else
      echo "FAILED"
      echo "Got output:"
      echo "$output"
    fi
	echo
  else
    echo "waiting for additional checks..."
  fi
}

unset LROTATE_NEEDED_PERCENTAGE
unset LROTATE_EXTENDED_LOG

# 1. No arguments
run_test "Usage:" "Test 1: run without arguments (expect Usage error)"

# 2. Only one argument
run_test "Usage:" "Test 2: run with one argument (expect Usage error)" "$TESTDIR"

# 3. Invalid LROTATE_NEEDED_PERCENTAGE (string instead of int)
export LROTATE_NEEDED_PERCENTAGE="abc"
run_test "LROTATE_NEEDED_PERCENTAGE must be a positive integer" "Test 3: invalid environment variable" "$TESTDIR" 1000
unset LROTATE_NEEDED_PERCENTAGE

# 4. Non-numeric size
run_test "Size must be positive integer" "Test 4: non-numeric size" "$TESTDIR" "abc"

# 5. Zero size
run_test "Size must be positive integer" "Test 5: zero as size" "$TESTDIR" 0

# 6. Empty path
run_test "Path is empty" "Test 6: empty path" "" 1000

# 7. Non-existent path
run_test "Path does not exist or it is not a directory" "Test 7: non-existent path" "/fake/path" 1000

# 8. Path is file, not directory
mkdir -p "$TESTDIR"
echo "data" >"$TESTDIR/file.ext"
run_test "Path does not exist or it is not a directory" "Test 8: path is a file" "$TESTDIR/test.ext" 1000

# 9. Folder smaller than threshold
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/smallfile" bs=1024 count=1 &>/dev/null
run_test "No archivation needed" "Test 9: directory smaller than threshold" "$TESTDIR" 100000

# 10. Folder exceeds threshold
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/bigfile" bs=1024 count=100 &>/dev/null
run_test "Archivation needed" "Test 10: directory exceeds threshold" "$TESTDIR" 100  
rm -rf "backup"

# 11. Folder size exactly equals threshold (>=)
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/exact" bs=1024 count=1 &>/dev/null
export LROTATE_NEEDED_PERCENTAGE=10
run_test "Archivation needed" "Test 11: size equals threshold" "$TESTDIR" 1024
unset LROTATE_NEEDED_PERCENTAGE
rm -rf "backup"

# 12. Extended log message when env var unset
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
export LROTATE_EXTENDED_LOG=true
run_test "extendedlog: LROTATE_NEEDED_PERCENTAGE is empty, using default percentage!" "Test 12: extended log message shown" "$TESTDIR" 1000
unset LROTATE_EXTENDED_LOG

# 13. Valid custom percentage = 90 (no archivation)
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/small" bs=1500 count=1 &>/dev/null
export LROTATE_NEEDED_PERCENTAGE=90
run_test "No archivation needed" "Test 13: custom percentage = 90%" "$TESTDIR" 2000
unset LROTATE_NEEDED_PERCENTAGE

# 14. Negative percentage
export LROTATE_NEEDED_PERCENTAGE=-5
run_test "LROTATE_NEEDED_PERCENTAGE must be a positive integer" "Test 14: negative percentage value" "$TESTDIR" 2000
unset LROTATE_NEEDED_PERCENTAGE

# 15. Check archive files and logs folder
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/biglog1.txt" bs=1024 count=1 &>/dev/null
dd if=/dev/zero of="$TESTDIR/biglog2.txt" bs=1024 count=1 &>/dev/null
sleep 0.5
dd if=/dev/zero of="$TESTDIR/biglog3.txt" bs=1024 count=2 &>/dev/null

export LROTATE_NEEDED_PERCENTAGE=50
run_test "" "Test 15: check archive files and logs folder" "$TESTDIR" 4096
unset LROTATE_NEEDED_PERCENTAGE

archive_file=$(find "backup" -name "*.tar.gz" 2>/dev/null | head -n 1)
if [ -z "$archive_file" ]; then
  echo "FAILED: archive file not found!"
else
  mkdir -p "extracted"
  tar -xzf "$archive_file" -C "extracted" 2>/dev/null
  if [ -f "extracted/biglog1.txt" ] && [ -f "extracted/biglog2.txt" ] && \
     [ ! -f "extracted/biglog3.txt" ] && [ -f "$TESTDIR/biglog3.txt" ] && \
	 [ ! -f "$TESTDIR/biglog1.txt" ] && [ ! -f "$TESTDIR/biglog2.txt" ]; then
    echo "PASSED"
  else
    echo "FAILED: archive does not contain all original files or files are not removed properly from logs folder!"
  fi
  rm -rf "extracted"
fi
rm -rf "backup"

cd ..
rm -rf "$WORKDIR"