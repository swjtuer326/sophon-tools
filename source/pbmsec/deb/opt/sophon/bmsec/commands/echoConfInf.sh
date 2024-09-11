#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

iptables_output=$(sudo iptables -t nat -nL | grep -E 'DNAT.*tcp.*:22$')
declare -A seNCtrl_ALL_SUB_EXT_SSH_PORT
while IFS= read -r line
do
    port=$(echo "$line" | sed -n 's/.*dpt:\([0-9]\+\).*/\1/p')
    ip=$(echo "$line" | sed -n 's/.*to:\([0-9.]\+\):22.*/\1/p')
    if [[ "$port" != "" ]] && [[ "$ip" != "" ]]; then
        seNCtrl_ALL_SUB_EXT_SSH_PORT["$ip"]=$port
    fi
done <<< "$iptables_output"

echo "config info: "
for ((i = 0; i < $seNCtrl_ALL_SUB_NUM; i++)); do
    if [[ "${seNCtrl_ALL_SUB_IP[$i]}" == "NAN" ]]; then continue; fi
    echo "$(($i + 1)). ${seNCtrl_ALL_SUB_USER[$i]}:${seNCtrl_ALL_SUB_PASSWORD[$i]}@(${seNCtrl_ALL_SUB_IP[$i]}):${seNCtrl_ALL_SUB_PORT[$i]} -> ${seNCtrl_ALL_SUB_EXT_SSH_PORT[${seNCtrl_ALL_SUB_IP[$i]}]}"
done
