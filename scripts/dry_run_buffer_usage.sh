#!/usr/bin/env bash

# This scripts changes the buffer size of the fuzzer(AFL/AFL++/Angora)
# to see how they perform under different buffer size.

help_msg() {
  set +euxo pipefail
  echo ""
  if [ "$#" -eq 1 ];
  then
    echo $1
    echo ""
  fi
  echo "Usage: "
  echo "./script/dry_run_buffer_usage.sh <test-bin> [loc] [output]"
  echo 
  echo "  <test-bin>: The binary to test, has to exist in \`./script/find_args_and_seed.sh\`"
  echo "  [loc]: The location of your output directory. We will be \`cd\` there first. Defaults to `pwd`"
  echo "  [output]: The name of your output directory. Defaults to \`output_<test-bin>\`"
  echo 
  echo " This script depends on gclang-\$FUZZER-init-bench to run. If you don't have it yet, you may"
  echo " want to run the following commands first."
  echo
  echo "\`docker build unibench_build/gclang-afl-init/ --tag gclang-afl-init-bench\`"
  echo
}

if [ "$#" -lt 1 ];
then
  help_msg "This script requires at least 1 arguments."
  exit 2
fi

# Determine bineary to run and it exists
BIN=$1
source `pwd`/scripts/find_args_and_seed.sh
if [[ ! -z ${SEED_DIR+x} ]]
then
  help_msg "Seem like binary \"$BIN\" doesn't exist."
  exit 2
fi
if [[ $BIN == pdftotext ]]
then
  COMPILER=CXX
else
  COMPILER=CC
fi

OUTPUTS=`pwd`
if [ "$#" -ge 2 ];
then
  OUTPUTS=$2
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
ARGS=$ARGS
OUTPUT_DIR=$OUTPUT_DIR
BR_COUNT_BUF_SIZE=$BR_COUNT_BUF_SIZE
COMPILER=$COMPILER

cd $2

angora_buffer_usage() {
  FUZZER="angora"
  for OUTPUT in $OUTPUTS/0
  do
    screen -S buffer -dm \
    docker run -it \
    -v $OUTPUT:/output \
    gclang-${FUZZER}-init-bench:latest \
    bash -c "
      sed -i 's/pub const MAP_SIZE_POW2: usize = 20;/pub const MAP_SIZE_POW2: usize = $BR_COUNT_BUF_SIZE;/'  /$FUZZER/common/src/config.rs 
      sed -i 's/#define MAP_SIZE_POW2 20/#define MAP_SIZE_POW2 $BR_COUNT_BUF_SIZE;/'  /$FUZZER/llvm_mode/include/defs.h 
      cd $FUZZER
      CC=clang CXX=clang++ ./build/build.sh
      \$$COMPILER /d/p/bc/$BIN.bc -o /fast -ldl -lm -lz -lpthread
      USE_TRACK=1 \$$COMPILER /d/p/bc/$BIN.bc -o /taint -ldl -lm -lz -lpthread
      rm /output/buffer_usage -rf
      /$FUZZER/angora_fuzzer -T 1 \\
        --input /output/queue --output /output/buffer_usage \\
        -t /taint -- /fast $ARGS 
    " 
  done
}

afl_buffer_usage(){
  # The part for aflplusplus seems not working.
  # Because aflplusplus don'e use fixed buffer. The buffer size is 
  # determined at compile time.
  for FUZZER in afl
  do
    if [ $FUZZER == afl ]
    then
      INSERT_FUZZER_EXIT="sed -i '/write_stats_file(t_byte_ratio, stab_ratio, avg_exec);/a exit(0);' \
        /$FUZZER/afl-fuzz.c"
      QUEUE="queue"
      REINSTALL_FUZZER="CC=clang CXX=clang++ make && make install"
    else
      INSERT_FUZZER_EXIT="\
        sed -i \
          '/write_stats_file(afl, t_byte_ratio, stab_ratio, afl->stats_avg_exec);/a exit(0);' \
          /$FUZZER/src/afl-fuzz-stats.c && \
        sed -i 's/#define STATS_UPDATE_SEC/#define STATS_UPDATE_SEC 1\/\//' /$FUZZER/config.h && \
        sed -i 's/#define STATS_UPDATE_SEC/#define STATS_UPDATE_SEC 1\/\//' /$FUZZER/include/config.h \
      "
      QUEUE="default/queue"
      REINSTALL_FUZZER="CC=clang CXX=clang++ make clean && \
        make distrib CFLAGS=\"-O3 -funroll-loops -D_FORTIFY_SOURCE=2\" && make install"
    fi
    for OUTPUT in $OUTPUTS/0
    do
      DUMMY=dummy_$FUZZER
      NEW=new_$FUZZER
      # screen -S buffer -dm \
      docker run  -it \
        -v ~/work:/work \
        -v $OUTPUT:/output \
        gclang-${FUZZER}-bench:latest \
        bash -c "
          $INSERT_FUZZER_EXIT
          sed -i 's/#define MAP_SIZE_POW2/#define MAP_SIZE_POW2 $BR_COUNT_BUF_SIZE\/\//' \\
            /$FUZZER/config.h 
          cd $FUZZER
          $REINSTALL_FUZZER
          CC=/$FUZZER/afl-clang CXX=/$FUZZER/afl-clang++ \\
            \$$COMPILER /d/p/bc/$BIN.bc -o /d/p/$BIN -ldl -lm -lz -lpthread

          rm /output/$DUMMY /output/$NEW -rf
          /$FUZZER/afl-fuzz -t 1000+ \\
            -i /output/queue -o /output/$DUMMY \\
            -- /d/p/$BIN $ARGS 
        " 
    done
  done
}

echo "Copying remove_useless_seed.py to ~/work/"
cp ~/Valkyrie-unifuzz/scripts/remove_useless_seed.py ~/work/
afl_buffer_usage
