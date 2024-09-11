#!/bin/bash
sudo apt install -y docker.io
sudo docker pull ubuntu:18.04
source_path=$(pwd)
sudo docker run --rm --privileged -v /dev:/dev -v ${source_path}:/root/workspace ubuntu:18.04 /bin/bash -c "sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list && sed -i 's|http://ports.ubuntu.com/ubuntu-ports/|http://mirrors.ustc.edu.cn/ubuntu-ports/|g' /etc/apt/sources.list && apt-get update && apt-get -y install qt5-default qtbase5-dev qttools5-dev g++ libgl1-mesa-dev patchelf cmake make gcc git wget libfuse2 fuse libglib2.0-0 && cd /root/workspace && git config --global --add safe.directory /root/workspace && ./linux_release.sh"
sudo chmod 777 output/*.AppImage
sudo rm -rf arm64 
