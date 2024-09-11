#!/bin/bash

param_count="$#"

qt_batch_deployment_run_path="$(dirname "$(readlink -f "$0")")"

echo "param_count: $param_count"
args=("$@")

if [ "$param_count" -gt 1 ]; then
    ${qt_batch_deployment_run_path}/qt_batch_deployment_no_ui "${args[@]}"
else
    ${qt_batch_deployment_run_path}/qt_batch_deployment "${args[@]}"
fi
