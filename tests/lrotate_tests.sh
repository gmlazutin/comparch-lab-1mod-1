#!/bin/bash

SCRIPT="$(pwd)/lrotate.sh"
WORKDIR="$(pwd)/.test_lrotate"
TESTDIR="$WORKDIR/test_dir"

if [ ! -f "$SCRIPT" ]; then
  echo "$SCRIPT not found"
  exit 1
fi

mkdir -p "$WORKDIR"
cd "$WORKDIR"

clean_and_exit() {
  unset LROTATE_NEEDED_PERCENTAGE
  unset LROTATE_EXTENDED_LOG
  rm -rf "$WORKDIR"
  exit "$1"
}

init_test() {
  unset LROTATE_NEEDED_PERCENTAGE
  unset LROTATE_EXTENDED_LOG
  mkdir -p "$TESTDIR"
}

finish_test() {
  [ ! -d "$TESTDIR" ] || rm -rf "$TESTDIR"
  [ ! -d "backup" ] || rm -rf "backup"
  [ ! -d "extracted" ] || rm -rf "extracted"
}

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
      clean_and_exit 1
    fi
	echo
  else
    echo "waiting for additional checks..."
  fi
}

# 1. No arguments
init_test
run_test "Usage:" "Test 1: run without arguments (expect Usage error)"
finish_test


# 2. Only one argument
init_test
run_test "Usage:" "Test 2: run with one argument (expect Usage error)" "$TESTDIR"
finish_test

# 3. Invalid LROTATE_NEEDED_PERCENTAGE (string instead of int)
init_test
export LROTATE_NEEDED_PERCENTAGE="abc"
run_test "LROTATE_NEEDED_PERCENTAGE must be a positive integer" "Test 3: invalid environment variable" "$TESTDIR" 1000
finish_test

# 4. Non-numeric size
init_test
run_test "Size must be positive integer" "Test 4: non-numeric size" "$TESTDIR" "abc"
finish_test

# 5. Zero size
init_test
run_test "Size must be positive integer" "Test 5: zero as size" "$TESTDIR" 0
finish_test

# 6. Empty path
init_test
run_test "Path is empty" "Test 6: empty path" "" 1000
finish_test

# 7. Non-existent path
init_test
run_test "Path does not exist or it is not a directory" "Test 7: non-existent path" "/fake/path" 1000
finish_test

# 8. Path is file, not directory
init_test
echo "data" >"$TESTDIR/file.ext"
run_test "Path does not exist or it is not a directory" "Test 8: path is a file" "$TESTDIR/test.ext" 1000
finish_test

# 9. Folder smaller than threshold
init_test
dd if=/dev/zero of="$TESTDIR/smallfile" bs=1024 count=1 &>/dev/null
run_test "No archivation needed" "Test 9: directory smaller than threshold" "$TESTDIR" 100000
finish_test

# 10. Folder exceeds threshold
init_test
dd if=/dev/zero of="$TESTDIR/bigfile" bs=1024 count=100 &>/dev/null
run_test "Archivation needed" "Test 10: directory exceeds threshold" "$TESTDIR" 100  
finish_test

# 11. Folder size exactly equals threshold (>=)
init_test
dd if=/dev/zero of="$TESTDIR/exact" bs=1024 count=1 &>/dev/null
export LROTATE_NEEDED_PERCENTAGE=10
run_test "Archivation needed" "Test 11: size equals threshold" "$TESTDIR" 1024
finish_test

# 12. Extended log message when env var unset
init_test
export LROTATE_EXTENDED_LOG=true
run_test "extendedlog: LROTATE_NEEDED_PERCENTAGE is empty, using default percentage!" "Test 12: extended log message shown" "$TESTDIR" 1000
finish_test

# 13. Valid custom percentage = 90 (no archivation)
init_test
dd if=/dev/zero of="$TESTDIR/small" bs=1500 count=1 &>/dev/null
export LROTATE_NEEDED_PERCENTAGE=90
run_test "No archivation needed" "Test 13: custom percentage = 90%" "$TESTDIR" 2000
finish_test

# 14. Negative percentage
init_test
export LROTATE_NEEDED_PERCENTAGE=-5
run_test "LROTATE_NEEDED_PERCENTAGE must be a positive integer" "Test 14: negative percentage value" "$TESTDIR" 2000
finish_test

# 15. Empty folder
init_test
run_test "No archivation needed" "Test 15: empty folder" "$TESTDIR" 1
finish_test


# 16. Check archive files and logs folder
init_test
dd if=/dev/zero of="$TESTDIR/biglog1.txt" bs=1024 count=1 &>/dev/null
dd if=/dev/zero of="$TESTDIR/biglog2.txt" bs=1024 count=1 &>/dev/null
sleep 0.5
dd if=/dev/zero of="$TESTDIR/biglog3.txt" bs=1024 count=1 &>/dev/null

export LROTATE_NEEDED_PERCENTAGE=50
run_test "" "Test 16: check archive files and logs folder" "$TESTDIR" 4096

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
	clean_and_exit 1
  fi
fi
finish_test

clean_and_exit 0
