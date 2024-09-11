#!/bin/bash

# These parameters are used to exclude irrelevant files
# and directories in the context of repackaging mode.
# Users can add custom irrelevant files and directories
# in the format of ROOTFS_EXCLUDE_FLAGS_INT to the
# ROOTFS_EXCLUDE_FLAGS_USER parameter.
ROOTFS_EXCLUDE_FLAGS_INT=' --exclude=./var/log/* --exclude=./media/* --exclude=./sys/* --exclude=./proc/* --exclude=./dev/* --exclude=./factory/* --exclude=./run/udev/* --exclude=./run/user/* --exclude=./socrepack '
ROOTFS_EXCLUDE_FLAGS_USER='  '
ROOTFS_EXCLUDE_FLAGS_RUN=" ${ROOTFS_EXCLUDE_FLAGS_INT} ${ROOTFS_EXCLUDE_FLAGS_USER} "
ROOTFS_EXCLUDE_FLAGS=''
ROOTFS_INCLUDE_PATHS='./var/log/nginx ./var/log/redis ./var/log/mosquitto ./var/log/mysql'

# These parameters define several generated files and
# their default sizes for repackaging. Users can modify
# them according to their device specifications.
TGZ_FILES=(boot data opt system recovery rootfs)
# Here are the default sizes for each partition
declare -A TGZ_FILES_SIZE
TGZ_FILES_SIZE=(["boot"]=131072 ["recovery"]=3145728 ["rootfs"]=2621440 ["opt"]=2097152 ["system"]=2097152 ["data"]=4194304)
# The increased size of each partition compared to the original partition table
TGZ_ALL_SIZE=$((100*1024))
EMMC_ALL_SIZE=20971520
EMMC_MAX_SIZE=30000000
ROOTFS_RW_SIZE=$((6144*1024))
TAR_SIZE=0
PWD="$(dirname "$(readlink -f "\$0")")"
TGZ_FILES_PATH=${PWD}
PARTITION_FILE=partition32G.xml
BM1684_SOC_VERSION=0
NEED_BAK_FLASH=1
SOC_NAME=""
PIGZ_GZIP_COM=""
export GZIP=-1
export PIGZ=-1

if type pigz >/dev/null 2>&1 ; then
	PIGZ_GZIP_COM="pigz"
	echo "INFO: find pigz"
else
	PIGZ_GZIP_COM="gzip"
	echo "INFO: not find pigz, multi-thread acceleration cannot be used, please install pigz and try again or continue to use gzip"
fi
echo "INFO: PIGZ_GZIP_COM:${PIGZ_GZIP_COM}"

socbak_cleanup() {
	echo -e "\nINFO: Received a kill signal. Cleaning up..."
	systemctl disable resize-helper.service
	exit 0
}
trap socbak_cleanup SIGTERM SIGINT

SOCBAK_GET_TAR_SIZE_KB=0
socbak_get_tar_size() {
	echo "INFO: get tar $1 files size..."
	pushd ${PWD}
	SOCBAK_GET_TAR_SIZE_KB=$(tar -I ${PIGZ_GZIP_COM} -tvf $1 --totals 2>&1 | tail -n 1 | awk -F':' '{printf $2}' | awk -F' ' '{printf "%.0f\n", $1/1024}')
	echo "WARNING: $1 files size is ${SOCBAK_GET_TAR_SIZE_KB}"
	popd
}

if [ $PWD != "/socrepack" ]; then
	echo "ERROR: The current path is not \"/socrepack\", please check it"
	exit 1
fi
echo "INFO: The current path is \"/socrepack\""

FILESYSTEM=$(df -T . | tail -n 1 | awk '{print $2}')
if [[ "${FILESYSTEM}" != "ext4" ]]; then
	echo "WARNING: The current directory's file system ${FILESYSTEM} is not ext4, there may be some issues."
fi

