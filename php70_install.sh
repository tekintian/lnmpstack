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
# PHP 版本 1 -> php-5.3 ; 2 -> php-5.4 ; 3 -> php-5.5 ; 4 -> php-5.6 ; 5 -> php-7.0 ; 6 -> php-7.1
sed -i "s@^PHP_version.*@PHP_version=5@" ./mphp.conf
sed -i "s@^MPHP_version.*@MPHP_version=70@" ./mphp.conf
sed -i "s@^php_install_dir.*@php_install_dir=/usr/local/php-70@" ./options.conf

. ./versions.txt
. ./options.conf
. ./mphp.conf
. ./include/color.sh
. ./include/check_os.sh
. ./include/check_dir.sh
. ./include/download.sh
. ./include/get_char.sh

# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

mkdir -p $wwwroot_dir/default $wwwlogs_dir
[ -d /home/data ] && chmod 755 /home/data


# get the IP information
IPADDR=`./include/get_ipaddr.py`
PUBLIC_IPADDR=`./include/get_public_ipaddr.py`
IPADDR_COUNTRY_ISP=`./include/get_ipaddr_state.py $PUBLIC_IPADDR`
IPADDR_COUNTRY=`echo $IPADDR_COUNTRY_ISP | awk '{print $1}'`
[ "`echo $IPADDR_COUNTRY_ISP | awk '{print $2}'`"x == '1000323'x ] && IPADDR_ISP=aliyun


# get memory for mphp
. ./include/memory_m.sh


# Check download source packages
. ./include/check_download.sh
downloadDepsSrc=1
checkDownload 2>&1 | tee -a ${oneinstack_dir}/install.log


#php
. include/php-7.0.sh
Install_PHP70 2>&1 | tee -a ${oneinstack_dir}/php_install.log

# redis
if [ "${redis_yn}" == 'y' ]; then
  . include/redis.sh
  [ ! -d "${redis_install_dir}" ] && Install_redis-server 2>&1 | tee -a ${oneinstack_dir}/php_install.log
  [ -e "${php_install_dir}/bin/phpize" ] && [ ! -e "$(${php_install_dir}/bin/php-config --extension-dir)/redis.so" ] && Install_php-redis 2>&1 | tee -a ${oneinstack_dir}/php_install.log
fi

# memcached
if [ "${memcached_yn}" == 'y' ]; then
  . include/memcached.sh
  [ ! -d "${memcached_install_dir}/include/memcached" ] && Install_memcached 2>&1 | tee -a ${oneinstack_dir}/php_install.log
  [ -e "${php_install_dir}/bin/phpize" ] && [ ! -e "$(${php_install_dir}/bin/php-config --extension-dir)/memcache.so" ] && Install_php-memcache 2>&1 | tee -a ${oneinstack_dir}/php_install.log
  [ -e "${php_install_dir}/bin/phpize" ] && [ ! -e "$(${php_install_dir}/bin/php-config --extension-dir)/memcached.so" ] && Install_php-memcached 2>&1 | tee -a ${oneinstack_dir}/php_install.log
fi


# ImageMagick or GraphicsMagick
if [ "$Magick" == '1' ]; then
  . include/ImageMagick.sh
  [ ! -d "/usr/local/imagemagick" ] && Install_ImageMagick 2>&1 | tee -a $oneinstack_dir/install.log
  [ ! -e "`$php_install_dir/bin/php-config --extension-dir`/imagick.so" ] && Install_php-imagick 2>&1 | tee -a $oneinstack_dir/install.log
elif [ "$Magick" == '2' ]; then
  . include/GraphicsMagick.sh
  [ ! -d "/usr/local/graphicsmagick" ] && Install_GraphicsMagick 2>&1 | tee -a $oneinstack_dir/install.log
  [ ! -e "`$php_install_dir/bin/php-config --extension-dir`/gmagick.so" ] && Install_php-gmagick 2>&1 | tee -a $oneinstack_dir/install.log
fi

# PHP opcode cache
case "${PHP_cache}" in
  1)
    if [[ "${PHP_version}" =~ ^[1,2]$ ]]; then
      . include/zendopcache.sh
      Install_ZendOPcache 2>&1 | tee -a ${oneinstack_dir}/install.log
    fi
    ;;
  2)
    . include/xcache.sh
    Install_XCache 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  3)
    . include/apcu.sh
    Install_APCU 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  4)
    if [[ "${PHP_version}" =~ ^[1,2]$ ]]; then
      . include/eaccelerator.sh
      Install_eAccelerator 2>&1 | tee -a ${oneinstack_dir}/install.log
    fi
    ;;
esac

# ZendGuardLoader (php <= 5.6)
if [ "$ZendGuardLoader_yn" == 'y' ]; then
  . include/ZendGuardLoader.sh
  Install_ZendGuardLoader 2>&1 | tee -a $oneinstack_dir/install.log
fi
