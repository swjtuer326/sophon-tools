#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

userInputSubId=""
if [ $# -eq 1 ]; then
    userInputSubId="$1"
else
    echo "Enter the core id for connect debug uart, default is 1:"
    read userInputSubId
    if [ -z "$userInputSubId" ]; then
        userInputSubId="1"
    fi
fi
echo "Uart To Core Id: $userInputSubId"
if [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 0 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
    sudo -i <<EOF
source "${seNCtrl_SENCRT_PATH}"
${seNCtrl_SENCRT_HEADER}_switch_uart "${userInputSubId}"
EOF
    ${seNCtrl_PWD}/binTools/killPros ${seNCtrl_DEBUG_UART} &> /dev/null
    ${seNCtrl_PICOCOM} --send-cmd "sb -vv --ymodem" --receive-cmd "rb -vv --ymodem -E" -b 115200 ${seNCtrl_DEBUG_UART}
    ${seNCtrl_PWD}/binTools/killPros ${seNCtrl_DEBUG_UART} &> /dev/null
else
    echo "error arg:  $userInputSubId"
fi
