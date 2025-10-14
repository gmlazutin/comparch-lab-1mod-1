#!/bin/bash
SCRIPT="./lrotate.sh"
WORKDIR="./.test_lrotate_dir"
TESTDIR="$WORKDIR/test_dir"
TMPFILE="$WORKDIR/_tmp_output.txt"

if [ ! -f "$SCRIPT" ]; then
  echo "$SCRIPT not found"
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
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/bigfile" bs=1024 count=80 &>/dev/null
expected="Archivation needed"
run_test "Test 10: directory exceeds threshold" "$TESTDIR" 100000

# 11. Folder size exactly equals threshold (>=)
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
dd if=/dev/zero of="$TESTDIR/exact" bs=1 count=5000 &>/dev/null
export LROTATE_NEEDED_PERCENTAGE=50
expected="Archivation needed"
run_test "Test 11: size equals threshold" "$TESTDIR" 10000

# 12. Extended log message when env var unset
rm -rf "$TESTDIR"
mkdir -p "$TESTDIR"
export LROTATE_EXTENDED_LOG=true
expected="extendedlog: LROTATE_NEEDED_PERCENTAGE is empty, using default percentage!"
run_test "Test 12: extended log message shown" "$TESTDIR" 1000

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
unset LROTATE_NEEDED_PERCENTAGE

rm -rf "$WORKDIR"
rm -f "$TMPFILE"unset LROTATE_EXTENDED_LOG
unset LROTATE_NEEDED_PERCENTAGE
unset LROTATE_NEEDED_PERCENTAGE
rm -rf "$TESTDIR"

