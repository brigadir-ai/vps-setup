#!/bin/bash
# change-wg-port.sh - Смена порта WireGuard для обхода блокировок
# Используй если провайдер блокирует порт 443

set -e

echo "🔄 СМЕНА ПОРТА WIREGUARD"
echo "========================"

echo ""
echo "⚠️  ВНИМАНИЕ: Если провайдер заблокировал IP полностью,"
echo "   смена порта может не помочь. В этом случае используй"
echo "   shadowsocks-setup.sh или udp2raw-setup.sh"
echo ""

# Проверяем права
if [[ $EUID -ne 0 ]]; then
    echo "❌ Запускай от root: sudo bash $0"
    exit 1
fi

# Проверяем конфиг WireGuard
CONFIG="/etc/wireguard/wg0.conf"
if [[ ! -f "$CONFIG" ]]; then
    echo "❌ Конфиг WireGuard не найден: $CONFIG"
    echo "   Установи WireGuard сначала: ./wireguard-setup.sh"
    exit 1
fi

echo ""
echo "📁 ТЕКУЩАЯ КОНФИГУРАЦИЯ:"
echo "   Конфиг: $CONFIG"
echo "   Текущий порт (ListenPort):"
grep ListenPort "$CONFIG" || echo "   ❌ Не найден ListenPort"

echo ""
echo "🎯 ВЫБЕРИ НОВЫЙ ПОРТ:"
echo "   1) 53    - DNS трафик (рекомендуется)"
echo "   2) 80    - HTTP трафик"
echo "   3) 443   - HTTPS трафик (текущий)"
echo "   4) 8080  - HTTP альтернативный"
echo "   5) 8443  - HTTPS альтернативный"
echo "   6) 4443  - udp2raw порт"
echo "   7) Другой порт (введи число)"
echo ""

read -p "Выбери вариант (1-7): " choice

case $choice in
    1)
        NEW_PORT=53
        PROTOCOL="UDP (DNS)"
        ;;
    2)
        NEW_PORT=80
        PROTOCOL="UDP (HTTP)"
        ;;
    3)
        NEW_PORT=443
        PROTOCOL="UDP (HTTPS)"
        ;;
    4)
        NEW_PORT=8080
        PROTOCOL="UDP"
        ;;
    5)
        NEW_PORT=8443
        PROTOCOL="UDP"
        ;;
    6)
        NEW_PORT=4443
        PROTOCOL="UDP"
        ;;
    7)
        read -p "Введи номер порта: " NEW_PORT
        if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
            echo "❌ Неверный номер порта"
            exit 1
        fi
        PROTOCOL="UDP"
        ;;
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac

echo ""
echo "🔧 МЕНЯЮ ПОРТ НА $NEW_PORT ($PROTOCOL)..."

# Останавливаем WireGuard
echo "   Останавливаю WireGuard..."
systemctl stop wg-quick@wg0 2>/dev/null || true

# Бэкапим конфиг
BACKUP="$CONFIG.backup.$(date +%s)"
cp "$CONFIG" "$BACKUP"
echo "   Бэкап создан: $BACKUP"

# Меняем порт в конфиге
if grep -q "ListenPort" "$CONFIG"; then
    # Заменяем существующий ListenPort
    sed -i "s/ListenPort = .*/ListenPort = $NEW_PORT/" "$CONFIG"
else
    # Добавляем ListenPort если нет
    echo "ListenPort = $NEW_PORT" >> "$CONFIG"
fi

echo "   Порт изменён в конфиге"

echo ""
echo "🛡️  ОБНОВЛЕНИЕ FIREWALL:"

# Удаляем старое правило для порта 443
if command -v ufw &>/dev/null; then
    echo "   Настраиваю UFW..."
    
    # Получаем старый порт из бэкапа
    OLD_PORT=$(grep "ListenPort" "$BACKUP" | grep -o '[0-9]*' || echo "443")
    
    # Удаляем старое правило если есть
    ufw delete allow ${OLD_PORT}/udp 2>/dev/null || true
    
    # Добавляем новое правило
    ufw allow ${NEW_PORT}/udp comment "WireGuard VPN"
    ufw reload
    echo "   ✅ Правило UFW обновлено: порт $NEW_PORT/udp открыт"
