#!/bin/bash
# fix-headscale-download.sh - Исправление проблем с загрузкой Headscale

set -e

echo "🔧 ИСПРАВЛЕНИЕ ЗАГРУЗКИ HEADSCALE"
echo "================================"

echo ""
echo "1. 🔍 ПРОВЕРКА ТЕКУЩЕЙ ПРОБЛЕМЫ:"

# Проверяем доступность разных URL
VERSION="0.22.3"
ARCH="amd64"  # VPS x86_64

URLS=(
    "https://github.com/juanfont/headscale/releases/download/v${VERSION}/headscale_${VERSION}_linux_${ARCH}.tar.gz"
    "https://github.com/juanfont/headscale/releases/download/v${VERSION}/headscale_v${VERSION}_linux_${ARCH}.tar.gz"
    "https://objects.githubusercontent.com/github-production-release-asset-2e65be.s3.amazonaws.com/juanfont/headscale/v${VERSION}/headscale_${VERSION}_linux_${ARCH}.tar.gz"
)

echo "   Проверяю доступность URL..."
for URL in "${URLS[@]}"; do
    echo "   • $URL"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -I "$URL" --max-time 10 || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo "     ✅ Доступен (HTTP $HTTP_CODE)"
        WORKING_URL="$URL"
        break
    else
        echo "     ❌ Недоступен (HTTP $HTTP_CODE)"
    fi
done

echo ""
echo "2. 🚀 ВАРИАНТЫ РЕШЕНИЯ:"

if [[ -n "$WORKING_URL" ]]; then
    echo "   ✅ Найден рабочий URL: $WORKING_URL"
    echo ""
    echo "   Загружаю..."
    cd /tmp
    wget --timeout=30 "$WORKING_URL" -O headscale.tar.gz
    tar -xzf headscale.tar.gz
    mv headscale /usr/local/bin/
    chmod +x /usr/local/bin/headscale
    echo "   ✅ Headscale установлен"
else
    echo "   ❌ Все URL недоступны. Пробую другие варианты..."
    echo ""
    echo "   A. УСТАНОВКА ЧЕРЕЗ DOCKER (если установлен Docker):"
    if command -v docker &>/dev/null; then
        echo "      ✅ Docker установлен. Запускаю Headscale в Docker..."
        docker run -d \
            --name headscale \
            -p 8080:8080 \
            -v /etc/headscale:/etc/headscale \
            -v /var/lib/headscale:/var/lib/headscale \
            headscale/headscale:latest
        echo "      ✅ Headscale запущен в Docker"
    else
        echo "      ❌ Docker не установлен"
    fi
    
    echo ""
    echo "   B. СКАЧАТЬ ЧЕРЕЗ RPi И ПЕРЕДАТЬ ПО SCP:"
    echo "      1. На RPi выполни:"
    echo "         wget https://github.com/juanfont/headscale/releases/download/v${VERSION}/headscale_${VERSION}_linux_${ARCH}.tar.gz"
    echo "      2. Передай на VPS:"
    echo "         scp headscale_${VERSION}_linux_${ARCH}.tar.gz root@89.127.203.22:/tmp/"
    echo "      3. На VPS распакуй:"
    echo "         tar -xzf /tmp/headscale_${VERSION}_linux_${ARCH}.tar.gz"
    echo "         mv headscale /usr/local/bin/"
    
    echo ""
    echo "   C. УСТАНОВИТЬ ИЗ СИСТЕМНЫХ ПАКЕТОВ:"
    echo "      apt update"
    echo "      apt install -y golang"
    echo "      go install github.com/juanfont/headscale@latest"
    
    echo ""
    echo "   D. ПРОПУСТИТЬ HEADSCALE (НЕ КРИТИЧНО):"
    echo "      WireGuard и AdGuard уже работают."
    echo "      Headscale нужен только для mesh-сети между устройствами."
    echo "      Можно установить позже."
fi

echo ""
echo "3. 📋 ПРОВЕРКА УСТАНОВКИ:"

if command -v headscale &>/dev/null || docker ps | grep -q headscale; then
    echo "   ✅ Headscale установлен"
    
    # Создаём базовый конфиг если нет
    if [[ ! -f /etc/headscale/config.yaml ]]; then
        mkdir -p /etc/headscale
        cat > /etc/headscale/config.yaml << EOF
server_url: http://89.127.203.22:8080
listen_addr: 0.0.0.0:8080
private_key_path: /var/lib/headscale/private.key
db_path: /var/lib/headscale/db.sqlite
EOF
        echo "   ✅ Базовый конфиг создан"
    fi
    
    # Открываем порт в firewall
    if command -v ufw &>/dev/null; then
        ufw allow 8080/tcp comment 'Headscale' 2>/dev/null || true
    fi
    
    echo ""
    echo "   🌐 Headscale будет доступен по: http://89.127.203.22:8080"
else
    echo "   ℹ️  Headscale не установлен"
    echo "   Выбери один из вариантов выше для установки."
fi

echo ""
echo "========================================"
echo "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "========================================"
echo ""
echo "🎯 РЕКОМЕНДАЦИЯ:"
echo "• Если VPN и AdGuard работают — Headscale не критичен."
echo "• Можно установить позже, когда решится проблема с GitHub."
echo "• Основная цель (Telegram через VPN) уже достигнута."
echo ""
echo "📱 ЧТО УЖЕ РАБОТАЕТ:"
echo "✅ WireGuard VPN на порту 443"
echo "✅ AdGuard Home на порту 3000"
echo "✅ Блокировка рекламы"
echo "✅ Telegram через немецкий IP"
echo ""
echo "🔧 ЧТО МОЖНО ДОБАВИТЬ ПОЗЖЕ:"
echo "• Headscale для mesh-сети"
echo "• Обфускация WireGuard (udp2raw)"
echo "• Мониторинг и бэкапы"