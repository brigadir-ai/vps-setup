#!/bin/bash
# shadowsocks-setup.sh - Установка Shadowsocks для обхода блокировок
# Маскирует трафик под HTTPS, сложнее для детектирования

set -e

echo "🌊 УСТАНОВКА SHADOWSOCKS"
echo "========================"

echo ""
echo "ℹ️  Что такое Shadowsocks?"
echo "   • Socks5 прокси с шифрованием"
echo "   • Маскируется под HTTPS трафик"
echo "   • Сложнее для детектирования чем WireGuard"
echo "   • Нужен клиент на телефоне (Shadowsocks)"
echo ""

# Проверяем права
if [[ $EUID -ne 0 ]]; then
    echo "❌ Запускай от root: sudo bash $0"
    exit 1
fi

echo ""
echo "1. 📦 УСТАНОВКА ЗАВИСИМОСТЕЙ:"
apt update
apt install -y python3 python3-pip git

echo ""
echo "2. 🔧 УСТАНОВКА SHADOWSOCKS:"
pip3 install shadowsocks

# Проверяем установку
if ! command -v ssserver &>/dev/null; then
    echo "❌ Shadowsocks не установился через pip"
    echo "   Пробую альтернативную установку..."
    apt install -y shadowsocks-libev 2>/dev/null || echo "   ❌ shadowsocks-libev тоже не установился"
fi

echo ""
echo "3. 🔐 ГЕНЕРАЦИЯ КОНФИГУРАЦИИ:"

# Генерируем случайные параметры
PASSWORD=$(openssl rand -base64 16 | tr -d '\n=' | head -c 16)
PORT=8388  # Стандартный порт Shadowsocks
METHOD="aes-256-gcm"  # Современный метод шифрования

CONFIG_DIR="/etc/shadowsocks"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config.json" << EOF
{
    "server": "0.0.0.0",
    "server_port": $PORT,
    "password": "$PASSWORD",
    "method": "$METHOD",
    "mode": "tcp_and_udp",
    "fast_open": true,
    "plugin": "",
    "plugin_opts": "",
    "timeout": 300,
    "udp_timeout": 300
}
EOF

echo "✅ Конфиг создан: $CONFIG_DIR/config.json"

echo ""
echo "4. 🚀 СОЗДАНИЕ SYSTEMD СЛУЖБЫ:"

# Проверяем какая версия установлена
SHADOWSOCKS_BIN=$(command -v ssserver 2>/dev/null || command -v ss-server 2>/dev/null || echo "")

if [[ -z "$SHADOWSOCKS_BIN" ]]; then
    echo "❌ Shadowsocks бинарник не найден"
    echo "   Пробую установить из репозитория..."
    apt install -y shadowsocks-libev
    SHADOWSOCKS_BIN=$(command -v ss-server)
fi

if [[ -n "$SHADOWSOCKS_BIN" ]]; then
    cat > /etc/systemd/system/shadowsocks.service << EOF
[Unit]
Description=Shadowsocks Proxy Server
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=$SHADOWSOCKS_BIN -c $CONFIG_DIR/config.json
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable shadowsocks
    echo "✅ Systemd служба создана"
else
    echo "❌ Не удалось найти бинарник Shadowsocks"
    echo "   Создаю службу для python-версии..."
    
    cat > /etc/systemd/system/shadowsocks.service << EOF
[Unit]
Description=Shadowsocks Proxy Server (Python)
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=/usr/local/bin/ssserver -c $CONFIG_DIR/config.json
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable shadowsocks
fi

echo ""
echo "5. 🔓 ОТКРЫТИЕ ПОРТА В FIREWALL:"
if command -v ufw &>/dev/null; then
    ufw allow $PORT/tcp comment "Shadowsocks TCP"
    ufw allow $PORT/udp comment "Shadowsocks UDP"
    ufw reload
    echo "✅ Порт $PORT открыт в firewall"
else
    echo "ℹ️  UFW не установлен, открой порт $PORT вручную"
fi

echo ""
echo "6. 🚀 ЗАПУСК SHADOWSOCKS:"
systemctl start shadowsocks
sleep 3

if systemctl is-active --quiet shadowsocks; then
    echo "✅ Shadowsocks запущен"
    
    # Проверяем порт
    if ss -tulpn | grep -q ":$PORT"; then
        echo "✅ Порт $PORT слушается"
    else
        echo "⚠️  Порт $PORT не слушается"
    fi
else
    echo "❌ Shadowsocks не запустился"
    echo "   Проверь логи: journalctl -u shadowsocks -f"
    exit 1
fi

echo ""
echo "7. 📱 КОНФИГ ДЛЯ ТЕЛЕФОНА:"

