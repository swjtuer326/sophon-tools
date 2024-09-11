#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

#考虑到升级流程的重要性，不采用多进程升级，各个算力板逐个升级
function updateFun(){
    ${seNCtrl_PWD}/bmsec pf "$1" "/recovery/tftp/spi_flash.bin" "/data/spi_flash.bin"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    ${seNCtrl_PWD}/bmsec pf "$1" ${seNCtrl_PWD}/binTools/flash_update /data/flash_update
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    file_size=$(stat -c %s "/recovery/tftp/spi_flash.bin")
    file_size_mb=$((file_size / 1024 / 1024))
    flash_update_cmd=""
    if [ $file_size_mb -gt 2 ]; then
        flash_update_cmd="sudo /data/flash_update -i /data/spi_flash.bin -b 0x6000000"
    else
        flash_update_cmd="sudo /data/flash_update -f /data/spi_flash.bin -b 0x6000000"
    fi
    ${seNCtrl_PWD}/bmsec run "$1" "sudo chmod +x /data/flash_update;${flash_update_cmd}"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    ${seNCtrl_PWD}/bmsec run "$1" "/home/linaro/tftp_update/mk_bootscr.sh;sudo sync"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    ${seNCtrl_PWD}/bmsec run "$1" "sudo reboot" &> /dev/null
    return 0
}

userInputSubId=""
seNCtrl_ALL_SUB_RUNS=()
if [ $# -eq 1 ]; then
    userInputSubId="$1"
else
    echo "Enter the core id for echo debug uart, default is all:"
    read userInputSubId
    if [ -z "$userInputSubId" ]; then
        echo "error arg:  $userInputSubId"
        exit 0
    fi
fi
if [[ "$userInputSubId" =~ ^[0-9]+(\+[0-9]+)+$ ]]; then
  IFS=$seNCtrl_MULTIPLE_SEPARATOR read -ra seNCtrl_ALL_SUB_RUNS <<< "$userInputSubId"
  userInputSubId=all
fi
echo "update Id: $userInputSubId"
sudo chmod -R 777 /recovery/tftp
if [ "$userInputSubId" == "all" ]; then
    for ((i = 0; i < $seNCtrl_ALL_SUB_NUM; i++)); do
        if [[ "${seNCtrl_ALL_SUB_IP[$i]}" == "NAN" ]]; then continue; fi
        if [ ${#seNCtrl_ALL_SUB_RUNS[@]} -gt 0 ] && [[ ! " ${seNCtrl_ALL_SUB_RUNS[*]} " =~ " $(($i+1)) " ]]; then continue; fi
        echo "start update $(($i + 1))..."
        updateFun $(($i + 1))
    done
elif [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 1 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
    if [[ "${seNCtrl_ALL_SUB_IP[$(($userInputSubId - 1))]}" == "NAN" ]]; then echo "cannot support core Id:$userInputSubId"; return 0; fi
    updateFun "$userInputSubId"
else
    echo "error arg:  $userInputSubId"
fi
