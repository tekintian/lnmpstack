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

. ./options.conf
. ./mphp.conf
. ./include/color.sh
. ./include/check_dir.sh
. ./include/check_os.sh
. ./include/get_char.sh

# Check if user is root
[ $(id -u) != '0' ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

Usage() {
  printf "
Usage: $0 [ ${CMSG}add${CEND} | ${CMSG}del${CEND} ]
${CMSG}add${CEND}    --->Add Virtualhost
${CMSG}del${CEND}    --->Delete Virtualhost

"
}

Choose_env() {
  if [ -e "${php_install_dir}/bin/phpize" -a -e "${tomcat_install_dir}/conf/server.xml" -a -e "/usr/bin/hhvm" ]; then
    Number=111
    while :; do echo
      echo "Please choose to use environment:"
      echo -e "\t${CMSG}1${CEND}. Use php $MPHP_version "
      echo -e "\t${CMSG}2${CEND}. Use java"
      echo -e "\t${CMSG}3${CEND}. Use hhvm"
      read -p "Please input a number:(Default 1 press Enter) " Choose_number
      [ -z "${Choose_number}" ] && Choose_number=1
      if [[ ! ${Choose_number} =~ ^[1-3]$ ]]; then
        echo "${CWARNING}input error! Please only input number 1,2,3${CEND}"
      else
        break
      fi
    done
    case "${Choose_number}" in
      1)
        NGX_FLAG=php
        ;;
      2)
        NGX_FLAG=java
        ;;
      3)
        NGX_FLAG=hhvm
        ;;
    esac
  elif [ -e "${php_install_dir}/bin/phpize" -a -e "${tomcat_install_dir}/conf/server.xml" -a ! -e "/usr/bin/hhvm" ]; then
    Number=110
    while :; do echo
      echo "Please choose to use environment:"
      echo -e "\t${CMSG}1${CEND}. Use php"
      echo -e "\t${CMSG}2${CEND}. Use java"
      read -p "Please input a number:(Default 1 press Enter) " Choose_number
      [ -z "${Choose_number}" ] && Choose_number=1
      if [[ ! ${Choose_number} =~ ^[1-2]$ ]]; then
        echo "${CWARNING}input error! Please only input number 1,2${CEND}"
      else
        break
      fi
    done
    [ "${Choose_number}" == '1' ] && NGX_FLAG=php
    [ "${Choose_number}" == '2' ] && NGX_FLAG=java
  elif [ -e "${php_install_dir}/bin/phpize" -a ! -e "${tomcat_install_dir}/conf/server.xml" -a ! -e "/usr/bin/hhvm" ]; then
    Number=100
    NGX_FLAG=php
  elif [ -e "${php_install_dir}/bin/phpize" -a ! -e "${tomcat_install_dir}/conf/server.xml" -a -e "/usr/bin/hhvm" ]; then
    Number=101
    while :; do echo
      echo "Please choose to use environment:"
      echo -e "\t${CMSG}1${CEND}. Use php"
      echo -e "\t${CMSG}2${CEND}. Use hhvm"
      read -p "Please input a number:(Default 1 press Enter) " Choose_number
      [ -z "${Choose_number}" ] && Choose_number=1
      if [[ ! ${Choose_number} =~ ^[1-2]$ ]]; then
        echo "${CWARNING}input error! Please only input number 1,2${CEND}"
      else
        break
      fi
    done
    [ "${Choose_number}" == '1' ] && NGX_FLAG=php
    [ "${Choose_number}" == '2' ] && NGX_FLAG=hhvm
  elif [ ! -e "${php_install_dir}/bin/phpize" -a -e "${tomcat_install_dir}/conf/server.xml" -a -e "/usr/bin/hhvm" ]; then
    Number=011
    while :; do echo
      echo "Please choose to use environment:"
      echo -e "\t${CMSG}1${CEND}. Use java"
      echo -e "\t${CMSG}2${CEND}. Use hhvm"
      read -p "Please input a number:(Default 1 press Enter) " Choose_number
      [ -z "${Choose_number}" ] && Choose_number=1
      if [[ ! ${Choose_number} =~ ^[1-2]$ ]]; then
        echo "${CWARNING}input error! Please only input number 1,2${CEND}"
      else
        break
      fi
    done
    [ "${Choose_number}" == '1' ] && NGX_FLAG=java
    [ "${Choose_number}" == '2' ] && NGX_FLAG=hhvm
  elif [ ! -e "${php_install_dir}/bin/phpize" -a -e "${tomcat_install_dir}/conf/server.xml" -a ! -e "/usr/bin/hhvm" ]; then
    Number=010
    NGX_FLAG=java
  elif [ ! -e "${php_install_dir}/bin/phpize" -a ! -e "${tomcat_install_dir}/conf/server.xml" -a -e "/usr/bin/hhvm" ]; then
    Number=001
    NGX_FLAG=hhvm
  else
    Number=000
    NGX_FLAG=php
  fi

  case "${NGX_FLAG}" in
    "php")
      NGX_CONF=$(echo -e "location ~ [^/]\.php(/|$) {\n    #fastcgi_pass remote_php_ip:90${MPHP_version};\n    fastcgi_pass unix:/dev/shm/php${MPHP_version}-cgi.sock;\n    fastcgi_index index.php;\n    include fastcgi.conf;\n  }")
      ;;
    "java")
      NGX_CONF=$(echo -e "location ~ {\n    proxy_pass http://127.0.0.1:8080;\n    include proxy.conf;\n  }")
      ;;
    "hhvm")
      NGX_CONF=$(echo -e "location ~ .*\.(php|php5)?$ {\n    fastcgi_pass unix:/var/log/hhvm/sock;\n    fastcgi_index index.php;\n    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;\n    include fastcgi_params;\n  }")
      ;;
  esac
}