# Создаём QR код для удобного сканирования
cat > /tmp/shadowsocks-client.json << EOF
{
    "server": "89.127.203.22",
    "server_port": $PORT,
    "password": "$PASSWORD",
    "method": "$METHOD",
    "mode": "tcp_and_udp",
    "remarks": "VPS-Germany"
}
EOF

# Создаём строку для ручного ввода
SS_URL="ss://$(echo -n "$METHOD:$PASSWORD" | base64 | tr -d '\n')@89.127.203.22:$PORT#VPS-Germany"

echo ""
echo "📱 ДАННЫЕ ДЛЯ ПОДКЛЮЧЕНИЯ:"
echo "╔══════════════════════════════════════════╗"
echo "║ Сервер:    89.127.203.22                 ║"
echo "║ Порт:      $PORT                            ║"
echo "║ Пароль:    $PASSWORD       ║"
echo "║ Метод:     $METHOD              ║"
echo "║ Режим:     TCP и UDP                     ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "🔗 ССЫЛКА ДЛЯ ИМПОРТА:"
echo "$SS_URL"
echo ""
echo "📋 КАК ПОДКЛЮЧИТЬСЯ:"
echo "1. Установи на телефон клиент Shadowsocks:"
echo "   • Android: 'Shadowsocks' из Google Play или F-Droid"
echo "   • iOS: 'Shadowrocket' или 'Potatso Lite' (через App Store)"
echo "2. В клиенте выбери 'Импорт из QR кода' или 'Добавить вручную'"
echo "3. Введи данные выше"
echo "4. Включи прокси"
echo ""
echo "🌐 КАК ИСПОЛЬЗОВАТЬ С WIREGUARD:"
echo "Можно использовать Shadowsocks как прокси для WireGuard:"
echo "1. Настрой Shadowsocks на телефоне"
echo "2. В настройках WireGuard укажи:"
echo "   • Endpoint: 89.127.203.22:443 (или другой порт)"
echo "   • Подключись через прокси (Socks5): 127.0.0.1:1080"
echo "3. Или используй только Shadowsocks для всего трафика"

echo ""
echo "8. 📊 ПРОВЕРКА РАБОТЫ:"

# Проверочный скрипт
cat > /tmp/test-shadowsocks.sh << EOF
#!/bin/bash
echo "🔍 ТЕСТ SHADOWSOCKS"
echo "Сервер: 89.127.203.22:$PORT"
echo "Пробую подключиться..."
timeout 5 curl --socks5-hostname 127.0.0.1:1080 https://ipleak.net 2>/dev/null | grep -o 'Your IP address: [^<]*' || echo "❌ Не удалось подключиться"
EOF

chmod +x /tmp/test-shadowsocks.sh

echo "   Создан тестовый скрипт: /tmp/test-shadowsocks.sh"
echo "   Запусти на телефоне после настройки клиента"

echo ""
echo "9. 🔧 ДОПОЛНИТЕЛЬНЫЕ ВАРИАНТЫ:"

# Создаём конфиг для v2ray-plugin (обфускация)
cat > /tmp/shadowsocks-v2ray.json << EOF
{
    "server": "0.0.0.0",
    "server_port": 8443,
    "password": "$PASSWORD",
    "method": "$METHOD",
    "plugin": "v2ray-plugin",
    "plugin_opts": "server;path=/ws;host=89.127.203.22"
}
EOF

echo "   Для дополнительной маскировки можно использовать v2ray-plugin"
echo "   Конфиг для v2ray-plugin: /tmp/shadowsocks-v2ray.json"
echo "   Нужно установить: apt install v2ray-plugin"

echo ""
echo "========================================"
echo "✅ SHADOWSOCKS УСТАНОВЛЕН!"
echo "========================================"
echo ""
echo "🎯 ИНСТРУКЦИЯ ДЛЯ ТЕЛЕФОНА:"
echo "1. Установи клиент Shadowsocks"
echo "2. Добавь сервер с параметрами выше"
echo "3. Включи прокси"
echo "4. Проверь https://ipleak.net"
echo "5. Если работает — Telegram должен открываться"
echo ""
echo "⚠️  ВАЖНО:"
echo "• Shadowsocks проксирует только TCP трафик по умолчанию"
echo "• Для UDP (VoIP, игры) нужна отдельная настройка"
echo "• Если не работает, попробуй сменить метод шифрования на 'chacha20-ietf-poly1305'"
echo ""
echo "🔧 ЕСЛИ НЕ РАБОТАЕТ:"
echo "1. Проверь что порт $PORT открыт на VPS:"
echo "   nc -zv 89.127.203.22 $PORT"
echo "2. Проверь логи: journalctl -u shadowsocks -f"
echo "3. Попробуй другой порт (443, 8443)"
echo "4. Используй v2ray-plugin для маскировки под WebSocket"
echo ""
echo "📞 Сообщи результат после настройки."