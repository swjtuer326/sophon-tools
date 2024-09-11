#!/bin/bash
###############################################
############zetao.zhang@sophgo.com#############
############shiwei.su@sophgo.com###############
###############################################

toolVersion=$(dpkg -l | grep "bmsec" | awk '{print $3}')
echo "bmsec version: $toolVersion"
echo "help:"
echo "The tool has two usage modes. The first usage mode is the command-line mode, which uses command-line arguments as parameters for each subfunction."
echo "usage: bmsec [run <id> <args>]"
echo "The second one is interactive command mode."
echo -e "$seNCtrl_OPTIONS_INFO"
echo "More help information can be found by run 'man bmsec' "
echo "More help information can be found in the HTML document located in the /opt/sophon/bmsec/doc"
