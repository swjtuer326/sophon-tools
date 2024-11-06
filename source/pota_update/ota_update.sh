#!/bin/bash

# 配置区域
EMMC_SECTOR_B=512
original_ifs=$IFS
# 刷机环境准备
flash_pre_str='
# Bitmain ota update U-Boot script
# disable MCU watchdog
i2c dev 1; i2c mw 0x69 1 0
setenv update_all 1
setenv reset_after 1
led status off
led error on
'
# 刷机完成后执行
flash_post_str='# Bitmain ota update U-Boot script
echo all done

led status on
led error off
setenv light 1

if test "$reset_after" = "1"; then reset; fi;

while true; do
if test $light = "0"; then led status off; setenv light 1; else led status on; setenv light 0; fi;
echo "Please remove the installation medium, then reboot"; sleep 0.5; done;
'

rm -rf /dev/shm/ota_sucess_flag
rm -rf /dev/shm/ota_error_flag

function panic()
{
    if [ $# -gt 0 ]; then
        echo "" >&1
        echo "[PANIC] $@" >&1
        echo "" >&1
    fi
    popd &>/dev/null
    touch /dev/shm/ota_error_flag
    exit 1
}

# 必须是root账户
if [ ! "$(id -u)" -eq 0 ]; then
    panic "must use root"
fi

# 检查的工具
need_tools=("systemd" "systemd-run" "tee" "exec" "echo" "bc" "gdisk" "mkimage" "awk" "sed" "tr" "gzip")
for tool in "${need_tools[@]}"; do
    if ! command -v "$tool" > /dev/null 2>&1; then
        panic "$tool: cannot find"
    fi
done

# 启动后台服务，依赖systemd
DDR_SHELL_FILE="/dev/shm/ota_shell.sh"
SHELL_FILE="$(readlink -f "${BASH_SOURCE[0]}")"
if [[ "$SHELL_FILE" != "${DDR_SHELL_FILE}"  ]]; then
    rm -f "${DDR_SHELL_FILE}"
    cp "$SHELL_FILE" "${DDR_SHELL_FILE}"
    chmod +x "${DDR_SHELL_FILE}"
    cd /
    # systemctl stop sophon-ota-update.service
    # systemctl reset-failed sophon-ota-update.service
    # rm /run/systemd/transient/sophon-ota-update.service
    # systemctl daemon-reload
    systemd-run --unit=sophon-ota-update.service --collect bash -c "${DDR_SHELL_FILE} $(dirname $SHELL_FILE)"
    if [[ "$?" != "0" ]]; then
        systemd-run --unit=sophon-ota-update.service bash -c "${DDR_SHELL_FILE} $(dirname $SHELL_FILE)"
    fi
    systemctl status sophon-ota-update.service --no-page -l
    echo '[INFO] ota server started, check status use: "systemctl status sophon-ota-update.service --no-page -l"'
    echo '[INFO] server log file: /dev/shm/ota_shell.sh.log'
    echo '[INFO] if ota sucess, file /dev/shm/ota_sucess_flag will be created'
    echo '[INFO] else if ota error, file /dev/shm/ota_error_flag will be created'
    echo '[INFO] please wait file /dev/shm/ota_sucess_flag or /dev/shm/ota_error_flag'
    echo '[WARRNING] ota server will resize last partition on emmc, if error, please check emmc partitions'
    echo '[WARRNING] ota server will stop docker server and all program on last partition'
    exit 0
fi

# 配置日志能力
LOGFILE="$(readlink -f "${BASH_SOURCE[0]}").log"
rm -f $LOGFILE
exec > >(tee -a "$LOGFILE") 2>&1

echo "[INFO] ota update tool, version: v1.0.0"

WORK_DIR="$1"
echo "[INFO] work dir: $WORK_DIR"
cd $WORK_DIR

function file_validate()
{
    local file
    file=$(eval echo \$1)
    [ -r ${file} ] || panic "$i \"$file\" is not readable"
}

# 记录系统信息
echo "-----------------------------------------------------------"
echo "$(date)" >> "$LOGFILE"
echo "Info:" >> "$LOGFILE"
bm_version >> "$LOGFILE"
bm_get_basic_info >> "$LOGFILE"
cat /factory/OEMconfig.ini >> "$LOGFILE"
lsblk -f >> "$LOGFILE"
df -h >> "$LOGFILE"
lsusb >> "$LOGFILE"
lspci >> "$LOGFILE"
top -n1 >> "$LOGFILE"

pushd sdcard

CPU_MODEL=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)
! [[ "$CPU_MODEL" == "" ]] || panic "cannot get cpu model from /proc/cpuinfo"