Create_self_SSL() {
  printf "
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
"

  echo
  read -p "Country Name (2 letter code) [CN]: " SELFSIGNEDSSL_C
  [ -z "${SELFSIGNEDSSL_C}" ] && SELFSIGNEDSSL_C="CN"

  echo
  read -p "State or Province Name (full name) [Shanghai]: " SELFSIGNEDSSL_ST
  [ -z "${SELFSIGNEDSSL_ST}" ] && SELFSIGNEDSSL_ST="Shanghai"

  echo
  read -p "Locality Name (eg, city) [Shanghai]: " SELFSIGNEDSSL_L
  [ -z "${SELFSIGNEDSSL_L}" ] && SELFSIGNEDSSL_L="Shanghai"

  echo
  read -p "Organization Name (eg, company) [Example Inc.]: " SELFSIGNEDSSL_O
  [ -z "${SELFSIGNEDSSL_O}" ] && SELFSIGNEDSSL_O="Example Inc."

  echo
  read -p "Organizational Unit Name (eg, section) [IT Dept.]: " SELFSIGNEDSSL_OU
  [ -z "${SELFSIGNEDSSL_O}U" ] && SELFSIGNEDSSL_OU="IT Dept."

  openssl req -new -newkey rsa:2048 -sha256 -nodes -out ${PATH_SSL}/${domain}.csr -keyout ${PATH_SSL}/${domain}.key -subj "/C=${SELFSIGNEDSSL_C}/ST=${SELFSIGNEDSSL_ST}/L=${SELFSIGNEDSSL_L}/O=${SELFSIGNEDSSL_O}/OU=${SELFSIGNEDSSL_OU}/CN=${domain}" > /dev/null 2>&1
  openssl x509 -req -days 36500 -sha256 -in ${PATH_SSL}/${domain}.csr -signkey ${PATH_SSL}/${domain}.key -out ${PATH_SSL}/${domain}.crt > /dev/null 2>&1
}

Create_SSL() {
  if [ -e "${python_install_dir}/bin/certbot" ]; then
    while :; do echo
      read -p "Do you want to use a Let's Encrypt certificate? [y/n]: " letsencrypt_yn
      if [[ ! ${letsencrypt_yn} =~ ^[y,n]$ ]]; then
        echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
      else
        break
      fi
    done
    if [ "${letsencrypt_yn}" == 'y' ]; then
      PUBLIC_IPADDR=$(./include/get_public_ipaddr.py)
      for D in ${domain} ${moredomainame}
      do
        Domain_IPADDR=$(ping ${D} -c1 | sed '1{s/[^(]*(//;s/).*//;q}')
        [ "${PUBLIC_IPADDR}" != "${Domain_IPADDR}" ] && { echo; echo "${CFAILURE}DNS problem: NXDOMAIN looking up A for ${D}${CEND}"; echo; exit 1; }
      done

      #add Email
      while :
      do
        echo
        read -p "Please enter Administrator Email(example: admin@example.com): " Admin_Email
        if [ -z "$(echo ${Admin_Email} | grep '.*@.*\..*')" ]; then
          echo "${CWARNING}input error! ${CEND}"
        else
          break
        fi
      done

      [ "${moredomainame_yn}" == 'y' ] && moredomainame_D="$(for D in ${moredomainame}; do echo -d ${D}; done)"
      if [ "${nginx_ssl_yn}" == 'y' ]; then 
        [ ! -d ${web_install_dir}/conf/vhost ] && mkdir ${web_install_dir}/conf/vhost
        echo "server {  server_name ${domain}${moredomainame};  root ${vhostdir};  access_log off; }" > ${web_install_dir}/conf/vhost/${domain}.conf
        /etc/init.d/nginx reload > /dev/null
      fi

      if [ "${apache_ssl_yn}" == 'y' ]; then
        [ ! -d ${apache_install_dir}/conf/vhost ] && mkdir ${apache_install_dir}/conf/vhost
        cat > ${apache_install_dir}/conf/vhost/${domain}.conf << EOF
<VirtualHost *:80>
  ServerAdmin admin@example.com
  DocumentRoot "${vhostdir}"
  ServerName ${domain}
  ${Apache_Domain_alias}
<Directory "${vhostdir}">
  SetOutputFilter DEFLATE
  Options FollowSymLinks ExecCGI
  Require all granted
  AllowOverride All
  Order allow,deny
  Allow from all
  DirectoryIndex index.html index.php
</Directory>
</VirtualHost>
EOF
        /etc/init.d/httpd restart > /dev/null
      fi

      ${python_install_dir}/bin/certbot certonly --webroot --agree-tos --quiet --email ${Admin_Email} -w ${vhostdir} -d ${domain} ${moredomainame_D}
      if [ -s "/etc/letsencrypt/live/${domain}/cert.pem" ]; then
        [ -e "${PATH_SSL}/${domain}.crt" ] && rm -rf ${PATH_SSL}/${domain}.{crt,key}
        ln -s /etc/letsencrypt/live/${domain}/fullchain.pem ${PATH_SSL}/${domain}.crt
        ln -s /etc/letsencrypt/live/${domain}/privkey.pem ${PATH_SSL}/${domain}.key
        if [ -e "${web_install_dir}/sbin/nginx" -a -e "${apache_install_dir}/conf/httpd.conf" ]; then
          Cron_Command="/etc/init.d/nginx reload;/etc/init.d/httpd graceful"
        elif [ -e "${web_install_dir}/sbin/nginx" -a ! -e "${apache_install_dir}/conf/httpd.conf" ]; then
          Cron_Command="/etc/init.d/nginx reload"
        elif [ ! -e "${web_install_dir}/sbin/nginx" -a -e "${apache_install_dir}/conf/httpd.conf" ]; then
          Cron_Command="/etc/init.d/httpd graceful"
        fi
        [ "${OS}" == "CentOS" ] && Cron_file=/var/spool/cron/root || Cron_file=/var/spool/cron/crontabs/root
        [ -z "$(grep 'certbot renew' ${Cron_file})" ] && echo "0 0 1 * * ${python_install_dir}/bin/certbot renew --renew-hook \"${Cron_Command}\"" >> $Cron_file
      else
        echo "${CFAILURE}Error: Let's Encrypt SSL certificate installation failed! ${CEND}"
        exit 1
      fi
    else
      Create_self_SSL
    fi
  else
    Create_self_SSL
  fi
}

