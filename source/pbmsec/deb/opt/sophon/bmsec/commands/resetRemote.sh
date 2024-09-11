#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

userInputSubId=""
seNCtrl_ALL_SUB_RUNS=()
if [ $# -eq 1 ]; then
    userInputSubId="$1"
else
    echo "Enter the core id to reset power:"
    read userInputSubId
fi
echo "Reset Core Id: $userInputSubId"
if [[ "$userInputSubId" =~ ^[0-9]+(\+[0-9]+)+$ ]]; then
  IFS=$seNCtrl_MULTIPLE_SEPARATOR read -ra seNCtrl_ALL_SUB_RUNS <<< "$userInputSubId"
  userInputSubId=all
fi
if [[ "$userInputSubId" == "all" ]]; then
    for ((i = 1; i <= $seNCtrl_ALL_SUB_NUM; i++)); do
        if [ ${#seNCtrl_ALL_SUB_RUNS[@]} -gt 0 ] && [[ ! " ${seNCtrl_ALL_SUB_RUNS[*]} " =~ " $i " ]]; then continue; fi
        sudo -i <<EOF
source "${seNCtrl_SENCRT_PATH}"
${seNCtrl_SENCRT_HEADER}_set_reset "${i}"
EOF
    done
elif [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 0 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
    sudo -i <<EOF
source "${seNCtrl_SENCRT_PATH}"
${seNCtrl_SENCRT_HEADER}_set_reset "${userInputSubId}"
EOF
else
    echo "error arg:  $userInputSubId"
fi

