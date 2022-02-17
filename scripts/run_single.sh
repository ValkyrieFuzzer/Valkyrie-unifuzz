#!/bin/sh

# ENV
# -- FUZZER
# -- BIN
# -- COREID
# -- WORKDIR
# -- DURATION
# -- COV = final, live, plot
# -- FUZZARGS

. $(dirname $0)/common.sh

: ${TAG:=latest}

if test -z "$WORKDIR" || test -z "$FUZZER" || test -z "$BIN"; then
    error "Environment variables WORKDIR, FUZZER, BIN must be set!"
fi

if test "$(echo $WORKDIR | head -c 1)" != "/"; then
    error "WORKDIR must be an absoluted path!"
fi

if test -z $COREID; then
    COREID=0
    warn "COREID not set... Setting to $COREID by default"
fi

if test -z $DURATION; then
    DURATION=10m
    warn "DURATION not set... Setting to $DURATION by default"
fi

INDEX=0
while test -d $WORKDIR/$FUZZER/$BIN/$INDEX; do
    INDEX=$(($INDEX + 1))
done

mkdir -p $WORKDIR/$FUZZER/$BIN
NAME="$FUZZER-$BIN-$INDEX"

if test -n "$(docker ps -q -f name=$NAME)"; then
    error "Container $NAME still running!"
elif test -n "$(docker ps -aq -f name=$NAME)"; then
    warn "Removing idle container $NAME"
    docker rm $NAME >/dev/null
fi

if test -z "$SEEDS"; then
    SEEDS="/dev/null"
fi

docker run -d \
    -v $UNIFUZZ:/unifuzz \
    -v $WORKDIR/$FUZZER/$BIN/$INDEX:/work \
    -v $SEEDS:/seeds \
    -e FUZZER=$FUZZER \
    -e BIN=$BIN \
    -e COREID=$COREID \
    -e DURATION=$DURATION \
    -e COV=$COV \
    -e FUZZARGS="$FUZZARGS" \
    --name $NAME \
    --ulimit core=0 \
    --shm-size=4gb \
    --cpuset-cpus=$COREID \
    gclang-$FUZZER-bench:$TAG \
    bash -c "/unifuzz/scripts/entrypoint.sh"
