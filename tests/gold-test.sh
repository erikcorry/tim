#!/bin/bash
# Copyright (C) 2023 Toitware ApS.
# Use of this source code is governed by a Zero-Clause BSD license that can
# be found in the tests/TESTS_LICENSE file.

set -e

TOIT_RUN=$1
COMMAND_FILE=$2
TOIT_NAME=$3
UNIX_NAME=$4

mkdir -p build

# Get the name of the file without the path and the extension.
testname=${COMMAND_FILE##*/}
testname=${testname%%.cmd}
mkdir -p tests/gold/$TOIT_NAME-$testname
mkdir -p build/$TOIT_NAME-$testname
echo Testing $testname commands
exitvalue=0
for optionfile in tests/$TOIT_NAME/*.options
do
  OPTIONS=$(cat $optionfile)
  name=${optionfile##*/}
  name=${name%%.options}
  echo "Name '$name'"
  in_file=tests/$TOIT_NAME-inputs/$testname.cmd
  out_file=build/$TOIT_NAME-$testname/$name.out
  echo $TOIT_RUN bin/$TOIT_NAME.toit $OPTIONS < $in_file > $out_file
  $TOIT_RUN bin/$TOIT_NAME.toit $OPTIONS < $in_file > $out_file

  if [ ! -f tests/gold/$TOIT_NAME-$testname/$name.out ]; then
    echo "No file: tests/gold/$TOIT_NAME-$testname/$name.out"
    exitvalue=1
  else
    diff -u tests/gold/$TOIT_NAME-$testname/$name.out build/$TOIT_NAME-$testname/$name.out
    cmp tests/gold/$TOIT_NAME-$testname/$name.out tests/gold/$TOIT_NAME-$testname/$name.out
  fi
done

exit $exitvalue
