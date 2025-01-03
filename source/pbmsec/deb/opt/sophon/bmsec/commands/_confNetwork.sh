#!/bin/bash
###############################################
############junjie.liu@sophgo.com##############
###############################################

# Some vars come from 1_network.sh
# config netplan of host
CORE_NETPLAN_FILE="$YAML_FILE"
CORE_NETPLAN_FILE_BAK="/etc/netplan/netcfg.yaml.bak"
CONF_YAML="${YAML_FILE/01/09}"

SUB_NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
SUB_NETPLAN_FILE_BAK="/etc/netplan/01-netcfg.yaml.bak"
se_directory=$(dirname "$se_files")
iptable_setup="$se_directory/iptable_setup.sh"

ret=$(sudo bash -c "source $se_files;sectr_get_auth")
if [ -n "$ret" ] && [ $ret -eq 0 ]; then
    echo "[Warning] 开机初始化中，请等待几分钟再执行该命令"
    exit 0
fi

if [[ ! -f "$CORE_NETPLAN_FILE" ]]; then
    echo "[Error] file '$CORE_NETPLAN_FILE' does not exist"
    exit 1
fi

usage() {
    echo "usage: $1 [OPTIONS]"
    echo "OPTIONS:"
    echo "  -h , HELP INFO"
    echo "  0 , default config mode"
    echo "  1 , config bridge mode"
    echo "  2 , config bonding mode"
    echo "  3 , config bridge and bonding mode"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        0)
            echo "[info] default config..."
            mode=0
            ;;
        1)
            echo "[info] config bridges..."
            mode=1
            ;;
        2)
            echo "[info] config bonding..."
            mode=2
            ;;
        3)
            echo "[info] config bridges and bonding..."
            mode=3
	        ;;
        *)
            echo "[Error] invalid args '$1'" >&2
            usage
            ;;
    esac
    shift
done

