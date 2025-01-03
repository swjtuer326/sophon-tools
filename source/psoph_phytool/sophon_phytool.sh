#!/bin/bash
#set -x
reg1=$(sudo phytool read eth1/0/0x02)  # PHY ID1 
reg2=$(sudo phytool read eth1/0/0x03)  # PHY ID2 

reg1_dec=$((reg1))
reg2_dec=$((reg2))

combined_dec=$(( (reg1_dec << 16) | reg2_dec ))
combined_hex=$(printf "0x%08x" $combined_dec)

echo "[info]: PHY chip ID: $combined_hex"

if [ "$#" -lt 6 ]; then
    echo "usage: $0 <read|write> <ic_name> <device> <phy_addr> <page> <reg_addr> [write_data]"
    echo "examples:"
    echo "read:  $0 read YT eth1 0x0 0xa003 0x1f"
    echo "write: $0 write RTL eth1 0x0 0xd08 0x15 0x19"
    exit 1
fi


operation=$1
ic_name=$2
device=$3
phy_addr=$4
page=$5
reg_addr=$6


# set page_reg according to ic_name
if [ "$ic_name" == "YT" ]; then
    page_reg=0x1e
    echo "[info]: ic page reg: $page_reg"
elif [ "$ic_name" == "RTL" ]; then
    page_reg=0x1f
    echo "[info]: ic page reg: $page_reg"
elif [ "$ic_name" == "MARVEL" ]; then
    page_reg=0x16
    echo "[info]: ic page reg: $page_reg"
else
    echo "[Warning]: $ic_name is not support!"
    exit 1
fi


function read_phy_reg() {
	device=$1
	phy_addr=$2
	page=$3
	reg_addr=$4

	sudo phytool write ${device}/${phy_addr}/${page_reg} ${page}
	dump_reg=$(sudo phytool read  ${device}/${phy_addr}/${reg_addr})
	echo "[info]: ${device}: page is ${page} , reg addr is ${reg_addr}, reg value is ${dump_reg}"
	sudo phytool write ${device}/${phy_addr}/${page_reg} 0x00
}

function write_phy_reg() {
	device=$1
	phy_addr=$2
	page=$3
	reg_addr=$4
	write_data=$5

	sudo phytool write ${device}/${phy_addr}/${page_reg} ${page}
	sudo phytool write ${device}/${phy_addr}/${reg_addr} ${write_data}
	sudo phytool write ${device}/${phy_addr}/${page_reg} 0x00

	# check if write data successfully
	if [ $? -ne 0 ]; then
            echo "[Error]: write reg failed: ${device}/${phy_addr}/${reg_addr}"
            exit 1
	fi
}

if [ "$operation" == "read" ]; then
    read_phy_reg $device $phy_addr $page $reg_addr
elif [ "$operation" == "write" ]; then
    if [ "$#" -ne 7 ]; then
        echo "[Warning]: need: <write_data>"
        exit 1
    fi
    write_data=$7
    write_phy_reg $device $phy_addr $page $reg_addr $write_data
    echo "[info]: $device: page: $page, reg addr: $reg_addr, write data: $write_data"
else
    echo "[Error]: invalid operation: $operation. choose 'read' or 'write'."
    exit 1
fi
