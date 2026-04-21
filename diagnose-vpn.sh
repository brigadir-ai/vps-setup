#!/bin/bash
# diagnose-vpn.sh - Диагностика проблем с VPN и Telegram
# Запусти на VPS

set -e

echo "🔍 ДИАГНОСТИКА VPN И TELEGRAM"
echo "=============================="

echo ""
echo "1. 📡 ПРОВЕРКА ИНТЕРНЕТА НА VPS:"
if ping -c 2 -W 1 8.8.8.8 &>/dev/null; then
    echo "   ✅ VPS имеет доступ в интернет"
else
    echo "   ❌ VPS НЕТ доступа в интернет"
    echo "   Проверь сетевые настройки VPS"
    exit 1
fi

echo ""
echo "2. 🌐 ПРОВЕРКА WIREGUARD НА VPS:"
if systemctl is-active --quiet wg-quick@wg0; then
    echo "   ✅ WireGuard служба запущена"
    
    # Проверяем интерфейс
    if ip link show wg0 &>/dev/null; then
        echo "   ✅ Интерфейс wg0 существует"
        echo "   IP адрес wg0: $(ip addr show wg0 | grep 'inet ' | awk '{print $2}')"
    else
        echo "   ❌ Интерфейс wg0 НЕ существует"
    fi
    
    # Проверяем подключения
    echo "   Подключенные клиенты:"
    wg show 2>/dev/null || echo "   ❌ Нет подключений"
else
    echo "   ❌ WireGuard служба НЕ запущена"
    echo "   Запусти: systemctl start wg-quick@wg0"
fi

echo ""
echo "3. 🎯 ПРОВЕРКА TELEGRAM API С VPS:"
echo "   Пробую подключиться к Telegram API..."
if timeout 10 curl -s -I https://api.telegram.org | grep -E "HTTP/2 200|HTTP/1.1 200" &>/dev/null; then
    echo "   ✅ Telegram API доступен с VPS"
else
    echo "   ❌ Telegram API НЕ доступен с VPS"
    echo "   Возможно блокировка на уровне VPS провайдера"
fi

echo ""
echo "4. 🔧 ПРОВЕРКА DNS (ADGUARD):"
if systemctl is-active --quiet AdGuardHome; then
    echo "   ✅ AdGuard запущен"
    
    # Проверяем DNS запросы
    echo "   Тестирую DNS..."
    if dig @10.0.0.1 google.com +short &>/dev/null; then
        echo "   ✅ DNS запросы через AdGuard работают"
    else
        echo "   ❌ DNS запросы через AdGuard НЕ работают"
        echo "   Попробуй публичный DNS: dig @1.1.1.1 google.com"
    fi
    
    # Проверяем блокировку Telegram DNS
    echo "   Проверяю Telegram домены..."
    TELEGRAM_DOMAINS=("telegram.org" "web.telegram.org" "api.telegram.org")
    for domain in "${TELEGRAM_DOMAINS[@]}"; do
        if dig @10.0.0.1 $domain +short | grep -q "addr"; then
            echo "   ✅ $domain разрешается"
        else
            echo "   ❌ $domain НЕ разрешается"
        fi
    done
else
    echo "   ❌ AdGuard НЕ запущен"
    echo "   Запусти: systemctl start AdGuardHome"
fi

echo ""
echo "5. 🔥 ПРОВЕРКА FIREWALL (UFW):"
if command -v ufw &>/dev/null; then
    echo "   Статус UFW:"
    ufw status | grep Status
    echo ""
    echo "   Проверка открытых портов для WireGuard:"
    ufw status | grep -E "443|udp" || echo "   ❌ Порт 443/udp не открыт"
else
    echo "   ℹ️  UFW не установлен"
fi

echo ""
echo "6. 📊 ПРОВЕРКА СЕТЕВЫХ ПРАВИЛ:"
echo "   Проверка IP форвардинга..."
if sysctl net.ipv4.ip_forward | grep -q "1"; then
    echo "   ✅ IP форвардинг включен"
