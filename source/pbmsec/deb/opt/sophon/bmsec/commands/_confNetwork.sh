#!/bin/bash
###############################################
############junjie.liu@sophgo.com##############
###############################################

# Some vars come from 1_network.sh
# config netplan of host
CORE_NETPLAN_FILE="$YAML_FILE"
CORE_NETPLAN_FILE_BAK="/etc/netplan/netcfg.yaml.bak"

SUB_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
SUB_NETPLAN_FILE_BAK="/etc/netplan/01-netcfg.yaml.bak"
iptable_setup="/root/se_ctrl/iptable_setup.sh"

ret=$(sudo bash -c "source /root/se_ctrl/sectr.sh;sectr_get_auth")
if [ $ret -eq 0 ]; then
    echo "开机初始化中，请等待几分钟再执行该命令"
    exit 0
fi

if [[ ! -f "$CORE_NETPLAN_FILE" ]]; then
    echo "error: file '$CORE_NETPLAN_FILE' does not exist"
    exit 1
fi

usage() {
    echo "usage: $1 [OPTIONS]"
    echo "OPTIONS:"
    echo "  -h , HELP INFO"
    echo "  0 , delete bridge config"
    echo "  1 , config bridge mode"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        0)
            echo "delete bridges config..."
            mode=0
            ;;
        1)
            echo "config bridges..."
            mode=1
            ;;
        *)
            echo "Error: invalid args '$1'" >&2
            usage
            ;;
    esac
    shift
done

function reset_network()
{   
    echo "reset network config of all cores"
    for ((id = 1; id <= $seNCtrl_ALL_SUB_NUM; id++)); do
        file_name=$(basename "$SUB_NETPLAN_FILE_BAK")
        ret=$(${seNCtrl_PWD}/bmsec run $id "ls /etc/netplan/" | grep $file_name)
        # echo $ret
        if [[ -n "$ret" ]]; then
            ${seNCtrl_PWD}/bmsec run $id "sudo chmod 777 $SUB_NETPLAN_FILE_BAK" &> /dev/null
            ${seNCtrl_PWD}/bmsec run $id "sudo mv $SUB_NETPLAN_FILE_BAK $SUB_NETPLAN_FILE" &> /dev/null
            ${seNCtrl_PWD}/bmsec run $id "sudo netplan apply" &> /dev/null
        else
            echo "Warning: The file $SUB_NETPLAN_FILE_BAK in core $id does not exist. Please reboot core $id"
        fi
    done

    sudo chmod 777 ${seNCtrl_PWD}/configs/sub/subInfo.12
    sudo sed -i 's/Bridge_CONFIG_FLAG=1/Bridge_CONFIG_FLAG=0/' ${seNCtrl_PWD}/configs/sub/subInfo.12
    sudo sed -i '/^Bridge_IP_HALF=/d' ${seNCtrl_PWD}/configs/sub/subInfo.12
    
    if grep -q "bridges:" "$CORE_NETPLAN_FILE"; then
        echo "reset host netplan config..."
        if [[ -f "$CORE_NETPLAN_FILE_BAK" ]]; then
            sudo chmod 777 $CORE_NETPLAN_FILE_BAK
            sudo mv $CORE_NETPLAN_FILE_BAK $CORE_NETPLAN_FILE
            sudo netplan apply
        else
            sudo cat $CORE_NETPLAN_FILE
            echo "error: $CORE_NETPLAN_FILE_BAK in host does not exist!!! Please modify your $CORE_NETPLAN_FILE of host by yourself!"
        fi
    fi
    # reset iptable_setup.sh
    sudo chmod 777 $iptable_setup
    sudo sed -i '/^wanname=br0/d; s/^#wanname=/wanname=/' "$iptable_setup"
    if ! [ "$product" = "SE6-CTRL" ] && [ "$product" = "SE6 CTRL" ] && [ "$product" = "SM7 CTRL" ] && [ "$product" = "SE8 CTRL" ]; then
        sudo $iptable_setup > /dev/null 2>&1
    fi
    echo "please reboot!"
}

