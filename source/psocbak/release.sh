#!/bin/bash

BUILD_RET=0

echo "build socbak ..."

rm -rf socbak.zip 2&>/dev/null
rm -rf output 2&>/dev/null
mkdir output

if [ -f "$CMD_7Z" ]; then
	echo "found 7z"
	$CMD_7Z a -mx9 socbak.zip socbak
	BUILD_RET=$?
elif [ -f "$CMD_ZIP" ]; then
	echo "found zip"
	$CMD_ZIP -r -9 socbak.zip socbak
	BUILD_RET=$?
else
	echo "Unsatisfied build dependencies"
	BUILD_RET=-1
fi
cp socbak.zip output/

exit $BUILD_RET