function conf_core_netplan()
{   
    mode=$1
    sudo chmod 777 $CORE_NETPLAN_FILE

    if [ "$mode" -eq 1 ]; then
        echo "[info] Bridge mode!"
        # BLOCK=$BRIDGE_BLOCK

        # set ip addr of eth0/1 as NULL
        sudo sed -i "/$INTERFACE_0:/,/addresses:/ {
            s/addresses: \[[^]]*\]/addresses: []/
        }" $CORE_NETPLAN_FILE

        sudo sed -i "/$INTERFACE_1:/,/addresses:/ {
            s/addresses: \[[^]]*\]/addresses: []/
        }" $CORE_NETPLAN_FILE

    elif [ "$mode" -eq 2 ]; then
        echo "[info] Bonding mode!"
        # BLOCK=$BOND_BLOCK

        if [[ "$WAN" == "eno5" ]]; then
            #se8-288
            sudo sed -i "/eno5:/,/addresses:/ {
                s/addresses: \[[^]]*\]/addresses: []/
            }" $CORE_NETPLAN_FILE

            sudo sed -i "/eno6:/,/addresses:/ {
                s/addresses: \[[^]]*\]/addresses: []/
            }" $CORE_NETPLAN_FILE
        else
            sudo sed -i "/enp4s0:/,/addresses:/ {
                s/addresses: \[[^]]*\]/addresses: []/
            }" $CORE_NETPLAN_FILE

            sudo sed -i "/enp7s0:/,/addresses:/ {
                s/addresses: \[[^]]*\]/addresses: []/
            }" $CORE_NETPLAN_FILE            
        fi

    elif [ "$mode" -eq 3 ]; then
        echo "[info] Bonding and Bridge mode!"
        # BLOCK=$BRIDGE_BOND

        # set ip addr of eth0/1 as NULL
        sudo sed -i "/$INTERFACE_0:/,/addresses:/ {
            s/addresses: \[[^]]*\]/addresses: []/
        }" $CORE_NETPLAN_FILE

        sudo sed -i "/$INTERFACE_1:/,/addresses:/ {
            s/addresses: \[[^]]*\]/addresses: []/
        }" $CORE_NETPLAN_FILE

        if [[ "$WAN" == "eno5" ]]; then
            #se8-288
            sudo sed -i "/eno5:/,/addresses:/ {
                s/addresses: \[[^]]*\]/addresses: []/
            }" $CORE_NETPLAN_FILE

            sudo sed -i "/eno6:/,/addresses:/ {
                s/addresses: \[[^]]*\]/addresses: []/
            }" $CORE_NETPLAN_FILE
        else
            sudo sed -i "/enp4s0:/,/addresses:/ {
                s/addresses: \[[^]]*\]/addresses: []/
            }" $CORE_NETPLAN_FILE

            sudo sed -i "/enp7s0:/,/addresses:/ {
                s/addresses: \[[^]]*\]/addresses: []/
            }" $CORE_NETPLAN_FILE            
        fi

    fi

    if [ ! -e "$CONF_YAML" ]; then
        if [[ "$WAN" == "eno5" ]]; then
            #se8-288
            BRIDGE_BLOCK=$(cat << EOF
# Let NetworkManager manage all devices on this system
network:
  version: 2
  renderer: NetworkManager
  bridges:
                br0:
                        interfaces: [$WAN, $INTERFACE_0, $INTERFACE_1]
                        dhcp4: yes
                        addresses: [192.168.150.3/24, $seNCtrl_SUB_IP_0/24, $seNCtrl_SUB_IP_1/24]
                        nameservers:
                                addresses: [8.8.8.8]
EOF
)

            BOND_BLOCK=$(cat << EOF
# Let NetworkManager manage all devices on this system
network:
  version: 2
  renderer: NetworkManager
  bonds:
                bond0:
                        interfaces: [eno5,eno6]
                        dhcp4: yes
                        addresses: [192.168.150.3/24]
                        nameservers:
                                addresses: [8.8.8.8]
                        parameters:
                                mode: balance-rr
EOF
)

            BRIDGE_BOND=$(cat << EOF
# Let NetworkManager manage all devices on this system
network:
  version: 2
  renderer: NetworkManager
  bonds:
                bond0:
                        interfaces: [eno5,eno6]
                        dhcp4: no
                        addresses: []
                        nameservers:
                                addresses: []
                        parameters:
                                mode: balance-rr
  bridges:
                br0:
                        interfaces: [bond0, $INTERFACE_0, $INTERFACE_1]
                        dhcp4: yes
                        addresses: [192.168.150.3/24, $seNCtrl_SUB_IP_0/24, $seNCtrl_SUB_IP_1/24]
                        nameservers:
                                addresses: [8.8.8.8]
EOF
)
        else

            WAN=$(ip -o -f inet addr show | awk '$2 ~ /^enp/ {print $2}')
            if [ -z "$WAN" ]; then
                echo "[Error] WAN ip is null，please check your network status... or run 'bmsec netconf 0' to reset your network"
                exit 1
            fi
        
            BRIDGE_BLOCK=$(cat << EOF
network:
        version: 2
        renderer: networkd
        bridges:
                br0:
                        interfaces: [$WAN, $INTERFACE_0, $INTERFACE_1]
                        dhcp4: yes
                        addresses: [192.168.150.3/24, $seNCtrl_SUB_IP_0/24, $seNCtrl_SUB_IP_1/24]
                        nameservers:
                                addresses: [8.8.8.8]
EOF
)

            BOND_BLOCK=$(cat << EOF
network:
        version: 2
        renderer: networkd
        bonds:
                bond0:
                        interfaces: [enp4s0, enp7s0]
                        dhcp4: yes
                        addresses: [192.168.150.3/24]
                        nameservers:
                                addresses: [8.8.8.8]
                        parameters:
                                mode: balance-rr
EOF
)

            BRIDGE_BOND=$(cat << EOF
network:
        version: 2
        renderer: networkd
        bonds:
                bond0:
                        interfaces: [enp4s0, enp7s0]
                        dhcp4: no
                        addresses: []
                        nameservers:
                                addresses: []
                        parameters:
                                mode: balance-rr
        bridges:
                br0:
                        interfaces: [bond0, $INTERFACE_0, $INTERFACE_1]
                        dhcp4: yes
                        addresses: [192.168.150.3/24, $seNCtrl_SUB_IP_0/24, $seNCtrl_SUB_IP_1/24]
                        nameservers:
                                addresses: [8.8.8.8]
EOF
)
        fi

        if [ "$mode" -eq 1 ]; then
            BLOCK=$BRIDGE_BLOCK
        elif [ "$mode" -eq 2 ]; then
            BLOCK=$BOND_BLOCK
        elif [ "$mode" -eq 3 ]; then
            BLOCK=$BRIDGE_BOND
        fi

        sudo touch $CONF_YAML
        sudo chmod 777 $CONF_YAML
        sudo echo "$BLOCK" > $CONF_YAML
    fi

    echo "[info] config netplan..."
    sudo cat $CONF_YAML
    sudo netplan apply

    if [ $? -ne 0 ]; then
        sudo cat $CORE_NETPLAN_FILE
        echo "[Error] netplan apply failed. Please check your netplan yaml file!"
        exit 1
    fi
}

