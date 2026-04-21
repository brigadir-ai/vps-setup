#!/bin/bash
# install-headscale.sh - Надёжная установка Headscale с обработкой ошибок
# Запусти если старый скрипт не работает

set -euo pipefail

echo "🚀 НАДЁЖНАЯ УСТАНОВКА HEADSCALE"
echo "================================"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "${BLUE}🔧 $1${NC}"; }

# Проверка прав
if [[ $EUID -ne 0 ]]; then
    log_error "Этот скрипт должен запускаться от root"
    exit 1
fi

# Переменные
HEADSCALE_BIN="/usr/local/bin/headscale"
CONFIG_DIR="/etc/headscale"
DATA_DIR="/var/lib/headscale"
SERVICE_FILE="/etc/systemd/system/headscale.service"
BACKUP_DIR="/tmp/headscale-backup-$(date +%s)"

echo ""
log_info "1. ПРОВЕРКА ТЕКУЩЕЙ УСТАНОВКИ"

# Проверяем установлен ли headscale
if command -v headscale &>/dev/null || [[ -f "$HEADSCALE_BIN" ]]; then
    log_warn "Headscale уже установлен в системе"
    echo ""
    echo "Варианты:"
    echo "1) Переустановить (сохранить конфиг и базу данных)"
    echo "2) Полностью удалить и установить заново"
    echo "3) Выйти"
    echo ""
    read -p "Выбери вариант (1-3): " choice
    
    case $choice in
        1)
            log_info "Переустановка с сохранением данных..."
            mkdir -p "$BACKUP_DIR"
            # Сохраняем важные файлы
            [[ -f "$CONFIG_DIR/config.yaml" ]] && cp "$CONFIG_DIR/config.yaml" "$BACKUP_DIR/"
            [[ -f "$DATA_DIR/db.sqlite" ]] && cp "$DATA_DIR/db.sqlite" "$BACKUP_DIR/"
            [[ -f "$DATA_DIR/private.key" ]] && cp "$DATA_DIR/private.key" "$BACKUP_DIR/"
            log_success "Данные сохранены в $BACKUP_DIR"
            
            # Останавливаем службу
            systemctl stop headscale 2>/dev/null || true
            systemctl disable headscale 2>/dev/null || true
            ;;
        2)
            log_info "Полное удаление и чистая установка..."
            # Останавливаем и удаляем службу
            systemctl stop headscale 2>/dev/null || true
            systemctl disable headscale 2>/dev/null || true
            rm -f "$SERVICE_FILE"
            systemctl daemon-reload
            
            # Удаляем файлы
            rm -f "$HEADSCALE_BIN"
            rm -rf "$CONFIG_DIR"
            rm -rf "$DATA_DIR"
            log_success "Старая установка удалена"
            ;;
        3)
            log_info "Выход..."
            exit 0
            ;;
        *)
            log_error "Неверный выбор"
            exit 1
            ;;
    esac
fi

echo ""
log_info "2. ПРОВЕРКА ЗАВИСИМОСТЕЙ"

# Проверяем и устанавливаем зависимости
DEPS=("curl" "wget" "systemctl")
MISSING_DEPS=()

for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    log_warn "Устанавливаю зависимости: ${MISSING_DEPS[*]}"
    apt update
    apt install -y "${MISSING_DEPS[@]}"
    log_success "Зависимости установлены"
else
    log_success "Все зависимости установлены"
fi

echo ""
log_info "3. ОПРЕДЕЛЕНИЕ АРХИТЕКТУРЫ"

ARCH=$(uname -m)
case $ARCH in
    x86_64|amd64) 
        ARCH="amd64"
        log_success "Архитектура: $ARCH (x86_64)"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        log_success "Архитектура: $ARCH (ARM64)"
        ;;
    armv7l|armhf)
        ARCH="arm"
        log_success "Архитектура: $ARCH (ARMv7)"
        ;;
    *)
        log_error "Неподдерживаемая архитектура: $ARCH"
        echo "Поддерживаемые: x86_64, aarch64, armv7l"
        exit 1
        ;;
esac

echo ""
log_info "4. ПОЛУЧЕНИЕ ПОСЛЕДНЕЙ ВЕРСИИ"

# Пытаемся получить версию разными способами
LATEST_VERSION=""
ATTEMPTS=0
MAX_ATTEMPTS=3

