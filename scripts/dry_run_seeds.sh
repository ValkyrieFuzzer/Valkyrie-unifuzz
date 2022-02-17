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
  echo "./script/dry_run_seeds.sh"
  echo 
  echo " This script depends on gclang-\$FUZZER-init-bench to run. If you don't have it yet, you may"
  echo " want to run the following commands first."
  echo
  echo "\`docker build unibench_build/gclang-angora-nr-init/ --tag gclang-angora-init-bench\`"
  echo "\`docker build unibench_build/gclang-valkyrie-se-init/ --tag gclang-valkyrie-se-init-bench\`"
  echo
}

OUTPUT_DIR=`pwd`/dry_run_seeds
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

set -euxo pipefail

OUTPUT_DIR=$OUTPUT_DIR
PROGS="imginfo jhead nm objdump pdftotext readelf readpng size tiffsplit xmllint"
cd $OUTPUT_DIR
ANGORA_FAMILY="angora-nr valkyrie"

for FUZZER in $ANGORA_FAMILY 
do
    IMAGE="gclang-$FUZZER-init-bench"
    if [[ "$(docker images -q $IMAGE 2> /dev/null)" == "" ]]; then
        help_msg "docker image $IMAGE doesn't exist. You may want to compile it first."
    fi
done

for BIN in $PROGS
do
  # Determine the arguments and seeds to use.
  # This script will return `$PACKAGE`, `$ARGS` and `$SEED_CATEGORY`,
  # determined according to Unifuzz Table 1
  BIN=$BIN
  source ../scripts/find_args_and_seed.sh
  SEED_DIR="/seeds/$SEED_CATEGORY"
  for FUZZER in $ANGORA_FAMILY
  do
    OUTPUT=${BIN}_${FUZZER}
    screen -S ${OUTPUT}_seed -dm \
    docker run -it \
    -v `pwd`/$OUTPUT:/$OUTPUT -v `pwd`/../seeds:/seeds \
    gclang-valkyrie-init-bench:latest \
    bash -c "
      rm /$OUTPUT/analysis -rf;
      /valkyrie/angora_fuzzer -T 1 \\
        --input $SEED_DIR --output /dry-run \\
        -t /d/p/angora/taint/$BIN -- /d/p/angora/fast/$BIN $RUN_ARGS @@;
      mv /dry-run/* /$OUTPUT
    " 
  done
done