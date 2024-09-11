#!/bin/bash

seNCtrl_ARCH=""
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    seNCtrl_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    seNCtrl_ARCH="arm64"
else
    echo "not support arch: $ARCH"
    exit -1
fi

sudo chmod +x ${seNCtrl_PWD}/binTools/${seNCtrl_ARCH}/*

seNCtrl_MEMSHARE=${seNCtrl_PWD}/binTools/${seNCtrl_ARCH}/memShare
seNCtrl_SSHPASS=${seNCtrl_PWD}/binTools/${seNCtrl_ARCH}/sshpass
seNCtrl_PICOCOM=${seNCtrl_PWD}/binTools/${seNCtrl_ARCH}/picocom
PATH=$PATH:${seNCtrl_PWD}/binTools/${seNCtrl_ARCH}
sudo chmod +x ${seNCtrl_PWD}/binTools/*
sudo chmod +x ${seNCtrl_PWD}/binTools/${seNCtrl_ARCH}/*
