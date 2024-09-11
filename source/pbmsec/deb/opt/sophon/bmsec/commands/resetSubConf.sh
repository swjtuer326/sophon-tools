#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
###############################################

sudo rm -rf "${seNCtrl_PWD}/configs/subNANInfo"
sudo rm -rf "${seNCtrl_PWD}/configs/dns/coreDns.conf"
${seNCtrl_PWD}/bmsec pconf