function conf_iptable()
{   
    # update wanname in iptable_setup.sh
    # iptable_setup="/root/se_ctrl/iptable_setup.sh"

    mode=$1
    if [[ "$mode" -eq 1 || "$mode" -eq 3 ]]; then
        WAN_NAME="br0"
    elif [ "$mode" -eq 2 ]; then
        WAN_NAME="bond0"
    fi

    if ! sudo grep -q "^wanname=$WAN_NAME" "$iptable_setup"; then
        sudo chmod 777 "$iptable_setup"
        sudo sed -i "/^wanname=/ s/^/#/" "$iptable_setup"
        sudo sed -i "/^#wanname=/a wanname=$WAN_NAME" "$iptable_setup"
        echo "[info] Update completed: 'wanname=$WAN_NAME' added."
    else
        echo "[info] wanname is $WAN_NAME."
    fi
}

function reset_network()
{   
    echo "[info] reset network config of all cores"
    echo "[info] bridge flag is $Bridge_CONFIG_FLAG"
    if [ $Bridge_CONFIG_FLAG -eq 1 ];then
        for ((id = 1; id <= $seNCtrl_ALL_SUB_NUM; id++)); do
            file_name=$(basename "$SUB_NETPLAN_FILE_BAK")
            ret=$(${seNCtrl_PWD}/bmsec run $id "ls /etc/netplan/" | grep $file_name)
            # echo $ret
            if [[ -n "$ret" ]]; then
                ${seNCtrl_PWD}/bmsec run $id "sudo chmod 777 $SUB_NETPLAN_FILE_BAK" &> /dev/null
                ${seNCtrl_PWD}/bmsec run $id "sudo mv $SUB_NETPLAN_FILE_BAK $SUB_NETPLAN_FILE" &> /dev/null
                ${seNCtrl_PWD}/bmsec run $id "sudo netplan apply" &> /dev/null
            else
                echo "[Warning] The file $SUB_NETPLAN_FILE_BAK in core $id does not exist. Please reboot core $id"
            fi
        done
    fi

    # sudo chmod 777 ${seNCtrl_PWD}/configs/sub/subInfo.12
    # sudo sed -i 's/Bridge_CONFIG_FLAG=1/Bridge_CONFIG_FLAG=0/' ${seNCtrl_PWD}/configs/sub/subInfo.12
    # sudo sed -i '/^Bridge_IP_HALF=/d' ${seNCtrl_PWD}/configs/sub/subInfo.12
    

    echo "[info] reset host netplan config..."
    if [[ -f "$CORE_NETPLAN_FILE_BAK" ]]; then
        if grep -q "bond0" "$CONF_YAML"; then
            echo "[info] config bond0 down and remove bonding!"
            sudo ifconfig bond0 down
            sudo rmmod bonding
        fi
        sudo chmod 777 $CORE_NETPLAN_FILE_BAK
        sudo mv $CORE_NETPLAN_FILE_BAK $CORE_NETPLAN_FILE
        sudo rm -f $CONF_YAML
        sudo netplan apply
    else
        if grep -q "bond0" "$CONF_YAML"; then
            echo "[info] config bond0 down and remove bonding!"
            sudo ifconfig bond0 down
            sudo rmmod bonding
        fi
        sudo rm -f $CONF_YAML
        sudo netplan apply
        sudo cat $CORE_NETPLAN_FILE
        echo "[Error] $CORE_NETPLAN_FILE_BAK in host does not exist!!! Please modify your $CORE_NETPLAN_FILE of host by yourself!"
    fi


    # reset iptable_setup.sh
    sudo chmod 777 $iptable_setup
    # sudo sed -i '/^wanname=br0/d; s/^#wanname=/wanname=/' "$iptable_setup"
    sudo sed -i -e '/^wanname=\(br0\|bond0\)/d' -e 's/^#wanname=/wanname=/' "$iptable_setup"
    if ! [ "$product" = "SE6-CTRL" ] && [ "$product" = "SE6 CTRL" ] && [ "$product" = "SM7 CTRL" ] && [ "$product" = "SE8 CTRL" ]; then
        sudo $iptable_setup > /dev/null 2>&1
    fi

    if [ $Bridge_CONFIG_FLAG -eq 1 ]; then
        sudo chmod 777 ${seNCtrl_PWD}/configs/sub/subInfo.12
        sudo sed -i 's/Bridge_CONFIG_FLAG=1/Bridge_CONFIG_FLAG=0/' ${seNCtrl_PWD}/configs/sub/subInfo.12
        sudo sed -i '/^Bridge_IP_HALF=/d' ${seNCtrl_PWD}/configs/sub/subInfo.12
        echo "[info] please reboot!"
    fi
}