function conf_bridge()
{   
    sudo chmod 777 ${seNCtrl_PWD}/configs/sub/subInfo.12
    if grep -q "Bridge_IP_HALF=" "${seNCtrl_PWD}/configs/sub/subInfo.12"; then
        sudo sed -i "s/^Bridge_IP_HALF=.*/Bridge_IP_HALF=$seNCtrl_SUB_IP_HALF/" "${seNCtrl_PWD}/configs/sub/subInfo.12"
    else
        sudo echo "Bridge_IP_HALF=$seNCtrl_SUB_IP_HALF" >> "${seNCtrl_PWD}/configs/sub/subInfo.12"
    fi
    sudo sed -i 's/Bridge_CONFIG_FLAG=0/Bridge_CONFIG_FLAG=1/' ${seNCtrl_PWD}/configs/sub/subInfo.12

    # set all cores as DHCP mode while still retain original ip addr for bmsec
    for ((id = 1; id <= $seNCtrl_ALL_SUB_NUM; id++)); do
        file_name=$(basename "$SUB_NETPLAN_FILE_BAK")
        ret=$(${seNCtrl_PWD}/bmsec run $id "ls /etc/netplan/" | grep $file_name)
        if [[ -n "$ret" ]]; then
            echo "The file $SUB_NETPLAN_FILE_BAK in core $id exists."
        else
            ${seNCtrl_PWD}/bmsec run $id "sudo cp $SUB_NETPLAN_FILE $SUB_NETPLAN_FILE_BAK" &> /dev/null
        fi
    done
    
    # ${seNCtrl_PWD}/bmsec getbi
    echo "set all cores as DHCP MODE!"
    ${seNCtrl_PWD}/bmsec run all "sudo chmod 777 $SUB_NETPLAN_FILE" #&> /dev/null
    ${seNCtrl_PWD}/bmsec run all "sudo sed -i 's/dhcp4: no/dhcp4: yes/' $SUB_NETPLAN_FILE" &> /dev/null
    ${seNCtrl_PWD}/bmsec run all "sudo sed -i '/gateway4:/d' $SUB_NETPLAN_FILE" &> /dev/null
    ${seNCtrl_PWD}/bmsec run all "sudo netplan apply" &> /dev/null
    # ${seNCtrl_PWD}/bmsec run all "sudo cat $SUB_NETPLAN_FILE" 

    # config host netplan
    if ! grep -q "bridges:" "$CORE_NETPLAN_FILE"; then
        echo "setting bridges in netplan yaml file..."
        if [[ ! -f "$CORE_NETPLAN_FILE_BAK" ]]; then
            echo "backup $CORE_NETPLAN_FILE"
            sudo cp $CORE_NETPLAN_FILE $CORE_NETPLAN_FILE_BAK
        fi
        sudo chmod 777 $CORE_NETPLAN_FILE
        if [[ "$WAN" == "eno5" ]]; then
        #se8-288
        BRIDGE_BLOCK=$(cat << EOF
  bridges:
                br0:
                        interfaces: [$WAN, $INTERFACE_0, $INTERFACE_1]
                        dhcp4: yes
                        addresses: [192.168.150.3/24, $seNCtrl_SUB_IP_0/24, $seNCtrl_SUB_IP_1/24]
                        nameservers:
                                addresses: [8.8.8.8]
EOF
)
        else
        BRIDGE_BLOCK=$(cat << EOF
        bridges:
                br0:
                        interfaces: [$WAN, $INTERFACE_0, $INTERFACE_1]
                        dhcp4: yes
                        addresses: [192.168.150.3/24, $seNCtrl_SUB_IP_0/24, $seNCtrl_SUB_IP_1/24]
                        nameservers:
                                addresses: [8.8.8.8]
EOF
)
        fi
        TEMP_FILE=$(mktemp /tmp/01-netcfg.yaml.tmp.XXXXXX) || { echo "can not create temp file"; exit 1; }

        while IFS= read -r line; do
            echo "$line" >> "$TEMP_FILE"
            # insert bridges config after renderer
            if [[ $line =~ renderer:[[:space:]]* ]]; then
                # insert bridges config block
                echo "$BRIDGE_BLOCK" >> "$TEMP_FILE"
            fi
        done < "$CORE_NETPLAN_FILE"
        sudo mv "$TEMP_FILE" "$CORE_NETPLAN_FILE" || { echo "can not modify netplan yaml file"; rm -f "$TEMP_FILE"; exit 1; }

        # set ip addr of eth0/1 as NULL
        sudo sed -i "/$INTERFACE_0:/,/optional: yes/ {
            s/addresses: \[[^]]*\]/addresses: []/
        }" $CORE_NETPLAN_FILE

        sudo sed -i "/$INTERFACE_1:/,/optional: yes/ {
            s/addresses: \[[^]]*\]/addresses: []/
        }" $CORE_NETPLAN_FILE
        
        echo "config netplan..."
        sudo netplan apply
        if [ $? -ne 0 ]; then
            sudo cat $CORE_NETPLAN_FILE
            echo "Error: netplan apply failed. Please check your netplan yaml file!"
            exit 1
        fi
    fi

    # update wanname in iptable_setup.sh
    # iptable_setup="/root/se_ctrl/iptable_setup.sh"
    if ! sudo grep -q '^wanname=br0' "$iptable_setup"; then
        sudo chmod 777 $iptable_setup
        sudo sed -i '/^wanname=/ s/^/#/' "$iptable_setup"
        sudo sed -i '/^#wanname=/a wanname=br0' "$iptable_setup"
        echo "Update completed: 'wanname=br0' added."
    else
        echo "wanname is br0."
    fi

    PID=$(ps -ef | grep "[b]ash $iptable_setup" | awk '{print $2}')
    if [ -n "$PID" ]; then
        sudo kill "$PID"
        # echo "kill iptable_setup.sh"
    fi
    sudo iptables -P FORWARD ACCEPT
    
}


if [ "$mode" -eq 0 ]; then
    echo "Mode is set to 0"
    reset_network
elif [ "$mode" -eq 1 ]; then
    echo "Mode is set to 1"
    conf_bridge
fi