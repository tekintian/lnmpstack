#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://blog.linuxeye.com
#
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/lj2007331/oneinstack

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear
printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"

# get pwd
sed -i "s@^oneinstack_dir.*@oneinstack_dir=`pwd`@" ./options.conf

. ./versions.txt
. ./options.conf
. ./include/color.sh
. ./include/check_os.sh
. ./include/check_dir.sh
. ./include/download.sh
. ./include/get_char.sh

# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

# check Pureftpd
while :; do echo
  read -p "Do you want to install Pure-FTPd? [y/n]: " FTP_yn
  if [[ ! $FTP_yn =~ ^[y,n]$ ]]; then
    echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
  else
    [ "$FTP_yn" == 'y' -a -e "$pureftpd_install_dir/sbin/pure-ftpwho" ] && { echo "${CWARNING}Pure-FTPd already installed! ${CEND}"; FTP_yn=Other; }
    break
  fi
done

# Pure-FTPd
if [ "${FTP_yn}" == 'y' ]; then
  . include/pureftpd.sh
  Install_PureFTPd 2>&1 | tee -a ${oneinstack_dir}/install.log
fi