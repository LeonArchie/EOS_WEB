# Основной этап
FROM nginx:1.23-alpine

# Метаданные
LABEL maintainer="your-email@example.com"
LABEL version="1.0"
LABEL description="EOS Application with Nginx and PHP-FPM"

# Установка системных утилит
RUN apk add --no-cache \
    php81-fpm \
    php81-json \
    php81-mbstring \
    php81-session \
    php81-pdo \
    php81-pdo_mysql \
    php81-tokenizer \
    php81-xml \
    php81-dom \
    php81-curl \
    supervisor \
    iputils \
    net-tools \
    curl

# Создание необходимых директорий
RUN mkdir -p \
    /var/www/html \
    /var/log/supervisor \
    /var/run/php \
    /var/log/php-fpm

# Копирование конфигураций
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
    -e 's/listen = 127.0.0.1:9000/listen = \/var\/run\/php\/php81-fpm.sock/g' \
    -e 's/;listen.mode = 0660/listen.mode = 0660/g' \
    /etc/php81/php-fpm.d/www.conf

# Создание симлинка для обратной совместимости
RUN ln -s /var/run/php/php81-fpm.sock /var/run/php/php7.4-fpm.sock

# Настройка прав
RUN chown -R nginx:nginx /var/www/html /var/run/php /var/log/php-fpm && \
    chmod -R 755 /var/www/html && \
    chmod -R 775 /var/run/php /var/log/php-fpm

# Создание healthcheck скрипта
RUN echo '#!/bin/sh\n\
# Check nginx\n\
if ! curl -f http://localhost:9443/health > /dev/null 2>&1; then\n\
    echo "Nginx health check failed"\n\
    exit 1\n\
fi\n\
# Check PHP-FPM\n\
if ! SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \\n\
    cgi-fcgi -bind -connect /var/run/php/php81-fpm.sock 2>/dev/null | grep -q "pong"; then\n\
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