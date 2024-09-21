#!/bin/bash

script_path="$(dirname "$(readlink -f "$0")")"

export CMD_BASH=$(command -v bash)

echo "release start ..."
pushd "$script_path"
	rm output/* -rf
	for dir in source/*/
	do
		echo "release $dir ..."
		pushd "$dir"
			if [ -f release.sh ]; then
				$CMD_BASH release.sh
				if [ -d output ]; then
					cp -r output/* "$script_path/output/" 2>/dev/null
				fi
			else
				echo "[$dir] no have release.sh, cannot auto release"
			fi
		popd
	done

popd
echo "release end"
