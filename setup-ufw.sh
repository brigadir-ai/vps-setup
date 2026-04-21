#!/bin/bash
# setup-ufw.sh - Настройка и запуск UFW (firewall)
# Запусти если ufw установлен, но не настроен

set -e

echo "🔧 НАСТРОЙКА UFW (FIREWALL)"
echo "==========================="

echo ""
echo "1. 📦 ПРОВЕРКА УСТАНОВКИ UFW:"
if ! command -v ufw &> /dev/null; then
    echo "❌ UFW не установлен. Устанавливаю..."
    apt update
    apt install -y ufw
    echo "✅ UFW установлен"
else
    echo "✅ UFW уже установлен: $(ufw --version | head -1)"
fi

echo ""
echo "2. 🔄 СБРОС ПРАВИЛ (если были):"
# Отключаем UFW если активен
if ufw status | grep -q "Status: active"; then
    echo "ℹ️  UFW уже активен. Сбрасываю правила..."
    ufw --force reset
    echo "✅ Правила сброшены"
fi

echo ""
echo "3. ⚙️  НАСТРОЙКА ПРАВИЛ ПО УМОЛЧАНИЮ:"
ufw default deny incoming
ufw default allow outgoing
echo "✅ По умолчанию: запретить входящие, разрешить исходящие"

echo ""
echo "4. 🔓 ОТКРЫВАЕМ НЕОБХОДИМЫЕ ПОРТЫ:"

# SSH
echo "   🔧 Порт 22/tcp (SSH)..."
ufw allow 22/tcp comment 'SSH access'

# WireGuard
echo "   🔧 Порт 443/udp (WireGuard VPN)..."
ufw allow 443/udp comment 'WireGuard VPN (obfuscated as HTTPS)'

# DNS (AdGuard)
echo "   🔧 Порт 53/tcp (DNS TCP)..."
ufw allow 53/tcp comment 'DNS (AdGuard)'
echo "   🔧 Порт 53/udp (DNS UDP)..."
ufw allow 53/udp comment 'DNS (AdGuard)'

# AdGuard Web UI
echo "   🔧 Порт 3000/tcp (AdGuard Web UI)..."
ufw allow 3000/tcp comment 'AdGuard Home Web Interface'

# Headscale
echo "   🔧 Порт 8080/tcp (Headscale)..."
ufw allow 8080/tcp comment 'Headscale control server'

# WireGuard дополнительно (если нужен TCP)
echo "   🔧 Порт 443/tcp (HTTPS, для обфускации)..."
ufw allow 443/tcp comment 'HTTPS (for obfuscation)'

echo ""
echo "5. 🚀 ВКЛЮЧЕНИЕ UFW:"
echo "⚠️  ВНИМАНИЕ: После включения все неразрешённые входящие соединения будут блокироваться."
echo "   Убедись что порт 22 (SSH) открыт выше!"
echo ""
read -p "   Продолжить? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Отменено пользователем."
    exit 1
fi

ufw --force enable
echo "✅ UFW включён"

echo ""
echo "6. 📊 ПРОВЕРКА СТАТУСА:"
ufw status numbered

echo ""
echo "7. 🌐 ПРОВЕРКА ОТКРЫТЫХ ПОРТОВ:"
ss -tulpn | grep -E ":22|:53|:443|:3000|:8080" | sort

echo ""
echo "========================================"
echo "✅ UFW НАСТРОЕН И ЗАПУЩЕН!"
echo "========================================"
echo ""
echo "📋 ОТКРЫТЫЕ ПОРТЫ:"
echo "• 22/tcp    - SSH"
echo "• 53/tcp    - DNS (AdGuard)"
echo "• 53/udp    - DNS (AdGuard)"
echo "• 443/tcp   - HTTPS (обфускация)"
echo "• 443/udp   - WireGuard VPN"
echo "• 3000/tcp  - AdGuard Web UI"
echo "• 8080/tcp  - Headscale"
echo ""
echo "⚙️  КОМАНДЫ ДЛЯ УПРАВЛЕНИЯ:"
echo "• ufw status              - статус и правила"
echo "• ufw status numbered     - правила с номерами"
echo "• ufw allow <port>/<proto> - добавить правило"
echo "• ufw delete <number>     - удалить правило по номеру"
echo "• ufw disable             - отключить (временно)"
echo "• ufw enable              - включить"
echo "• ufw reload              - перезагрузить правила"
echo ""
echo "⚠️  ВАЖНО:"
echo "1. Если потеряешь доступ, отключи UFW через веб-консоль:"
echo "   ufw disable"
echo "2. Для веб-консоли порт 22 не критичен, но для SSH нужен."
echo "3. Если что-то не работает, проверь что порт открыт в UFW."