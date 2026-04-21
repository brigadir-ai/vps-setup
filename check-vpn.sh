#!/bin/bash
# check-vpn.sh - Диагностика проблем с WireGuard VPN
# Запусти на VPS для проверки

set -e

echo "🔍 ДИАГНОСТИКА WIREGUARD VPN"
echo "============================="

# 1. Проверка статуса службы
echo ""
echo "1. 📦 СТАТУС СЛУЖБЫ WIREGUARD:"
if systemctl is-active --quiet wg-quick@wg0; then
    echo "   ✅ Служба запущена"
    systemctl status wg-quick@wg0 --no-pager -l | head -5
else
    echo "   ❌ Служба НЕ запущена"
    echo "   Попробуй: systemctl start wg-quick@wg0"
fi

# 2. Проверка интерфейса wg0
echo ""
echo "2. 🌐 ИНТЕРФЕЙС WG0:"
if ip link show wg0 &>/dev/null; then
    echo "   ✅ Интерфейс wg0 существует"
    ip addr show wg0 | grep -E "inet|state"
else
    echo "   ❌ Интерфейс wg0 НЕ существует"
fi

# 3. Проверка подключений
echo ""
echo "3. 🔗 ПОДКЛЮЧЕННЫЕ КЛИЕНТЫ:"
wg show 2>/dev/null || echo "   ❌ WireGuard не показывает подключения"

# 4. Проверка IP форвардинга
echo ""
echo "4. 📡 IP ФОРВАРДИНГ:"
if grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "   ✅ IP форвардинг включён в sysctl.conf"
else
    echo "   ❌ IP форвардинг НЕ включён"
    echo "   Добавь: echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf && sysctl -p"
fi

# 5. Проверка firewall (UFW)
echo ""
echo "5. 🔥 FIREWALL (UFW):"
if command -v ufw &>/dev/null; then
    ufw status | grep -A 20 "Status"
    echo ""
    echo "   Проверь что порт 443/udp открыт:"
    ufw status numbered | grep "443/udp" || echo "   ❌ Порт 443/udp не открыт"
else
    echo "   ℹ️  UFW не установлен"
fi

# 6. Проверка iptables правил
echo ""
echo "6. 📋 ПРАВИЛА IPTABLES ДЛЯ WG0:"
iptables -L -v -n | grep -E "wg0|ACCEPT|MASQUERADE" | head -10 || echo "   ℹ️  Правила не найдены"

# 7. Проверка доступа в интернет с сервера
echo ""
echo "7. 🌍 ДОСТУП В ИНТЕРНЕТ С VPS:"
if ping -c 2 -W 1 8.8.8.8 &>/dev/null; then
    echo "   ✅ VPS имеет доступ в интернет (8.8.8.8)"
else
    echo "   ❌ VPS НЕТ доступа в интернет"
fi

# 8. Проверка DNS
echo ""
echo "8. 🎯 DNS СЕРВЕР (должен быть 10.0.0.1, но AdGuard ещё не настроен):"
echo "   Текущий DNS на сервере:"
cat /etc/resolv.conf | grep nameserver || echo "   ❌ Не настроен"

# 9. Проверка порта 443 извне (используем внешний сервис)
echo ""
echo "9. 🚪 ПРОВЕРКА ПОРТА 443/udp ИЗВНЕ:"
echo "   Проверить можно на телефоне:"
echo "   • Установи 'Port Checker' приложение"
echo "   • Проверь порт 443 UDP на адресе 89.127.203.22"
echo "   • Или используй онлайн-чекер портов"

# 10. Рекомендации
echo ""
echo "🔧 РЕКОМЕНДАЦИИ:"
echo ""
echo "A. ЕСЛИ КЛИЕНТ ПОДКЛЮЧЕН, НО ИНТЕРНЕТА НЕТ:"
echo "   1. Проверь IP форвардинг (пункт 4)"
echo "   2. Проверь iptables правила (пункт 6)"
echo "   3. Временно отключи firewall: ufw disable"
echo ""
echo "B. ЕСЛИ КЛИЕНТ НЕ ПОДКЛЮЧАЕТСЯ ВООБЩЕ:"
echo "   1. Проверь порт 443/udp извне (пункт 9)"
echo "   2. Проверь что на телефоне включён VPN"
echo "   3. Проверь конфиг: нет ли ошибок в ключах"
echo ""
echo "C. ЕСЛИ TELEGRAM НЕ РАБОТАЕТ:"
echo "   1. Проблема может быть в DNS"
echo "   2. Попробуй в конфиге телефона изменить DNS на 1.1.1.1"
echo "   3. Или запусти ./fix-vpn-dns.sh на VPS"
echo ""
echo "📱 КОМАНДЫ ДЛЯ ПРОВЕРКИ НА ТЕЛЕФОНЕ:"
echo "• В приложении WireGuard: нажми на соединение → 'Посмотреть журнал'"
echo "• Если есть ошибки: 'Handshake did not complete' — проблема с портом"
echo "• Если нет ошибок, но трафик не идёт — проблема с маршрутизацией"
echo ""
echo "🚀 БЫСТРОЕ ИСПРАВЛЕНИЕ:"
echo "1. Перезапусти WireGuard на VPS: systemctl restart wg-quick@wg0"
echo "2. На телефоне: отключи и снова подключи VPN"
echo "3. Проверь доступ: ping 10.0.0.1 с телефона (если есть терминал)"