while [[ -z "$LATEST_VERSION" && $ATTEMPTS -lt $MAX_ATTEMPTS ]]; do
    ATTEMPTS=$((ATTEMPTS + 1))
    log_info "Попытка $ATTEMPTS из $MAX_ATTEMPTS..."
    
    # Способ 1: через GitHub API
    LATEST_VERSION=$(curl -s https://api.github.com/repos/juanfont/headscale/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || true)
    
    # Способ 2: через прямую загрузку страницы (если API не работает)
    if [[ -z "$LATEST_VERSION" ]]; then
        LATEST_VERSION=$(curl -s https://github.com/juanfont/headscale/releases | grep -oE 'tag/[^"]+' | head -1 | cut -d'/' -f2 2>/dev/null || true)
    fi
    
    # Способ 3: фиксированная версия как fallback
    if [[ -z "$LATEST_VERSION" ]]; then
        LATEST_VERSION="v0.22.3"  # Последняя стабильная на момент написания
        log_warn "Не удалось получить версию, использую фиксированную: $LATEST_VERSION"
    fi
    
    sleep 1
done

if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Не удалось получить версию Headscale"
    exit 1
fi

log_success "Версия Headscale: $LATEST_VERSION"

echo ""
log_info "5. ЗАГРУЗКА И УСТАНОВКА БИНАРНИКА"

# Создаем временную директорию
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

DOWNLOAD_URL="https://github.com/juanfont/headscale/releases/download/${LATEST_VERSION}/headscale_${LATEST_VERSION}_linux_${ARCH}.tar.gz"
log_info "Скачиваю: $DOWNLOAD_URL"

# Пытаемся скачать
if ! wget -q --timeout=30 --tries=3 "$DOWNLOAD_URL"; then
    log_error "Не удалось скачать Headscale"
    log_info "Проверь доступ к GitHub и интернет-соединение"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Проверяем скачанный файл
TAR_FILE="headscale_${LATEST_VERSION}_linux_${ARCH}.tar.gz"
if [[ ! -f "$TAR_FILE" ]]; then
    log_error "Файл не скачался"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Проверяем размер файла (должен быть > 1MB)
FILE_SIZE=$(stat -c%s "$TAR_FILE" 2>/dev/null || stat -f%z "$TAR_FILE" 2>/dev/null || echo "0")
if [[ $FILE_SIZE -lt 1000000 ]]; then
    log_error "Скачанный файл слишком мал ($FILE_SIZE байт), возможно повреждён"
    rm -rf "$TMP_DIR"
    exit 1
fi

log_success "Файл скачан ($FILE_SIZE байт)"

# Распаковываем
tar -xzf "$TAR_FILE"
if [[ ! -f "headscale" ]]; then
    log_error "В архиве нет файла headscale"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Устанавливаем
mv headscale "$HEADSCALE_BIN"
chmod +x "$HEADSCALE_BIN"
log_success "Бинарник установлен в $HEADSCALE_BIN"

# Очищаем временную директорию
rm -rf "$TMP_DIR"

echo ""
log_info "6. НАСТРОЙКА СИСТЕМНОГО ПОЛЬЗОВАТЕЛЯ"

if ! id "headscale" &>/dev/null; then
    useradd --system --home "$DATA_DIR" --create-home --shell /bin/false headscale
    log_success "Пользователь headscale создан"
else
    log_success "Пользователь headscale уже существует"
fi

echo ""
log_info "7. НАСТРОЙКА ДИРЕКТОРИЙ И КОНФИГА"

# Создаем директории
mkdir -p "$CONFIG_DIR"
mkdir -p "$DATA_DIR"
chown -R headscale:headscale "$DATA_DIR"

# Получаем IP сервера
SERVER_IP=$(hostname -I | awk '{print $1}')
if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP="127.0.0.1"
    log_warn "Не удалось определить IP, использую $SERVER_IP"
fi

# Проверяем занят ли порт 8080
if ss -tulpn | grep -q ":8080"; then
    log_warn "Порт 8080 уже занят другим процессом"
    log_info "Пытаюсь определить процесс..."
    ss -tulpn | grep ":8080"
    echo ""
    log_warn "Если это не Headscale, освободи порт или измени в конфиге"
fi

# Создаем конфиг
cat > "$CONFIG_DIR/config.yaml" << EOF
server_url: http://${SERVER_IP}:8080
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 0.0.0.0:50443
grpc_allow_insecure: false

private_key_path: $DATA_DIR/private.key
noise:
  private_key_path: $DATA_DIR/noise_private.key

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
db_path: $DATA_DIR/db.sqlite

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

log_success "Конфиг создан: $CONFIG_DIR/config.yaml"

echo ""
log_info "8. ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ"

# Восстанавливаем бэкап если есть
if [[ -d "$BACKUP_DIR" && -f "$BACKUP_DIR/db.sqlite" ]]; then
    cp "$BACKUP_DIR/db.sqlite" "$DATA_DIR/"
    log_success "База данных восстановлена из бэкапа"
else
    # Инициализируем новую базу
    sudo -u headscale "$HEADSCALE_BIN" --config "$CONFIG_DIR/config.yaml" db migrate
    log_success "Новая база данных создана"
fi

echo ""
log_info "9. СОЗДАНИЕ SYSTEMD СЛУЖБЫ"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=headscale - A Tailscale control server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=headscale
Group=headscale
ExecStart=$HEADSCALE_BIN serve --config $CONFIG_DIR/config.yaml
Restart=on-failure
RestartSec=5

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$DATA_DIR
ReadWritePaths=$CONFIG_DIR
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable headscale
log_success "Служба systemd создана"

echo ""
log_info "10. ЗАПУСК СЛУЖБЫ"

systemctl start headscale
sleep 3

if systemctl is-active --quiet headscale; then
    log_success "Headscale запущен"
else
    log_error "Headscale не запустился"
    log_info "Проверь логи: journalctl -u headscale -f"
    exit 1
fi

echo ""
log_info "11. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ И КЛЮЧА"

# Восстанавливаем конфиг из бэкапа если есть
if [[ -d "$BACKUP_DIR" && -f "$BACKUP_DIR/config.yaml" ]]; then
    log_info "Восстанавливаю пользователей из бэкапа..."
    # Если была база, пользователи уже там
else
    # Создаем пользователя если нет
    if ! sudo -u headscale "$HEADSCALE_BIN" --config "$CONFIG_DIR/config.yaml" users list 2>/dev/null | grep -q "default"; then
        sudo -u headscale "$HEADSCALE_BIN" --config "$CONFIG_DIR/config.yaml" users create default
        log_success "Пользователь 'default' создан"
    fi
fi

# Создаем pre-auth ключ
AUTH_KEY=$(sudo -u headscale "$HEADSCALE_BIN" --config "$CONFIG_DIR/config.yaml" preauthkeys create --user default --reusable --expiration 90d 2>/dev/null || echo "ERROR")
if [[ "$AUTH_KEY" != "ERROR" ]]; then
    log_success "Auth key создан: $AUTH_KEY"
else
    log_warn "Не удалось создать auth key (может уже существовать)"
    log_info "Проверь существующие ключи:"
    sudo -u headscale "$HEADSCALE_BIN" --config "$CONFIG_DIR/config.yaml" preauthkeys list 2>/dev/null || true
fi

echo ""
log_info "12. НАСТРОЙКА FIREWALL"

# Проверяем UFW
if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    ufw allow 8080/tcp comment 'Headscale control server' 2>/dev/null || true
    ufw allow 41641/udp comment 'Tailscale/Headscale UDP' 2>/dev/null || true
    ufw reload 2>/dev/null || true
    log_success "Правила firewall добавлены"
else
    log_info "UFW не активен, правила firewall не добавлены"
fi

echo ""
log_info "13. ПРОВЕРКА РАБОТЫ"

# Проверяем порт
if ss -tulpn | grep -q ":8080"; then
    log_success "Порт 8080 слушается"
else
    log_error "Порт 8080 не слушается"
fi

# Проверяем статус
if systemctl is-active --quiet headscale; then
    log_success "Служба активна"
else
    log_error "Служба не активна"
fi

echo ""
echo "========================================"
log_success "✅ HEADSCALE УСПЕШНО УСТАНОВЛЕН!"
echo "========================================"
echo ""
echo "🌐 ИНФОРМАЦИЯ:"
echo "• Control server: http://${SERVER_IP}:8080"
echo "• Auth key: ${AUTH_KEY:-'проверь командой: sudo -u headscale headscale --config /etc/headscale/config.yaml preauthkeys list'}"
echo "• Пользователь: default"
echo ""
echo "📱 КАК ПОДКЛЮЧИТЬ УСТРОЙСТВА:"
echo "1. Установи Tailscale на устройство"
echo "2. В настройках укажи: Custom login server"
echo "3. Введи: http://${SERVER_IP}:8080"
echo "4. Используй auth key выше"
echo ""
echo "🛠️  КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ:"
echo "• systemctl status headscale      - статус службы"
echo "• journalctl -u headscale -f      - логи в реальном времени"
echo "• headscale nodes list            - список устройств"
echo "• headscale users list            - список пользователей"
echo ""
echo "🔧 ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ:"
if [[ -d "$BACKUP_DIR" ]]; then
    echo "• Бэкап сохранён в: $BACKUP_DIR"
    echo "• Можно удалить после проверки: rm -rf $BACKUP_DIR"
fi
echo "• Конфиг: $CONFIG_DIR/config.yaml"
echo "• База данных: $DATA_DIR/db.sqlite"
echo "• Логи: journalctl -u headscale"
echo ""
echo "⚠️  ВАЖНО:"
echo "• Auth key действителен 90 дней"
echo "• Для продления создай новый: headscale preauthkeys create ..."
echo "• Храни ключ в безопасности!"
echo "========================================"