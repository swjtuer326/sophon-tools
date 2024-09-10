#!/bin/bash

script_path="$(dirname "$(readlink -f "$0")")"

export CMD_7Z=$(which 7z)
export CMD_ZIP=$(which zip)
export CMD_BASH=$(which bash)

echo "release start ..."
pushd "$script_path"

	for dir in source/*/
	do
		echo "release $dir ..."
		pushd "$dir"
			$CMD_BASH release.sh
			if [ -d output ]; then
				mv output/* "$script_path/output/" 2&>/dev/null
			fi
		popd
	done

popd
echo "release end"
