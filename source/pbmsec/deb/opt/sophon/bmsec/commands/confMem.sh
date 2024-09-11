#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

userInputSubId=""
optionMem=""
npuSize=""
vpuSize=""
vppSize=""
dtsFile=""
function editMem(){
    ${seNCtrl_PWD}/bmsec run $1 "sudo rm -rf /data/.memEdit; sudo sync;" &> /dev/null
    ${seNCtrl_PWD}/bmsec run $1 "mkdir -p /data/.memEdit" &> /dev/null
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    ${seNCtrl_PWD}/bmsec pf $1 "${seNCtrl_PWD}/binTools/memory_edit*.tar.xz" "/data/.memEdit/memory_edit.tar.xz"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    ${seNCtrl_PWD}/bmsec run $1 "pushd /data/.memEdit; tar -xaf memory_edit.tar.xz" &> /dev/null
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    if [ "$optionMem" == "p" ]; then
        ${seNCtrl_PWD}/bmsec run $1 "if [[ -e /bin/memory_edit.sh || -L /bin/memory_edit.sh && -e \$(readlink -f /bin/memory_edit.sh) ]]; then MEMEDITSHELL=/bin/memory_edit.sh; else MEMEDITSHELL=./memory_edit.sh; fi; pushd /data/.memEdit/memory_edit; \$MEMEDITSHELL -p ${dtsFile}" 2> /dev/null
        ${seNCtrl_PWD}/bmsec run $1 "sudo rm -rf /data/.memEdit; sudo sync;" &> /dev/null
    else
        ${seNCtrl_PWD}/bmsec run $1 "pushd /data/.memEdit/memory_edit; ./memory_edit.sh -c -npu ${npuSize} -vpu ${vpuSize} -vpp ${vppSize} ${dtsFile}" 2> /dev/null
        if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
        ${seNCtrl_PWD}/bmsec run $1 "pushd /data/.memEdit/memory_edit; sudo cp emmcboot.itb /boot/emmcboot.itb" &> /dev/null
        if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
        ${seNCtrl_PWD}/bmsec run $1 "sudo rm -rf /data/.memEdit; sudo sync; sudo reboot" &> /dev/null
    fi
    return 0
}
if [ $# -eq 2 ] || [ $# -eq 3 ]; then
    userInputSubId="$1"
    optionMem="$2"
    dtsFile="$3"
elif [ $# -eq 5 ] || [ $# -eq 6 ]; then
    userInputSubId="$1"
    optionMem="$2"
    npuSize="$3"
    vpuSize="$4"
    vppSize="$5"
    dtsFile="$6"
else
    echo "Enter the core id for memory modification, default is all:"
    read userInputSubId
    if [ -z "$userInputSubId" ]; then
        userInputSubId="all"
    fi
    echo "Enter the operation to perform [p(print memory info)/c(configure memory)]:"
    read optionMem
    if [ "$optionMem" == "p" ]; then
        echo "Perform memory distribution information printing"
    elif [ "$optionMem" == "c" ]; then
        echo "Enter the NPU size for configuration, in decimal MiB units:"
        read npuSize
        echo "Enter the VPU size for configuration, in decimal MiB units:"
        read vpuSize
        echo "Enter the VPP size for configuration, in decimal MiB units:"
        read vppSize
    else
        echo "error arg: $optionMem"
        return -1
    fi
    echo "Enter the specified device tree name, leave it empty for automatic detection:"
    read dtsFile
fi
echo "Core Id: $userInputSubId, option:$optionMem -> npuSize:$npuSize vpuSize:$vpuSize vppSize:$vppSize dtsFile:$dtsFile"
if [ "$userInputSubId" == "all" ] || [[ "$userInputSubId" =~ ^[0-9]+(\+[0-9]+)+$ ]]; then
    editMem "$userInputSubId"
elif [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 1 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
    if [[ "${seNCtrl_ALL_SUB_IP[$(($userInputSubId - 1))]}" == "NAN" ]]; then echo "cannot support core Id:$userInputSubId"; return 0; fi
    editMem "$userInputSubId"
else
    echo "error arg:  $userInputSubId"
fi

