#!/bin/bash

# Установка NGINX из официального репозитория
echo "Добавляем официальный репозиторий NGINX..."
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
sudo apt update -y

# Определяем директорию, где находится скрипт
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Установка пакетов из requirements.txt (если файл существует)
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "Устанавливаем зависимости из requirements.txt..."
    xargs sudo apt install -y < "$REQUIREMENTS_FILE"
else
    echo "Файл requirements.txt не найден, пропускаем установку зависимостей."
fi



# Проверяем наличие папки NGINX
NGINX_DIR="$SCRIPT_DIR/NGINX"
if [ ! -d "$NGINX_DIR" ]; then
    echo "Ошибка: папка $NGINX_DIR не найдена!"
    exit 1
fi

# Проверяем наличие основного файла конфигурации
NGINX_CONF="$NGINX_DIR/nginx.conf"
if [ ! -f "$NGINX_CONF" ]; then
    echo "Ошибка: основной файл конфигурации $NGINX_CONF не найден!"
    exit 1
fi

# Ищем доменный конфиг (первый .conf файл кроме nginx.conf)
DOMAIN_CONF=$(find "$NGINX_DIR" -maxdepth 1 -name "*.conf" ! -name "nginx.conf" | head -n 1)

if [ -z "$DOMAIN_CONF" ]; then
    echo "Ошибка: не найден доменный конфигурационный файл в $NGINX_DIR!"
    exit 1
fi

# Извлекаем имя домена из названия файла конфига
DOMAIN_NAME=$(basename "$DOMAIN_CONF" .conf)
echo "Найден домен: $DOMAIN_NAME"

# Копируем основную конфигурацию nginx и проверяем её
echo "Обновляем основную конфигурацию nginx..."
sudo cp -f "$NGINX_CONF" /etc/nginx/nginx.conf

# Деактивируем и удаляем старую зону default (если есть)
echo "Проверяем наличие default конфигурации..."
DEFAULT_CONF="/etc/nginx/sites-enabled/default"
if [ -f "$DEFAULT_CONF" ] || [ -L "$DEFAULT_CONF" ]; then
    echo "Найдена default конфигурация, удаляем..."
    sudo rm -f "$DEFAULT_CONF"
    sudo rm -f "/etc/nginx/sites-available/default"
    echo "Default конфигурация удалена!"
fi

# Создаем директорию для сайта
SITE_DIR="/var/www/$DOMAIN_NAME"
echo "Создаем директорию для сайта: $SITE_DIR"
sudo mkdir -p "$SITE_DIR"

# Проверяем наличие папки WEB
WEB_DIR="$SCRIPT_DIR/WEB"
if [ ! -d "$WEB_DIR" ]; then
    echo "Ошибка: папка $WEB_DIR не найдена!"
    exit 1
fi

# Копируем файлы сайта
echo "Копируем файлы сайта из $WEB_DIR в $SITE_DIR"
sudo cp -r "$WEB_DIR"/* "$SITE_DIR/"

# Устанавлием правильные права
sudo chown -R www-data:www-data "$SITE_DIR"
sudo chmod -R 755 "$SITE_DIR"

# Копируем доменную конфигурацию
SITE_CONF="/etc/nginx/sites-available/$DOMAIN_NAME.conf"
echo "Копируем доменную конфигурацию из $DOMAIN_CONF в $SITE_CONF"
sudo cp -f "$DOMAIN_CONF" "$SITE_CONF"

# Активируем сайт
echo "Активируем сайт $DOMAIN_NAME"
sudo ln -sf "$SITE_CONF" "/etc/nginx/sites-enabled/"

# Проверяем конфигурацию
sudo nginx -t
if [ $? -eq 0 ]; then
    # Очищаем логи NGINX перед перезапуском
    echo "Очищаем логи NGINX..."
    sudo truncate -s 0 /var/log/nginx/*.log
    sudo find /var/log/nginx/ -name "*.gz" -type f -delete
    
    # Перезапускаем NGINX
    sudo systemctl reload nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    echo "Сайт $DOMAIN_NAME успешно активирован!"
    echo "Домен: $DOMAIN_NAME"
    echo "Директория сайта: $SITE_DIR"
    echo "Конфигурационный файл: $SITE_CONF"
else
    echo "Ошибка в конфигурации сайта!"
    exit 1
fi