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
  echo "./script/run.sh <test-bin> <cpuset> [cov-live] [output-dir]"
  echo "  <test-bin>: The binary to test, has to exist in \`./script/find_args_and_seed.sh\`"
  echo "  <cpuset>: The cpuset to use, starting from <cpuset>."
  echo "  [cov-live]: Whether run cov-live along with fuzzers. Only \`y\` and \`n\` allowed. Defaults to \`n\`"
  echo "  [output-dir]: The directory to place output files. Defaults to \`output_<test-bin>\`"
}

if [ "$#" -lt 2 ];
then
  help_msg "This script requires at least 2 arguments."
  exit 2
fi

ONE="0"
TWO="0 1"
THREE=$(seq 0 2)
FIVE=$(seq 0 4)
THRITY_ONE=$(seq -f "%02g" 0 31)

ONE_HOUR=3600
FIVE_HOURS=18000
ONE_DAY=78900
ONE_WEEK=552300

# Determine binary to run and it exists
BIN=$1
# Determine the arguments and seeds to use.
# This script will return `$PACKAGE`, `$ARGS` and `$SEED_CATEGORY`,
# determined according to Unifuzz Table 1
source ./scripts/find_args_and_seed.sh
if [[ ! -z ${SEED_DIR+x} ]]
then
    help_msg "Seem like binary \"$BIN\" doesn't exist."
    exit 2
fi
SEED_DIR="/seeds/$SEED_CATEGORY"

CORE_ID=$2

COV_LIVE=n
if [ "$#" -ge 3 ];
then
  COV_LIVE=$3
  if [ $COV_LIVE != y ] && [ $COV_LIVE != n ]
  then
    help_msg "Please use \`y\` or \`n\` to specify cov_live."
    exit 2
  fi
fi

# Determine output dir
OUTPUT_DIR="output_$1"
if [ "$#" -eq 4 ];
then
  OUTPUT_DIR=$4
fi
# Create output dir. Abort if it exists.
#if [[ -d "$OUTPUT_DIR" ]]
#then
    #echo "$OUTPUT_DIR exists."
    #help_msg
    #exit 2
#fi

set -euxo pipefail

## Start running! Each fuzzer gets run `$REPEAT` times for `$DURATION` long.
BIN=$BIN
RUN_ARGS=$RUN_ARGS
SEED_CATEGORY=$SEED_CATEGORY
COV_LIVE=$COV_LIVE
OUTPUT_DIR=$OUTPUT_DIR

REPEAT=$TWO
DURATION=$ONE_DAY

# afl & aflplusplus
run_afl_family() {
  AFL_FAMILY="afl"
  for fuzzer in $AFL_FAMILY
  do
  for i in $REPEAT
    do
      OUTPUT=${fuzzer}_${BIN}_${i}
      # Create output dir. Abort if it exists.
      if [[ -d "$OUTPUT_DIR/$OUTPUT" ]]
      then
          help_msg "$OUTPUT_DIR/$OUTPUT exists."
          exit 2
      fi
    done
  done
  for fuzzer in $AFL_FAMILY
  do
    for i in $REPEAT
    do
      OUTPUT=${fuzzer}_${BIN}_${i}
      # Start the docker for $DURATION+300 seconds, give it 5 more minutes
      # in case coverage couldn't finish in time. The container is
      # automatically killed after that time.
      ID=`docker run -d -w /work -it \
        -v \`pwd\`/$OUTPUT_DIR:/work -v \`pwd\`/seeds:/seeds \
        gclang-${fuzzer}-bench:latest \
        bash -c "mkdir -p /work/$OUTPUT; sleep $(($DURATION+300)); rm /work/$OUTPUT -rf; mv /$OUTPUT /work" \
      `
      # Start a screen that does fuzzing in case we want to get back.
      screen -S $OUTPUT -dm \
        docker exec -it $ID bash -c "
          env AFL_MAP_SIZE=$AFL_MAP_SIZE \\
          timeout --signal=2 --foreground $DURATION \\
            /${fuzzer}/afl-fuzz  \\
            -b $CORE_ID -m 2048 -t 1000+ \\
            -i $SEED_DIR -o /$OUTPUT \\
            -- /d/p/${fuzzer}/$BIN $RUN_ARGS @@; \\
          bash \\
        "
      CORE_ID=$(($CORE_ID + 1))
      if [ $COV_LIVE == 'y' ]
      then
        # Start coverage live.
        screen -S ${OUTPUT}_cov -dm \
          docker exec -it $ID bash -c "
            /afl-cov/afl-cov -d /$OUTPUT \\
              -e \"/d/p/cov/$BIN $RUN_ARGS AFL_FILE\" \\
              --code-dir /coverage/ --sleep 60 \\
              --enable-branch-coverage --coverage-include-lines \\
              --lcov-exclude-pattern \"/usr/include/\* \*.y\" \\
              --cover-corpus --disable-gcov-check DISABLE_GCOV_CHECK --live; \\
            bash \\
          "
      fi
    done
  done
}

run_afl_family

# angora & valkyrie
run_angora_family() {
  ANGORA_FAMILY="angora"
  for fuzzer in $ANGORA_FAMILY
  do
    for i in $REPEAT
    do
      OUTPUT=${fuzzer}_${BIN}_${i}
      # Create output dir. Abort if it exists.
      if [[ -d "$OUTPUT_DIR/$OUTPUT" ]]
      then
          help_msg "$OUTPUT_DIR/$OUTPUT exists."
          exit 2
      fi
    done
  done
  for fuzzer in $ANGORA_FAMILY
  do
  for i in $REPEAT
    do
      OUTPUT=${fuzzer}_${BIN}_${i}
      ID=`docker run -d -w /work -it \
        -v \`pwd\`/$OUTPUT_DIR:/work -v \`pwd\`/seeds:/seeds \
        gclang-${fuzzer}-bench:latest \
        bash -c "mkdir -p /work/$OUTPUT; sleep $(($DURATION+300)); rm /work/$OUTPUT -rf; mv /$OUTPUT /work" \
      `
      screen -S $OUTPUT -dm \
        docker exec -it $ID bash -c "
          timeout --signal=2 --foreground $DURATION \\
            /${fuzzer}/angora_fuzzer \\
            -b $CORE_ID -M 2048 -T 1 \\
            --input $SEED_DIR --output /$OUTPUT \\
            -t /d/p/angora/taint/$BIN -- /d/p/angora/fast/$BIN $RUN_ARGS @@; \\
          bash \\
        "
      CORE_ID=$(($CORE_ID + 1))

      if [ $COV_LIVE == 'y' ]
      then
        screen -S ${OUTPUT}_cov -dm \
          docker exec -it $ID bash -c "
            /afl-cov/afl-cov -d /$OUTPUT \\
              -e \"/d/p/cov/$BIN $RUN_ARGS AFL_FILE\" \\
              --code-dir /coverage/ --sleep 60 \\
              --enable-branch-coverage --coverage-include-lines \\
              --lcov-exclude-pattern \"/usr/include/\* \*.y\" \\
              --cover-corpus --disable-gcov-check DISABLE_GCOV_CHECK --live; \\
            bash \\
          "
      fi
    done
  done
}

run_angora_family