Print_ssl() {
  if [ "${letsencrypt_yn}" == 'y' ]; then
    echo "$(printf "%-30s" "Let's Encrypt SSL Certificate:")${CMSG}/etc/letsencrypt/live/${domain}/fullchain.pem${CEND}"
    echo "$(printf "%-30s" "SSL Private Key:")${CMSG}/etc/letsencrypt/live/${domain}/privkey.pem${CEND}"
  else
    echo "$(printf "%-30s" "Self-signed SSL Certificate:")${CMSG}${PATH_SSL}/${domain}.crt${CEND}"
    echo "$(printf "%-30s" "SSL Private Key:")${CMSG}${PATH_SSL}/${domain}.key${CEND}"
    echo "$(printf "%-30s" "SSL CSR File:")${CMSG}${PATH_SSL}/${domain}.csr${CEND}"
  fi
}


Input_Add_domain() {
  if [ -e "${web_install_dir}/sbin/nginx" ]; then
    while :; do echo
      read -p "Do you want to setup SSL under Nginx? [y/n]: " nginx_ssl_yn
      if [[ ! ${nginx_ssl_yn} =~ ^[y,n]$ ]]; then
        echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
      else
        break
      fi
    done
  elif [ ! -e "${web_install_dir}/sbin/nginx" -a -e "${apache_install_dir}/bin/apachectl" ]; then
    while :; do echo
      read -p "Do you want to setup SSL under Apache? [y/n]: " apache_ssl_yn
      if [[ ! ${apache_ssl_yn} =~ ^[y,n]$ ]]; then
        echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
      else
        break
      fi
    done
  fi

  [ "${apache_ssl_yn}" == 'y' ] && { PATH_SSL=${apache_install_dir}/conf/ssl; [ ! -d "${PATH_SSL}" ] && mkdir ${PATH_SSL}; }
  [ "${nginx_ssl_yn}" == 'y' ] && { PATH_SSL=${web_install_dir}/conf/ssl; [ ! -d "${PATH_SSL}" ] && mkdir ${PATH_SSL}; }

  while :; do echo
    read -p "Please input domain(example: www.example.com): " domain
    if [ -z "$(echo ${domain} | grep '.*\..*')" ]; then
      echo "${CWARNING}input error! ${CEND}"
    else
      break
    fi
  done

  while :; do echo
    echo "Please input the directory for the domain:${domain} :"
    read -p "(Default directory: ${wwwroot_dir}/${domain}): " vhostdir
    if [ -n "${vhostdir}" -a -z "$(echo ${vhostdir} | grep '^/')" ]; then
      echo "${CWARNING}input error! Press Enter to continue...${CEND}"
    else
      if [ -z "${vhostdir}" ]; then
        vhostdir="${wwwroot_dir}/${domain}"
        echo "Virtual Host Directory=${CMSG}${vhostdir}${CEND}"
      fi
      echo
      echo "Create Virtul Host directory......"
      mkdir -p ${vhostdir}
      echo "set permissions of Virtual Host directory......"
      chown -R ${run_user}.${run_user} ${vhostdir}
      break
    fi
  done

  if [ -e "${web_install_dir}/conf/vhost/${domain}.conf" -o -e "${apache_install_dir}/conf/vhost/${domain}.conf" -o -e "${tomcat_install_dir}/conf/vhost/${domain}.xml" ]; then
    [ -e "${web_install_dir}/conf/vhost/${domain}.conf" ] && echo -e "${domain} in the Nginx/Tengine/OpenResty already exist! \nYou can delete ${CMSG}${web_install_dir}/conf/vhost/${domain}.conf${CEND} and re-create"
    [ -e "${apache_install_dir}/conf/vhost/${domain}.conf" ] && echo -e "${domain} in the Apache already exist! \nYou can delete ${CMSG}${apache_install_dir}/conf/vhost/${domain}.conf${CEND} and re-create"
    [ -e "${tomcat_install_dir}/conf/vhost/${domain}.xml" ] && echo -e "${domain} in the Tomcat already exist! \nYou can delete ${CMSG}${tomcat_install_dir}/conf/vhost/${domain}.xml${CEND} and re-create"
    exit
  else
    echo "domain=${domain}"
  fi

  while :; do echo
    read -p "Do you want to add more domain name? [y/n]: " moredomainame_yn
    if [[ ! ${moredomainame_yn} =~ ^[y,n]$ ]]; then
      echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
    else
      break
    fi
  done

  if [ "${moredomainame_yn}" == 'y' ]; then
    while :; do echo
      read -p "Type domainname or IP(example: example.com other.example.com): " moredomain
      if [ -z "$(echo ${moredomain} | grep '.*\..*')" ]; then
        echo "${CWARNING}input error! ${CEND}"
      else
        [ "${moredomain}" == "${domain}" ] && echo "${CWARNING}Domain name already exists! ${CND}" && continue
        echo domain list="$moredomain"
        moredomainame=" $moredomain"
        break
      fi
    done
    Apache_Domain_alias=ServerAlias${moredomainame}
    Tomcat_Domain_alias=$(for D in $(echo ${moredomainame}); do echo "<Alias>${D}</Alias>"; done)

    if [ -e "${web_install_dir}/sbin/nginx" ]; then
      while :; do echo
        read -p "Do you want to redirect from ${moredomain} to ${domain}? [y/n]: " redirect_yn
        if [[ ! ${redirect_yn} =~ ^[y,n]$ ]]; then
          echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
        else
          break
        fi
      done
      [ "${redirect_yn}" == 'y' ] && Nginx_redirect="if (\$host != $domain) {  return 301 \$scheme://${domain}\$request_uri;  }"
    fi
  fi

  if [ "${nginx_ssl_yn}" == 'y' ]; then
    while :; do echo
      read -p "Do you want to redirect all HTTP requests to HTTPS? [y/n]: " https_yn
      if [[ ! ${https_yn} =~ ^[y,n]$ ]]; then
        echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
      else
        break
      fi
    done

    if [[ "$(${web_install_dir}/sbin/nginx -V 2>&1 | grep -Eo 'with-http_v2_module')" = 'with-http_v2_module' ]]; then
      LISTENOPT="443 ssl http2"
    else
      LISTENOPT="443 ssl spdy"
    fi
    Create_SSL
    Nginx_conf=$(echo -e "listen 80;\n  listen ${LISTENOPT};\n  ssl_certificate ${PATH_SSL}/${domain}.crt;\n  ssl_certificate_key ${PATH_SSL}/${domain}.key;\n  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;\n  ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5;\n  ssl_prefer_server_ciphers on;\n  ssl_session_timeout 10m;\n  ssl_session_cache builtin:1000 shared:SSL:10m;\n  ssl_buffer_size 1400;\n  add_header Strict-Transport-Security max-age=15768000;\n  ssl_stapling on;\n  ssl_stapling_verify on;\n")
    Apache_SSL=$(echo -e "SSLEngine on\n  SSLCertificateFile \"${PATH_SSL}/${domain}.crt\"\n  SSLCertificateKeyFile \"${PATH_SSL}/${domain}.key\"")
  elif [ "$apache_ssl_yn" == 'y' ]; then
    Create_SSL
    Apache_SSL=$(echo -e "SSLEngine on\n  SSLCertificateFile \"${PATH_SSL}/${domain}.crt\"\n  SSLCertificateKeyFile \"${PATH_SSL}/${domain}.key\"")
    [ -z "$(grep 'Listen 443' ${apache_install_dir}/conf/httpd.conf)" ] && sed -i "s@Listen 80@&\nListen 443@" ${apache_install_dir}/conf/httpd.conf
    [ -z "$(grep 'ServerName 0.0.0.0:443' ${apache_install_dir}/conf/httpd.conf)" ] && sed -i "s@ServerName 0.0.0.0:80@&\nServerName 0.0.0.0:443@" ${apache_install_dir}/conf/httpd.conf
  else
    Nginx_conf="listen 80;"
  fi
}

