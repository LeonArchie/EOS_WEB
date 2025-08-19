FROM nginx:1.23-alpine

# Установка необходимых пакетов
RUN apk add --no-cache \
    php81 \
    php81-fpm \
    php81-mysqli \
    php81-mbstring \
    php81-session \
    supervisor \
    curl

# Создание директорий
RUN mkdir -p \
    /var/www/html \
    /var/log/supervisor \
    /var/run/php \
    /var/run/supervisor

# Копирование конфигураций
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/eos-dev.school59-ekb.ru.conf /etc/nginx/conf.d/default.conf

# Копирование конфигураций supervisor
COPY supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor/nginx.conf /etc/supervisor/conf.d/nginx.conf
COPY supervisor/php-fpm.conf /etc/supervisor/conf.d/php-fpm.conf

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
RUN chown -R nginx:nginx /var/www/html /var/run/php /var/log/supervisor && \
    chmod -R 755 /var/www/html && \
    chmod -R 775 /var/run/php && \
    chown -R nginx:nginx /var/run/supervisor && \
    chmod -R 775 /var/run/supervisor

# Создание health endpoint
RUN echo "OK" > /var/www/html/health

EXPOSE 9443

# Запуск через supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf", "-n"]