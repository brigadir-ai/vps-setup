#!/bin/bash
# adguard-setup.sh - Установка AdGuard Home для блокировки рекламы
# Выполняй после wireguard-setup.sh

set -e
set -u

echo "========================================"
echo "УСТАНОВКА ADGUARD HOME"
echo "DNS: 10.0.0.1 (внутри VPN сети)"
echo "Web UI: http://SERVER_IP:3000"
echo "========================================"

# 1. Проверка, что WireGuard работает
echo "🔧 Шаг 1: Проверка WireGuard..."
if ! systemctl is-active --quiet wg-quick@wg0; then
    echo "⚠️  WireGuard не запущен. Запускаю..."
    systemctl start wg-quick@wg0
fi

# 2. Установка AdGuard Home
echo "🔧 Шаг 2: Установка AdGuard Home..."
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v

# 3. Настройка AdGuard Home
echo "🔧 Шаг 3: Настройка AdGuard Home..."
mkdir -p /opt/AdGuardHome/conf

# Создаём начальную конфигурацию
cat > /opt/AdGuardHome/conf/AdGuardHome.yaml << 'EOF'
bind_host: 0.0.0.0
bind_port: 3000
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: "ru"
theme: "auto"
debug_pprof: false
web_session_ttl: 720
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  statistics_interval: 1
  querylog_enabled: true
  querylog_file_enabled: true
  querylog_size_memory: 1000
  querylog_interval: 24
  anonymize_client_ip: false
  protection_enabled: true
  blocking_mode: "default"
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocked_response_ttl: 10
  ratelimit: 20
  ratelimit_whitelist: []
  refuse_any: true
  upstream_dns:
    - "1.1.1.1"
    - "8.8.8.8"
    - "tcp://1.1.1.1"
    - "tcp://8.8.8.8"
  upstream_dns_file: ""
  bootstrap_dns:
    - "1.1.1.1"
    - "8.8.8.8"
  all_servers: false
  fastest_addr: false
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts: []
  trusted_proxies: []
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: false
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  port_dns_over_quic: 853
  allow_unencrypted_doh: true
  certificate_chain: ""
  private_key: ""
  certificate_path: ""
  private_key_path: ""
  strict_sni_check: false
filters:
  - enabled: true
    url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: https://easylist.to/easylist/easylist.txt
    name: EasyList
    id: 2
  - enabled: true
    url: https://easylist.to/easylist/easyprivacy.txt
    name: EasyPrivacy
    id: 3
  - enabled: true
    url: https://easylist-downloads.adblockplus.org/ruadlist+easylist.txt
    name: Russian Ads
    id: 4
  - enabled: true
    url: https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
    name: StevenBlack's Hosts
    id: 5
whitelist_filters: []
user_rules: []
dhcp:
  enabled: false
  interface_name: ""
  local_domain_name: "lan"
  dhcpv4:
    gateway_ip: ""
    subnet_mask: ""
    range_start: ""
    range_end: ""
    lease_duration: 86400
    icmp_timeout_msec: 1000
    options: []
  dhcpv6:
    range_start: ""
    lease_duration: 86400
    ra_slaac_only: false
    ra_allow_slaac: false
clients: []
log_compress: false
log_localtime: false
log_max_backups: 0
log_max_size: 100
log_max_age: 3
log_file: ""
verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 16
EOF

echo "✅ Конфигурация AdGuard Home создана."

# 4. Настройка systemd службы
echo "🔧 Шаг 4: Настройка службы AdGuard Home..."
cat > /etc/systemd/system/AdGuardHome.service << 'EOF'
[Unit]
Description=AdGuard Home: Network-level ads and trackers blocking DNS server
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/AdGuardHome
ExecStart=/opt/AdGuardHome/AdGuardHome --no-check-update -c /opt/AdGuardHome/conf/AdGuardHome.yaml -h 0.0.0.0 -w /opt/AdGuardHome/work
Restart=always
RestartSec=10
LimitNOFILE=400000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable AdGuardHome
systemctl start AdGuardHome

# 5. Настройка DNS в WireGuard
echo "🔧 Шаг 5: Настройка DNS в WireGuard..."
# Убедимся что AdGuard слушает на 10.0.0.1
# Добавим правило iptables для перенаправления DNS запросов
iptables -t nat -A PREROUTING -i wg0 -p udp --dport 53 -j DNAT --to-destination 10.0.0.1:53
iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 53 -j DNAT --to-destination 10.0.0.1:53

# Сохраняем правила iptables
apt install -y iptables-persistent
netfilter-persistent save

# 6. Настройка firewall для AdGuard Home
echo "🔧 Шаг 6: Настройка firewall..."
ufw allow 53/tcp comment 'AdGuard DNS TCP'
ufw allow 53/udp comment 'AdGuard DNS UDP'
ufw allow 3000/tcp comment 'AdGuard Web UI'
ufw reload

# 7. Интеграция с системой
echo "🔧 Шаг 7: Интеграция с системой..."
# Настраиваем локальный DNS resolver чтобы система использовала AdGuard
echo "nameserver 127.0.0.1" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null || true

# 8. Проверка работы
echo "🔧 Шаг 8: Проверка работы AdGuard Home..."
sleep 5  # Даём время на запуск

if systemctl is-active --quiet AdGuardHome; then
    echo "✅ AdGuard Home запущен."
    
    # Проверка DNS
    echo "🔍 Тестирование DNS..."
    if dig @10.0.0.1 google.com +short > /dev/null 2>&1; then
        echo "✅ DNS запросы работают."
    else
        echo "⚠️  DNS запросы не проходят. Проверь настройки."
    fi
else
    echo "❌ AdGuard Home не запущен. Проверь логи: journalctl -u AdGuardHome"
fi

echo ""
echo "========================================"
echo "✅ ADGUARD HOME УСТАНОВЛЕН И НАСТРОЕН!"
echo "========================================"
echo ""
echo "🌐 ИНФОРМАЦИЯ:"
echo "• DNS сервер (внутри VPN): 10.0.0.1"
echo "• Веб-интерфейс: http://$(hostname -I | awk '{print $1}'):3000"
echo "• Логин: admin"
echo "• Пароль: admin (смени при первом входе!)"
echo ""
echo "📱 КАК НАСТРОИТЬ ДЛЯ ТЕЛЕФОНА:"
echo "1. Подключись к WireGuard VPN"
echo "2. DNS автоматически настроен на 10.0.0.1"
echo "3. Проверь блокировку рекламы: открой browsercheck.opendns.com"
echo ""
echo "🛠️  КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ:"
echo "  • systemctl status AdGuardHome  - статус службы"
echo "  • journalctl -u AdGuardHome -f  - логи в реальном времени"
echo "  • http://SERVER_IP:3000         - веб-интерфейс"
echo ""
echo "🔧 ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ:"
echo "1. Залогинься в веб-интерфейс (admin/admin)"
echo "2. Смени пароль!"
echo "3. Настрой дополнительные фильтры:"
echo "   - AdGuard Base filter"
echo "   - AdGuard Tracking Protection"
echo "   - RU AdList (для русской рекламы)"
echo "4. Настрой статистику и логирование"
echo ""
echo "⚠️  ВАЖНО: AdGuard блокирует рекламу на уровне DNS."
echo "   Некоторые приложения могут обходить блокировку (DoH, DoT)."
echo "   Для полной защиты может потребоваться блокировка портов 853/443."
echo "========================================"