Nginx_anti_hotlinking() {
  while :; do echo
    read -p "Do you want to add hotlink protection? [y/n]: " anti_hotlinking_yn
    if [[ ! $anti_hotlinking_yn =~ ^[y,n]$ ]]; then
      echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
    else
      break
    fi
  done

  if [ -n "$(echo ${domain} | grep '.*\..*\..*')" ]; then
    domain_allow="*.${domain#*.} ${domain}"
  else
    domain_allow="*.${domain} ${domain}"
  fi

  if [ "${anti_hotlinking_yn}" == 'y' ]; then
    if [ "${moredomainame_yn}" == 'y' ]; then
      domain_allow_all=${domain_allow}${moredomainame}
    else
      domain_allow_all=${domain_allow}
    fi
    anti_hotlinking=$(echo -e "location ~ .*\.(wma|wmv|asf|mp3|mmf|zip|rar|jpg|gif|png|swf|flv|mp4)$ {\n  valid_referers none blocked ${domain_allow_all};\n  if (\$invalid_referer) {\n      #rewrite ^/ http://www.example.com/403.html;\n      return 403;\n    }\n  }")
  else
    anti_hotlinking=
  fi
}

Nginx_rewrite() {
  [ ! -d "${web_install_dir}/conf/rewrite" ] && mkdir ${web_install_dir}/conf/rewrite
  while :; do echo
    read -p "Allow Rewrite rule? [y/n]: " rewrite_yn
    if [[ ! "${rewrite_yn}" =~ ^[y,n]$ ]]; then
      echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
    else
      break
    fi
  done
  if [ "${rewrite_yn}" == 'n' ]; then
    rewrite="none"
    touch "${web_install_dir}/conf/rewrite/${rewrite}.conf"
  else
    echo
    echo "Please input the rewrite of programme :"
    echo "${CMSG}wordpress${CEND},${CMSG}discuz${CEND},${CMSG}opencart${CEND},${CMSG}thinkphp${CEND},${CMSG}laravel${CEND},${CMSG}typecho${CEND},${CMSG}ecshop${CEND},${CMSG}drupal${CEND},${CMSG}joomla${CEND} rewrite was exist."
    read -p "(Default rewrite: other): " rewrite
    if [ "${rewrite}" == "" ]; then
      rewrite="other"
    fi
    echo "You choose rewrite=${CMSG}$rewrite${CEND}"
    [ "${NGX_FLAG}" == 'php' -a "${rewrite}" == "thinkphp" ] && NGX_CONF=$(echo -e "location ~ \.php {\n    #fastcgi_pass remote_php_ip:9000;\n    fastcgi_pass unix:/dev/shm/php-cgi.sock;\n    fastcgi_index index.php;\n    include fastcgi_params;\n    set \$real_script_name \$fastcgi_script_name;\n    if (\$fastcgi_script_name ~ \"^(.+?\.php)(/.+)\$\") {\n      set \$real_script_name \$1;\n      #set \$path_info \$2;\n    }\n    fastcgi_param SCRIPT_FILENAME \$document_root\$real_script_name;\n    fastcgi_param SCRIPT_NAME \$real_script_name;\n    #fastcgi_param PATH_INFO \$path_info;\n  }")
    if [ -e "config/${rewrite}.conf" ]; then
      /bin/cp config/${rewrite}.conf ${web_install_dir}/conf/rewrite/${rewrite}.conf
    else
      touch "${web_install_dir}/conf/rewrite/${rewrite}.conf"
    fi
  fi
}

