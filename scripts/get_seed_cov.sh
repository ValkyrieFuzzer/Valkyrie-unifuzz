#!/usr/bin/env bash

help_msg() {
  set +euxo pipefail
  echo ""
  if [ "$#" -eq 1 ];
  then
    echo $1
    echo ""
  fi
  echo "Usage: "
  echo "./script/cov.sh <test-bin> [output-dir]"
  echo "  <test-bin>: The binary to test, has to exist in \`./script/find_args_and_seed.sh\`"
  echo "  [output-dir]: The directory to place output files. Defaults to \`output_<test-bin>\`"
}

if [ "$#" -lt 1 ];
then
  help_msg "This script requires at least 1 arguments."
  exit 2
fi

# Determine binary to run and it exists
BIN=$1
# Determine the arguments and seeds to use.
# This script will return `$PACKAGE`, `$ARGS` and `$SEED_CATEGORY`,
# determined according to Unifuzz Table 1
source ~/Valkyrie-unifuzz/scripts/find_args_and_seed.sh
if [[ ! -z ${SEED_DIR+x} ]]
then
    help_msg "Seem like binary \"$BIN\" doesn't exist."
    exit 2
fi
SEED_DIR="/seeds/$SEED_CATEGORY"

# Determine output dir
OUTPUT_DIR="output_$1"
if [ "$#" -eq 3 ];
then
  OUTPUT_DIR=$3
fi
# Create output dir. Abort if it exists.
if [[ ! -d "$OUTPUT_DIR" ]]
then
    help_msg "$OUTPUT_DIR doesn't exist."
    exit 2
fi

set -euxo pipefail

## Start running! Each fuzzer gets run `$REPEAT` times for `$DURATION` long.
BIN=$BIN
RUN_ARGS=$RUN_ARGS
OUTPUT_DIR=$OUTPUT_DIR

# afl & aflplusplus
run_cov() {
  cd $OUTPUT_DIR
  cp -r afl_${BIN}_0 afl_${BIN}_seed
  rm -rf afl_${BIN}_seed/cov
  cd afl_${BIN}_seed/queue
  find .  -maxdepth 1 ! -name 'id:*orig:*' -type f -exec rm -rvf {} +
  cd ../..
 
  OUTPUT=afl_${BIN}_seed
  
    screen -S ${OUTPUT}_cov -dm \
    docker run -w /work -it \
      -v `pwd`/$OUTPUT:/work \
      gclang-afl-bench:latest \
      bash -c "
          /afl-cov/afl-cov -d /work \\
            -e \"/d/p/cov/$BIN $RUN_ARGS AFL_FILE\" \\
            --code-dir /coverage/\\
            --enable-branch-coverage --coverage-include-lines \\
            --lcov-exclude-pattern \"/usr/include/\* \*.y\" \\
            --cover-corpus --disable-gcov-check DISABLE_GCOV_CHECK; \\
        "
}

run_cov
