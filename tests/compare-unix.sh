#!/bin/bash
# Copyright (C) 2023 Toitware ApS.
# Use of this source code is governed by a Zero-Clause BSD license that can
# be found in the tests/TESTS_LICENSE file.

set -e

TOIT_RUN=$1
COMMAND_FILE=$2
TOIT_NAME=$3   # eg. ted or tim.
UNIX_NAME=$4   # eg. ed or vi.

mkdir -p build
mkdir -p build/gold

# Get the name of the file without the path and the extension.
testname=${COMMAND_FILE##*/}
testname=${testname%%.cmd}
echo Testing $testname options: $OPTIONS
for optionfile in tests/$UNIX_NAME/*.options
do
  OPTIONS=$(cat $optionfile)
  name=${optionfile##*/}
  name=${name%%.options}
  echo "Name '$name'"
  in_file=tests/$UNIX_NAME-inputs/$testname.cmd
  toit_out_file=build/$TOIT_NAME-$name-$testname.out
  unix_out_file=build/gold/$UNIX_NAME-$name-$testname.out
  echo "$TOIT_RUN bin/$TOIT_NAME.toit $OPTIONS < $in_file"
  bash -c "$TOIT_RUN bin/$TOIT_NAME.toit $OPTIONS < $in_file"
  bash -c "$TOIT_RUN bin/$TOIT_NAME.toit $OPTIONS < $in_file > $toit_out_file"
  bash -c "$UNIX_NAME $OPTIONS < $in_file > $unix_out_file"

  diff -u build/gold/$UNIX_NAME-$name-$testname.out build/$TOIT_NAME-$name-$testname.out
  cmp build/$TOIT_NAME-$name-$testname.out build/gold/$UNIX_NAME-$name-$testname.out
done