Nginx_log() {
while :; do echo
    read -p "Allow Nginx/Tengine/OpenResty access_log? [y/n]: " access_yn
    if [[ ! "${access_yn}" =~ ^[y,n]$ ]]; then
        echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
    else
        break
    fi
done
if [ "${access_yn}" == 'n' ]; then
    N_log="access_log off;"
else
    N_log="access_log ${wwwlogs_dir}/${domain}_nginx.log combined;"
    echo "You access log file=${CMSG}${wwwlogs_dir}/${domain}_nginx.log${CEND}"
fi
}

Create_nginx_tomcat_conf() {
  [ ! -d ${web_install_dir}/conf/vhost ] && mkdir ${web_install_dir}/conf/vhost
  cat > ${web_install_dir}/conf/vhost/${domain}.conf << EOF
server {
  ${Nginx_conf}
  server_name ${domain}${moredomainame};
  ${N_log}
  index index.html index.htm index.jsp;
  root ${vhostdir};
  ${Nginx_redirect}
  #error_page 404 = /404.html;
  #error_page 502 = /502.html;
  ${anti_hotlinking}
  location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|mp4|ico)$ {
    expires 30d;
    access_log off;
  }
  location ~ .*\.(js|css)?$ {
    expires 7d;
    access_log off;
  }
  location ~ /\.ht {
    deny all;
  }
  ${NGX_CONF}
}
EOF

  [ "${https_yn}" == 'y' ] && sed -i "s@^root.*;@&\nif (\$ssl_protocol = \"\") { return 301 https://\$server_name\$request_uri; }@" ${web_install_dir}/conf/vhost/${domain}.conf

  cat > ${tomcat_install_dir}/conf/vhost/${domain}.xml << EOF
<Host name="${domain}" appBase="${vhostdir}" unpackWARs="true" autoDeploy="true"> ${Tomcat_Domain_alias}
  <Context path="" docBase="${vhostdir}" debug="0" reloadable="false" crossContext="true"/>
  <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
    prefix="${domain}_access_log." suffix=".txt" pattern="%h %l %u %t &quot;%r&quot; %s %b" />
</Host>
EOF
  [ -z "$(grep -o "vhost-${domain} SYSTEM" ${tomcat_install_dir}/conf/server.xml)" ] && sed -i "/vhost-localhost SYSTEM/a<\!ENTITY vhost-${domain} SYSTEM \"file://${tomcat_install_dir}/conf/vhost/${domain}.xml\">" ${tomcat_install_dir}/conf/server.xml
  [ -z "$(grep -o "vhost-${domain};" ${tomcat_install_dir}/conf/server.xml)" ] && sed -i "s@vhost-localhost;@&\n      \&vhost-${domain};@" ${tomcat_install_dir}/conf/server.xml

  echo
  ${web_install_dir}/sbin/nginx -t
  if [ $? == 0 ]; then
    echo "Reload Nginx......"
    ${web_install_dir}/sbin/nginx -s reload
    /etc/init.d/tomcat restart
  else
    rm -rf ${web_install_dir}/conf/vhost/${domain}.conf
    echo "Create virtualhost ... [${CFAILURE}FAILED${CEND}]"
    exit 1
  fi

  printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
  echo "$(printf "%-30s" "Your domain:")${CMSG}${domain}${CEND}"
  echo "$(printf "%-30s" "Nginx Virtualhost conf:")${CMSG}${web_install_dir}/conf/vhost/${domain}.conf${CEND}"
  echo "$(printf "%-30s" "Tomcat Virtualhost conf:")${CMSG}${tomcat_install_dir}/conf/vhost/${domain}.xml${CEND}"
  echo "$(printf "%-30s" "Directory of:")${CMSG}${vhostdir}${CEND}"
  [ "${nginx_ssl_yn}" == 'y' ] && Print_ssl
}

Create_tomcat_conf() {
  cat > ${tomcat_install_dir}/conf/vhost/${domain}.xml << EOF
<Host name="${domain}" appBase="webapps" unpackWARs="true" autoDeploy="true"> ${Tomcat_Domain_alias}
  <Context path="" docBase="${vhostdir}" debug="0" reloadable="false" crossContext="true"/>
  <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
    prefix="${domain}_access_log." suffix=".txt" pattern="%h %l %u %t &quot;%r&quot; %s %b" />
</Host>
EOF
  [ -z "$(grep -o "vhost-${domain} SYSTEM" ${tomcat_install_dir}/conf/server.xml)" ] && sed -i "/vhost-localhost SYSTEM/a<\!ENTITY vhost-${domain} SYSTEM \"file://${tomcat_install_dir}/conf/vhost/${domain}.xml\">" ${tomcat_install_dir}/conf/server.xml
  [ -z "$(grep -o "vhost-${domain};" ${tomcat_install_dir}/conf/server.xml)" ] && sed -i "s@vhost-localhost;@&\n      \&vhost-${domain};@" ${tomcat_install_dir}/conf/server.xml

  echo
  /etc/init.d/tomcat restart

  printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
  echo "$(printf "%-30s" "Your domain:")${CMSG}${domain}${CEND}"
  echo "$(printf "%-30s" "Tomcat Virtualhost conf:")${CMSG}${tomcat_install_dir}/conf/vhost/${domain}.xml${CEND}"
  echo "$(printf "%-30s" "Directory of:")${CMSG}${vhostdir}${CEND}"
  echo "$(printf "%-30s" "index url:")${CMSG}http://${domain}:8080/${CEND}"
}

