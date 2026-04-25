#!/bin/bash

set -eu

###############################
# application-specific
IMAGE_NAME=atk-logic
FILEPATH=/atk-logic/ATK-Logic
###############################
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if ! [ -f libsigrokdecode.a ]; then
    # build libsigrokdecode.a
    rm -rf atk_libsigrokdecode
    git clone https://github.com/bieganski/atk_libsigrokdecode
    pushd atk_libsigrokdecode >/dev/null
    ./gen_libsigrokdecode_a.sh
    cp libsigrokdecode.a ../
    popd > /dev/null
fi

# build atk-logic from the local workspace, using previously built libsigrokdecode.a
docker build --no-cache -t $IMAGE_NAME $SCRIPT_DIR

id=$(docker create $IMAGE_NAME)
docker cp $id:$FILEPATH `basename $FILEPATH`
docker rm -v $id
