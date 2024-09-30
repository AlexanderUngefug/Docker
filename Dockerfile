FROM nginx:1.23-alpine

EXPOSE 8000
CMD ["/sbin/entrypoint.sh"]

ARG cachet_ver
ARG archive_url

ENV cachet_ver ${cachet_ver:-2.4}
ENV archive_url ${archive_url:-https://github.com/cachethq/Cachet/archive/${cachet_ver}.tar.gz}

ENV COMPOSER_VERSION 2.2.0

RUN apk add --no-cache --update \
    php81 \
    php81-apcu \
    php81-bcmath \
    php81-ctype \
    php81-curl \
    php81-dom \
    php81-fileinfo \
    php81-fpm \
    php81-gd \
    php81-iconv \
    php81-intl \
    php81-json \
    php81-mbstring \
    php81-mysqlnd \
    php81-opcache \
    php81-openssl \
    php81-pdo \
    php81-pdo_mysql \
    php81-pdo_pgsql \
    php81-pdo_sqlite \
    php81-phar \
    php81-posix \
    php81-redis \
    php81-session \
    php81-simplexml \
    php81-soap \
    php81-sqlite3 \
    php81-tokenizer \
    php81-xml \
    php81-xmlreader \
    php81-xmlwriter \
    php81-zip \
    php81-zlib \
    postfix \
    postgresql \
    postgresql-client \
    sqlite \
    openssh \
    sudo \
    wget \
    git \
    curl \
    bash \
    grep \
    supervisor

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    ln -sf /dev/stdout /var/log/php81/error.log && \
    ln -sf /dev/stderr /var/log/php81/error.log

RUN adduser -S -s /bin/bash -u 1001 -G root www-data

RUN echo "www-data	ALL=(ALL:ALL)	NOPASSWD:SETENV:	/usr/sbin/postfix" >> /etc/sudoers

RUN touch /var/run/nginx.pid && \
    chown -R www-data:root /var/run/nginx.pid

RUN chown -R www-data:root /etc/php81/php-fpm.d

RUN mkdir -p /var/www/html && \
    mkdir -p /usr/share/nginx/cache && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /var/lib/nginx && \
    chown -R www-data:root /var/www /usr/share/nginx/cache /var/cache/nginx /var/lib/nginx/

# Install composer
RUN wget https://getcomposer.org/installer -O /tmp/composer-setup.php && \
    wget https://composer.github.io/installer.sig -O /tmp/composer-setup.sig && \
    php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }" && \
    php /tmp/composer-setup.php --version=$COMPOSER_VERSION --install-dir=bin && \
    php -r "unlink('/tmp/composer-setup.php');"

WORKDIR /var/www/html/
USER 1001

RUN wget ${archive_url} && \
    tar xzf ${cachet_ver}.tar.gz --strip-components=1 && \
    chown -R www-data:root /var/www/html && \
    rm -r ${cachet_ver}.tar.gz && \
    php /bin/composer.phar update && \
    php /bin/composer.phar install -o && \
    rm -rf bootstrap/cache/*

COPY conf/php-fpm-pool.conf /etc/php81/php-fpm.d/www.conf
COPY conf/supervisord.conf /etc/supervisor/supervisord.conf
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx-site.conf /etc/nginx/conf.d/default.conf
COPY conf/.env.docker /var/www/html/.env
COPY entrypoint.sh /sbin/entrypoint.sh

USER root
RUN chmod g+rwx /var/run/nginx.pid && \
    chmod -R g+rw /var/www /usr/share/nginx/cache /var/cache/nginx /var/lib/nginx/ /etc/php81/php-fpm.d storage
USER 1001
