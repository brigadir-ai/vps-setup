#!/bin/bash
# headscale-setup.sh - Установка Headscale (альтернатива Tailscale)
# Выполняй после adguard-setup.sh

set -e
set -u

echo "========================================"
echo "УСТАНОВКА HEADSCALE"
echo "Mesh-сеть для твоих устройств"
echo "========================================"

# 1. Загрузка и установка Headscale
echo "🔧 Шаг 1: Установка Headscale..."
# Определяем архитектуру
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
    *) echo "❌ Неподдерживаемая архитектура: $ARCH"; exit 1 ;;
esac

# Загружаем последнюю версию
LATEST_VERSION=$(curl -s https://api.github.com/repos/juanfont/headscale/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "📦 Устанавливаю Headscale $LATEST_VERSION для $ARCH..."

# Скачиваем и распаковываем
cd /tmp
wget -q "https://github.com/juanfont/headscale/releases/download/${LATEST_VERSION}/headscale_${LATEST_VERSION}_linux_${ARCH}.tar.gz"
tar -xzf "headscale_${LATEST_VERSION}_linux_${ARCH}.tar.gz"
mv headscale /usr/local/bin/
chmod +x /usr/local/bin/headscale

# 2. Создание системного пользователя
echo "🔧 Шаг 2: Создание пользователя headscale..."
if ! id "headscale" &>/dev/null; then
    useradd --system --home /var/lib/headscale --create-home --shell /bin/false headscale
fi

# 3. Создание директорий и конфигурации
echo "🔧 Шаг 3: Настройка директорий и конфигурации..."
mkdir -p /var/lib/headscale
mkdir -p /etc/headscale

# Создаём конфигурационный файл
cat > /etc/headscale/config.yaml << 'EOF'
server_url: http://SERVER_PUBLIC_IP:8080  # Замени на реальный IP
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 0.0.0.0:50443
grpc_allow_insecure: false

private_key_path: /var/lib/headscale/private.key
noise:
  private_key_path: /var/lib/headscale/noise_private.key

ip_prefixes:
  - fd7a:115c:a1e0::/48
  - 100.64.0.0/10

derp:
  server:
    enabled: false
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 24h

disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m
node_update_check_interval: 10s

db_type: sqlite3
db_path: /var/lib/headscale/db.sqlite

acl_policy_path: ""

dns_config:
  nameservers:
    - 1.1.1.1
  domains: []
  magic_dns: true
  base_domain: example.com

unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"

log:
  level: info
  format: text

disable_oidc: true
disable_user_registration: false
logtail:
  enabled: false
randomize_client_port: false
EOF

# Заменяем SERVER_PUBLIC_IP на реальный IP
SERVER_IP=$(hostname -I | awk '{print $1}')
sed -i "s|SERVER_PUBLIC_IP|$SERVER_IP|g" /etc/headscale/config.yaml

# 4. Инициализация базы данных
echo "🔧 Шаг 4: Инициализация базы данных..."
sudo -u headscale headscale --config /etc/headscale/config.yaml db migrate

# 5. Создание systemd службы
echo "🔧 Шаг 5: Создание systemd службы..."
cat > /etc/systemd/system/headscale.service << 'EOF'
[Unit]
Description=headscale - A Tailscale control server
After=network.target

[Service]
Type=simple
User=headscale
Group=headscale
ExecStart=/usr/local/bin/headscale serve --config /etc/headscale/config.yaml
Restart=always
RestartSec=5

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/headscale
ReadWritePaths=/etc/headscale
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable headscale
systemctl start headscale

# 6. Создание пользователя и pre-auth ключа
echo "🔧 Шаг 6: Создание пользователя и ключа..."
# Создаём пользователя (если ещё не создан)
if ! sudo -u headscale headscale --config /etc/headscale/config.yaml users list | grep -q "default"; then
    sudo -u headscale headscale --config /etc/headscale/config.yaml users create default
fi

# Создаём pre-auth ключ для автоматического подключения
AUTH_KEY=$(sudo -u headscale headscale --config /etc/headscale/config.yaml preauthkeys create --user default --reusable --expiration 90d)
echo "🔑 Pre-auth ключ создан: $AUTH_KEY"

# 7. Настройка firewall
echo "🔧 Шаг 7: Настройка firewall..."
ufw allow 8080/tcp comment 'Headscale control server'
ufw allow 41641/udp comment 'Tailscale/Headscale UDP'
ufw reload

# 8. Интеграция с WireGuard (опционально)
echo "🔧 Шаг 8: Интеграция с WireGuard..."
echo "========================================"
echo "ИНТЕГРАЦИЯ WIREGUARD И HEADSCALE:"
echo ""
echo "1. WireGuard и Headscale могут работать параллельно"
echo "2. WireGuard: для всего трафика через VPN (интернет)"
echo "3. Headscale: для mesh-сети между твоими устройствами"
echo ""
echo "КАК ПОДКЛЮЧИТЬ УСТРОЙСТВА:"
echo ""
echo "Для Linux (Raspberry Pi):"
echo "  curl -fsSL https://tailscale.com/install.sh | sh"
echo "  tailscale up --login-server http://$SERVER_IP:8080 --auth-key $AUTH_KEY"
echo ""
echo "Для macOS/Windows:"
echo "  1. Установи Tailscale"
echo "  2. В настройках укажи login server: http://$SERVER_IP:8080"
echo "  3. Используй auth key: $AUTH_KEY"
echo ""
echo "Для Android/iOS (через Tailscale):"
echo "  1. Установи Tailscale из магазина"
echo "  2. В настройках → Use custom login server"
echo "  3. Укажи: http://$SERVER_IP:8080"
echo "  4. Введи auth key: $AUTH_KEY"
echo "========================================"

# 9. Проверка работы
echo "🔧 Шаг 9: Проверка работы Headscale..."
sleep 3
if systemctl is-active --quiet headscale; then
    echo "✅ Headscale запущен."
    
    # Проверяем статус
    echo "🔍 Статус Headscale:"
    sudo -u headscale headscale --config /etc/headscale/config.yaml nodes list
else
    echo "❌ Headscale не запущен. Проверь логи: journalctl -u headscale"
fi

echo ""
echo "========================================"
echo "✅ HEADSCALE УСТАНОВЛЕН И НАСТРОЕН!"
echo "========================================"
echo ""
echo "🌐 ИНФОРМАЦИЯ:"
echo "• Control server: http://$SERVER_IP:8080"
echo "• Auth key: $AUTH_KEY"
echo "• Пользователь: default"
echo ""
echo "📱 КАК ПОДКЛЮЧИТЬ УСТРОЙСТВА:"
echo "1. Установи Tailscale на устройство"
echo "2. Укажи custom login server: http://$SERVER_IP:8080"
echo "3. Используй auth key выше"
echo "4. Устройства появятся в сети 100.64.x.x"
echo ""
echo "🛠️  КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ:"
echo "  • systemctl status headscale      - статус службы"
echo "  • journalctl -u headscale -f      - логи в реальном времени"
echo "  • headscale --config /etc/headscale/config.yaml nodes list - список узлов"
echo "  • headscale --config /etc/headscale/config.yaml users list - список пользователей"
echo ""
echo "🔧 ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ:"
echo "1. Настрой DERP серверы для лучшей connectivity"
echo "2. Настрой ACL для контроля доступа между устройствами"
echo "3. Настрой домен для MagicDNS"
echo "4. Настрой OAuth/SSO для аутентификации"
echo ""
echo "⚠️  ВАЖНО:"
echo "• Auth key действителен 90 дней"
echo "• Для продления создай новый ключ: headscale preauthkeys create ..."
echo "• Храни ключ в безопасности!"
echo "========================================"