Create_nginx_php-fpm_hhvm_conf() {
  [ ! -d ${web_install_dir}/conf/vhost ] && mkdir ${web_install_dir}/conf/vhost
  cat > ${web_install_dir}/conf/vhost/${domain}.conf << EOF
server {
  ${Nginx_conf}
  server_name ${domain}${moredomainame};
  ${N_log}
  index index.html index.htm index.php;
  include ${web_install_dir}/conf/rewrite/${rewrite}.conf;
  root ${vhostdir};
  ${Nginx_redirect}
  #error_page 404 = /404.html;
  #error_page 502 = /502.html;
  ${anti_hotlinking}
  ${NGX_CONF}
  location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|mp4|ico)$ {
    expires 30d;
    access_log off;
  }
  location ~ .*\.(js|css)?$ {
    expires 7d;
    access_log off;
  }
  location ~ /\.ht {
    deny all;
  }
}
EOF

  [ "${https_yn}" == 'y' ] && sed -i "s@^  root.*;@&\n  if (\$ssl_protocol = \"\") { return 301 https://\$server_name\$request_uri; }@" ${web_install_dir}/conf/vhost/${domain}.conf

  echo
  ${web_install_dir}/sbin/nginx -t
  if [ $? == 0 ]; then
    echo "Reload Nginx......"
    ${web_install_dir}/sbin/nginx -s reload
  else
    rm -rf ${web_install_dir}/conf/vhost/${domain}.conf
    echo "Create virtualhost ... [${CFAILURE}FAILED${CEND}]"
    exit 1
  fi

  printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
  echo "$(printf "%-30s" "Your domain:")${CMSG}${domain}${CEND}"
  echo "$(printf "%-30s" "Virtualhost conf:")${CMSG}${web_install_dir}/conf/vhost/${domain}.conf${CEND}"
  echo "$(printf "%-30s" "Directory of:")${CMSG}${vhostdir}${CEND}"
  [ "${rewrite_yn}" == 'y' ] && echo "$(printf "%-30s" "Rewrite rule:")${CMSG}${web_install_dir}/conf/rewrite/${rewrite}.conf${CEND}"
  [ "${nginx_ssl_yn}" == 'y' ] && Print_ssl
}

Apache_log() {
  while :; do echo
    read -p "Allow Apache access_log? [y/n]: " access_yn
    if [[ ! "${access_yn}" =~ ^[y,n]$ ]]; then
      echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
    else
      break
    fi
  done

  if [ "${access_yn}" == 'n' ]; then
    A_log='CustomLog "/dev/null" common'
  else
    A_log="CustomLog \"${wwwlogs_dir}/${domain}_apache.log\" common"
    echo "You access log file=${wwwlogs_dir}/${domain}_apache.log"
  fi
}

Create_apache_conf() {
  [ "$(${apache_install_dir}/bin/apachectl -v | awk -F'.' /version/'{print $2}')" == '4' ] && R_TMP='Require all granted' || R_TMP=
  [ ! -d ${apache_install_dir}/conf/vhost ] && mkdir ${apache_install_dir}/conf/vhost
  cat > ${apache_install_dir}/conf/vhost/${domain}.conf << EOF
<VirtualHost *:80>
  ServerAdmin admin@example.com
  DocumentRoot "${vhostdir}"
  ServerName ${domain}
  ${Apache_Domain_alias}
  ErrorLog "${wwwlogs_dir}/${domain}_error_apache.log"
  ${A_log}
<Directory "${vhostdir}">
  SetOutputFilter DEFLATE
  Options FollowSymLinks ExecCGI
  ${R_TMP}
  AllowOverride All
  Order allow,deny
  Allow from all
  DirectoryIndex index.html index.php
</Directory>
</VirtualHost>
EOF
  [ "$apache_ssl_yn" == 'y' ] && cat >> ${apache_install_dir}/conf/vhost/${domain}.conf << EOF
<VirtualHost *:443>
  ServerAdmin admin@example.com
  DocumentRoot "${vhostdir}"
  ServerName ${domain}
  ${Apache_Domain_alias}
  ${Apache_SSL}
  ErrorLog "${wwwlogs_dir}/${domain}_error_apache.log"
  ${A_log}
<Directory "${vhostdir}">
  SetOutputFilter DEFLATE
  Options FollowSymLinks ExecCGI
  ${R_TMP}
  AllowOverride All
  Order allow,deny
  Allow from all
  DirectoryIndex index.html index.php
</Directory>
</VirtualHost>
EOF

  echo
  ${apache_install_dir}/bin/apachectl -t
  if [ $? == 0 ]; then
    echo "Restart Apache......"
    /etc/init.d/httpd restart
  else
    rm -rf ${apache_install_dir}/conf/vhost/${domain}.conf
    echo "Create virtualhost ... [${CFAILURE}FAILED${CEND}]"
    exit 1
  fi

  printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
  echo "$(printf "%-30s" "Your domain:")${CMSG}${domain}${CEND}"
  echo "$(printf "%-30s" "Virtualhost conf:")${CMSG}${apache_install_dir}/conf/vhost/${domain}.conf${CEND}"
  echo "$(printf "%-30s" "Directory of:")${CMSG}${vhostdir}${CEND}"
  [ "${apache_ssl_yn}" == 'y' ] && Print_ssl
}

