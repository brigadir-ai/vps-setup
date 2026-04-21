#!/bin/bash
# download-headscale.sh - Простая загрузка Headscale с проверкой всех шагов

set -e

echo "📥 ПРОСТАЯ ЗАГРУЗКА HEADSCALE"
echo "============================="

echo ""
echo "1. 🔍 ОПРЕДЕЛЕНИЕ АРХИТЕКТУРЫ:"
ARCH=$(uname -m)
echo "   Архитектура системы: $ARCH"

case $ARCH in
    x86_64|amd64)
        ARCH="amd64"
        echo "   ✅ Использую: $ARCH"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        echo "   ✅ Использую: $ARCH"
        ;;
    armv7l|armhf)
        ARCH="arm"
        echo "   ✅ Использую: $ARCH"
        ;;
    *)
        echo "   ❌ Неподдерживаемая архитектура: $ARCH"
        echo "   Продолжаю с amd64 (наиболее вероятно)"
        ARCH="amd64"
        ;;
esac

echo ""
echo "2. 🌐 ПРОВЕРКА ДОСТУПА К GITHUB:"
echo "   Проверяю ping..."
ping -c 2 github.com > /dev/null && echo "   ✅ GitHub доступен по ping"

echo "   Проверяю HTTPS..."
curl -s -I https://github.com --max-time 10 | grep HTTP && echo "   ✅ GitHub доступен по HTTPS"

echo "   Проверяю releases..."
curl -s -I https://github.com/juanfont/headscale/releases --max-time 10 | grep HTTP && echo "   ✅ Releases доступны"

echo ""
echo "3. 🔗 ПОЛУЧЕНИЕ ПОСЛЕДНЕЙ ВЕРСИИ:"
VERSION="v0.22.3"  # Фиксированная версия
echo "   Использую фиксированную версию: $VERSION"
echo "   (Если нужно другую, измени переменную VERSION в скрипте)"

echo ""
echo "4. 📦 СОСТАВЛЕНИЕ URL ДЛЯ ЗАГРУЗКИ:"
URL="https://github.com/juanfont/headscale/releases/download/${VERSION}/headscale_${VERSION:1}_linux_${ARCH}.tar.gz"
echo "   URL: $URL"

echo ""
echo "5. ⬇️  ПРОВЕРКА URL ПЕРЕД ЗАГРУЗКОЙ:"
echo "   Проверяю доступность URL..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -I "$URL" --max-time 10)
if [[ "$HTTP_CODE" == "200" ]]; then
    echo "   ✅ URL доступен (HTTP $HTTP_CODE)"
else
    echo "   ❌ URL не доступен (HTTP $HTTP_CODE)"
    echo "   Пробую альтернативный формат..."
    # Альтернативный формат имени файла
    ALT_URL="https://github.com/juanfont/headscale/releases/download/${VERSION}/headscale_${VERSION}_linux_${ARCH}.tar.gz"
    echo "   Альтернативный URL: $ALT_URL"
    ALT_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -I "$ALT_URL" --max-time 10)
    if [[ "$ALT_HTTP_CODE" == "200" ]]; then
        echo "   ✅ Альтернативный URL доступен (HTTP $ALT_HTTP_CODE)"
        URL="$ALT_URL"
    else
        echo "   ❌ Оба URL недоступны"
        exit 1
    fi
fi

echo ""
echo "6. ⬇️  СКАЧИВАНИЕ С WGET:"
echo "   Пробую wget..."
cd /tmp
if wget --timeout=30 --tries=3 "$URL"; then
    echo "   ✅ Файл скачан через wget"
else
    echo "   ❌ wget не сработал, пробую curl..."
    if curl -L --max-time 30 --retry 3 -o "headscale_${VERSION:1}_linux_${ARCH}.tar.gz" "$URL"; then
        echo "   ✅ Файл скачан через curl"
    else
        echo "   ❌ Оба метода не сработали"
        echo ""
        echo "🔧 ВОЗМОЖНЫЕ ПРИЧИНЫ:"
        echo "1. Проблема с DNS (попробуй: nslookup github.com)"
        echo "2. Блокировка releases.githubusercontent.com"
        echo "3. Проблема с сетью VPS"
        echo "4. Неправильная архитектура"
        exit 1
    fi
fi

echo ""
echo "7. 📁 ПРОВЕРКА СКАЧАННОГО ФАЙЛА:"
FILENAME=$(ls /tmp/*.tar.gz | head -1)
echo "   Скачанный файл: $FILENAME"
ls -lh "$FILENAME"

FILESIZE=$(stat -c%s "$FILENAME" 2>/dev/null || stat -f%z "$FILENAME" 2>/dev/null || echo "0")
if [[ $FILESIZE -lt 1000000 ]]; then
    echo "   ❌ Файл слишком мал ($FILESIZE байт), возможно повреждён"
    echo "   Содержимое файла (первые 100 байт):"
    head -c 100 "$FILENAME"
    echo ""
    exit 1
else
    echo "   ✅ Размер файла нормальный: $FILESIZE байт"
fi

echo ""
echo "8. 📦 РАСПАКОВКА:"
tar -xzf "$FILENAME"
if [[ -f "headscale" ]]; then
    echo "   ✅ Файл headscale извлечён"
    ls -lh headscale
else
    echo "   ❌ Файл headscale не найден в архиве"
    echo "   Содержимое архива:"
    tar -tzf "$FILENAME"
    exit 1
fi

echo ""
echo "9. 🚀 УСТАНОВКА:"
mv headscale /usr/local/bin/
chmod +x /usr/local/bin/headscale
echo "   ✅ Установлен в /usr/local/bin/headscale"

echo ""
echo "10. ✅ ПРОВЕРКА:"
if /usr/local/bin/headscale --version; then
    echo "   ✅ Headscale работает!"
else
    echo "   ❌ Headscale не запускается"
    exit 1
fi

echo ""
echo "========================================"
echo "✅ HEADSCALE УСПЕШНО СКАЧАН И УСТАНОВЛЕН!"
echo "========================================"
echo ""
echo "Дальше нужно настроить конфиг и службу:"
echo "1. Создать пользователя: useradd --system headscale"
echo "2. Создать /etc/headscale/config.yaml"
echo "3. Создать systemd службу"
echo "4. Запустить: systemctl start headscale"
echo ""
echo "Или используй скрипт установки после загрузки."