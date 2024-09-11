#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

seNCtrl_REBOOT_ALL_PATH=$(which reboot_all)

if [[ "${seNCtrl_REBOOT_ALL_PATH}" == "" ]]; then
    echo "cannot find reboot_all file, exit."
    return 0
fi
if [ -f /usr/sbin/bmrt_setup.sh ]; then
    echo "start reset all sub"
    grep -va "reboot" "${seNCtrl_REBOOT_ALL_PATH}" | sudo bash
    sleep 3
    echo "start config all sub"
    sudo -i <<EOF
    /usr/sbin/bmrt_setup.sh
EOF
else
    echo "cannot find /usr/sbin/bmrt_setup.sh file, exit."
    return 0
fi