Create_nginx_apache_mod-php_conf() {
  # Nginx/Tengine/OpenResty
  [ ! -d ${web_install_dir}/conf/vhost ] && mkdir ${web_install_dir}/conf/vhost
  cat > ${web_install_dir}/conf/vhost/${domain}.conf << EOF
server {
  ${Nginx_conf}
  server_name ${domain}${moredomainame};
  ${N_log}
  index index.html index.htm index.php;
  root ${vhostdir};
  ${Nginx_redirect}
  ${anti_hotlinking}
  location / {
    try_files \$uri @apache;
  }
  location @apache {
    proxy_pass http://127.0.0.1:88;
    include proxy.conf;
  }
  location ~ .*\.(php|php5|cgi|pl)?$ {
    proxy_pass http://127.0.0.1:88;
    include proxy.conf;
  }
  location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|flv|mp4|ico)$ {
    expires 30d;
    access_log off;
  }
  location ~ .*\.(js|css)?$ {
    expires 7d;
    access_log off;
  }
  location ~ /\.ht {
    deny all;
  }
}
EOF

  [ "${https_yn}" == 'y' ] && sed -i "s@^  root.*;@&\n  if (\$ssl_protocol = \"\") { return 301 https://\$server_name\$request_uri; }@" ${web_install_dir}/conf/vhost/${domain}.conf

  echo
  ${web_install_dir}/sbin/nginx -t
  if [ $? == 0 ]; then
    echo "Reload Nginx......"
    ${web_install_dir}/sbin/nginx -s reload
  else
    rm -rf ${web_install_dir}/conf/vhost/${domain}.conf
    echo "Create virtualhost ... [${CFAILURE}FAILED${CEND}]"
  fi

  # Apache
  [ "$(${apache_install_dir}/bin/apachectl -v | awk -F'.' /version/'{print $2}')" == '4' ] && R_TMP="Require all granted" || R_TMP=
  [ ! -d ${apache_install_dir}/conf/vhost ] && mkdir ${apache_install_dir}/conf/vhost
  cat > ${apache_install_dir}/conf/vhost/${domain}.conf << EOF
<VirtualHost *:88>
  ServerAdmin admin@example.com
  DocumentRoot "${vhostdir}"
  ServerName ${domain}
  ${Apache_Domain_alias}
  ${Apache_SSL}
  ErrorLog "${wwwlogs_dir}/${domain}_error_apache.log"
  ${A_log}
<Directory "${vhostdir}">
  SetOutputFilter DEFLATE
  Options FollowSymLinks ExecCGI
  ${R_TMP}
  AllowOverride All
  Order allow,deny
  Allow from all
  DirectoryIndex index.html index.php
</Directory>
</VirtualHost>
EOF

  echo
  ${apache_install_dir}/bin/apachectl -t
  if [ $? == 0 ]; then
    echo "Restart Apache......"
    /etc/init.d/httpd restart
  else
    rm -rf ${apache_install_dir}/conf/vhost/${domain}.conf
    exit 1
  fi

  printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#       For more information please visit https://oneinstack.com      #
#######################################################################
"
  echo "$(printf "%-30s" "Your domain:")${CMSG}${domain}${CEND}"
  echo "$(printf "%-30s" "Nginx Virtualhost conf:")${CMSG}${web_install_dir}/conf/vhost/${domain}.conf${CEND}"
  echo "$(printf "%-30s" "Apache Virtualhost conf:")${CMSG}${apache_install_dir}/conf/vhost/${domain}.conf${CEND}"
  echo "$(printf "%-30s" "Directory of:")${CMSG}${vhostdir}${CEND}"
  [ "${rewrite_yn}" == 'y' ] && echo "$(printf "%-28s" "Rewrite rule:")${CMSG}${web_install_dir}/conf/rewrite/${rewrite}.conf${CEND}"
  [ "${nginx_ssl_yn}" == 'y' ] && Print_ssl
}

Add_Vhost() {
  if [ -e "${web_install_dir}/sbin/nginx" -a ! -e "${apache_install_dir}/conf/httpd.conf" ]; then
    Choose_env
    Input_Add_domain
    Nginx_anti_hotlinking
    if [ "${NGX_FLAG}" == "java" ]; then
      Nginx_log
      Create_nginx_tomcat_conf
    else
      Nginx_rewrite
      Nginx_log
      Create_nginx_php-fpm_hhvm_conf
    fi
  elif [ ! -e "${web_install_dir}/sbin/nginx" -a -e "${apache_install_dir}/conf/httpd.conf" ]; then
    Choose_env
    Input_Add_domain
    Apache_log
    Create_apache_conf
  elif [ ! -e "${web_install_dir}/sbin/nginx" -a ! -e "${apache_install_dir}/conf/httpd.conf" -a -e "${tomcat_install_dir}/conf/server.xml" ]; then
    Choose_env
    Input_Add_domain
    Create_tomcat_conf
  elif [ -e "${web_install_dir}/sbin/nginx" -a -e "$(ls ${apache_install_dir}/modules/libphp?.so 2>/dev/null)" ]; then
    Choose_env
    Input_Add_domain
    Nginx_anti_hotlinking
    if [ "${NGX_FLAG}" == "java" ]; then
      Nginx_log
      Create_nginx_tomcat_conf
    elif [ "${NGX_FLAG}" == "hhvm" ]; then
      Nginx_rewrite
      Nginx_log
      Create_nginx_php-fpm_hhvm_conf
    elif [ "${NGX_FLAG}" == "php" ]; then
      #Nginx_rewrite
      Nginx_log
      Apache_log
      Create_nginx_apache_mod-php_conf
    fi
  else
    echo "Error! ${CFAILURE}Web server${CEND} not found!"
  fi
}

