#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

nfsConfig_cleanup() {
    ${seNCtrl_PWD}/bmsec run all "sudo umount /socrepack"
    sudo rm -rf /etc/exports.d/bmsecNfsSysBak.exports
    sudo exportfs -ra
    sudo systemctl restart nfs-server
}

systemBakPack_cleanup() {
    echo -e "\nReceived a kill signal. Cleaning up..."
    nfsConfig_cleanup
    exit 0
}
trap systemBakPack_cleanup SIGTERM SIGINT

function nfsShareBak(){
    id="$1"
    seNCtrl_NFS_PATH_LOCAL="$2"
    seNCtrl_NFS_PATH_REMOTE="$3"
    sudo mkdir -p ${seNCtrl_NFS_PATH_LOCAL}
    sudo chmod 777 ${seNCtrl_NFS_PATH_LOCAL}
    sudo mkdir -p /etc/exports.d/
    sudo cp ${seNCtrl_PWD}/configs/bmsecNfsSysBak.exports /etc/exports.d/
    sudo cp ${seNCtrl_PWD}/binTools/socBak.sh ${seNCtrl_NFS_PATH_LOCAL}
    sudo sed -i "s|172.16|$seNCtrl_SUB_IP_HALF|g" /etc/exports.d/bmsecNfsSysBak.exports
    sudo sed -i "s|/data/bmsecNfsShare|$seNCtrl_NFS_PATH_LOCAL|g" /etc/exports.d/bmsecNfsSysBak.exports
    ${seNCtrl_PWD}/bmsec run $id "for mount_point in \$(mount | grep nfs | awk '{print \$3}'); do sudo umount \"\$mount_point\"; done"
    sync
    sudo exportfs -ra
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    sudo systemctl restart nfs-server
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    ${seNCtrl_PWD}/bmsec run $id "sudo mkdir -p ${seNCtrl_NFS_PATH_REMOTE}"
    ${seNCtrl_PWD}/bmsec run $id "sudo chmod 777 ${seNCtrl_NFS_PATH_REMOTE}"
    ${seNCtrl_PWD}/bmsec run $id "sudo mount -t nfs \$(netstat -nr | grep '^0.0.0.0' | awk '{print \$2}'):${seNCtrl_NFS_PATH_LOCAL} ${seNCtrl_NFS_PATH_REMOTE}"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    ${seNCtrl_PWD}/bmsec run $id "[ -e ${seNCtrl_NFS_PATH_REMOTE}/socBak.sh ] && sudo chmod +x ${seNCtrl_NFS_PATH_REMOTE}/socBak.sh || exit 1"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    ${seNCtrl_PWD}/bmsec run $id "pushd ${seNCtrl_NFS_PATH_REMOTE} && sudo bash ./socBak.sh"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
}

function packTftp(){
    seNCtrl_NFS_PATH_LOCAL="$1"
    pushd ${seNCtrl_NFS_PATH_LOCAL}
        files=("rootfs.tgz" "opt.tgz" "boot.tgz" "recovery.tgz" "data.tgz" "fip.bin" "spi_flash*bin" "partition32G.xml")
        for file in "${files[@]}"; do
        if ls $file 1> /dev/null 2>&1; then
            echo "check $file ok"
        else
            echo "check $file error"
            return 1
        fi
    done
    popd
    sudo cp ${seNCtrl_PWD}/binTools/bm_make_package.sh ${seNCtrl_NFS_PATH_LOCAL}
    sudo cp ${seNCtrl_PWD}/binTools/${seNCtrl_ARCH}/mk_gpt ${seNCtrl_NFS_PATH_LOCAL}
    sudo chmod +x ${seNCtrl_NFS_PATH_LOCAL}/*.sh
    sudo chmod +x ${seNCtrl_NFS_PATH_LOCAL}/mk_gpt
    pushd ${seNCtrl_NFS_PATH_LOCAL}
    sudo PATH=$PATH ./bm_make_package.sh tftp ./partition32G.xml ${seNCtrl_NFS_PATH_LOCAL}
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; return 1; fi
    pushd tftp
    sudo md5sum ./* | sudo tee ./md5.txt
    sudo chmod 777 md5.txt
    popd
    popd
}

userInputSubId=""
userInputLocalBak=""
userInputOnlyBak=""
if [ $# -eq 2 ] || [ $# -eq 3 ]; then
    userInputSubId="$1"
    userInputLocalBak="$2"
    userInputOnlyBak="$3"
else
    echo "Enter the sub id to store the packaged:"
    read userInputSubId
    echo "Enter the local dir path to store the packaged files:"
    read userInputLocalBak
    echo "Enter only bak mode:"
    read userInputOnlyBak
fi
if [[ "$userInputLocalBak" == "" ]] || [[ ! -d "$userInputLocalBak" ]]; then
    echo "ERROR: userInputLocalBak:$userInputLocalBak, exit"
    return 1
fi
if seNCtrl_command_exists mkimage; then
    echo "bak core $userInputSubId to $userInputLocalBak"
else
    echo "mkimage installation failed. Please install it manually (The tool may be in the u-boot-tools package)."
    return 1
fi
if [[ "$userInputSubId" =~ ^[0-9]+$ &&  userInputSubId -ge 0 &&  userInputSubId -le $seNCtrl_ALL_SUB_NUM ]]; then
    ${seNCtrl_PWD}/bmsec run $userInputSubId "[ -e "/system/data/buildinfo.txt" ] && exit 1 || exit 0"
    if [ $? -ne 0 ]; then echo "Version 3.0.0 or older is not supported"; return 1; fi
    if [[ "${seNCtrl_ALL_SUB_IP[$(($userInputSubId - 1))]}" == "NAN" ]]; then echo "cannot support core Id:$userInputSubId"; return 1; fi
    nfsShareBak "$userInputSubId" "$userInputLocalBak" "/socrepack"
    if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; systemBakPack_cleanup; return 1; fi
    nfsConfig_cleanup
    if [[ "$userInputOnlyBak" != "onlyBak" ]]; then
        packTftp "$userInputLocalBak"
        if [ $? -ne 0 ]; then echo "command "${FUNCNAME[1]}" "${BASH_SOURCE[1]}" "$LINENO" error"; systemBakPack_cleanup; return 1; fi
    fi
    echo "bakpack files in ${userInputLocalBak}:"
    ls -lah ${userInputLocalBak}
fi