else
    echo "   ℹ️  UFW не установлен, правила firewall не обновлены"
    echo "   Открой порт $NEW_PORT/udp в firewall вручную"
fi

echo ""
echo "🚀 ПЕРЕЗАПУСК WIREGUARD:"

systemctl start wg-quick@wg0
sleep 2

if systemctl is-active --quiet wg-quick@wg0; then
    echo "   ✅ WireGuard запущен на порту $NEW_PORT"
    
    # Показываем новый конфиг клиента
    echo ""
    echo "📱 ОБНОВИ КОНФИГ НА ТЕЛЕФОНЕ:"
    echo "   В конфиге WireGuard на телефоне измени:"
    echo "   Было: Endpoint = 89.127.203.22:443"
    echo "   Стало: Endpoint = 89.127.203.22:$NEW_PORT"
    echo ""
    echo "   Или скачай новый конфиг:"
    echo "   curl -O http://89.127.203.22:8080/wg0-client.conf"
    echo ""
    
    # Проверяем слушается ли порт
    if ss -ulpn | grep -q ":$NEW_PORT"; then
        echo "   ✅ Порт $NEW_PORT/udp слушается"
    else
        echo "   ⚠️  Порт $NEW_PORT/udp НЕ слушается, проверь конфиг"
    fi
else
    echo "   ❌ WireGuard не запустился"
    echo "   Восстанавливаю бэкап..."
    cp "$BACKUP" "$CONFIG"
    systemctl start wg-quick@wg0
    echo "   Восстановлен старый конфиг из $BACKUP"
    exit 1
fi

echo ""
echo "🔍 ПРОВЕРКА:"
echo "   На VPS проверь:"
echo "   • systemctl status wg-quick@wg0"
echo "   • ss -ulpn | grep :$NEW_PORT"
echo ""
echo "   На телефоне:"
echo "   1. Измени Endpoint на порт $NEW_PORT"
echo "   2. Подключись к VPN"
echo "   3. Проверь https://ipleak.net"
echo ""

# Создаём скрипт для проверки портов
cat > /tmp/check-ports.sh << EOF
#!/bin/bash
echo "🔍 ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ НА 89.127.203.22"
echo "Порт 53/udp  (DNS):    \$(timeout 2 nc -zu 89.127.203.22 53 && echo "✅" || echo "❌")"
echo "Порт 80/udp  (HTTP):   \$(timeout 2 nc -zu 89.127.203.22 80 && echo "✅" || echo "❌")"
echo "Порт 443/udp (HTTPS):  \$(timeout 2 nc -zu 89.127.203.22 443 && echo "✅" || echo "❌")"
echo "Порт 8080/tcp (HTTP):  \$(timeout 2 nc -z 89.127.203.22 8080 && echo "✅" || echo "❌")"
echo "Порт 3000/tcp (AdGuard): \$(timeout 2 nc -z 89.127.203.22 3000 && echo "✅" || echo "❌")"
EOF

chmod +x /tmp/check-ports.sh

echo "📋 Создан скрипт проверки портов: /tmp/check-ports.sh"
echo "   Запусти на телефоне (если есть Termux) или на другом устройстве"

echo ""
echo "========================================"
echo "✅ ПОРТ ИЗМЕНЁН НА $NEW_PORT"
echo "========================================"
echo ""
echo "⚠️  ЕСЛИ НЕ ПОМОГЛО:"
echo "   Провайдер мог заблокировать IP полностью."
echo "   В этом случае используй:"
echo "   1. ./udp2raw-setup.sh   - маскировка под TCP"
echo "   2. ./shadowsocks-setup.sh - маскировка под HTTPS"
echo ""
echo "📞 Сообщи результат после смены порта."