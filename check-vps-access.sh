#!/bin/bash
# check-vps-access.sh - Проверка доступности VPS с разных портов
# Запусти на телефоне (Termux) или на другом устройстве

echo "🔍 ПРОВЕРКА ДОСТУПНОСТИ VPS"
echo "==========================="
echo "VPS IP: 89.127.203.22"
echo ""

# Проверяем установлен ли nc (netcat)
if ! command -v nc &>/dev/null; then
    echo "⚠️  Установи netcat для проверки портов:"
    echo "   Termux: pkg install netcat-openbsd"
    echo "   Ubuntu: apt install netcat"
    echo "   macOS: brew install netcat"
    echo ""
    echo "Проверяю через curl..."
    USE_CURL=true
else
    USE_CURL=false
fi

echo "📡 ПРОВЕРКА PING:"
if ping -c 2 -W 2 89.127.203.22 &>/dev/null; then
    echo "✅ Ping работает"
else
    echo "❌ Ping НЕ работает (возможно блокировка ICMP)"
fi

echo ""
echo "🌐 ПРОВЕРКА ПОРТОВ:"

PORTS=(
    "22    - SSH"
    "53    - DNS (UDP)"
    "80    - HTTP"
    "443   - HTTPS / WireGuard"
    "3000  - AdGuard Home"
    "8080  - HTTP файлы / Headscale"
    "8388  - Shadowsocks"
    "8443  - HTTPS альтернативный"
)

for port_info in "${PORTS[@]}"; do
    port=$(echo "$port_info" | awk '{print $1}')
    desc=$(echo "$port_info" | cut -d'-' -f2-)
    
    if [[ "$USE_CURL" == "true" ]]; then
        # Проверяем HTTP/HTTPS порты через curl
        if [[ "$port" == "80" || "$port" == "3000" || "$port" == "8080" ]]; then
            if timeout 3 curl -s -I "http://89.127.203.22:$port" &>/dev/null; then
                echo "✅ Порт $port: $desc (HTTP доступен)"
            else
                echo "❌ Порт $port: $desc (HTTP недоступен)"
            fi
        elif [[ "$port" == "443" || "$port" == "8443" ]]; then
            if timeout 3 curl -s -I "https://89.127.203.22:$port" --insecure &>/dev/null; then
                echo "✅ Порт $port: $desc (HTTPS доступен)"
            else
                echo "❌ Порт $port: $desc (HTTPS недоступен)"
            fi
        else
            echo "⚪ Порт $port: $desc (нужен netcat для проверки)"
        fi
    else
        # Проверяем через netcat
        if [[ "$port" == "53" ]]; then
            # DNS порт - UDP
            if timeout 2 nc -zu 89.127.203.22 53 &>/dev/null; then
                echo "✅ Порт $port: $desc (UDP доступен)"
            else
                echo "❌ Порт $port: $desc (UDP недоступен)"
            fi
        elif [[ "$port" == "443" || "$port" == "8388" ]]; then
            # WireGuard и Shadowsocks - проверяем оба протокола
            if timeout 2 nc -z 89.127.203.22 "$port" &>/dev/null; then
                echo "✅ Порт $port: $desc (TCP доступен)"
            else
                echo "❌ Порт $port: $desc (TCP недоступен)"
            fi
            if timeout 2 nc -zu 89.127.203.22 "$port" &>/dev/null; then
                echo "  ↳ UDP также доступен"
            fi
        else
            # Остальные порты - TCP
            if timeout 2 nc -z 89.127.203.22 "$port" &>/dev/null; then
                echo "✅ Порт $port: $desc (TCP доступен)"
            else
                echo "❌ Порт $port: $desc (TCP недоступен)"
            fi
        fi
    fi
done

echo ""
echo "📱 ПРОВЕРКА ДОСТУПНОСТИ СЕРВИСОВ:"

# Проверяем основные сервисы
echo "• WireGuard (порт 443/udp):"
if ping -c 1 -W 1 10.0.0.1 &>/dev/null 2>&1; then
    echo "  ✅ VPN сеть работает (пинг до шлюза)"
else
    echo "  ❌ VPN сеть не работает"
fi

echo ""
echo "• AdGuard Home (порт 3000):"
if timeout 3 curl -s http://89.127.203.22:3000 | grep -q "AdGuard"; then
    echo "  ✅ AdGuard Home доступен"