# 使用MD5文件进行刷机包校验
echo "[INFO] md5 check start"
md5file=$(find . -type f -name "*md5*")
file_validate ${md5file}
md5sum -c ${md5file} &>> "$LOGFILE" || panic "md5 check error!!!"
echo "[INFO] md5 check sucess"

# 确定刷机包大小和刷机后占空空间
xmlfile=$(find . -type f -name "partition*xml")
OTA_NEW_PACKAGE_GPT_PART_SIZE_KB=$(cat ${xmlfile} | grep "<physical_partition " | awk -F'"' '{print $2}')
OTA_NEW_ALL_PART_SIZE_KB=$(cat ${xmlfile} | grep "<partition " | awk -F'"' '{print $4}' | paste -sd+ - | bc)
OTA_GPT_TEMP_FILE="/dev/shm/ota_gpt"
rm -f ${OTA_GPT_TEMP_FILE}
gzip -cd gpt.gz > ${OTA_GPT_TEMP_FILE}
gdisk -l ${OTA_GPT_TEMP_FILE} 2>&1 >> "$LOGFILE"
# 获取emmc扇区大小
OTA_NEW_SECTOR_SIZE=$(gdisk -l ${OTA_GPT_TEMP_FILE} 2>&1 | grep "ector size" | awk -F' ' '{print $4}' | awk -F'/' '{print $1}')
if [[ "$EMMC_SECTOR_B" != "$OTA_NEW_SECTOR_SIZE" ]]; then
    panic "get emmc sector size [$OTA_NEW_SECTOR_SIZE] not is default size [$EMMC_SECTOR_B], please check emmc and gdisk tool"
fi
OTA_NEW_GPT_END_SECTOR=$(gdisk -l ${OTA_GPT_TEMP_FILE} 2>&1 | tail -n1 | awk -F' ' '{print $3}')
OTA_NEW_GPT_END_SIZE_KB=$(echo "$OTA_NEW_SECTOR_SIZE * $OTA_NEW_GPT_END_SECTOR / 1024" | bc)
rm -f ${OTA_GPT_TEMP_FILE}
OTA_NEW_MAX_SIZE_KB=0
if [ $OTA_NEW_MAX_SIZE_KB -lt $OTA_NEW_PACKAGE_GPT_PART_SIZE_KB ]; then
    OTA_NEW_MAX_SIZE_KB=$OTA_NEW_PACKAGE_GPT_PART_SIZE_KB
fi
if [ $OTA_NEW_MAX_SIZE_KB -lt $OTA_NEW_ALL_PART_SIZE_KB ]; then
    OTA_NEW_MAX_SIZE_KB=$OTA_NEW_ALL_PART_SIZE_KB
fi
if [ $OTA_NEW_MAX_SIZE_KB -lt $OTA_NEW_GPT_END_SIZE_KB ]; then
    OTA_NEW_MAX_SIZE_KB=$OTA_NEW_GPT_END_SIZE_KB
fi
OTA_PACK_SIZE_KB=$(ls -l --block-size=K | awk -F' ' '{print $5}' | tr -d 'K' | sed '/^$/d' | paste -sd+ - | bc)
OTA_NEED_SIZE_KB=$OTA_NEW_MAX_SIZE_KB
echo "[INFO] update need size: $OTA_NEED_SIZE_KB KB"
OTA_EMMC_SIZE_KB=$(echo "$(lsblk -b | grep '^mmcblk0' | head -n1 | awk -F' ' '{print $4}') / 1024" | bc)
echo "[INFO] emmc size: $OTA_EMMC_SIZE_KB KB"
if [ $OTA_EMMC_SIZE_KB -le $OTA_NEED_SIZE_KB ]; then
    panic "check update size error!!!"