echo "INFO: get chip id ..."
if [ -e /proc/device-tree/model ]; then
	if [[ "$(grep -ai "bm1688" '/proc/device-tree/model' 2>/dev/null | wc -l)" != "0" ]]; then
		SOC_NAME="bm1688"
	elif [[ "$(grep -ai "athena2" '/proc/device-tree/model' 2>/dev/null | wc -l)" != "0" ]]; then
		SOC_NAME="bm1688"
	fi
else
	if [[ "$(busybox devmem 0x50010000)" == "0x16860000" ]]; then
		SOC_NAME="bm1684x"
	elif [[ "$(busybox devmem 0x50010000)" == "0x16840000" ]]; then
		SOC_NAME="bm1684"
	fi
fi
if [[ "${SOC_NAME}" == "" ]]; then
	echo "ERROR: cannot get chip id!"
	exit -1
else
	echo "INFO: chip id is ${SOC_NAME}"
fi

ROOTFS_EXCLUDE_FLAGS="${ROOTFS_EXCLUDE_FLAGS_RUN}"
for TGZ_FILE in "${TGZ_FILES[@]}"
do
	if [[ "$(lsblk | grep mmcblk0p | grep ${TGZ_FILE} | wc -l)" != "0" ]]; then
		echo "INFO: find ${TGZ_FILE} on emmc."
		ROOTFS_EXCLUDE_FLAGS="${ROOTFS_EXCLUDE_FLAGS} --exclude=./${TGZ_FILE}/* "
	elif [[ "${TGZ_FILE}" == "rootfs" ]] || [[ "${TGZ_FILE}" == "rootfs_rw" ]]; then
		echo "INFO: must bak ${TGZ_FILE} on emmc."
	else
		echo "INFO: not find ${TGZ_FILE} on emmc."
		unset TGZ_FILES_SIZE["${TGZ_FILE}"]
		TGZ_FILES=( ${TGZ_FILES[@]/${TGZ_FILE}} )
	fi
done
if [[ "$SOC_NAME" == "bm1684x" ]] || [[ "$SOC_NAME" == "bm1684" ]]; then
	have_system_of_mmc0=$(lsblk | grep mmcblk0p | grep system | wc -l)
	if [[ "$have_system_of_mmc0" == "1" ]]; then
		BM1684_SOC_VERSION=0
		NEED_BAK_FLASH=0
		echo "INFO: find /system dir, the version is 3.0.0 or lower, cannot suppot bakpack spi_flash"
	elif [ -d "/opt" ]; then
		BM1684_SOC_VERSION=1
		NEED_BAK_FLASH=1
		echo "INFO: find /opt dir, the version is V22.09.02 or higher"
	fi
elif [[ "$SOC_NAME" == "bm1688" ]]; then
	NEED_BAK_FLASH=1
	ROOTFS_RW_SIZE=$((9291456 + 0))
fi

if [ "$NEED_BAK_FLASH" -eq 1 ]; then
	echo "INFO: bakpack spi_flash start"
	if [[ "$SOC_NAME" == "bm1684x" ]] || [[ "$SOC_NAME" == "bm1684" ]] || [ -f /boot/spi_flash.bin ]; then
		cp /boot/spi_flash.bin spi_flash.bin
		rm -rf fip.bin
		FLASH_OFFSET=0
		if [[ "$SOC_NAME" == "bm1684x" ]]; then
			echo "INFO: soc is bm1684x"
			FLASH_OFFSET=0
			if [[ "$(flash_update -d fip.bin -b 0x6000000 -o 0x30000 -l 0x170000 | grep "^read" | wc -l)" == "0" ]]; then
				echo "WARNING: bak fip.bin cannot read data"
				rm -rf fip.bin
			fi
		elif [[ "$SOC_NAME" == "bm1684" ]]; then
			echo "INFO: soc is bm1684"
			FLASH_OFFSET=1
			if [[ "$(flash_update -d fip.bin -b 0x6000000 -o 0x40000 -l 0x160000 | grep "^read" | wc -l)" == "0" ]]; then
				echo "WARNING: bak fip.bin cannot read data"
				rm -rf fip.bin
			fi
		else
			echo "ERROR: cannot support reg 0x50010000: ${chip_reg_flag}"
			exit 1
		fi
		rm -rf spi_flash_$SOC_NAME.bin
		if [[ "$(flash_update -d spi_flash_$SOC_NAME.bin -b 0x6000000 -o 0 -l 0x200000 | grep "^read" | wc -l)" == "0" ]]; then
			echo "WARNING: bak spi_flash_$SOC_NAME.bin cannot read data"
			rm -rf spi_flash_$SOC_NAME.bin
			rm -rf spi_flash.bin
		else
			dd if=spi_flash_$SOC_NAME.bin of=spi_flash.bin seek=$FLASH_OFFSET bs=4194304 conv=notrunc
			cp spi_flash.bin /boot/spi_flash.bin.socBakNew
		fi
	elif [[ "$SOC_NAME" == "bm1688" ]]; then
		dd if=/dev/mmcblk0boot0 of=${TGZ_FILES_PATH}/fip.bin bs=512 count=2048
		if [[ "$?" != "0" ]]; then
			echo "WARNING: bak fip.bin cannot read data"
			rm -rf fip.bin
		fi
	fi
	echo "INFO: bakpack spi_flash end"
