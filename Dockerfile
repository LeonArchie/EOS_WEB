# Этап сборки для зависимостей
FROM alpine:3.16 as deps

# Установка утилит для скачивания
RUN apk add --no-cache curl wget

# Скачивание и подготовка зависимостей (пример)
# RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Основной этап
FROM nginx:1.23-alpine

# Установка системных утилит
RUN apk add --no-cache --virtual .build-deps \
    curl \
    && apk add --no-cache \
    php8-fpm \
    php8-json \
    php8-mbstring \
    php8-session \
    php8-pdo \
    php8-pdo_mysql \
    php8-tokenizer \
    php8-xml \
    php8-dom \
    php8-curl \
    supervisor \
    iputils \
    net-tools \
    curl \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

# Создание необходимых директорий
RUN mkdir -p \
    /var/www/html \
    /var/log/supervisor \
    /var/run/php \
    /var/log/php-fpm

# Копирование конфигураций из этапа сборки (если нужно)
# COPY --from=deps /some/file /destination/

# Копирование локальных конфигураций
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/app-config.school59-ekb.ru.conf /etc/nginx/conf.d/default.conf
COPY supervisor/ /etc/supervisor/

# Копирование веб-файлов
COPY web/ /var/www/html/

# Настройка PHP-FPM
RUN sed -i \
    -e 's/;listen.owner = nobody/listen.owner = nginx/g' \
    -e 's/;listen.group = nobody/listen.group = nginx/g' \
    -e 's/user = nobody/user = nginx/g' \
    -e 's/group = nobody/group = nginx/g' \
    -e 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php\/php7.4-fpm.sock/g' \
    -e 's/;listen.mode = 0660/listen.mode = 0660/g' \
    /etc/php7/php-fpm.d/www.conf

# Настройка прав
RUN chown -R nginx:nginx /var/www/html /var/run/php /var/log/php-fpm && \
    chmod -R 755 /var/www/html && \
    chmod -R 775 /var/run/php /var/log/php-fpm

# Создание healthcheck скрипта
RUN echo '#!/bin/sh\n\
# Check nginx\n\
if ! curl -f http://localhost:80/health > /dev/null 2>&1; then\n\
    echo "Nginx health check failed"\n\
    exit 1\n\
fi\n\
# Check PHP-FPM\n\
if ! SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \\n\
    cgi-fcgi -bind -connect /var/run/php/php7.4-fpm.sock 2>/dev/null | grep -q "pong"; then\n\
    echo "PHP-FPM health check failed"\n\
    exit 1\n\
fi\n\
exit 0' > /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Создание простой healthcheck страницы
RUN echo "OK" > /var/www/html/health

# Открытие портов
EXPOSE 9443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /healthcheck.sh

# Запуск через supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]