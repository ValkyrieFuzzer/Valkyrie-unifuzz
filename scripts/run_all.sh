#!/bin/sh

. $(dirname $0)/configrc
. $(dirname $0)/common.sh

usage() {
    echo "USAGE:"
    echo "    run_all.sh [FLAGS] [OPTIONS]"
    echo
    echo "FLAGS:"
    echo "    -h, --help"
    echo
    echo "OPTIONS:"
    echo "    -c, --first-core <COREID>"
    echo "        --with-seed <SEED>"
    echo "        --with-cov <COV>"
}

while test $# -gt 0; do
    case $1 in
    -h|--help)
        usage
        exit
        ;;
    -c|--first-core)
        COREID=$2
        ;;
    --with-seeds)
        SEEDS=$2
        ;;
    --with-cov)
        COV=$2
        ;;
    *)
        usage
        exit 1
        ;;
    esac
    shift
    shift
done

: ${COREID:=0}
: ${COV:=final}
: ${SEEDS:=$UNIFUZZ/seeds}

F=$(echo $FUZZERS | wc -w)
B=$(echo $BINS | wc -w)
CORES=$(($F * $B * $REPEAT))
LAST=$(($COREID + $CORES - 1))

if test $LAST -ge $(nproc); then
    error "Not enought cores! ($LAST >= $(nproc))"
fi

info "Workdir        $WORKDIR"
info "Fuzzers        $FUZZERS"
info "Fuzzer args    $FUZZARGS"
info "Binaries       $B"
info "Repeat         $REPEAT"
info "Cores required $CORES"
info "Occupying core $COREID - $LAST"
prompt "Do you wish to continue?"

if test ! -d "$WORKDIR" || test -z "$(ls -A $WORKDIR)"; then
    if test "$(echo $WORKDIR | head -c 1)" != "/"; then
        error "WORKDIR must be an absoluted path!"
    fi
else
    prompt "WORKDIR exists and not empty! Do you wish to continue?"
fi

for I in $(seq $REPEAT); do
    for FUZZER in $FUZZERS; do
        for BIN in $BINS; do
            . $(dirname $0)/run_single.sh
            COREID=$(($COREID + 1))
        done
    done
done

cp $(dirname $0)/configrc $WORKDIR/configrc
info "Configuration file written to $WORKDIR/configrc"
info "Run docker ps to check for running containers."
info "Run docker logs -f FUZZER-BIN-INDEX to view fuzzer output."
info "Run docker exec -it FUZZER-BIN-INDEX /bin/bash to ssh into container."
