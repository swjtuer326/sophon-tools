#!/bin/bash

BUILD_RET=0

echo "build ota_update ..."

rm -rf output 2>/dev/null
mkdir output

cp ota_update.sh output/

exit $BUILD_RET
