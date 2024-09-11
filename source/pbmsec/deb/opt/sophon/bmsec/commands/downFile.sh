#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

userInputSubId=""
userInputRemote=""
userInputLocal=""
seNCtrl_ALL_SUB_RUNS=()
if [ $# -eq 3 ]; then
    userInputSubId="$1"
    userInputRemote="$2"
    userInputLocal="$3"
else
    echo "Enter the core id for down file, default is all:"
    read userInputSubId
    if [ -z "$userInputSubId" ]; then
        userInputSubId="all"
    fi
    echo "Enter the remote file:"
    read userInputRemote
    echo "Enter the local file:"
    read userInputLocal
fi
if [[ "$userInputSubId" =~ ^[0-9]+(\+[0-9]+)+$ ]]; then
  IFS=$seNCtrl_MULTIPLE_SEPARATOR read -ra seNCtrl_ALL_SUB_RUNS <<< "$userInputSubId"
  userInputSubId=all
fi
echo "Core Id: $userInputSubId, Remote:$userInputRemote -> Local:$userInputLocal"
if [ "$userInputSubId" == "all" ]; then
    for ((i = 0; i < $seNCtrl_ALL_SUB_NUM; i++)); do
        if [[ "${seNCtrl_ALL_SUB_IP[$i]}" == "NAN" ]]; then continue; fi
        if [ ${#seNCtrl_ALL_SUB_RUNS[@]} -gt 0 ] && [[ ! " ${seNCtrl_ALL_SUB_RUNS[*]} " =~ " $(($i+1)) " ]]; then continue; fi
        fileName=$(basename "$userInputLocal")
        filePath=$(dirname "$userInputLocal")
        mkdir -p "$filePath"
        echo "=============core$(($i + 1)) to $filePath/$(($i+1))_${fileName}==============="
        export SSHPASS=${seNCtrl_ALL_SUB_PASSWORD[$i]}
        ssh-keygen -R ${seNCtrl_ALL_SUB_IP[$i]} &> /dev/null
        $seNCtrl_SSH_RSYNC "ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=${seNCtrl_SSH_TIMEOUT} -p ${seNCtrl_ALL_SUB_PORT[$i]}" -avP ${seNCtrl_ALL_SUB_USER[$i]}@${seNCtrl_ALL_SUB_IP[$i]}:"$userInputRemote" "$filePath/${i}_${fileName}"
        if [ $? -eq "0" ]; then echo "[BMSEC]:Core $(($i+1)) Run Return Sucess"; else echo "[BMSEC]:Core $(($i+1)) Return Error"; fi
        unset SSHPASS
    done
elif [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 1 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
    if [[ "${seNCtrl_ALL_SUB_IP[$(($userInputSubId - 1))]}" == "NAN" ]]; then echo "cannot support core Id:$userInputSubId"; return 0; fi
    userInputSubIds=$(($userInputSubId - 1))
    export SSHPASS=${seNCtrl_ALL_SUB_PASSWORD[$userInputSubIds]}
    ssh-keygen -R ${seNCtrl_ALL_SUB_IP[$userInputSubIds]} &> /dev/null
    $seNCtrl_SSH_RSYNC "ssh -q -o StrictHostKeyChecking=no -p ${seNCtrl_ALL_SUB_PORT[$userInputSubIds]}" -avP ${seNCtrl_ALL_SUB_USER[$userInputSubIds]}@${seNCtrl_ALL_SUB_IP[$userInputSubIds]}:"$userInputRemote" "$userInputLocal"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" error, exit!"; exit 1; fi
    unset SSHPASS
else
    echo "error arg:  $userInputSubId"
fi