else
    echo "  ❌ AdGuard Home недоступен"
fi

echo ""
echo "• Файловый сервер (порт 8080):"
if timeout 3 curl -s http://89.127.203.22:8080 | grep -q "Index of"; then
    echo "  ✅ Файловый сервер доступен"
    echo "  📁 Список файлов: curl -s http://89.127.203.22:8080"
else
    echo "  ❌ Файловый сервер недоступен"
fi

echo ""
echo "🎯 АНАЛИЗ РЕЗУЛЬТАТОВ:"
echo ""
echo "A. ЕСЛИ ВСЕ ПОРТЫ НЕДОСТУПНЫ:"
echo "   ❌ IP адрес 89.127.203.22 полностью заблокирован"
echo "   🔧 РЕШЕНИЕ:"
echo "   1. Подожди 5-10 минут (блокировка может быть временной)"
echo "   2. Используй другой порт (53, 80)"
echo "   3. Подключись через мобильный интернет другого оператора"
echo "   4. Используй Shadowsocks с v2ray-plugin (маскировка под WebSocket)"
echo ""
echo "B. ЕСЛИ НЕКОТОРЫЕ ПОРТЫ ДОСТУПНЫ:"
echo "   ✅ Блокировка выборочная"
echo "   🔧 РЕШЕНИЕ:"
echo "   1. Используй доступный порт для WireGuard"
echo "   2. Или используй доступный порт для Shadowsocks"
echo ""
echo "C. ЕСЛИ ВСЕ ПОРТЫ ДОСТУПНЫ:"
echo "   ✅ Проблема в конфигурации WireGuard"
echo "   🔧 РЕШЕНИЕ:"
echo "   1. Проверь конфиг WireGuard на телефоне"
echo "   2. Проверь что служба WireGuard запущена на VPS"
echo "   3. Проверь firewall на VPS"
echo ""

# Создаём скрипт для автоматической проверки
cat > /tmp/quick-vps-check.sh << 'EOF'
#!/bin/bash
echo "⚡ БЫСТРАЯ ПРОВЕРКА VPS"
echo "IP: 89.127.203.22"
echo ""
echo "1. Проверяю основные порты..."
for port in 443 53 80 8080; do
    if timeout 1 nc -z 89.127.203.22 $port 2>/dev/null; then
        echo "✅ Порт $port доступен"
    else
        echo "❌ Порт $port недоступен"
    fi
done
echo ""
echo "2. Проверяю сервисы..."
curl -s -I --max-time 2 http://89.127.203.22:3000 2>/dev/null | grep -q "200" && echo "✅ AdGuard работает" || echo "❌ AdGuard не работает"
curl -s -I --max-time 2 http://89.127.203.22:8080 2>/dev/null | grep -q "200" && echo "✅ Файловый сервер работает" || echo "❌ Файловый сервер не работает"
EOF

chmod +x /tmp/quick-vps-check.sh

echo "📋 Создан скрипт быстрой проверки: /tmp/quick-vps-check.sh"
echo "   Запусти: ./quick-vps-check.sh"

echo ""
echo "🔧 РЕКОМЕНДАЦИИ:"
echo ""
echo "1. ЕСЛИ IP ЗАБЛОКИРОВАН ПОЛНОСТЬЮ:"
echo "   • Подожди 10-15 минут"
echo "   • Перезагрузи роутер (смени IP)"
echo "   • Используй мобильный интернет"
echo "   • Смени порт WireGuard на 53 (DNS)"
echo ""
echo "2. ЕСЛИ БЛОКИРУЮТ ТОЛЬКО WIREGUARD:"
echo "   • Используй Shadowsocks"
echo "   • Настрой udp2raw для маскировки"
echo "   • Используй другой протокол (OpenVPN)"
echo ""
echo "3. ЕСЛИ ПРОБЛЕМА В НАСТРОЙКАХ:"
echo "   • Проверь конфиг WireGuard на VPS"
echo "   • Проверь firewall на VPS"
echo "   • Проверь IP форвардинг"
echo ""

echo "========================================"
echo "✅ ПРОВЕРКА ЗАВЕРШЕНА"
echo "========================================"
echo ""
echo "📞 Сообщи какие порты доступны для выбора решения."