fi
# 判断最后一个分区是否已经扩容
OTA_EMMC_PART_SIZE=$(lsblk -b /dev/mmcblk0 | grep -v "^mmcblk0" | grep "mmcblk0" | awk -F' ' '{print $4}' | paste -sd+ - | bc)
OTA_EMMC_PART_SIZE=$(($OTA_EMMC_PART_SIZE + $OTA_EMMC_PART_SIZE / 10))
if [ $OTA_EMMC_SIZE_KB -gt $OTA_EMMC_PART_SIZE ]; then
    panic "check update size error, all partitions less than 90% of the emmc space!!!"
fi
echo "[INFO] check update size check sucess"
# 缩小最后一个分区，空出刷机包大小的空间
echo "[INFO] resize last part to write update pack start"
OTA_LAST_DEVICE=/dev/$(lsblk -o NAME /dev/mmcblk0 | tail -n1 | sed 's|└─||g')
OTA_LAST_DEVICE_MOUNT_POINT=$(df | grep "${OTA_LAST_DEVICE}" | awk -F' ' '{print $6}')
OTA_LAST_DEVICE_SIZE_KB=$(echo "$(lsblk -b ${OTA_LAST_DEVICE} | tail -n1 | awk -F' ' '{print $4}') / 1024" | bc)
OTA_PACK_NUM=$(ls -l ./ | wc -l)
# 最后一个分区后预留20MB空间，并且每一个包开始都是一个扇区对齐
OTA_LAST_DEVICE_NEW_SIZE_KB=$(echo "$OTA_LAST_DEVICE_SIZE_KB - $OTA_PACK_SIZE_KB - ($OTA_PACK_NUM) - (10 * 1024) - (20 * 1024)" | bc)
OTA_PACK_WRITE_START_SECTOR=$(echo "($OTA_EMMC_SIZE_KB - $OTA_PACK_SIZE_KB - ($OTA_PACK_NUM) - (10 * 1024)) * (1024 / $EMMC_SECTOR_B)" | bc)
echo "[INFO] last device $OTA_LAST_DEVICE need resize $OTA_LAST_DEVICE_SIZE_KB KB -> $OTA_LAST_DEVICE_NEW_SIZE_KB KB"
cd /
echo "[INFO] kill process of ${OTA_LAST_DEVICE_MOUNT_POINT} start"
lsof | grep "${OTA_LAST_DEVICE_MOUNT_POINT}" >> "$LOGFILE"
systemctl stop docker
for item in $(lsof | grep "${OTA_LAST_DEVICE_MOUNT_POINT}" | awk -F' ' '{print $2}'); do
    echo "[INFO] need kill PID:$item"
    kill -15 $item &>/dev/null
    kill -9 $item &>/dev/null
done
for item in $(lsof | grep "${OTA_LAST_DEVICE_MOUNT_POINT}" | awk -F' ' '{print $2}'); do
    echo "[INFO] need kill PID:$item"
    kill -15 $item &>/dev/null
    kill -9 $item &>/dev/null
done
echo "[INFO] kill process of ${OTA_LAST_DEVICE_MOUNT_POINT} sucess"
umount -f ${OTA_LAST_DEVICE}
if [[ "$(df | grep ${OTA_LAST_DEVICE} | wc -l)" != "0" ]]; then
    panic "umount ${OTA_LAST_DEVICE} error!!!"
fi
e2fsck -yf ${OTA_LAST_DEVICE}
resize2fs ${OTA_LAST_DEVICE} ${OTA_LAST_DEVICE_NEW_SIZE_KB}K -f
if [[ "$?" != "0" ]]; then
    panic "resize2fs ${OTA_LAST_DEVICE} -> ${OTA_LAST_DEVICE_NEW_SIZE_KB}K, please check if your eMMC partition is healthy"
fi
mount -a
cd $WORK_DIR/sdcard
if [[ "$?" != "0" ]]; then
    panic "resize2fs ${OTA_LAST_DEVICE} -> ${OTA_LAST_DEVICE_NEW_SIZE_KB}K, please check if your eMMC partition is healthy"
fi
echo "[INFO] resize last part to write update pack sucess"