function conf_network()
{   
    mode=$1
    echo "[info] mode is $mode"

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
            echo "[info] The file $SUB_NETPLAN_FILE_BAK in core $id exists."
        else
            ${seNCtrl_PWD}/bmsec run $id "sudo cp $SUB_NETPLAN_FILE $SUB_NETPLAN_FILE_BAK" &> /dev/null
        fi
    done
    
    # ${seNCtrl_PWD}/bmsec getbi
    echo "[info] set all cores as DHCP MODE!"
    ${seNCtrl_PWD}/bmsec run all "sudo chmod 777 $SUB_NETPLAN_FILE" #&> /dev/null
    ${seNCtrl_PWD}/bmsec run all "sudo sed -i 's/dhcp4: no/dhcp4: yes/' $SUB_NETPLAN_FILE" &> /dev/null
    ${seNCtrl_PWD}/bmsec run all "sudo sed -i '/gateway4:/d' $SUB_NETPLAN_FILE" &> /dev/null
    ${seNCtrl_PWD}/bmsec run all "sudo netplan apply" &> /dev/null
    # ${seNCtrl_PWD}/bmsec run all "sudo cat $SUB_NETPLAN_FILE" 

    # config host netplan
    if [[ ! -f "$CONF_YAML" ]]; then
        echo "[info] setting bridges in netplan yaml file..."
        if [[ ! -f "$CORE_NETPLAN_FILE_BAK" ]]; then
            echo "[info] backup $CORE_NETPLAN_FILE"
            sudo cp $CORE_NETPLAN_FILE $CORE_NETPLAN_FILE_BAK
        fi
    fi

    conf_core_netplan $mode
    conf_iptable $mode

    PID=$(ps -ef | grep "[b]ash $iptable_setup" | awk '{print $2}')
    if [ -n "$PID" ]; then
        sudo kill "$PID"
        # echo "kill iptable_setup.sh"
    fi
    sudo iptables -P FORWARD ACCEPT
    
}


if [ "$mode" -eq 0 ]; then
    # reset network
    echo "[info] Mode is set to 0"
    reset_network
elif [ "$mode" -eq 2 ]; then
    # bonding mode only
    echo "[info] Mode is set to 2"
    if [[ ! -f "$CORE_NETPLAN_FILE_BAK" ]]; then
        echo "[info] backup $CORE_NETPLAN_FILE"
        sudo cp $CORE_NETPLAN_FILE $CORE_NETPLAN_FILE_BAK
    fi
    conf_core_netplan $mode
    conf_iptable $mode
    sleep 10
    sudo $iptable_setup > /dev/null 2>&1
    iptable_setup_status=$?
    if [ "$iptable_setup_status" -ne 0 ];then
        echo "Please run $iptable_setup!"
    fi
else
    # bridge mode or bridge + bonding mode
    conf_network $mode
fi
