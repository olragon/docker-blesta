FROM php:7.4-apache

ENV BLESTA_VERSION=5.0.4
ENV BUILD_DEPS \
    cron \
    g++ \
    gettext \
    libicu-dev \
    openssl \
    libc-client-dev \
    libkrb5-dev \
    libxml2-dev \
    libfreetype6-dev \
    libgd-dev \
    libmcrypt-dev \
    bzip2 \
    libbz2-dev \
    libtidy-dev \
    libcurl4-openssl-dev \
    libz-dev \
    libmemcached-dev \
    libxslt-dev \
    libgmp-dev \
    libldap2-dev \
    python3 \
    python3-pycurl \
    unzip \
    wget \
    supervisor \
    git

RUN apt-get update \
    && apt-get install --yes --no-install-recommends $BUILD_DEPS \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    # && docker-php-ext-install pdo pdo_mysql curl gmp imap json ldap mbstring simplexml gd \
    && yes '' | pecl install -f mailparse mcrypt-1.0.1 \
    && docker-php-ext-enable mcrypt \
    && a2enmod rewrite \
    && a2enmod headers \
    && a2enmod remoteip  \
    && apt-get -y autoclean && apt-get -y autoremove && apt-get -y clean && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /etc/cron.{hourly,daily,weekly,monthly} \
    && echo "extension=mailparse.so" > /usr/local/etc/php/conf.d/docker-php-ext-mailparse.ini \
    && sed -i 's/^LogFormat/#&/' /etc/apache2/apache2.conf \
    && echo "[PHP]" >> /usr/local/etc/php/php.ini \
    && echo "expose_php=Off" >> /usr/local/etc/php/php.ini \
    && echo "ServerTokens Prod" >> /etc/apache2/conf-enabled/security.conf \
    && echo "ServerSignature Off" >> /etc/apache2/conf-enabled/security.conf \
    && ln -sf /proc/self/fd/1 /var/log/apache2/access.log \
    && ln -sf /proc/self/fd/1 /var/log/apache2/error.log

RUN curl -o ioncube.tar.gz http://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz \
    && tar -xvvzf ioncube.tar.gz \
    && mv ioncube/ioncube_loader_lin_7.4.so `php-config --extension-dir` \
    && rm -Rf ioncube.tar.gz ioncube \
    && docker-php-ext-enable ioncube_loader_lin_7.4

ADD supervisord.conf /etc/supervisor/supervisord.conf
ADD logformat.conf /etc/apache2/conf-enabled/logformat.conf
ADD remoteip.conf /etc/apache2/conf-enabled/remoteip.conf
ADD entrypoint.sh /entrypoint.sh

RUN mkdir /var/www/app \
    && curl -o blesta.zip -sSL https://account.blesta.com/client/plugin/download_manager/client_main/download/135/blesta-${VERSION}.zip \
    && unzip blesta.zip -d /var/www/app \
    && rm blesta.zip \
    && chown -R www-data:www-data /var/www/app/blesta/cache /var/www/app/uploads /var/www/app/blesta/config \
    && mv /var/www/app /var/www/docker-backup-app \
    && sed -ri -e 's!/var/www/html!/var/www/app/blesta!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/html!/var/www/app/blesta!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
    && echo '*/5 * * * * www-data /usr/local/bin/php /var/www/app/blesta/index.php cron' > /etc/cron.d/blesta \
    && echo '0 9 * * 3 www-data [ `date +\%d` -le 7 ] && /usr/bin/curl -sSL https://download.db-ip.com/free/dbip-city-lite-2021-05.mmdb.gz | gunzip > /var/www/app/uploads/system/GeoLite2-City.mmdb' >> /etc/cron.d/blesta

VOLUME /var/www/app
WORKDIR /var/www/app
EXPOSE 80

HEALTHCHECK CMD curl --silent --fail localhost:80 || exit 1
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord"]
