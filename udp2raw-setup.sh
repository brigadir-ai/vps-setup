#!/bin/bash
# udp2raw-setup.sh - Настройка обфускации WireGuard через udp2raw
# Защита от DPI блокировок в России

set -e

echo "🛡️  НАСТРОЙКА UDP2RAW ДЛЯ ОБХОДА БЛОКИРОВОК"
echo "=========================================="

echo ""
echo "ℹ️  Что такое udp2raw?"
echo "   • Маскирует UDP трафик WireGuard под TCP"
echo "   • Обходит DPI (глубокий анализ трафика)"
echo "   • Провайдер видит обычный TCP трафик на порту 4443"
echo "   • WireGuard продолжает работать на порту 443 локально"

echo ""
echo "1. 📦 УСТАНОВКА ЗАВИСИМОСТЕЙ:"
apt update
apt install -y build-essential git cmake libssl-dev

echo ""
echo "2. 🔧 КОМПИЛЯЦИЯ UDP2RAW:"
cd /tmp
git clone https://github.com/wangyu-/udp2raw-tunnel.git
cd udp2raw-tunnel
make

# Проверяем компиляцию
if [[ -f "udp2raw_amd64" ]]; then
    mv udp2raw_amd64 /usr/local/bin/udp2raw
    chmod +x /usr/local/bin/udp2raw
    echo "✅ udp2raw установлен"
else
    # Пробуем другую архитектуру
    if [[ -f "udp2raw_arm" ]]; then
        mv udp2raw_arm /usr/local/bin/udp2raw
        chmod +x /usr/local/bin/udp2raw
        echo "✅ udp2raw установлен (ARM)"
    else
        echo "❌ Не удалось скомпилировать udp2raw"
        echo "   Пробую скачать предварительно собранный бинарник..."
        # Пробуем скачать релиз
        wget https://github.com/wangyu-/udp2raw-tunnel/releases/download/20230206.0/udp2raw_binaries.tar.gz
        tar -xzf udp2raw_binaries.tar.gz
        mv udp2raw_amd64 /usr/local/bin/udp2raw 2>/dev/null || mv udp2raw_arm /usr/local/bin/udp2raw
        chmod +x /usr/local/bin/udp2raw
    fi
fi

echo ""
echo "3. 🔐 СОЗДАНИЕ КЛЮЧА ШИФРОВАНИЯ:"
# Генерируем случайный ключ
UDP2RAW_KEY=$(openssl rand -base64 32 | tr -d '\n=' | head -c 32)
echo "   Ключ шифрования: $UDP2RAW_KEY"
echo "   Сохрани этот ключ! Он понадобится для клиента."

echo ""
echo "4. 🚀 СОЗДАНИЕ SYSTEMD СЛУЖБЫ ДЛЯ UDP2RAW:"
cat > /etc/systemd/system/udp2raw.service << EOF
[Unit]
Description=UDP2Raw Tunnel for WireGuard obfuscation
After=network.target wg-quick@wg0.service
Requires=wg-quick@wg0.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/udp2raw -s -l0.0.0.0:4443 -r127.0.0.1:443 -k "$UDP2RAW_KEY" --raw-mode faketcp -a --cipher-mode xor --auth-mode simple
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udp2raw

echo ""
echo "5. 🔓 НАСТРОЙКА FIREWALL ДЛЯ ПОРТА 4443:"
if command -v ufw &>/dev/null; then
    ufw allow 4443/tcp comment 'UDP2RAW obfuscated WireGuard'
    ufw reload
    echo "✅ Порт 4443/tcp открыт в firewall"
else
    echo "ℹ️  UFW не установлен, добавь правило iptables вручную"
fi

echo ""
echo "6. 🚀 ЗАПУСК UDP2RAW:"
systemctl start udp2raw
sleep 2

if systemctl is-active --quiet udp2raw; then
    echo "✅ udp2raw запущен"
    echo "   Прослушивает порт: 0.0.0.0:4443 (TCP)"
    echo "   Перенаправляет на: 127.0.0.1:443 (WireGuard)"
else
    echo "❌ udp2raw не запустился"
    echo "   Проверь логи: journalctl -u udp2raw -f"
fi

