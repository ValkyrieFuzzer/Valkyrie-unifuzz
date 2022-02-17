# Run in docker

# ENV
# -- FUZZER
# -- BIN
# -- DURATION
# -- COV
# -- FUZZARGS

# LOG_FILE=/work/log
# exec > >(tee -a $LOG_FILE) 2> >(tee -a $LOG_FILE >&2)
# echo "This line will appear both in $LOG_FILE and on screen"

. $(dirname $0)/common.sh
. $(dirname $0)/find_args_and_seed.sh

OUTDIR=/work/output

if test -d "/seeds"; then
    SEEDDIR=/seeds/$SEED_CATEGORY
fi

# Use `docker run --cpuset-sets=$COREID` to bind cpu affinity instead
export AFL_NO_AFFINITY=1
export ANGORA_DISABLE_CPU_BINDING=1

if test $FUZZER = "afl" || test $FUZZER = "aflplusplus"; then
    FUZZCMD="afl-fuzz -m 2048 -t 1000+
    -i $SEEDDIR -o $OUTDIR -- /d/p/$FUZZER/$BIN $ARGS"
elif test $(echo $FUZZER | head -c 6) = "angora"; then
    FUZZCMD="/angora/angora_fuzzer $FUZZARGS -M 2048 -T 1 -t /d/p/angora/taint/$BIN
    -i $SEEDDIR -o $OUTDIR -- /d/p/angora/fast/$BIN $ARGS"
elif test $(echo $FUZZER) = "valkyrie-solver"; then
    FUZZCMD="/valkyrie/target/release/fuzzer $FUZZARGS -M 2048 -T 1 -t /d/p/angora/taint/$BIN
    -i $SEEDDIR -o $OUTDIR -- /d/p/angora/fast/$BIN $ARGS"
elif test $(echo $FUZZER | head -c 8) = "valkyrie"; then
    FUZZCMD="/valkyrie/target/release/fuzzer $FUZZARGS --san /d/p/asan/$BIN -M 2048 -T 1 -t /d/p/angora/taint/$BIN
    -i $SEEDDIR -o $OUTDIR -- /d/p/angora/fast/$BIN $ARGS"
elif test $FUZZER = "timer"; then
    mkdir -p $OUTDIR
    rm -f $OUTDIR/time.csv
    for SEED in $SEEDDIR/*; do
        printf "$SEED "
        REPLACED=$(echo $ARGS | sed 's|@@|$SEED|g')
        /timer /d/p/gclang/$BIN $REPLACED | tee -a $OUTDIR/time.csv
    done
    awk '{ total += $1; count++ } END { print total/count }' $OUTDIR/time.csv > $OUTDIR/summary.csv
    exit
elif test $FUZZER = "initial-coverage"; then
    mkdir -p $OUTDIR/queue
    i=0
    for f in $SEEDDIR/*; do
        id="id:$(printf %06d $i)"
        cp $f $OUTDIR/queue/$id
        i=$(($i + 1))
    done
    FUZZCMD="echo Copying seeds to $OUTDIR/queue"
else
    error "$FUZZER not yet supported, exiting..."
fi

# Start running fuzzer...
timeout -s 2 $DURATION $FUZZCMD

# Run coverage afterwards, COV must be set
. $(dirname $0)/cov.sh
