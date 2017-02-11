#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://blog.linuxeye.com
#
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/lj2007331/oneinstack

Install_PHP53() {
  pushd ${oneinstack_dir}/src
  
  # Problem building php-5.3 with openssl

    OpenSSL_args='--with-openssl'



  
  id -u $run_user >/dev/null 2>&1
  [ $? -ne 0 ] && useradd -M -s /sbin/nologin $run_user
  
  tar xzf php-$php53_version.tar.gz
  patch -d php-$php53_version -p0 < fpm-race-condition.patch
  pushd php-$php53_version
  patch -p1 < ../php5.3patch
  patch -p1 < ../debian_patches_disable_SSLv2_for_openssl_1_0_0.patch
  make clean
  [ ! -d "$php_install_dir" ] && mkdir -p $php_install_dir
  if [[ $Apache_version =~ ^[1-2]$ ]] || [ -e "$apache_install_dir/bin/apxs" ]; then
    ./configure --prefix=$php_install_dir --with-config-file-path=$php_install_dir/etc \
    --with-config-file-scan-dir=$php_install_dir/etc/php.d \
    --with-apxs2=$apache_install_dir/bin/apxs --disable-fileinfo \
    --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
    --with-iconv-dir=/usr/local --with-freetype-dir --with-jpeg-dir --with-png-dir --with-zlib \
    --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-exif \
    --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local --enable-mbregex \
    --enable-mbstring --with-mcrypt --with-gd --enable-gd-native-ttf $OpenSSL_args \
    --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-ftp --enable-intl --with-xsl \
    --with-gettext --enable-zip --enable-soap --disable-debug
  else
    ./configure --prefix=$php_install_dir --with-config-file-path=$php_install_dir/etc \
    --with-config-file-scan-dir=$php_install_dir/etc/php.d \
    --with-fpm-user=$run_user --with-fpm-group=$run_user --enable-fpm --disable-fileinfo \
    --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
    --with-iconv-dir=/usr/local --with-freetype-dir --with-jpeg-dir --with-png-dir --with-zlib \
    --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-exif \
    --enable-sysvsem --enable-inline-optimization --with-curl=/usr/local --enable-mbregex \
    --enable-mbstring --with-mcrypt --with-gd --enable-gd-native-ttf $OpenSSL_args \
    --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-ftp --enable-intl --with-xsl \
    --with-gettext --enable-zip --enable-soap --disable-debug
  fi
  sed -i '/^BUILD_/ s/\$(CC)/\$(CXX)/g' Makefile
  make ZEND_EXTRA_LIBS='-liconv' -j ${THREAD}
  make install
  
  if [ -e "$php_install_dir/bin/phpize" ]; then
    echo "${CSUCCESS}PHP installed successfully! ${CEND}"
  else
    rm -rf $php_install_dir
    echo "${CFAILURE}PHP install failed, Please Contact the author! ${CEND}"
    kill -9 $$
  fi
  
  [ -z "`grep ^'export PATH=' /etc/profile`" ] && echo "export PATH=$php_install_dir/bin:\$PATH" >> /etc/profile
  [ -n "`grep ^'export PATH=' /etc/profile`" -a -z "`grep $php_install_dir /etc/profile`" ] && sed -i "s@^export PATH=\(.*\)@export PATH=$php_install_dir/bin:\1@" /etc/profile
  . /etc/profile
  
  # wget -c http://pear.php.net/go-pear.phar
  # $php_install_dir/bin/php go-pear.phar
  
  [ ! -e "$php_install_dir/etc/php.d" ] && mkdir -p $php_install_dir/etc/php.d
  /bin/cp php.ini-production $php_install_dir/etc/php.ini
  
  sed -i "s@^memory_limit.*@memory_limit = ${Memory_limit}M@" $php_install_dir/etc/php.ini
  sed -i 's@^output_buffering =@output_buffering = On\noutput_buffering =@' $php_install_dir/etc/php.ini
  sed -i 's@^;cgi.fix_pathinfo.*@cgi.fix_pathinfo=0@' $php_install_dir/etc/php.ini
  sed -i 's@^short_open_tag = Off@short_open_tag = On@' $php_install_dir/etc/php.ini
  sed -i 's@^expose_php = On@expose_php = Off@' $php_install_dir/etc/php.ini
  sed -i 's@^request_order.*@request_order = "CGP"@' $php_install_dir/etc/php.ini
  sed -i 's@^;date.timezone.*@date.timezone = Asia/Shanghai@' $php_install_dir/etc/php.ini
  sed -i 's@^post_max_size.*@post_max_size = 100M@' $php_install_dir/etc/php.ini
  sed -i 's@^upload_max_filesize.*@upload_max_filesize = 50M@' $php_install_dir/etc/php.ini
  sed -i 's@^max_execution_time.*@max_execution_time = 5@' $php_install_dir/etc/php.ini
  sed -i 's@^disable_functions.*@disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server,fsocket,popen@' $php_install_dir/etc/php.ini
  [ -e /usr/sbin/sendmail ] && sed -i 's@^;sendmail_path.*@sendmail_path = /usr/sbin/sendmail -t -i@' $php_install_dir/etc/php.ini
  
  if [[ ! $Apache_version =~ ^[1-2]$ ]] && [ ! -e "$apache_install_dir/bin/apxs" ]; then
    # php-fpm Init Script
    /bin/cp sapi/fpm/init.d.php-fpm /etc/init.d/php53-fpm
    chmod +x /etc/init.d/php53-fpm
    sed -i 's@^# Provides: .*@# Provides: php53-fpm@' /etc/init.d/php53-fpm
    [ "$OS" == 'CentOS' ] && { chkconfig --add php53-fpm; chkconfig php53-fpm on; }
    [[ $OS =~ ^Ubuntu$|^Debian$ ]] && update-rc.d php53-fpm defaults

    cat > $php_install_dir/etc/php-fpm.conf <<EOF
;;;;;;;;;;;;;;;;;;;;;
; FPM Configuration ;
;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;
; Global Options ;
;;;;;;;;;;;;;;;;;;

[global]
pid = run/php53-fpm.pid
error_log = log/php53-fpm.log
log_level = warning

emergency_restart_threshold = 30
emergency_restart_interval = 60s
process_control_timeout = 5s
daemonize = yes

;;;;;;;;;;;;;;;;;;;;
; Pool Definitions ;
;;;;;;;;;;;;;;;;;;;;

[$run_user]
listen = /dev/shm/php53-cgi.sock
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = $run_user
listen.group = $run_user
listen.mode = 0666
user = $run_user
group = $run_user

pm = dynamic
pm.max_children = 12
pm.start_servers = 8
pm.min_spare_servers = 6
pm.max_spare_servers = 12
pm.max_requests = 2048
pm.process_idle_timeout = 10s
request_terminate_timeout = 120
request_slowlog_timeout = 0

pm.status_path = /php53-fpm_status
slowlog = log/slow.log
rlimit_files = 51200
rlimit_core = 0

catch_workers_output = yes
;env[HOSTNAME] = $HOSTNAME
env[PATH] = /usr/local/bin:/usr/bin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp
EOF

    [ -d "/run/shm" -a ! -e "/dev/shm" ] && sed -i 's@/dev/shm@/run/shm@' $php_install_dir/etc/php-fpm.conf $oneinstack_dir/vhost.sh $oneinstack_dir/config/nginx.conf

    if [ $Mem -le 3000 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = $(($Mem/3/20))@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = $(($Mem/3/30))@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = $(($Mem/3/40))@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = $(($Mem/3/20))@" $php_install_dir/etc/php-fpm.conf
    elif [ $Mem -gt 3000 -a $Mem -le 4500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 50@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 30@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 20@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 50@" $php_install_dir/etc/php-fpm.conf
    elif [ $Mem -gt 4500 -a $Mem -le 6500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 60@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 40@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 30@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 60@" $php_install_dir/etc/php-fpm.conf
    elif [ $Mem -gt 6500 -a $Mem -le 8500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 70@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 50@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 40@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 70@" $php_install_dir/etc/php-fpm.conf
    elif [ $Mem -gt 8500 ]; then
      sed -i "s@^pm.max_children.*@pm.max_children = 80@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.start_servers.*@pm.start_servers = 60@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.min_spare_servers.*@pm.min_spare_servers = 50@" $php_install_dir/etc/php-fpm.conf
      sed -i "s@^pm.max_spare_servers.*@pm.max_spare_servers = 80@" $php_install_dir/etc/php-fpm.conf
    fi

    #[ "$Web_yn" == 'n' ] && sed -i "s@^listen =.*@listen = $IPADDR:9053@" $php_install_dir/etc/php-fpm.conf
    service php53-fpm start

  elif [[ $Apache_version =~ ^[1-2]$ ]] || [ -e "$apache_install_dir/bin/apxs" ]; then
    service httpd restart
  fi
  popd
  [ -e "$php_install_dir/bin/phpize" ] && rm -rf php-$php53_version
  popd
}