# 生成刷机文件emmc中存储位置表
echo "[INFO] Generate Upgrade Package File Address Data Table start"
OTA_EMMC_UPDATE_CMD_FILE=$(cat boot_emmc.cmd | grep -a ^load | grep boot_emmc | awk -F' ' '{print $NF}' | awk -F'/' '{print $NF}')
OTA_FIP_UPDATE_CMD_FILE=$(cat boot.cmd | grep -a ^load | head -n1 | awk -F' ' '{print $NF}' | awk -F'/' '{print $NF}')
OTA_FIP_FILE=$(cat $OTA_FIP_UPDATE_CMD_FILE | grep -a ^load | awk -F' ' '{print $NF}' | awk -F'/' '{print $NF}')
OTA_FIP_FLASH_OFFSET=()
OTA_FIP_FLASH_SIZE=()
IFS=$'\n'
for item in $(cat $OTA_FIP_UPDATE_CMD_FILE | grep -a ^mmc | grep write); do
    if [[ -z "$item" ]]; then
        continue
    fi
    OTA_FIP_FLASH_OFFSET+=("$(echo "$item" | awk -F' ' '{print $(NF-1)}')")
    OTA_FIP_FLASH_SIZE+=("$(echo "$item" | awk -F' ' '{print $NF}')")