echo ""
echo "7. 📱 КОНФИГ ДЛЯ ТЕЛЕФОНА (WireGuard + udp2raw):"
echo "   Для телефона нужно:"
echo "   1. Установить udp2raw клиент (Android: 'UDP2RAW' в F-Droid)"
echo "   2. Настроить udp2raw клиент с параметрами:"
echo ""
echo "   ╔══════════════════════════════════════╗"
echo "   ║ НАСТРОЙКИ UDP2RAW НА ТЕЛЕФОНЕ:      ║"
echo "   ╠══════════════════════════════════════╣"
echo "   ║ Режим: Клиент                       ║"
echo "   ║ Локальный порт: 4443                ║"
echo "   ║ Удалённый адрес: 89.127.203.22      ║"
echo "   ║ Удалённый порт: 4443                ║"
echo "   ║ Ключ: $UDP2RAW_KEY  ║"
echo "   ║ Режим: faketcp                      ║"
echo "   ║ Шифрование: xor                     ║"
echo "   ║ Аутентификация: simple              ║"
echo "   ╚══════════════════════════════════════╝"
echo ""
echo "   3. В WireGuard изменить Endpoint:"
echo "      Было: 89.127.203.22:443"
echo "      Стало: 127.0.0.1:4443"
echo ""
echo "   4. Запустить udp2raw клиент, затем WireGuard"

echo ""
echo "8. 🔧 АЛЬТЕРНАТИВА: КЛИЕНТСКИЙ СКРИПТ ДЛЯ ANDROID (Termux):"
cat > /tmp/udp2raw-client.sh << EOF
#!/bin/bash
# udp2raw-client.sh - Клиент udp2raw для Android (Termux)
# Запусти в Termux после установки udp2raw

SERVER="89.127.203.22"
PORT="4443"
KEY="$UDP2RAW_KEY"

echo "Запуск udp2raw клиента..."
echo "Сервер: \$SERVER:\$PORT"
echo "Ключ: \$KEY"

# Скачать udp2raw для Android
if [[ ! -f udp2raw_arm ]]; then
    wget https://github.com/wangyu-/udp2raw-tunnel/releases/download/20230206.0/udp2raw_arm
    chmod +x udp2raw_arm
fi

# Запустить клиент
./udp2raw_arm -c -l127.0.0.1:4443 -r\$SERVER:\$PORT -k "\$KEY" --raw-mode faketcp -a --cipher-mode xor --auth-mode simple
EOF

echo "   Скрипт для Termux сохранён: /tmp/udp2raw-client.sh"
echo "   Для использования:"
echo "   1. Установи Termux из F-Droid"
echo "   2. В Termux: bash /tmp/udp2raw-client.sh"
echo "   3. Запусти WireGuard с Endpoint 127.0.0.1:4443"

echo ""
echo "9. 🧪 ПРОВЕРКА РАБОТЫ UDP2RAW:"
echo "   На VPS проверь:"
echo "   • systemctl status udp2raw"
echo "   • ss -tulpn | grep 4443"
echo ""
echo "   На телефоне проверь:"
echo "   1. Запусти udp2raw клиент"
echo "   2. Запусти WireGuard"
echo "   3. Открой https://ipleak.net"
echo "   4. Должен быть немецкий IP"

echo ""
echo "🔧 РЕШЕНИЕ ПРОБЛЕМ:"
echo ""
echo "A. Если udp2raw не компилируется:"
echo "   Используй предварительно собранные бинарники:"
echo "   wget https://github.com/wangyu-/udp2raw-tunnel/releases/download/20230206.0/udp2raw_binaries.tar.gz"
echo ""
echo "B. Если порт 4443 заблокирован:"
echo "   Смени порт в настройках (например, на 443, 80, 53)"
echo ""
echo "C. Если не работает:"
echo "   1. Проверь ключ шифрования"
echo "   2. Проверь что WireGuard работает на порту 443"
echo "   3. Проверь firewall на VPS"
echo ""
echo "⚠️  ВАЖНО:"
echo "• Без udp2raw клиента на телефоне WireGuard не будет работать"
echo "• Ключ шифрования должен совпадать на сервере и клиенте"
echo "• udp2raw добавляет небольшую задержку (~10-20ms)"

echo ""
echo "========================================"
echo "✅ UDP2RAW НАСТРОЕН!"
echo "========================================"
echo ""
echo "🎯 ДЕЙСТВИЯ НА ТЕЛЕФОНЕ:"
echo "1. Установи udp2raw клиент (или используй Termux)"
echo "2. Настрой с параметрами выше"
echo "3. Измени Endpoint в WireGuard на 127.0.0.1:4443"
echo "4. Запусти udp2raw клиент"
echo "5. Запусти WireGuard"
echo "6. Проверь https://ipleak.net"
echo ""
echo "📞 Если не работает — сообщи ошибки."