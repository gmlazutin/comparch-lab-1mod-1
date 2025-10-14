#!/bin/bash
SCRIPT="./lrotate.sh"
WORKDIR="./.test_lab_dir"
TESTDIR="$WORKDIR/test_dir"
TMPFILE="$WORKDIR/_tmp_output.txt"

if [ ! -f "$SCRIPT" ]; then
  echo "lrotate.sh not found"
  exit 2
fi

mkdir -p "$WORKDIR"

run_test() {
  local desc="$1"
  shift
  echo ">>> $desc"
  rm -rf "$TESTDIR"
  mkdir -p "$TESTDIR"
  "$SCRIPT" "$@" >"$TMPFILE" 2>&1
  local code=$?
  local output
  output=$(cat "$TMPFILE")
  if echo "$output" | grep -q "$expected"; then
    echo "PASSED"
  else
    echo "FAILED"
    echo "Got output:"
    echo "$output"
  fi
  echo
}

# 1. No arguments
expected="Usage:"
run_test "Test 1: run without arguments (expect Usage error)"

# 2. Only one argument
expected="Usage:"
run_test "Test 2: run with one argument (expect Usage error)" "$TESTDIR"

# 3. Invalid LROTATE_NEEDED_PERCENTAGE (string instead of int)
export LROTATE_NEEDED_PERCENTAGE="abc"
expected="LROTATE_NEEDED_PERCENTAGE must be a positive integer"
run_test "Test 3: invalid environment variable" "$TESTDIR" 1000
unset LROTATE_NEEDED_PERCENTAGE

# 4. Non-numeric size
expected="Size must be positive integer"
run_test "Test 4: non-numeric size" "$TESTDIR" "abc"

# 5. Zero size
expected="Size must be positive integer"
run_test "Test 5: zero as size" "$TESTDIR" 0

# 6. Empty path
expected="Path is empty"
run_test "Test 6: empty path" "" 1000

# 7. Non-existent path
expected="Path does not exist"
run_test "Test 7: non-existent path" "/fake/path" 1000

# 8. Path is file, not directory
mkdir -p "$TESTDIR"
echo "data" >"$TESTDIR/file"
expected="Path is not a directory"
run_test "Test 8: path is a file" "$TESTDIR/file" 1000

# 9. Folder smaller than threshold
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/smallfile" bs=1024 count=1 &>/dev/null
expected="No archivation needed"
run_test "Test 9: directory smaller than threshold" "$TESTDIR" 100000

# 10. Folder exceeds threshold
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/bigfile" bs=1024 count=80 &>/dev/null
expected="Archivation needed"
run_test "Test 10: directory exceeds threshold" "$TESTDIR" 1000  # уменьшил size, чтобы реально превышало

# 11. Folder size exactly equals threshold (>=)
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/exact" bs=1 count=5000 &>/dev/null
export LROTATE_NEEDED_PERCENTAGE=50
expected="Archivation needed"
run_test "Test 11: size equals threshold" "$TESTDIR" 10000
unset LROTATE_NEEDED_PERCENTAGE

# 12. Extended log message when env var unset
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
export LROTATE_EXTENDED_LOG=true
unset LROTATE_NEEDED_PERCENTAGE
expected="extendedlog: LROTATE_NEEDED_PERCENTAGE is empty, using default percentage!"
run_test "Test 12: extended log message shown" "$TESTDIR" 1000
unset LROTATE_EXTENDED_LOG

# 13. Valid custom percentage = 90 (no archivation)
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/small" bs=1024 count=1 &>/dev/null
export LROTATE_NEEDED_PERCENTAGE=90
expected="No archivation needed"
run_test "Test 13: custom percentage = 90%" "$TESTDIR" 2000
unset LROTATE_NEEDED_PERCENTAGE

# 14. Negative percentage
export LROTATE_NEEDED_PERCENTAGE=-5
expected="LROTATE_NEEDED_PERCENTAGE must be a positive integer"
run_test "Test 14: negative percentage value" "$TESTDIR" 2000

# 15. Check that archived files are correct
TESTDIR=$(mktemp -d)
echo "log1" > "$TESTDIR/log1.txt"
echo "log2" > "$TESTDIR/log2.txt"
expected=""
run_test "Test 15: archive contains all original files" "$TESTDIR" 2000

# Find created archive
archive_file=$(ls "$TESTDIR"/*.tar.gz 2>/dev/null | head -n 1)
if [ -z "$archive_file" ]; then
  echo "Test 15 failed: archive file not found!"
  exit 1
fi

# Extract archive and check contents
mkdir -p extracted
tar -xzf "$archive_file" -C extracted
if [ ! -f extracted/log1.txt ] || [ ! -f extracted/log2.txt ]; then
  echo "Test 15 failed: archive does not contain all original files!"
  rm -rf extracted "$TESTDIR"
  exit 1
fi

rm -rf extracted
echo "Test 15 passed!"

# 16. Check that old logs are deleted after archiving
TESTDIR=$(mktemp -d)
echo "aaa" > "$TESTDIR/a.log"
echo "bbb" > "$TESTDIR/b.log"
expected=""
run_test "Test 16: old log files deleted after archiving" "$TESTDIR" 2000

# Verify that .log files are deleted
remaining_logs=$(find "$TESTDIR" -type f -name "*.log" | wc -l)
if [ "$remaining_logs" -ne 0 ]; then
  echo "Test 16 failed: old log files were not deleted!"
  rm -rf "$TESTDIR"
  exit 1
fi

# Verify that archive exists
archive_count=$(find "$TESTDIR" -type f -name "*.tar.gz" | wc -l)
if [ "$archive_count" -eq 0 ]; then
  echo "Test 16 failed: archive not created!"
  rm -rf "$TESTDIR"
  exit 1
fi

echo "Test 16 passed!"
rm -rf "$TESTDIR"

rm -rf "$WORKDIR"
rm -f "$TMPFILE"
unset LROTATE_EXTENDED_LOG
unset LROTATE_NEEDED_PERCENTAGE
