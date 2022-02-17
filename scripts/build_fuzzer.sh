#!/usr/bin/env bash

set -euxo pipefail

cd dockerized_fuzzing

docker build base --tag unifuzz_base
docker build fuzz_cov_base --tag fuzz_cov_base

for fuzzer in valkyrie valkyrie-br valkyrie-solver aflplusplus angora afl
do
    docker build $fuzzer --tag $fuzzer &
done
wait