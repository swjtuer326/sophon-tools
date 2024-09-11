#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

userInputSubId=""
if [ $# -eq 1 ]; then
    userInputSubId="$1"
else
    echo "Enter the core id for connect with ssh, default is 1:"
    read userInputSubId
    if [ -z "$userInputSubId" ]; then
        userInputSubId="1"
    fi
fi
echo "Ssh To Core Id: $userInputSubId"
if [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 0 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
    if [[ "${seNCtrl_ALL_SUB_IP[$(($userInputSubId - 1))]}" == "NAN" ]]; then echo "cannot support core Id:$userInputSubId"; return 0; fi
    userInputSubIds=$(($userInputSubId - 1))
    export SSHPASS=${seNCtrl_ALL_SUB_PASSWORD[$userInputSubIds]}
    ssh-keygen -R ${seNCtrl_ALL_SUB_IP[$userInputSubIds]} &> /dev/null
    ${seNCtrl_SSH} ${seNCtrl_ALL_SUB_USER[$userInputSubIds]}@${seNCtrl_ALL_SUB_IP[$userInputSubIds]} -p ${seNCtrl_ALL_SUB_PORT[$userInputSubIds]}
    unset SSHPASS
else
    echo "error arg:  $userInputSubId"
fi
