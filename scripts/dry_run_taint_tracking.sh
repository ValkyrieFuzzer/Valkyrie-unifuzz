#!/usr/bin/env bash

# This script runs taint tracking on all Angora family seeds.
# It generates a log file as all taint tracking results, 
# then runs a tool to convert that log into json so we know what's all the 
# constraints in a seed.

help_msg() {
  set +euxo pipefail
  echo ""
  if [ "$#" -eq 1 ];
  then
    echo $1
    echo ""
  fi
  echo "Usage: "
  echo "./script/dry_run_taint_tracking.sh <test-bin> [loc] [output]"
  echo 
  echo "  <test-bin>: The binary to test, has to exist in \`./script/find_args_and_seed.sh\`"
  echo "  [loc]: The location of your output directory. We will be \`cd\` there first. Defaults to `pwd`"
  echo "  [output]: The name of your output directory. Defaults to \`output_<test-bin>\`"
  echo 
  echo " This script depends on gclang-\$FUZZER-init-bench to run. If you don't have it yet, you may"
  echo " want to run the following commands first."
  echo
  echo "\`docker build unibench_build/gclang-angora-init/ --tag gclang-angora-init-bench\`"
  echo "\`docker build unibench_build/gclang-valkyrie-se-init/ --tag gclang-valkyrie-se-init-bench\`"
  echo
}

if [ "$#" -lt 1 ];
then
  help_msg "This script requires at least 1 arguments."
  exit 2
fi

# Determine bineary to run and it exists
BIN=$1
source ./scripts/find_args_and_seed.sh
if [[ ! -z ${SEED_DIR+x} ]]
then
  help_msg "Seem like binary \"$BIN\" doesn't exist."
  exit 2
fi

if [ "$#" -ge 2 ];
then
  cd $2
fi

OUTPUT_DIR="output_$1"
if [ "$#" -ge 3 ];
then
  OUTPUT_DIR=$3
fi
# Determine output dir

set -euxo pipefail

BIN=$BIN
RUN_ARGS=$RUN_ARGS
OUTPUT_DIR=$OUTPUT_DIR

cd $OUTPUT_DIR
ANGORA_FAMILY="angora-nr valkyrie"

for FUZZER in $ANGORA_FAMILY 
do
    IMAGE="gclang-$FUZZER-init-bench"
    if [[ "$(docker images -q $IMAGE 2> /dev/null)" == "" ]]; then
        help_msg "docker image $IMAGE doesn't exist. You may want to compile it first."
    fi
done

for FUZZER in $ANGORA_FAMILY
do
  if [ -d ${FUZZER}_${BIN}_0 ]
  then
  for OUTPUT in ${FUZZER}_${BIN}_*
  do
    screen -S ${OUTPUT}_track -dm \
    docker run -it \
    -v `pwd`/$OUTPUT:/$OUTPUT \
    gclang-valkyrie-init-bench:latest \
    bash -c "
      rm /$OUTPUT/analysis -rf;
      /valkyrie/angora_fuzzer -T 1 \\
        --input /$OUTPUT/queue --output /$OUTPUT/analysis \\
        -t /d/p/angora/taint/$BIN -- /d/p/angora/fast/$BIN $RUN_ARGS @@; \\
      cp /$OUTPUT/analysis/cond_queue.csv /$OUTPUT/valkyrie-cond-queue.csv;
    " 
  done
  fi
done