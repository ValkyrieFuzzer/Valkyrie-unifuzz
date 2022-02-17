#!/usr/bin/env bash

set -euxo pipefail

# Update compiling: all fuzzers starts with a gclang precompiled
# bytecode version of the program to avoid all compiling jargons.
for dir in coverage gclang
do
    docker build unibench_build/${dir} --tag ${dir}-bench
done

for dir in valkyrie valkyrie-br valkyrie-solver angora afl aflplusplus
do
    # Build docker image, which will build all the benchmarks too.
    docker build unibench_build/gclang-${dir} --tag gclang-${dir}-bench & 
done
wait 
