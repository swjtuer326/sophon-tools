#!/bin/bash

product=$(cat /sys/bus/i2c/devices/1-0017/information 2> /dev/null | grep model | awk -F \" '{print $4}')
seNCtrl_DEBUG_UART=""
se_files=($(sudo find /root -maxdepth 1 -type d -name 'se*' -exec find {} -maxdepth 1 -type f -name 'se*ctr.sh' \;))
export seNCtrl_SENCRT_PATH="${se_files[0]}"
if [ "$seNCtrl_SENCRT_PATH" = "" ]; then echo "cannot find sectr, exit"; exit -1; fi
fileName=$(basename "$seNCtrl_SENCRT_PATH")
seNCtrl_SENCRT_HEADER="${fileName%%.sh}"
seNCtrl_SUB_IP_HALF=""
seNCtrl_HOST_SUB_ETHS=()
if [ "$product" = "SE6-CTRL" ] || [ "$product" = "SE6 CTRL" ] || [ "$product" = "SM7 CTRL" ] || [ "$product" = "SE8 CTRL" ]; then
    seNCtrl_HOST_SUB_ETHS+=('eth0' 'eth1')
    seNCtrl_DEBUG_UART=/dev/ttyS2
    
else #se8 x86
    seNCtrl_HOST_SUB_ETHS+=('eno1' 'enp2s0f0' 'bond0')
    seNCtrl_DEBUG_UART=/dev/ttyS1
fi
for eth in "${seNCtrl_HOST_SUB_ETHS[@]}"; do
    seNCtrl_SUB_IP_HALF=$(ifconfig "$eth" 2> /dev/null | grep "inet "|awk '{print $2}'|awk -F . '{printf("%d.%d\n", $1,$2)}')
    if [ -n "$seNCtrl_SUB_IP_HALF" ]; then break; fi
done
if [ "$seNCtrl_SUB_IP_HALF" = "" ]; then echo "cannot get ip to core, exit"; ifconfig; exit -1; fi
source <(sed 's/172\.16/${seNCtrl_SUB_IP_HALF}/g' ${seNCtrl_PWD}/configs/sub/subInfo.12)
sudo chmod 777 ${seNCtrl_DEBUG_UART}
if [ ! -e "${seNCtrl_PWD}/configs/subNANInfo" ]; then
    echo "init info not, make it..."
    sudo touch ${seNCtrl_PWD}/configs/subNANInfo
    sudo chmod 777 ${seNCtrl_PWD}/configs/subNANInfo
    for ((id = 1; id <= $seNCtrl_ALL_SUB_NUM; id++)); do
        ret=$(sudo bash -c "source ${seNCtrl_SENCRT_PATH}; ${seNCtrl_SENCRT_HEADER}_get_aiu_pg ${id} 2> /dev/null;")
        ret=$(echo "$ret" | tail -n 1)
        if [[ "$ret" =~ ^[0-9]+$ && "$ret" -ge 1 ]]; then
            echo "core ${id} is power good"
        else
            echo "core ${id} is not power good"
            echo "${id}" >> ${seNCtrl_PWD}/configs/subNANInfo
        fi
    done
fi

while IFS= read -r id || [[ -n "$id" ]]; do
    if [[ "$id" =~ ^[0-9]+$ &&  id -ge 1 &&  id -le $seNCtrl_ALL_SUB_NUM ]]; then
        seNCtrl_ALL_SUB_IP_ID["${seNCtrl_ALL_SUB_IP[$(($id - 1))]}"]=""
        seNCtrl_ALL_SUB_IP[$(($id - 1))]="NAN"
    fi
done < "${seNCtrl_PWD}/configs/subNANInfo"
