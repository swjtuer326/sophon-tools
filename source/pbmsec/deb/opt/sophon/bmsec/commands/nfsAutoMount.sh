#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

function nfsShare(){
    id="$1"
    seNCtrl_NFS_PATH_LOCAL="$2"
    seNCtrl_NFS_PATH_REMOTE="$3"
    if [[ "$seNCtrl_NFS_PATH_REMOTE" == "/data/"* ]]; then
        sudo mkdir -p ${seNCtrl_NFS_PATH_LOCAL}
        sudo chmod 777 ${seNCtrl_NFS_PATH_LOCAL}
        sudo mkdir -p /etc/exports.d/
        sudo cp ${seNCtrl_PWD}/configs/bmsecNfs.exports /etc/exports.d/
        sudo sed -i "s|172.16|$seNCtrl_SUB_IP_HALF|g" /etc/exports.d/bmsecNfs.exports
        sudo sed -i "s|/data/bmsecNfsShare|$seNCtrl_NFS_PATH_LOCAL|g" /etc/exports.d/bmsecNfs.exports
        ${seNCtrl_PWD}/bmsec run $id "sudo umount ${seNCtrl_NFS_PATH_REMOTE}"
        sudo exportfs -ra
        sudo systemctl restart nfs-server
        ${seNCtrl_PWD}/bmsec run $id "mkdir -p ${seNCtrl_NFS_PATH_REMOTE}"
        ${seNCtrl_PWD}/bmsec run $id "sudo chmod 777 ${seNCtrl_NFS_PATH_REMOTE}"
        ${seNCtrl_PWD}/bmsec run $id "sudo mount -t nfs \$(netstat -nr | grep '^0.0.0.0' | awk '{print \$2}'):${seNCtrl_NFS_PATH_LOCAL} ${seNCtrl_NFS_PATH_REMOTE}"
    else
        echo "ERROR: remote dir path not in /data, There is a security risk, exit"
        return 1
    fi
}

userInputRemoteNfs=""
userInputLocalNfs=""
if [ $# -eq 2 ]; then
    userInputLocalNfs="$1"
    userInputRemoteNfs="$2"
else
    echo "Enter the local dir path:"
    read userInputLocalNfs
    echo "Enter the remote dir path:"
    read userInputRemoteNfs
fi
if [[ "$userInputLocalNfs" == "" ]] || [[ "$userInputRemoteNfs" == "" ]]; then
    echo "ERROR: userInputLocalNfs:$userInputLocalNfs userInputRemoteNfs:$userInputRemoteNfs, exit"
    return 1
fi

nfsShare all "$userInputLocalNfs" "$userInputRemoteNfs"
