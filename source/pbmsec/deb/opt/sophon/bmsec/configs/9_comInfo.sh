#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

#存放支持的命令
unset seNCtrl_OPTIONS_BY_ID
declare -A seNCtrl_OPTIONS_BY_ID
unset seNCtrl_OPTIONS_BY_NAME
declare -A seNCtrl_OPTIONS_BY_NAME

seNCtrl_SSH_TIMEOUT=10

seNCtrl_OPTIONS_INFO="List of parameters [Enter the number]:"
#打印帮助信息
seNCtrl_OPTIONS_BY_ID["1"]="echoHelp.sh"
seNCtrl_OPTIONS_BY_NAME["help"]="echoHelp.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 1. Print help documentation [help]"
#打印配置信息
seNCtrl_OPTIONS_BY_ID["2"]="echoConfInf.sh"
seNCtrl_OPTIONS_BY_NAME["pconf"]="echoConfInf.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 2. Print configuration information [pconf]"
#远程执行一条命令
seNCtrl_OPTIONS_BY_ID["3"]="runCmd.sh"
seNCtrl_OPTIONS_BY_NAME["run"]="runCmd.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 3. Execute remote commands [run <id> <cmd>]"
seNCtrl_SSH_CMD="${seNCtrl_SSHPASS} -e ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=${seNCtrl_SSH_TIMEOUT} "
#获取所有远程设备信息
seNCtrl_OPTIONS_BY_ID["4"]="getBasicInf.sh"
seNCtrl_OPTIONS_BY_NAME["getbi"]="getBasicInf.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 4. Get basic information for all remote devices [getbi]"
unset seNCtrl_LIBSOPHON_SDK_VERSION
declare -A seNCtrl_LIBSOPHON_SDK_VERSION
seNCtrl_LIBSOPHON_SDK_VERSION["0.4.2"]="V22.10.01"
seNCtrl_LIBSOPHON_SDK_VERSION["0.4.3"]="V22.11.01"
seNCtrl_LIBSOPHON_SDK_VERSION["0.4.4"]="V22.12.01"
seNCtrl_LIBSOPHON_SDK_VERSION["0.4.6"]="V23.03.01"
seNCtrl_LIBSOPHON_SDK_VERSION["0.4.8"]="V23.05.01"
seNCtrl_LIBSOPHON_SDK_VERSION["0.4.9"]="V23.07.01"
#上传文件
seNCtrl_OPTIONS_BY_ID["5"]="pushFile.sh"
seNCtrl_OPTIONS_BY_NAME["pf"]="pushFile.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 5. Upload files [pf <id> <localFile> <remoteFile>]"
seNCtrl_SSH_RSYNC="$seNCtrl_SSHPASS -e rsync -e "
#下载文件
seNCtrl_OPTIONS_BY_ID["6"]="downFile.sh"
seNCtrl_OPTIONS_BY_NAME["df"]="downFile.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 6. Download files [df <id> <remoteFile> <localFile>]"
#链接指定ssh
seNCtrl_OPTIONS_BY_ID["7"]="sshRemote.sh"
seNCtrl_OPTIONS_BY_NAME["ssh"]="sshRemote.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 7. Connect to a specified ID with SSH [ssh <id>]"
seNCtrl_SSH="$seNCtrl_SSHPASS -e ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=${seNCtrl_SSH_TIMEOUT} "
#关闭某个算力节点电源
seNCtrl_OPTIONS_BY_ID["8"]="resetRemote.sh"
seNCtrl_OPTIONS_BY_NAME["reset"]="resetRemote.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 8. Restart the power of core [reset <id>]"
#链接指定算力节点调试串口
seNCtrl_OPTIONS_BY_ID["9"]="uartRemote.sh"
seNCtrl_OPTIONS_BY_NAME["uart"]="uartRemote.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 9. Connect to the debugging UART of core use picocom [uart <id>]"
#持续打印指定算力节点调试串口
seNCtrl_OPTIONS_BY_ID["10"]="puartRemote.sh"
seNCtrl_OPTIONS_BY_NAME["puart"]="puartRemote.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 10. Print the debugging UART of core [puart <id>]"
#使用控制板自带刷机包升级指定算力板
seNCtrl_OPTIONS_BY_ID["11"]="update.sh"
seNCtrl_OPTIONS_BY_NAME["update"]="update.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 11. Upgrade a core using /recovery/tftp [update <id>]"
#检查当前tftp升级进度
#该功能需要tftp配置文件/etc/default/tftpd-hpa中开启TFTP_OPTIONS="--secure -v"中的-v选项
seNCtrl_OPTIONS_BY_ID["12"]="tftpCheck.sh"
seNCtrl_OPTIONS_BY_NAME["tftpc"]="tftpCheck.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 12. Check the upgrade progress [tftpc]"
seNCtrl_CHECK_TFTP_LOG='sudo journalctl -u tftpd-hpa 2> /dev/null | tail -n 25 | grep RRQ '
#启动NFS服务并共享到算力板
seNCtrl_OPTIONS_BY_ID["13"]="nfsAutoMount.sh"
seNCtrl_OPTIONS_BY_NAME["nfs"]="nfsAutoMount.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 13. Share /data/bmsecNfsShare to specific compute node with nfs [nfs <localPath> <remotePath>]"
#进行算力板内存配置
seNCtrl_OPTIONS_BY_ID["14"]="confMem.sh"
seNCtrl_OPTIONS_BY_NAME["cmem"]="confMem.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 14. Configure core memory [cmem <id> {<p> / < <c> <npuSize> <vpuSize> <vppSize> >} [dtsFile]]"
#重置已有配置
seNCtrl_OPTIONS_BY_ID["15"]="resetSubConf.sh"
seNCtrl_OPTIONS_BY_NAME["rconf"]="resetSubConf.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 15. Reset cores config [rconf]"
#将某一个算力节点的系统进行打包
seNCtrl_OPTIONS_BY_ID["16"]="systemBakPack.sh"
seNCtrl_OPTIONS_BY_NAME["sysbak"]="systemBakPack.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 16. Package the system of a computing power node [sysbak <id> <localPath> [onlyBak]]"
#将某一个算力节点的系统进行端口映射
seNCtrl_OPTIONS_BY_ID["17"]="port2port.sh"
seNCtrl_OPTIONS_BY_NAME["pt"]="port2port.sh"
seNCtrl_OPTIONS_INFO="${seNCtrl_OPTIONS_INFO} \n 17. Edit port mappings to cores [pt <opt> <hostIp> <id> <localport> <remoteport>]"

seNCtrl_COMMAND_NUM=${#seNCtrl_OPTIONS_BY_ID[@]}
sudo chmod +x ${seNCtrl_PWD}/commands/*

#根据系统reboot_all文件和se_init文件进行所有算力板强制重置
seNCtrl_OPTIONS_BY_NAME["_reset_all"]="_reset_all.sh"
#对只能进入uboot状态的算力节点进行强制刷机（需要确保/recovery/tftp下刷机包的正确性）
seNCtrl_OPTIONS_BY_NAME["_update_sub"]="_update_sub.sh"
