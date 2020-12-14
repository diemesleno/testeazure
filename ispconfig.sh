#!/bin/bash

# Check if user has root privileges
if [[ $EUID -ne 0 ]]; then
    echo "You must run the script as root or using sudo"
    exit 1
fi

apt-get update && apt-get upgrade -y
apt-get install -yq wget
apt-get install -yq perl dialog apt-utils
apt-get install -yq lsb-release systemd

OSRELEASE=$(lsb_release -si | awk '{print tolower($0)}')
CODENAME=$(lsb_release -sc)

## Reconfigure Dash
echo "dash dash/sh boolean false" | debconf-set-selections
dpkg-reconfigure -f noninteractive dash > /dev/null 2>&1

MY_IP=$(ip a s|sed -ne '/127.0.0.1/!{s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p}' | tr '\n' ' ')

echo -e "Set Server Name Ex: mail.geekuniversity.com.br []: \c "
read  SERVER_FQDN

echo -e "Set Server IP Ex: $MY_IP []: \c "
read  SERVER_IP

echo "" >>/etc/hosts
echo "$SERVER_IP  $SERVER_FQDN" >>/etc/hosts
hostnamectl set-hostname $SERVER_FQDN
echo "$SERVER_FQDN" > /proc/sys/kernel/hostname


apt-get -y install ssh openssh-server ntp binutils sudo ntpdate curl dirmngr
apt-get -y install postfix postfix-mysql mariadb-client mariadb-server openssl getmail4
apt-get -y install dovecot-imapd dovecot-pop3d dovecot-mysql dovecot-sieve dovecot-lmtpd

## To secure the MariaDB / MySQL installation and to disable the test database, run this command:
sed -i 's|bind-address|#bind-address|' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's|# this is only for embedded server|sql_mode=NO_ENGINE_SUBSTITUTION|' /etc/mysql/mariadb.conf.d/50-server.cnf
service mysql restart
mysql_secure_installation
service mysql restart


apt-get -y install amavisd-new spamassassin clamav clamav-daemon zoo unzip bzip2 arj nomarch lzop cabextract
apt-get -y install apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon nginx
apt-get -y install libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl postgrey

## The ISPConfig 3 setup uses amavisd which loads the SpamAssassin filter library internally,
## so we can stop SpamAssassin to free up some RAM:
service spamassassin stop
systemctl disable spamassassin


if [ "$CODENAME" != "stretch" ]; then
    apt-get -y install php7.4 php7.4-common php7.4-gd php7.4-mysql php7.4-imap php7.4-cli php7.4-cgi
    apt-get -y install php7.4-pear php7.4-mcrypt php7.4-imagick php7.4-ldap
    apt-get -y install php7.4-curl php7.4-intl php7.4-memcache php7.4-memcached php7.4-pspell
    apt-get -y install php7.4-recode php7.4-sqlite php7.4-tidy php7.4-xmlrpc php7.4-xsl php7.4-recode
else
    apt-get -y install php7.4 php7.4-common php7.4-gd php7.4-mysql php7.4-imap php7.4-cli php7.4-cgi
    apt-get -y install php7.4-pear php7.4-mcrypt php7.4-imagick php7.4-mbstring php7.4-ldap
    apt-get -y install php7.4-curl php7.4-intl php7.4-memcache php7.4-memcached php7.4-pspell php7.4-recode
    apt-get -y install php7.4-recode php7.4-sqlite3 php7.4-tidy php7.4-xmlrpc php7.4-xsl php7.4-xml
fi

apt-get -y install mcrypt imagemagick ssl-cert

### Install HHVM
apt-get install -y apt-transport-https software-properties-common
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xB4112585D386EB94

add-apt-repository https://dl.hhvm.com/ubuntu
apt-get update && apt-get -y install hhvm
update-rc.d -f hhvm remove
echo 'hhvm.mysql.socket = /var/run/mysqld/mysqld.sock' >> /etc/hhvm/php.ini

apt-get -y install build-essential autoconf automake libtool flex bison debhelper binutils

#mkdir /opt/certbot
#cd /opt/certbot
#wget https://dl.eff.org/certbot-auto
#chmod a+x ./certbot-auto && ./certbot-auto

if [ "$CODENAME" != "stretch" ]; then
    apt-get -y install php7.4-fpm
else
    apt-get -y install php7.4-fpm
fi

apt-get -y install pure-ftpd-common pure-ftpd-mysql quota quotatool fcgiwrap

# Change ini do PHP
sed -i 's|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|' /etc/ph*/*/php.ini
sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 100M|' /etc/ph*/*/php.ini
sed -i 's|post_max_size = 8M|post_max_size = 32M|' /etc/ph*/*/php.ini
sed -i 's|error_reporting = E_ALL & ~E_DEPRECATED|error_reporting =  E_ERROR|' /etc/ph*/*/php.ini
sed -i 's|short_open_tag = Off|short_open_tag = On|' /etc/ph*/*/php.ini
sed -i "s|;date.timezone =|date.timezone = 'America\/Sao_Paulo'|" /etc/ph*/*/php.ini


if [ "$CODENAME" != "stretch" ]; then
    service php7.4-fpm reload
else
    service php7.4-fpm reload
fi

### Enable Quota /var/www
# sed -i 's|defaults|defaults,usrjquota=quota.user,grpjquota=quota.group,jqfmt=vfsv0|' /etc/fstab
# mount -o remount /var/www
# quotacheck -avugm
# quotaon -avug

## Install Let's Encrypt | apt-get install -y certbot
mkdir /opt/certbot && cd /opt/certbot
wget https://dl.eff.org/certbot-auto
chmod a+x ./certbot-auto && ./certbot-auto --install-only --non-interactive


## echo 1 > /etc/pure-ftpd/conf/TLS
mkdir -p /etc/ssl/private/

openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -keyout /etc/ssl/private/pure-ftpd.pem -out /etc/ssl/private/pure-ftpd.pem
chmod 600 /etc/ssl/private/pure-ftpd.pem && service pure-ftpd-mysql restart

apt-get -y install bind9 haveged dnsutils vlogger webalizer awstats geoip-database libclass-dbi-mysql-perl
rm -f /etc/cron.d/awstats


## Download ISPConfig 3.1.X
cd /tmp
get_isp=https://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz
wget -c ${get_isp}
tar xvfz $(basename ${get_isp})
cd ispconfig3_install/install && php -q install.php

## Install PHPMyadmin
## Para Instalar o PHPMyadmin Execute o Script abaixo
## https://gist.github.com/jniltinho/9af397c8ddb035a322b75aecce7cdeae
