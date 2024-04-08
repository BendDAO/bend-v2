#!/bin/bash

# @dev
# This bash script setups the needed artifacts to use
# the @benddao/bend-v2 package as source of deployment
# scripts for testing or coverage purposes.
#
# A separate  artifacts directory was created 
# due at running tests all external artifacts
# located at /artifacts are deleted,  causing
# the deploy library to not find the external
# artifacts. 

echo "[BASH] Setting up testnet environment"

if [ ! "$SKIP_CLEAN" = true ]; then
    # remove hardhat and artifacts cache
    npm run ci:clean

    # compile contracts
    npm run compile
else
    echo "[BASH] Skipping clean & compilation"
fi

# Copy artifacts into separate directory to allow
# the hardhat-deploy library load all artifacts without duplicates 
mkdir -p temp-artifacts
cp -r artifacts/* temp-artifacts

export GIT_COMMIT_HASH=`git rev-parse HEAD | cast to-bytes32`

echo "[BASH] Testnet environment ready"