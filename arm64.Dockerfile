FROM starwarsfan/edomi-baseimage-builder:latest-arm64 as builder
MAINTAINER Yves Schumann <y.schumann@yetnet.ch>

# Dependencies to build stuff
RUN dnf -y install \
        mosquitto \
        mosquitto-devel \
        mariadb-devel \
        which

# For 19001051 (MQTT Publish Server)
RUN cd /tmp \
 && git clone https://github.com/mgdm/Mosquitto-PHP \
 && cd Mosquitto-PHP \
 && phpize \
 && ./configure \
 && make \
 && make install DESTDIR=/tmp/Mosquitto-PHP

RUN cd /tmp \
 && mkdir -p /tmp/Mosquitto-PHP/usr/lib64/mariadb/plugin \
 && git clone https://github.com/jonofe/lib_mysqludf_sys \
 && cd lib_mysqludf_sys/ \
 && gcc -march=armv8-a \
        -DMYSQL_DYNAMIC_PLUGIN \
        -fPIC \
        -Wall \
        -I/usr/include/mysql/server \
        -I/usr/include/mysql/server/private \
        -I. \
        -shared lib_mysqludf_sys.c \
        -o /tmp/Mosquitto-PHP/usr/lib64/mariadb/plugin/lib_mysqludf_sys.so

RUN cd /tmp \
 && git clone https://github.com/mysqludf/lib_mysqludf_log \
 && cd lib_mysqludf_log \
 && autoreconf -i \
 && ./configure \
 && make \
 && make install DESTDIR=/tmp/Mosquitto-PHP

FROM rockylinux/rockylinux:latest-arm64
MAINTAINER Yves Schumann <y.schumann@yetnet.ch>

COPY qemu-aarch64-static /usr/bin/

RUN dnf module enable -y \
        php:7.4 \
 && dnf install -y \
        epel-release \
 && dnf update -y \
 && dnf upgrade -y \
 && dnf clean all

RUN dnf install -y \
        ca-certificates \
        chrony \
        dos2unix \
        expect \
        file \
        git \
        hostname \
        httpd \
        mariadb-server \
        mod_ssl \
        mosquitto \
        mosquitto-devel \
        nano \
        nginx \
        net-snmp-utils \
        net-tools \
        nss \
        oathtool \
        openssh-server \
        openssl \
        passwd \
        php \
        php-curl \
        php-gd \
        php-json \
        php-mbstring \
        php-mysqlnd \
        php-process \
        php-snmp \
        php-soap \
        php-xml \
        php-zip \
        python2 \
        sudo \
        tar \
        unzip \
        vsftpd \
        wget \
        dnf-utils \
 && dnf clean all \
 && rm -f /etc/vsftpd/ftpusers \
          /etc/vsftpd/user_list

# Alexa
RUN ln -s /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /etc/pki/tls/cacert.pem \
 && sed -i \
        -e '/\[curl\]/ a curl.cainfo = /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem' \
        -e '/\[openssl\] a openssl.cafile = /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem' \
        /etc/php.ini

# Mosquitto-LBS
COPY --from=builder /tmp/Mosquitto-PHP/modules /usr/lib64/php/modules/
COPY --from=builder /tmp/Mosquitto-PHP/usr/lib64/mariadb /usr/lib64/mariadb/
COPY --from=builder /tmp/lib_mysqludf_log/installdb.sql /root/
RUN echo 'extension=mosquitto.so' > /etc/php.d/50-mosquitto.ini

# Get composer
RUN cd /tmp \
 && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
 && php -r "if (hash_file('sha384', 'composer-setup.php') === file_get_contents('https://composer.github.io/installer.sig')) { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
 && php composer-setup.php \
 && php -r "unlink('composer-setup.php');" \
 && mv composer.phar /usr/local/bin/composer \
 && mkdir -p /usr/local/edomi/main/include/php

# Telegram-LBS 19000303 / 19000304
RUN cd /usr/local/edomi/main/include/php \
 && git clone https://github.com/php-telegram-bot/core \
 && mv core php-telegram-bot \
 && cd php-telegram-bot \
 && composer install \
 && chmod 777 -R .

# MikroTik RouterOS API 19001059
RUN cd /usr/local/edomi/main/include/php \
 && git clone https://github.com/jonofe/Net_RouterOS \
 && cd Net_RouterOS \
 && composer install \
 && chmod 777 -R .

# Philips HUE Bridge 19000195
# As long as https://github.com/sqmk/Phue/pull/143 is not merged, fix phpunit via sed
RUN cd /usr/local/edomi/main/include/php \
 && git clone https://github.com/sqmk/Phue \
 && cd Phue \
 && sed -i "s/PHPUnit/phpunit/g" composer.json \
 && composer install \
 && chmod 777 -R .

# Mailer-LBS 19000587
RUN cd /usr/local/edomi/main/include/php \
 && mkdir PHPMailer \
 && cd PHPMailer \
 && composer require phpmailer/phpmailer \
 && chmod 777 -R .

# Alexa Control 19000809
RUN cd /etc/ssl/certs \
 && wget https://curl.haxx.se/ca/cacert.pem -O /etc/ssl/certs/cacert-Mozilla.pem \
 && echo "curl.cainfo=/etc/ssl/certs/cacert-Mozilla.pem" >> /etc/php.d/curl.ini

# Edomi
RUN systemctl enable chronyd \
 && systemctl enable vsftpd \
 && systemctl enable httpd \
 && systemctl enable mariadb

# Nginx as the main entry without dedicated websocket handling
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 && systemctl enable nginx

RUN sed -e "s/listen=.*$/listen=YES/g" \
        -e "s/listen_ipv6=.*$/listen_ipv6=NO/g" \
        -e "s/userlist_enable=.*/userlist_enable=NO/g" \
        -i /etc/vsftpd/vsftpd.conf \
 && mv /usr/bin/systemctl /usr/bin/systemctl_ \
 && wget https://raw.githubusercontent.com/starwarsfan/docker-systemctl-replacement/master/files/docker/systemctl.py -O /usr/bin/systemctl \
 && chmod 755 /usr/bin/systemctl
