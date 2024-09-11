#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

# 10:27:33 172.16.140.12 //system.3-of-15.gz
seNCtrl_TFTPD_LOG=$(bash -c "$seNCtrl_CHECK_TFTP_LOG | awk '{print \$3,\$8,\$10}'")
#echo "$seNCtrl_TFTPD_LOG"
declare -A progress_dict
while read -r line; do
    time=$(echo "$line" | awk '{print $1}')
    ip=$(echo "$line" | awk '{print $2}')
    filename=$(echo "$line" | awk '{print $3}')
    if [[ $filename =~ ([0-9]+)-of-([0-9]+).gz ]]; then
        current=$((${BASH_REMATCH[1]}))
        total=$((${BASH_REMATCH[2]}))
        progress=$((current * 100 / total))
        filename=$(echo "$filename" | sed 's/.*\///;s/\..*//')
        if [[ "$filename" == "boot" ]] && [[ "$progress" == "100" ]]; then
            progress_dict["$ip"]="[${time}] update 100%"
        else
            progress_dict["$ip"]="[${time}] $filename -> $progress%"
        fi
    elif [[ ! -z "$filename" ]]; then
        filename=$(echo "$filename" | sed 's/.*\///;s/\..*//')
        progress_dict["$ip"]="[${time}] $filename -> 100%"
    fi
done <<< "$seNCtrl_TFTPD_LOG"

echo -e "ID\tIP\t\t\tINFO"
for ((i = 0; i < $seNCtrl_ALL_SUB_NUM; i++)); do
    if [[ "${seNCtrl_ALL_SUB_IP[$i]}" == "NAN" ]]; then continue; fi
    echo -e "$(($i + 1))\t${seNCtrl_ALL_SUB_IP[$i]}\t${progress_dict["${seNCtrl_ALL_SUB_IP[$i]}"]}"
done
