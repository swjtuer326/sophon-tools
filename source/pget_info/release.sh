#!/bin/bash

BUILD_RET=0

echo "build get_info ..."

rm -rf output

mkdir output

cp get_info.sh output/
cp get_info_log_to_png.* output/

exit $BUILD_RET
