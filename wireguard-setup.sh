#!/bin/bash
# wireguard-setup.sh - Установка WireGuard VPN сервера на порту 443
# Выполняй после security-setup.sh

set -e
set -u

echo "========================================"
echo "УСТАНОВКА WIREGUARD VPN СЕРВЕРА"
echo "Порт: 443 (обфусцированный как HTTPS)"
echo "========================================"

# 1. Установка WireGuard и зависимостей
echo "🔧 Шаг 1: Установка WireGuard..."
apt update
apt install -y wireguard qrencode resolvconf

# 2. Генерация ключей сервера
echo "🔧 Шаг 2: Генерация ключей..."
mkdir -p /etc/wireguard
cd /etc/wireguard

# Генерация приватного и публичного ключей сервера
if [ ! -f server_private.key ]; then
    wg genkey | tee server_private.key | wg pubkey > server_public.key
    chmod 600 server_private.key server_public.key
    echo "✅ Ключи сервера сгенерированы."
else
    echo "ℹ️  Ключи сервера уже существуют."
fi

# 3. Определение сетевого интерфейса
INTERFACE=$(ip route show default | awk '/default/ {print $5}' | head -1)
echo "🌐 Сетевой интерфейс: $INTERFACE"

# 4. Создание конфигурации сервера (wg0.conf)
echo "🔧 Шаг 3: Создание конфигурации сервера..."
SERVER_PRIVATE_KEY=$(cat server_private.key)

cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 443
PrivateKey = $SERVER_PRIVATE_KEY
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE
SaveConfig = true

# Клиент 1: Твой телефон
[Peer]
# PublicKey будет добавлен после генерации клиента
PublicKey = CLIENT_PUBLIC_KEY_WILL_BE_ADDED
AllowedIPs = 10.0.0.2/32
EOF

chmod 600 /etc/wireguard/wg0.conf
echo "✅ Конфигурация сервера создана."

# 5. Включение IP форвардинга
echo "🔧 Шаг 4: Включение IP форвардинга..."
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
sed -i '/net.ipv6.conf.all.forwarding/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# 6. Генерация клиентского конфига
echo "🔧 Шаг 5: Генерация конфига для клиента (телефон)..."
mkdir -p /etc/wireguard/clients
cd /etc/wireguard/clients

# Генерация ключей клиента
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

# Получение публичного IP сервера (или домена)
SERVER_PUBLIC_IP=$(curl -4 -s ifconfig.co)
echo "🌍 Публичный IP сервера: $SERVER_PUBLIC_IP"

# Создание клиентского конфига
cat > phone.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.0.0.2/32
DNS = 10.0.0.1  # AdGuard DNS (будет настроен позже)

[Peer]
PublicKey = $(cat /etc/wireguard/server_public.key)
Endpoint = $SERVER_PUBLIC_IP:443
AllowedIPs = 0.0.0.0/0, ::/0  # Весь трафик через VPN
PersistentKeepalive = 25
EOF

# Добавление клиента в серверный конфиг
sed -i "s/PublicKey = CLIENT_PUBLIC_KEY_WILL_BE_ADDED/PublicKey = $CLIENT_PUBLIC_KEY/" /etc/wireguard/wg0.conf

echo "✅ Конфиг для телефона создан: /etc/wireguard/clients/phone.conf"

# 7. Генерация QR-кода
echo "🔧 Шаг 6: Генерация QR-кода для телефона..."
qrencode -t ansiutf8 < phone.conf
echo ""
echo "📱 Отсканируй этот QR-код в приложении WireGuard на телефоне."

# Также сохраняем QR-код в файл
qrencode -o /etc/wireguard/clients/phone.png < phone.conf
echo "💾 QR-код сохранён в файл: /etc/wireguard/clients/phone.png"

# 8. Запуск WireGuard
echo "🔧 Шаг 7: Запуск WireGuard..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
sleep 2

# Проверка статуса
echo "🔍 Проверка статуса WireGuard..."
systemctl status wg-quick@wg0 --no-pager -l
wg show

# 9. Настройка firewall для WireGuard (дополнительно)
echo "🔧 Шаг 8: Настройка firewall..."
# Убедимся что порт 443/udp открыт
ufw allow 443/udp comment 'WireGuard VPN'
ufw reload

# 10. Настройка обфускации (опционально, но рекомендуется)
echo "🔧 Шаг 9: Настройка базовой обфускации..."
echo "========================================"
echo "РЕКОМЕНДАЦИИ ПО ОБФУСКАЦИИ:"
echo ""
echo "1. WireGuard уже работает на порту 443 (как HTTPS)"
echo "2. Для дополнительной обфускации можно установить udp2raw:"
echo ""
echo "   # Установка udp2raw (faketcp режим)"
echo "   git clone https://github.com/wangyu-/udp2raw-tunnel.git"
echo "   cd udp2raw-tunnel"
echo "   make"
echo "   # Запуск сервера udp2raw"
echo "   ./udp2raw_amd64 -s -l0.0.0.0:4443 -r127.0.0.1:443 \\"
echo "     -k \"YourSecretPassword\" --raw-mode faketcp -a"
echo ""
echo "3. Клиенты должны использовать udp2raw для подключения"
echo "4. Скрипт udp2raw-setup.sh можно создать позже по необходимости"
echo "========================================"

echo ""
echo "========================================"
echo "✅ WIREGUARD УСТАНОВЛЕН И НАСТРОЕН!"
echo "========================================"
echo ""
echo "📋 ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ:"
echo "• Сервер: $SERVER_PUBLIC_IP:443"
echo "• Сеть: 10.0.0.0/24"
echo "• Твой IP в VPN: 10.0.0.2"
echo "• DNS: 10.0.0.1 (AdGuard будет настроен позже)"
echo ""
echo "📱 КАК ПОДКЛЮЧИТЬ ТЕЛЕФОН:"
echo "1. Установи WireGuard из магазина приложений"
echo "2. Нажми '+', выбери 'Сканировать QR-код'"
echo "3. Отсканируй QR-код выше"
echo "4. Нажми 'Подключиться'"
echo ""
echo "🛠️  КОМАНДЫ ДЛЯ ПРОВЕРКИ:"
echo "  • wg show                    - статус подключений"
echo "  • systemctl status wg-quick@wg0 - статус службы"
echo "  • cat /etc/wireguard/clients/phone.conf - конфиг клиента"
echo ""
echo "⚠️  Сохрани QR-код и конфиг в надёжном месте!"
echo "========================================"