Del_NGX_Vhost() {
  if [ -e "${web_install_dir}/sbin/nginx" ]; then
    [ -d "${web_install_dir}/conf/vhost" ] && Domain_List=$(ls ${web_install_dir}/conf/vhost | sed "s@.conf@@g")
    if [ -n "${Domain_List}" ]; then
      echo
      echo "Virtualhost list:"
      echo ${CMSG}${Domain_List}${CEND}
        while :; do echo
          read -p "Please input a domain you want to delete: " domain
          if [ -z "$(echo ${domain} | grep '.*\..*')" ]; then
            echo "${CWARNING}input error! ${CEND}"
          else
            if [ -e "${web_install_dir}/conf/vhost/${domain}.conf" ]; then
              Directory=$(grep '^  root' ${web_install_dir}/conf/vhost/${domain}.conf | head -1 | awk -F'[ ;]' '{print $(NF-1)}')
              rm -rf ${web_install_dir}/conf/vhost/${domain}.conf
              ${web_install_dir}/sbin/nginx -s reload
              while :; do echo
                read -p "Do you want to delete Virtul Host directory? [y/n]: " Del_Vhost_wwwroot_yn
                if [[ ! ${Del_Vhost_wwwroot_yn} =~ ^[y,n]$ ]]; then
                  echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
                else
                  break
                fi
              done
              if [ "${Del_Vhost_wwwroot_yn}" == 'y' ]; then
                echo "Press Ctrl+c to cancel or Press any key to continue..."
                char=$(get_char)
                rm -rf ${Directory}
              fi
              echo
              echo "${CMSG}Domain: ${domain} has been deleted.${CEND}"
              echo
            else
              echo "${CWARNING}Virtualhost: ${domain} was not exist! ${CEND}"
            fi
            break
          fi
        done

    else
      echo "${CWARNING}Virtualhost was not exist! ${CEND}"
    fi
  fi
}

Del_Apache_Vhost() {
  if [ -e "${apache_install_dir}/conf/httpd.conf" ]; then
    if [ -e "${web_install_dir}/sbin/nginx" ]; then
      rm -rf ${apache_install_dir}/conf/vhost/${domain}.conf
      /etc/init.d/httpd restart
    else
      Domain_List=$(ls ${apache_install_dir}/conf/vhost | grep -v '0.conf' | sed "s@.conf@@g")
      if [ -n "${Domain_List}" ]; then
        echo
        echo "Virtualhost list:"
        echo ${CMSG}${Domain_List}${CEND}
        while :; do echo
          read -p "Please input a domain you want to delete: " domain
          if [ -z "$(echo ${domain} | grep '.*\..*')" ]; then
            echo "${CWARNING}input error! ${CEND}"
          else
            if [ -e "${apache_install_dir}/conf/vhost/${domain}.conf" ]; then
              Directory=$(grep '^<Directory ' ${apache_install_dir}/conf/vhost/${domain}.conf | head -1 | awk -F'"' '{print $2}')
              rm -rf ${apache_install_dir}/conf/vhost/${domain}.conf
              /etc/init.d/httpd restart
              while :; do echo
                read -p "Do you want to delete Virtul Host directory? [y/n]: " Del_Vhost_wwwroot_yn
                if [[ ! ${Del_Vhost_wwwroot_yn} =~ ^[y,n]$ ]]; then
                  echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
                else
                  break
                fi
              done

              if [ "${Del_Vhost_wwwroot_yn}" == 'y' ]; then
                echo "Press Ctrl+c to cancel or Press any key to continue..."
                char=$(get_char)
                rm -rf ${Directory}
              fi
              echo "${CSUCCESS}Domain: ${domain} has been deleted.${CEND}"
            else
              echo "${CWARNING}Virtualhost: ${domain} was not exist! ${CEND}"
            fi
            break
          fi
        done

      else
        echo "${CWARNING}Virtualhost was not exist! ${CEND}"
      fi
    fi
  fi
}

Del_Tomcat_Vhost() {
  if [ -e "${tomcat_install_dir}/conf/server.xml" ]; then
    if [ -e "${web_install_dir}/sbin/nginx" ]; then
      if [ -n "$(grep vhost-${domain} ${tomcat_install_dir}/conf/server.xml)" ]; then
        sed -i /vhost-${domain}/d ${tomcat_install_dir}/conf/server.xml
        rm -rf ${tomcat_install_dir}/conf/vhost/${domain}.xml
        /etc/init.d/tomcat restart
      fi
    else
      Domain_List=$(ls ${tomcat_install_dir}/conf/vhost | grep -v 'localhost.xml' | sed "s@.xml@@g")
      if [ -n "${Domain_List}" ]; then
        echo
        echo "Virtualhost list:"
        echo ${CMSG}${Domain_List}${CEND}
        while :; do echo
          read -p "Please input a domain you want to delete: " domain
          if [ -z "$(echo ${domain} | grep '.*\..*')" ]; then
            echo "${CWARNING}input error! ${CEND}"
          else
            if [ -n "$(grep vhost-${domain} ${tomcat_install_dir}/conf/server.xml)" ]; then
              sed -i /vhost-${domain}/d ${tomcat_install_dir}/conf/server.xml
              rm -rf ${tomcat_install_dir}/conf/vhost/${domain}.xml
              /etc/init.d/tomcat restart
              while :; do echo
                read -p "Do you want to delete Virtul Host directory? [y/n]: " Del_Vhost_wwwroot_yn
                if [[ ! ${Del_Vhost_wwwroot_yn} =~ ^[y,n]$ ]]; then
                  echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
                else
                  break
                fi
              done

              if [ "${Del_Vhost_wwwroot_yn}" == 'y' ]; then
                echo "Press Ctrl+c to cancel or Press any key to continue..."
                char=$(get_char)
                rm -rf ${Directory}
              fi
              echo "${CSUCCESS}Domain: ${domain} has been deleted.${CEND}"
            else
              echo "${CWARNING}Virtualhost: ${domain} was not exist! ${CEND}"
            fi
            break
          fi
        done

      else
        echo "${CWARNING}Virtualhost was not exist! ${CEND}"
      fi
    fi
  fi
}

if [ $# == 0 ]; then
  Add_Vhost
elif [ $# == 1 ]; then
  case $1 in
  add)
    Add_Vhost
    ;;
  del)
    Del_NGX_Vhost
    Del_Apache_Vhost
    Del_Tomcat_Vhost
    ;;
  *)
    Usage
    ;;
  esac
else
  Usage
fi