else
    echo "   ❌ IP форвардинг НЕ включен"
    echo "   Включи: echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf && sysctl -p"
fi

echo ""
echo "7. 🐛 ПРОВЕРКА БЛОКИРОВКИ WIREGUARD (DPI):"
echo "   Признаки блокировки DPI в России:"
echo "   • WireGuard подключается, но трафик не идёт"
echo "   • Handshake проходит, но данные не передаются"
echo "   • В логах WireGuard: 'Handshake did not complete'"
echo ""
echo "   Проверь на телефоне в приложении WireGuard:"
echo "   1. Нажми на подключение → 'Посмотреть журнал'"
echo "   2. Если есть ошибки 'Handshake did not complete' — это DPI блокировка"
echo "   3. Если нет ошибок, но трафик 0 — тоже возможна блокировка"

echo ""
echo "8. 🚀 ТЕСТ МАРШРУТИЗАЦИИ:"
echo "   Чтобы проверить работает ли VPN вообще:"
echo ""
echo "   На телефоне (если есть терминал):"
echo "   1. Подключись к WireGuard"
echo "   2. Выполни: ping 10.0.0.1"
echo "   3. Если пинг идёт — VPN соединение работает"
echo "   4. Выполни: curl -I https://google.com"
echo "   5. Если работает — интернет через VPN есть"
echo ""
echo "   Или проверь через браузер телефона:"
echo "   1. Открой https://ipleak.net"
echo "   2. Должен показать немецкий IP (89.127.203.22)"
echo "   3. Если показывает российский IP — VPN не работает"

echo ""
echo "9. 🔧 РЕШЕНИЯ ДЛЯ ОБХОДА БЛОКИРОВКИ:"
echo ""
echo "   A. ОБФУСКАЦИЯ WIREGUARD:"
echo "      1. udp2raw — маскировка UDP под TCP"
echo "         Установи: ./udp2raw-setup.sh"
echo "      2. Shadowsocks + WireGuard"
echo "      3. obfsproxy"
echo ""
echo "   B. СМЕНА ПОРТА WIREGUARD:"
echo "      Сейчас порт 443 (HTTPS), попробуй 53 (DNS) или 80 (HTTP)"
echo ""
echo "   C. ПЕРЕХОД НА ДРУГОЙ ПРОТОКОЛ:"
echo "      1. OpenVPN (тоже может блокироваться)"
echo "      2. IPSec"
echo "      3. Socks5 прокси"
echo ""
echo "   D. ИСПОЛЬЗОВАНИЕ BRIDGE-СЕРВЕРА:"
echo "      VPN через другой порт/protocol, затем WireGuard"

echo ""
echo "10. 📱 ЭКСПРЕСС-ПРОВЕРКА НА ТЕЛЕФОНЕ:"
echo "    Выполни эти шаги и скажи результаты:"
echo ""
echo "    1. Включи VPN WireGuard на телефоне"
echo "    2. Открой браузер, перейди на https://ipleak.net"
echo "       • Какой IP показывает? (должен быть 89.127.203.22)"
echo "       • Какой country? (должен быть Germany)"
echo "    3. Пробуй открыть https://web.telegram.org"
echo "       • Открывается? Да/Нет"
echo "    4. Пробуй открыть https://google.com"
echo "       • Открывается? Да/Нет"
echo "    5. В приложении WireGuard: нажми на подключение → 'Посмотреть журнал'"
echo "       • Какие ошибки видишь? (скопируй)"
echo ""
echo "    Эти данные помогут понять проблему."

echo ""
echo "========================================"
echo "✅ ДИАГНОСТИКА ЗАВЕРШЕНА"
echo "========================================"
echo ""
echo "🎯 СЛЕДУЮЩИЕ ШАГИ:"
echo "1. Выполни проверки на телефоне (пункт 10)"
echo "2. Сообщи результаты"
echo "3. На основе результатов предложу решение"
echo ""
echo "⚠️  ВАЖНО: Если VPN не работает из-за DPI блокировки,"
echo "   нужно настраивать обфускацию (udp2raw)."