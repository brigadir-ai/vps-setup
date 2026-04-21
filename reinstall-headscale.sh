#!/bin/bash
# reinstall-headscale.sh - Безопасная переустановка Headscale с сохранением данных
# Используй если headscale-setup.sh не сработал или есть проблемы

set -e

echo "🔄 ПЕРЕУСТАНОВКА HEADSCALE"
echo "=========================="

echo ""
echo "1. ⏹️  ОСТАНОВКА СЛУЖБЫ:"
if systemctl is-active --quiet headscale; then
    systemctl stop headscale
    echo "   ✅ Служба остановлена"
else
    echo "   ℹ️  Служба не была запущена"
fi

echo ""
echo "2. 💾 СОХРАНЕНИЕ ДАННЫХ:"
BACKUP_DIR="/tmp/headscale-backup-$(date +%s)"
mkdir -p "$BACKUP_DIR"

# Копируем важные файлы
if [ -f "/etc/headscale/config.yaml" ]; then
    cp /etc/headscale/config.yaml "$BACKUP_DIR/"
    echo "   ✅ Конфиг сохранён: $BACKUP_DIR/config.yaml"
fi

if [ -f "/var/lib/headscale/db.sqlite" ]; then
    cp /var/lib/headscale/db.sqlite "$BACKUP_DIR/"
    echo "   ✅ База данных сохранена: $BACKUP_DIR/db.sqlite"
fi

if [ -f "/var/lib/headscale/private.key" ]; then
    cp /var/lib/headscale/private.key "$BACKUP_DIR/"
    echo "   ✅ Приватный ключ сохранён: $BACKUP_DIR/private.key"
fi

echo ""
echo "3. 🗑️  УДАЛЕНИЕ СТАРОЙ УСТАНОВКИ:"
# Удаляем бинарник
if [ -f "/usr/local/bin/headscale" ]; then
    rm -f /usr/local/bin/headscale
    echo "   ✅ Бинарник удалён"
fi

# Удаляем systemd службу
if [ -f "/etc/systemd/system/headscale.service" ]; then
    rm -f /etc/systemd/system/headscale.service
    systemctl daemon-reload
    echo "   ✅ Служба systemd удалена"
fi

echo ""
echo "4. 📦 УСТАНОВКА НОВОЙ ВЕРСИИ:"
# Определяем архитектуру
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l) ARCH="arm" ;;
    *) echo "❌ Неподдерживаемая архитектура: $ARCH"; exit 1 ;;
esac

echo "   Архитектура: $ARCH"

# Загружаем последнюю версию
echo "   Загружаю последнюю версию Headscale..."
cd /tmp
LATEST_VERSION=$(curl -s https://api.github.com/repos/juanfont/headscale/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "   Версия: $LATEST_VERSION"

wget -q "https://github.com/juanfont/headscale/releases/download/${LATEST_VERSION}/headscale_${LATEST_VERSION}_linux_${ARCH}.tar.gz"
tar -xzf "headscale_${LATEST_VERSION}_linux_${ARCH}.tar.gz"
mv headscale /usr/local/bin/
chmod +x /usr/local/bin/headscale
echo "   ✅ Headscale $LATEST_VERSION установлен"

echo ""
echo "5. 🏗️  ВОССТАНОВЛЕНИЕ КОНФИГУРАЦИИ:"
# Восстанавливаем конфиг или создаём новый
if [ -f "$BACKUP_DIR/config.yaml" ]; then
    mkdir -p /etc/headscale
    cp "$BACKUP_DIR/config.yaml" /etc/headscale/
    echo "   ✅ Конфиг восстановлен из бэкапа"
else
    echo "   ℹ️  Бэкап конфига не найден, создаём новый"
    # Создаём минимальный конфиг
    mkdir -p /etc/headscale
    cat > /etc/headscale/config.yaml << 'EOF'
server_url: http://SERVER_IP:8080
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
    
    # Заменяем SERVER_IP на реальный IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    sed -i "s|SERVER_IP|$SERVER_IP|g" /etc/headscale/config.yaml
    echo "   ✅ Новый конфиг создан"
fi

# Восстанавливаем базу данных если есть
if [ -f "$BACKUP_DIR/db.sqlite" ]; then
    mkdir -p /var/lib/headscale
    cp "$BACKUP_DIR/db.sqlite" /var/lib/headscale/
    chown -R headscale:headscale /var/lib/headscale
    echo "   ✅ База данных восстановлена"
else
    echo "   ℹ️  Бэкап базы данных не найден, создаём новую"
fi

echo ""
echo "6. 👤 ПРОВЕРКА ПОЛЬЗОВАТЕЛЯ HEADSCALE:"
if ! id "headscale" &>/dev/null; then
    useradd --system --home /var/lib/headscale --create-home --shell /bin/false headscale
    echo "   ✅ Пользователь headscale создан"
else
    echo "   ℹ️  Пользователь headscale уже существует"
fi

echo ""
echo "7. 📡 СОЗДАНИЕ SYSTEMD СЛУЖБЫ:"
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
echo "   ✅ Служба systemd создана"

echo ""
echo "8. 🗄️  ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ:"
mkdir -p /var/lib/headscale
chown -R headscale:headscale /var/lib/headscale
sudo -u headscale headscale --config /etc/headscale/config.yaml db migrate
echo "   ✅ База данных инициализирована"

echo ""
echo "9. 🚀 ЗАПУСК СЛУЖБЫ:"
systemctl enable headscale
systemctl start headscale
sleep 3

if systemctl is-active --quiet headscale; then
    echo "   ✅ Headscale запущен"
else
    echo "   ❌ Headscale не запустился. Проверь логи: journalctl -u headscale -f"
    exit 1
fi

echo ""
echo "10. 🔐 СОЗДАНИЕ AUTH KEY:"
# Создаём пользователя если нет
if ! sudo -u headscale headscale --config /etc/headscale/config.yaml users list 2>/dev/null | grep -q "default"; then
    sudo -u headscale headscale --config /etc/headscale/config.yaml users create default
    echo "   ✅ Пользователь 'default' создан"
fi

# Создаём pre-auth ключ
AUTH_KEY=$(sudo -u headscale headscale --config /etc/headscale/config.yaml preauthkeys create --user default --reusable --expiration 90d)
echo "   ✅ Auth key создан: $AUTH_KEY"

echo ""
echo "========================================"
echo "✅ HEADSCALE ПЕРЕУСТАНОВЛЕН!"
echo "========================================"
echo ""
echo "🌐 ИНФОРМАЦИЯ:"
echo "• Control server: http://$(hostname -I | awk '{print $1}'):8080"
echo "• Auth key: $AUTH_KEY"
echo "• Бэкап сохранён в: $BACKUP_DIR"
echo ""
echo "📱 КАК ПОДКЛЮЧИТЬ УСТРОЙСТВА:"
echo "1. Установи Tailscale на устройство"
echo "2. Укажи custom login server: http://$(hostname -I | awk '{print $1}'):8080"
echo "3. Используй auth key выше"
echo ""
echo "🛠️  ПРОВЕРКА:"
echo "  sudo -u headscale headscale --config /etc/headscale/config.yaml nodes list"
echo "  systemctl status headscale"