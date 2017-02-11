# @Author: tekin
# @Date:   2016-12-13 11:17:05
# @Last Modified by:   tekin
# @Last Modified time: 2016-12-13 11:27:16

#安裝多版本PHP的相關

# get the IP information
IPADDR=`./include/get_ipaddr.py`
PUBLIC_IPADDR=`./include/get_public_ipaddr.py`
IPADDR_COUNTRY_ISP=`./include/get_ipaddr_state.py $PUBLIC_IPADDR`
IPADDR_COUNTRY=`echo $IPADDR_COUNTRY_ISP | awk '{print $1}'`
[ "`echo $IPADDR_COUNTRY_ISP | awk '{print $2}'`"x == '1000323'x ] && IPADDR_ISP=aliyun

# Check binary dependencies packages
. ./include/check_sw.sh
case "${OS}" in
  "CentOS")
    installDepsCentOS 2>&1 | tee ${oneinstack_dir}/install.log
    ;;
  "Debian")
    installDepsDebian 2>&1 | tee ${oneinstack_dir}/install.log
    ;;
  "Ubuntu")
    installDepsUbuntu 2>&1 | tee ${oneinstack_dir}/install.log
    ;;
esac

# init
. ./include/memory.sh
case "${OS}" in
  "CentOS")
    . include/init_CentOS.sh 2>&1 | tee -a ${oneinstack_dir}/install.log
    [ -n "$(gcc --version | head -n1 | grep '4\.1\.')" ] && export CC="gcc44" CXX="g++44"
    ;;
  "Debian")
    . include/init_Debian.sh 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
  "Ubuntu")
    . include/init_Ubuntu.sh 2>&1 | tee -a ${oneinstack_dir}/install.log
    ;;
esac

# Check download source packages
. ./include/check_download.sh
downloadDepsSrc=1
checkDownload 2>&1 | tee -a ${oneinstack_dir}/install.log

# Install dependencies from source package
installDepsBySrc 2>&1 | tee -a ${oneinstack_dir}/install.log

