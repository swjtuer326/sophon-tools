#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

# 使用说明：本功能适用于算力节点可以进入uboot阶段但是不能正常启动的状态进行刷机操作

userInputNeedUpdate=""
userInputOtp_path=""
uartUpdateInfo='if test -n ${ramdisk_addr_b}; then echo "runtime is new value"; else echo "runtime is old value"; set ramdisk_addr_b 0x310400000;set ramdisk_addr_r 0x310000000;set scriptaddr 0x300040000;setenv unzip_addr 0x320000000;setenv chip_type "bm1684";fi;'
if [ $# -eq 1 ]; then
    userInputNeedUpdate="$1"
elif [ $# -eq 2 ]; then
    userInputNeedUpdate="$1"
    userInputOtp_path="$2"
else
    echo "Enter the core id to update:"
    read userInputNeedUpdate
fi
if [[ "$userInputNeedUpdate" == "" ]]; then
    echo "ERROR: userInputNeedUpdate:$userInputNeedUpdate, exit"
    return 1
fi
echo "Update To Core Id: $userInputNeedUpdate"
sudo chmod -R 777 /recovery/tftp
if [[ "$userInputNeedUpdate" =~ ^[0-9]+$ &&  userInputNeedUpdate -ge 0 && userInputNeedUpdate -le $seNCtrl_ALL_SUB_NUM ]]; then
    sudo -i <<EOF
source "${seNCtrl_SENCRT_PATH}"
${seNCtrl_SENCRT_HEADER}_switch_uart "${userInputNeedUpdate}"
EOF
    ${seNCtrl_PWD}/binTools/killPros ${seNCtrl_DEBUG_UART} &> /dev/null
    ${seNCtrl_PWD}/bmsec reset $userInputNeedUpdate
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    sudo stty -F ${seNCtrl_DEBUG_UART} 115200 cs8 -cstopb -parenb
    uartGetUbootFlag=0
    uartGetBL2Flag=0
    uartGetBL31Flag=0
    while read -r line; do
        if [[ "$line" == *"BL1: Booting BL2"* ]]; then
            echo "[INFO] BL2 booting..."
            uartGetBL2Flag=1
        elif [[ "$line" == *"BL1: Booting BL31"* ]]; then
            echo "[INFO] BL31 booting..."
            uartGetBL31Flag=1
        elif [[ "$line" == *"bm1684#"* ]]; then
            uartGetUbootFlag=$((${uartGetUbootFlag} + 1))
            echo "[INFO] get uboot terminal count: ${uartGetUbootFlag}"
        fi

        if [[ $uartGetUbootFlag -gt 10 ]]; then
            echo "[INFO] get uboot terminal, start update process"
            break
        fi
        if [[ "$uartGetBL2Flag" == "1" ]] || [[ "${uartGetBL31Flag}" == "1" ]]; then
            printf "\r\n" > "${seNCtrl_DEBUG_UART}"
        fi
        sleep 0.01
    done < "${seNCtrl_DEBUG_UART}"
    printf "\r\n" > "${seNCtrl_DEBUG_UART}"
    sleep 1
    echo $uartUpdateInfo > "${seNCtrl_DEBUG_UART}"
    sleep 1
    echo "printenv" > "${seNCtrl_DEBUG_UART}"
    sleep 1
    userInputSubIds=$(($userInputNeedUpdate - 1))
    echo "setenv ota_path ${userInputOtp_path}; setenv ipaddr ${seNCtrl_ALL_SUB_IP[$userInputSubIds]};setenv serverip $(echo "${seNCtrl_ALL_SUB_IP[$userInputSubIds]}" | awk -F'.' '{OFS="."} {$NF=200} 1'); setenv update_all 1;setenv reset_after 1;i2c dev 1; i2c mw 0x69 1 0;tftp \${scriptaddr} /\$ota_path/boot.scr;source \${scriptaddr}" > "${seNCtrl_DEBUG_UART}"
    while read -r line; do
        echo "$line"
        if [[ "$line" == *"SPI flash update done"* ]]; then
            echo "[INFO] This core(${userInputNeedUpdate}) is update..."
            break
        fi
    done < "${seNCtrl_DEBUG_UART}"
else
    echo "error arg:  $userInputNeedUpdate"
    return 1
fi
