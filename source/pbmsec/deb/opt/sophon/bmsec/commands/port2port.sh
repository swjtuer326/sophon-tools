#!/bin/bash
###############################################
############yuchuan.he@sophgo.com#############
###############################################
userInputOpt="$1"
userInputIP="$2"
userInputSubId="$3"
userInputPort="$4"
userInputcorePort="$5"
userInputprotocol="$6"
if [ -z "$userInputOpt" ]; then
    echo "Enter the opt, default is file [add,del,edit,run,ls]:"
    read userInputOpt
    if [ -z "$userInputOpt" ]; then
        userInputOpt="ls"
    fi
fi
if [[ "$userInputOpt" = "add" || "$userInputOpt" = "del" ]]; then
    if [ -z "$userInputIP" ]; then
        echo "Enter the HOST-IP."
        read userInputIP
        while [ -z "$userInputIP" ]
        do
            echo "Please input the true IP!"
            read userInputIP
        done
    fi
fi

if [ "$userInputOpt" = "add" ]; then
    if [ -z "$userInputSubId" ]; then
        echo "Enter the core id."
        read userInputSubId
        while [ -z "$userInputSubId" ]
        do
            echo "Please input the core id!"
            read userInputSubId
        done
    fi
    if [ -z "$userInputPort" ]; then
        echo "Enter the HOST-PORT"
        read userInputPort
        while [ -z "$userInputPort" ]
        do
            echo "Please input the host port!"
            read userInputPort
        done
    fi
    if [ -z "$userInputcorePort" ]; then
        echo "Enter the CORE-PORT"
        read userInputcorePort
        while [ -z "$userInputcorePort" ]
        do
            echo "Please input the core port!"
            read userInputcorePort
        done
    fi
    if [ -z "$userInputprotocol" ]; then
        echo "Enter the protocol[tcp/udp]"
        read userInputprotocol
        while [ -z "$userInputprotocol" ]
        do
            echo "Please input the protocol!"
            read userInputprotocol
        done
    fi

    echo "Opt : $userInputOpt, Core Id: $userInputSubId, Remote:$userInputcorePort -> Local:$userInputPort"
    if [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 1 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
        if [[ "${seNCtrl_ALL_SUB_IP[$(($userInputSubId - 1))]}" == "NAN" ]]; then echo "cannot support core Id:$userInputSubId"; return 0; fi
        userInputSubIds=$(($userInputSubId - 1))
        sudo iptables -t nat -A PREROUTING -d $userInputIP -p $userInputprotocol --dport $userInputPort -j DNAT --to-destination ${seNCtrl_ALL_SUB_IP[$userInputSubIds]}:$userInputcorePort
        if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" error, exit!"; exit 1; fi
    else
        echo "error arg:  $userInputSubId"
    fi
elif [ "$userInputOpt" = "del" ]; then
    if [ -z "$userInputSubId" ]; then
        echo "Enter the core id."
        read userInputSubId
        while [ -z "$userInputSubId" ]
        do
            echo "Please input the core id!"
        done
    fi
    if [ -z "$userInputPort" ]; then
        echo "Enter the HOST-PORT"
        read userInputPort
        while [ -z "$userInputPort" ]
        do
            echo "Please input the port!"
        done
    fi
    if [ -z "$userInputcorePort" ]; then
        echo "Enter the CORE-PORT"
        read userInputcorePort
        while [ -z "$userInputcorePort" ]
        do
            echo "Please input the core port!"
        done
    fi
    if [ -z "$userInputprotocol" ]; then
        echo "Enter the protocol[tcp/udp]"
        read userInputprotocol
        while [ -z "$userInputprotocol" ]
        do
            echo "Please input the protocol!"
            read userInputprotocol
        done
    fi
    echo "Opt : $userInputOpt, Core Id: $userInputSubId, Remote:$userInputcorePort -> Local:$userInputPort"
    if [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 1 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
        if [[ "${seNCtrl_ALL_SUB_IP[$(($userInputSubId - 1))]}" == "NAN" ]]; then echo "cannot support core Id:$userInputSubId"; return 0; fi
        userInputSubIds=$(($userInputSubId - 1))
        sudo iptables -t nat -D PREROUTING -d $userInputIP -p $userInputprotocol --dport $userInputPort -j DNAT --to-destination ${seNCtrl_ALL_SUB_IP[$userInputSubIds]}:$userInputcorePort
        if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" error, exit!"; exit 1; fi
    else
        echo "error arg:  $userInputSubId"
    fi
elif [ "$userInputOpt" = "run" ]; then
    echo "Opt : $userInputOpt"
    file="${seNCtrl_PWD}/configs/port.conf"
    line_number=0

    # 逐行读取文件
    while IFS= read -r line; do
        if [[ ${line:0:1} == "#" ]]; then
            continue
        fi
        ((line_number++))
        if [ -z "$line" ]; then
            break
        fi
        read -r coreid coreport port protocol ethname<<< "$line"
        if [[ ! $coreid =~ ^[0-9]+$ || ! $coreport =~ ^[0-9]+$ || ! $port =~ ^[0-9]+$  || "$port" -gt 65535 || "$coreport" -gt 65535 ]]; then
            echo "Line $line_number is not in the correct format."
            continue
        else
            message=$(sudo netstat -tuln | grep "$port")
            if [ -n "$userInputcorePort" ]; then
                    echo "Port $port is occupied."
                    continue
            fi
            Default_Ip=$(ifconfig $ethname | grep "inet "|awk '{print $2}' )
            if [[ "$coreid" =~ ^[0-9]+$ &&  coreid -ge 1 &&  coreid -le $seNCtrl_ALL_SUB_NUM ]]; then
                if [[ "${seNCtrl_ALL_SUB_IP[$(($coreid - 1))]}" == "NAN" ]]; then echo "cannot support core Id:$coreid"; continue; fi
                coreid=$(($coreid - 1))
                sudo iptables -t nat -A PREROUTING -d $Default_Ip -p $protocol --dport $port -j DNAT --to-destination ${seNCtrl_ALL_SUB_IP[$coreid]}:$coreport
                if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" error, exit!"; exit 1; fi
            else
                echo "error arg:  $coreid"
            fi
        fi


        echo "core id: $coreid, core port: $coreport -> local port: $port"
    done < "$file"
elif [ "$userInputOpt" = "ls" ]; then
    cmd="sudo iptables -t nat -nvL"
    printf "%-5s%-17s%-13s%-22s%-13s\n" "TYPE" "HOST-IP" "HOST-PORT" "(CORE-IP ID)" "CORE-PORT"
    while IFS= read -r -d $'\n' rule; do
        prot=$(echo "$rule" | awk '{print $4}')
        destination=$(echo "$rule" | awk '{print $9}')
        port=$(echo "$rule" | awk -F 'dpt' '{print $2}' | awk -F ' ' '{print $1}' | cut -d':' -f2- )
        ip=$(echo "$rule" | awk -F 'to:' '{print $2}' | awk -F ':' '{print $1}')
        port2=$(echo "$rule" | awk -F 'to:' '{print $2}' | awk -F ':' '{print $2}')
        if [[ -z $prot ]];then
            break
        fi
        if [ ! -v seNCtrl_ALL_SUB_IP_ID["$ip"] ]; then
            continue
        fi
        coreId=${seNCtrl_ALL_SUB_IP_ID[${ip}]}
        if [[ "$coreId" != "" ]]; then
            printf "%-5s%-17s%-13s%-22s%-13s\n" "$prot" "$destination" "$port" "($ip $coreId)" "$port2"
        fi
    done < <($cmd)
    echo "$message"
elif [ "$userInputOpt" = "edit" ]; then
    rm -rf ./*.swp
    vim ${seNCtrl_PWD}/configs/port.conf
else
    echo "error arg:  $userInputOpt"
fi