fi

if [[ "${SOC_BAK_NOT_TGZ}" == "1" ]]; then
	exit 0
fi

for TGZ_FILE in "${TGZ_FILES[@]}"
do
	case $TGZ_FILE in
		"rootfs")
			pushd /
			echo "INFO: tar $TGZ_FILE flags : $ROOTFS_EXCLUDE_FLAGS ..."
			systemctl enable resize-helper.service
			rm -rf $TGZ_FILES_PATH/$TGZ_FILE.tar
			tar --checkpoint=500 --checkpoint-action=ttyout='[%d sec]: C%u, %T%*\r' -capSf $TGZ_FILES_PATH/$TGZ_FILE.tar --numeric-owner $ROOTFS_EXCLUDE_FLAGS ./*
			tar --checkpoint=500 --checkpoint-action=ttyout='[%d sec]: C%u, %T%*\r' --ignore-failed-read -rapSf $TGZ_FILES_PATH/$TGZ_FILE.tar --numeric-owner $ROOTFS_INCLUDE_PATHS
			systemctl disable resize-helper.service
			echo "INFO: gzip tar file..."
			${PIGZ_GZIP_COM} -1 -c $TGZ_FILES_PATH/$TGZ_FILE.tar | dd of=$TGZ_FILES_PATH/$TGZ_FILE.tgz bs=4M status=progress
			rm -rf $TGZ_FILES_PATH/$TGZ_FILE.tar
			TAR_SIZE=$((512*1024))
			popd
			;;
		*)
			pushd /$TGZ_FILE
			echo "INFO: tar $TGZ_FILE ..."
			tar --checkpoint=500 --checkpoint-action=ttyout='[%d sec]: C%u, %T%*\r' -I ${PIGZ_GZIP_COM} -cpSf $TGZ_FILES_PATH/$TGZ_FILE.tgz --numeric-owner ./*
			if [ $TGZ_FILE == "data" ]; then
				TAR_SIZE=$((512*1024))
			else
				TAR_SIZE=$((100*1024))
			fi
			popd
			;;
	esac
	socbak_get_tar_size ${TGZ_FILE}.tgz
	TAR_SIZE_AUTO=$(( ${SOCBAK_GET_TAR_SIZE_KB} / 8 ))
	if [ $TAR_SIZE_AUTO -gt $TAR_SIZE ]; then
		TAR_SIZE=$(($TAR_SIZE_AUTO))
	fi
	TAR_SIZE=$((${SOCBAK_GET_TAR_SIZE_KB}+${TAR_SIZE}))
	echo "INFO: $TGZ_FILE : $TAR_SIZE KB"
	if [ $TAR_SIZE -gt ${TGZ_FILES_SIZE["$TGZ_FILE"]} ];
	then
		echo "INFO: need to expand $TGZ_FILE from ${TGZ_FILES_SIZE[$TGZ_FILE]} KB to $TAR_SIZE KB"
		TGZ_FILES_SIZE[$TGZ_FILE]=$TAR_SIZE
	fi
done

TGZ_ALL_SIZE=$(($TGZ_ALL_SIZE+${ROOTFS_RW_SIZE}))
for TGZ_FILE in "${TGZ_FILES[@]}"
do
	TGZ_ALL_SIZE=$(($TGZ_ALL_SIZE+${TGZ_FILES_SIZE["$TGZ_FILE"]}))
done
echo partition table size : $TGZ_ALL_SIZE KB

if [ $TGZ_ALL_SIZE -gt $EMMC_ALL_SIZE ];
	then
		echo "INFO: need to expand default partition table size from $EMMC_ALL_SIZE KB to $TGZ_ALL_SIZE KB"
		EMMC_ALL_SIZE=$TGZ_ALL_SIZE
fi

# if [ $TGZ_ALL_SIZE -gt $EMMC_MAX_SIZE ];
#	then
#		echo The total size is too large.
#		exit 1
# fi

if [[ "$SOC_NAME" == "bm1684x" ]] || [[ "$SOC_NAME" == "bm1684" ]]; then
	echo "INFO: FORE BM1684/X The generated file partition32G.xml can replace file bootloader-arm64/scripts/partition32G.xml in VXX or replace some information for 3.0.0"
fi
echo "<physical_partition size_in_kb=\"$EMMC_ALL_SIZE\">" > $TGZ_FILES_PATH/$PARTITION_FILE
# boot data opt system recovery rootfs
if [[ " ${TGZ_FILES[@]} " =~ " boot " ]]; then
	echo "  <partition label=\"BOOT\"       size_in_kb=\"${TGZ_FILES_SIZE[boot]}\"  readonly=\"false\"  format=\"1\" />" >> $TGZ_FILES_PATH/$PARTITION_FILE
fi
if [[ " ${TGZ_FILES[@]} " =~ " recovery " ]]; then
	echo "  <partition label=\"RECOVERY\"   size_in_kb=\"${TGZ_FILES_SIZE[recovery]}\"  readonly=\"false\" format=\"2\" />" >> $TGZ_FILES_PATH/$PARTITION_FILE
fi
echo "  <partition label=\"MISC\"       size_in_kb=\"10240\"  readonly=\"false\"   format=\"0\" />" >> $TGZ_FILES_PATH/$PARTITION_FILE
if [[ " ${TGZ_FILES[@]} " =~ " rootfs " ]]; then
	echo "  <partition label=\"ROOTFS\"     size_in_kb=\"${TGZ_FILES_SIZE[rootfs]}\" readonly=\"true\"   format=\"2\" />" >> $TGZ_FILES_PATH/$PARTITION_FILE
fi
echo "  <partition label=\"ROOTFS_RW\"  size_in_kb=\"${ROOTFS_RW_SIZE}\" readonly=\"false\"  format=\"2\" />" >> $TGZ_FILES_PATH/$PARTITION_FILE
if [[ " ${TGZ_FILES[@]} " =~ " opt " ]]; then
	echo "  <partition label=\"OPT\"       size_in_kb=\"${TGZ_FILES_SIZE[opt]}\" readonly=\"false\"  format=\"2\" />" >> $TGZ_FILES_PATH/$PARTITION_FILE
fi
if [[ " ${TGZ_FILES[@]} " =~ " system " ]]; then
	echo "  <partition label=\"SYSTEM\"     size_in_kb=\"${TGZ_FILES_SIZE[system]}\" readonly=\"false\"  format=\"2\" />" >> $TGZ_FILES_PATH/$PARTITION_FILE
fi
if [[ " ${TGZ_FILES[@]} " =~ " data " ]]; then
	echo "  <partition label=\"DATA\"       size_in_kb=\"${TGZ_FILES_SIZE[data]}\" readonly=\"false\"  format=\"2\" />" >> $TGZ_FILES_PATH/$PARTITION_FILE
fi
echo "</physical_partition>" >> $TGZ_FILES_PATH/$PARTITION_FILE
cat $TGZ_FILES_PATH/$PARTITION_FILE
sync