done
IFS=$original_ifs
echo "[INFO] fip file: $OTA_FIP_FILE"
for ((item = 0; item < ${#OTA_FIP_FLASH_OFFSET[@]}; item++)); do
    echo "[INFO] fip file flash to emmcboot1 ${OTA_FIP_FLASH_OFFSET[$item]}, size: ${OTA_FIP_FLASH_SIZE[$item]}"
done
offset=$(echo "$OTA_PACK_WRITE_START_SECTOR + (10 * 1024) * (1024 / $EMMC_SECTOR_B)" | bc)
size=$(echo "scale=0; $(stat -c %s $OTA_FIP_FILE) / $EMMC_SECTOR_B + 1" | bc)
OTA_FIP_WRITE_OFFSET=$(printf '0x%X' $offset)
OTA_FIP_WRITE_SIZE=$(printf '0x%X' $size)
OTA_UPDATE_PACK_WRITE_OFFSET=$(($OTA_FIP_WRITE_OFFSET + $OTA_FIP_WRITE_SIZE))
echo "[INFO] fip file write to emmc offset: $OTA_FIP_WRITE_OFFSET, size: $OTA_FIP_WRITE_SIZE"
unset OTA_EMMC_FLASH_OFFSET
unset OTA_EMMC_FLASH_SIZE
unset OTA_EMMC_FLASH_UNZIP_SIZE
unset OTA_EMMC_WRITE_OFFSET
unset OTA_EMMC_WRITE_SIZE
declare -A OTA_EMMC_FLASH_OFFSET
declare -A OTA_EMMC_FLASH_SIZE
declare -A OTA_EMMC_FLASH_UNZIP_SIZE
declare -A OTA_EMMC_WRITE_OFFSET
declare -A OTA_EMMC_WRITE_SIZE
OTA_EMMC_FILES=()
IFS=$'\n'
for emmc_boot_file in $(echo "${OTA_EMMC_UPDATE_CMD_FILE}"); do
    if [[ -z "$emmc_boot_file" ]]; then
        continue
    fi
    for item in $(cat $emmc_boot_file | grep -aE "^load |^unzip |^mmc write"); do
        if [[ -z "$item" ]]; then
            continue
        fi
        if [[ "$item" == "load "* ]]; then
            filename="$(echo "$item" | awk -F' ' '{print $NF}' | awk -F'/' '{print $NF}')"
            size=$(echo "scale=0; $(stat -c %s $filename) / $EMMC_SECTOR_B + 1" | bc)
            OTA_EMMC_FILES+=($filename)
            OTA_EMMC_WRITE_OFFSET["$filename"]=$(printf '0x%X' $OTA_UPDATE_PACK_WRITE_OFFSET)
            OTA_EMMC_WRITE_SIZE["$filename"]=$(printf '0x%X' $size)
            OTA_UPDATE_PACK_WRITE_OFFSET=$(($OTA_UPDATE_PACK_WRITE_OFFSET + $size))
        elif [[ "$item" == "unzip "* ]]; then
            OTA_EMMC_FLASH_UNZIP_SIZE["${OTA_EMMC_FILES[-1]}"]=$(echo "$item" | awk -F' ' '{print $(NF)}')
        elif [[ "$item" == "mmc write"* ]]; then
            OTA_EMMC_FLASH_OFFSET["${OTA_EMMC_FILES[-1]}"]=$(echo "$item" | awk -F' ' '{print $(NF-1)}')
            OTA_EMMC_FLASH_SIZE["${OTA_EMMC_FILES[-1]}"]=$(echo "$item" | awk -F' ' '{print $(NF)}')
        fi
    done
done
IFS=$original_ifs
for ((item = 0; item < ${#OTA_EMMC_FILES[@]}; item++)); do
    filename=${OTA_EMMC_FILES[$item]}
    echo -e "[INFO] file $filename
\t flash emmc offset: ${OTA_EMMC_FLASH_OFFSET["$filename"]},
\t size: ${OTA_EMMC_FLASH_SIZE["$filename"]},
\t unzip size: ${OTA_EMMC_FLASH_UNZIP_SIZE["$filename"]},
\t write to emmc offset: ${OTA_EMMC_WRITE_OFFSET["$filename"]},
\t size: ${OTA_EMMC_WRITE_SIZE["$filename"]}"
done
echo "[INFO] Generate Upgrade Package File Address Data Table sucess"

# 生成刷机文件
echo "[INFO] Generate Upgrade Script start"
OTA_UPDATE_SCRIPT_FILE=$LOGFILE.update.cmd
if [[ "${CPU_MODEL}" == "bm1684" ]]; then
# v3.0.0 uboot
    flash_pre_str+=";if test -n \${unzip_addr};then echo \"new version uboot\";
else setenv ramdisk_addr_b 0x310400000;
setenv ramdisk_addr_r 0x310000000;
setenv scriptaddr 0x300040000;
setenv chip_type bm1684;
setenv unzip_addr 0x320000000;
fi"
fi
echo "$flash_pre_str" > $OTA_UPDATE_SCRIPT_FILE

if [[ "${CPU_MODEL}" == "bm1684x" ]] || [[ "${CPU_MODEL}" == "bm1684" ]]; then
    echo "echo Program $OTA_FIP_FILE start
mmc dev 0
mmc read \${ramdisk_addr_r} ${OTA_FIP_WRITE_OFFSET} ${OTA_FIP_WRITE_SIZE}
if test \$? -eq 0; then
sf probe
if test \$? -ne 0; then
led status off
led error off
while true; do; echo "ERROR: SPI flash not exist"; sleep 0.5; done; fi;
print chip_type
" >> $OTA_UPDATE_SCRIPT_FILE
if [[ " ${OTA_EMMC_FILES[@]} " == *"system"* ]]; then
    flash_update_cmd="sf update \${ramdisk_addr_r} 0x0 0x120000"
else
    flash_update_cmd="if test \"\$chip_type\" = "bm1684"; then sf update \${ramdisk_addr_b} 0x0 0x200000; else sf update \${ramdisk_addr_r} 0x0 0x200000; fi"
fi
echo "$flash_update_cmd" >> $OTA_UPDATE_SCRIPT_FILE
echo "else
echo skip SPI flash update.
fi
echo Program fip.bin done
" >> $OTA_UPDATE_SCRIPT_FILE
elif [[ "${CPU_MODEL}" == "bm1688" ]] || [[ "${CPU_MODEL}" == "cv186ah" ]]; then
    echo "
echo Program $OTA_FIP_FILE start
mmc dev 0
mmc read \${ramdisk_addr_r} ${OTA_FIP_WRITE_OFFSET} ${OTA_FIP_WRITE_SIZE}
if test \$? -eq 0; then
mmc dev 0 1
if test \$? -ne 0; then
led status off
led error off
while true; do; echo \"ERROR: switch to mmc0(part1) fail\"; sleep 0.5; done; fi;
" >> $OTA_UPDATE_SCRIPT_FILE
    for ((item = 0; item < ${#OTA_FIP_FLASH_OFFSET[@]}; item++)); do
        echo "mmc write \${ramdisk_addr_r} ${OTA_FIP_FLASH_OFFSET[$item]} ${OTA_FIP_FLASH_SIZE[$item]}" >> $OTA_UPDATE_SCRIPT_FILE
    done
    echo "
else
echo skip fip flash.
fi
echo Program fip.bin done
" >> $OTA_UPDATE_SCRIPT_FILE
fi

echo "
led status off;sleep 0.2;led status on;sleep 0.2;led status off;sleep 0.2;led status on;sleep 0.2;led status off
" >> $OTA_UPDATE_SCRIPT_FILE

for ((item = 0; item < ${#OTA_EMMC_FILES[@]}; item++)); do
    filename=${OTA_EMMC_FILES[$item]}
echo "
echo Program $filename start
mmc dev 0
mmc read \${ramdisk_addr_r} ${OTA_EMMC_WRITE_OFFSET["$filename"]} ${OTA_EMMC_WRITE_SIZE["$filename"]}
if test \$? -ne 0; then
led status off
led error off
while true; do; echo \"ERROR: load package failed\"; sleep 0.5; done; fi;
echo
unzip \${ramdisk_addr_r} \${unzip_addr} ${OTA_EMMC_FLASH_UNZIP_SIZE["$filename"]}
if test \$? -ne 0; then
led status off
led error off
while true; do; echo \"ERROR: load package failed\"; sleep 0.5; done; fi;
echo
mmc write \${unzip_addr} ${OTA_EMMC_FLASH_OFFSET["$filename"]} ${OTA_EMMC_FLASH_SIZE["$filename"]}
if test \$? -ne 0; then
led status off
led error off
while true; do; echo \"ERROR: eMMC write failed\"; sleep 0.5; done; fi;
echo
echo Program $filename done
" >> $OTA_UPDATE_SCRIPT_FILE

echo "
led status off;sleep 0.2;led status on;sleep 0.2;led status off;sleep 0.2;led status on;sleep 0.2;led status off;
" >> $OTA_UPDATE_SCRIPT_FILE

done

echo "$flash_post_str" >> $OTA_UPDATE_SCRIPT_FILE
echo "[INFO] Generate Upgrade Script sucess"
echo "[INFO] Write packs to emmc start"
dd if="$OTA_FIP_FILE" of=/dev/mmcblk0 bs=$EMMC_SECTOR_B seek=$((${OTA_FIP_WRITE_OFFSET} + 0)) count=$((${OTA_FIP_WRITE_SIZE} + 0)) status=progress
if [[ "$?" != "0" ]]; then
    panic "Write file $OTA_FIP_FILE to emmc error!!!"
fi
for ((item = 0; item < ${#OTA_EMMC_FILES[@]}; item++)); do
    filename=${OTA_EMMC_FILES[$item]}
    echo -e "[INFO] write file $filename
    \t to emmc offset: ${OTA_EMMC_WRITE_OFFSET["$filename"]},
    \t size: ${OTA_EMMC_WRITE_SIZE["$filename"]}"
    dd if=$filename of=/dev/mmcblk0 bs=$EMMC_SECTOR_B seek=$((${OTA_EMMC_WRITE_OFFSET["$filename"]})) count=$((${OTA_EMMC_WRITE_SIZE["$filename"]})) status=progress
    if [[ "$?" != "0" ]]; then
        panic "Write file $filename to emmc error!!!"
    fi
done
echo "[INFO] Write packs to emmc sucess"

echo "[INFO] Write update script to boot start"
mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -n "boot.scr" -d $OTA_UPDATE_SCRIPT_FILE $OTA_UPDATE_SCRIPT_FILE.scr
if [[ "$?" != "0" ]]; then
    panic "mkimage error!!!"
fi
cp /boot/boot.scr.emmc /boot/boot.scr.emmc.otabak
if [[ "$?" != "0" ]]; then
    panic "cp /boot/boot.scr.emmc error!!!"
fi
cp $OTA_UPDATE_SCRIPT_FILE.scr /boot/boot.scr.emmc
if [[ "$?" != "0" ]]; then
    panic "cp $OTA_UPDATE_SCRIPT_FILE.scr error!!!"
fi
echo "[INFO] Write update script to boot sucess"
touch /dev/shm/ota_sucess_flag
echo "[INFO] wait sync ..."
sync
# reboot -f
popd #sdcard
echo "[INFO] Upgrade preparation is complete. Please restart the device to begin the upgrade."
