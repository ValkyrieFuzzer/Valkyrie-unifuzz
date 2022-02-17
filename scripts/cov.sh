#!/bin/bash

# Run in docker

# ENV
# -- FUZZER
# -- BIN
# -- ARGS
# -- OUTDIR
# -- COV = final, live, plot

. $(dirname $0)/common.sh

# Hack to get afl++ working
# if test $FUZZER = "aflplusplus"; then
#     OUTDIR=$OUTDIR/default
# fi

rm -f $OUTDIR/*.csv
rm -rf $OUTDIR/cov_bak

if test -d $OUTDIR/cov; then
    mv $OUTDIR/cov $OUTDIR/cov_bak
fi

case $COV in
"live")
    EXTRA="--live --cover-corpus --sleep 60"
    ;;
"plot")
    EXTRA=""
    ;;
"final")
    EXTRA="--cover-corpus"
    ;;
*)
    warn "COV not set, exiting..."
    exit
    ;;
esac

ARGS=$(echo $ARGS | sed s/@@/AFL_FILE/g)

# Remove irrevelent code to fasten speed & reduce report size.
cd /coverage
for LIB in * ; do
    if [[ $PACKAGE == *$LIB* ]]; then
        echo "Keeping $LIB"
    else
        rm -rf $LIB
    fi
done
cd /

/afl-cov/afl-cov \
    -d $OUTDIR \
    -c /coverage \
    -e "cat AFL_FILE | /d/p/cov/$BIN $ARGS" \
    --lcov-exclude-pattern "/usr/include/\* \*.y" \
    --enable-branch-coverage --coverage-include-lines \
    --disable-gcov-check DISABLE_GCOV_CHECK --overwrite $EXTRA
