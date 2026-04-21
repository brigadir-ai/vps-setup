#!/bin/bash
# check-headscale.sh - Диагностика установки Headscale
# Запусти на VPS если headscale-setup.sh не сработал

set -e

echo "🔍 ДИАГНОСТИКА HEADSCALE"
echo "========================"

echo ""
echo "1. 📦 ПРОВЕРКА УСТАНОВКИ БИНАРНИКА:"
if command -v headscale &> /dev/null; then
    echo "   ✅ Headscale установлен в: $(which headscale)"
    headscale --version || echo "   ℹ️  Не могу получить версию"
else
    echo "   ❌ Headscale НЕ установлен"
    echo "   Попробуй переустановить: ./headscale-setup.sh"
fi

echo ""
echo "2. 🚀 ПРОВЕРКА СЛУЖБЫ SYSTEMD:"
if systemctl is-active --quiet headscale; then
    echo "   ✅ Служба headscale запущена"
    systemctl status headscale --no-pager -l | head -10
else
    echo "   ❌ Служба headscale НЕ запущена"
    echo "   Попробуй: systemctl start headscale"
    echo "   Или проверь логи: journalctl -u headscale -f"
fi

echo ""
echo "3. 📁 ПРОВЕРКА КОНФИГУРАЦИОННЫХ ФАЙЛОВ:"
CONFIG="/etc/headscale/config.yaml"
if [ -f "$CONFIG" ]; then
    echo "   ✅ Конфиг найден: $CONFIG"
    echo "   Проверяю настройки..."
    grep -E "server_url|listen_addr|db_path" "$CONFIG" | head -5
else
    echo "   ❌ Конфиг НЕ найден: $CONFIG"
fi

echo ""
echo "4. 🔐 ПРОВЕРКА БАЗЫ ДАННЫХ:"
DB_PATH="/var/lib/headscale/db.sqlite"
if [ -f "$DB_PATH" ]; then
    echo "   ✅ База данных найдена: $DB_PATH ($(du -h "$DB_PATH" | cut -f1))"
else
    echo "   ❌ База данных НЕ найдена"
    echo "   Попробуй: sudo -u headscale headscale --config $CONFIG db migrate"
fi

echo ""
echo "5. 🚪 ПРОВЕРКА ПОРТА 8080:"
if ss -tulpn | grep :8080; then
    echo "   ✅ Порт 8080 слушается"
else
    echo "   ❌ Порт 8080 НЕ слушается"
    echo "   Проверь firewall: ufw status | grep 8080"
fi

echo ""
echo "6. 🔥 ПРОВЕРКА FIREWALL (UFW):"
if command -v ufw &>/dev/null; then
    echo "   Статус UFW:"
    ufw status | grep -E "8080|Status"
else
    echo "   ℹ️  UFW не установлен"
fi

echo ""
echo "7. 👤 ПРОВЕРКА ПОЛЬЗОВАТЕЛЕЙ И КЛЮЧЕЙ:"
if [ -f "$CONFIG" ] && [ -f "$DB_PATH" ]; then
    echo "   Попытка получить список пользователей..."
    sudo -u headscale headscale --config "$CONFIG" users list 2>/dev/null || echo "   ❌ Не могу получить список пользователей"
fi

echo ""
echo "8. 📊 ПРОВЕРКА ЛОГОВ:"
echo "   Последние 5 строк логов:"
journalctl -u headscale -n 5 --no-pager 2>/dev/null || echo "   ❌ Логи недоступны"

echo ""
echo "🔧 РЕКОМЕНДАЦИИ:"
echo ""
echo "A. ЕСЛИ HEADSCALE НЕ УСТАНОВЛЕН:"
echo "   Запусти: ./headscale-setup.sh"
echo ""
echo "B. ЕСЛИ СЛУЖБА НЕ ЗАПУСКАЕТСЯ:"
echo "   Проверь логи: journalctl -u headscale -f"
echo "   Переустанови: ./headscale-setup.sh"
echo ""
echo "C. ЕСЛИ ПОРТ 8080 НЕ ОТКРЫТ:"
echo "   Открой в firewall: ufw allow 8080/tcp"
echo "   Перезапусти службу: systemctl restart headscale"
echo ""
echo "D. ЕСЛИ НЕТ БАЗЫ ДАННЫХ:"
echo "   Инициализируй: sudo -u headscale headscale --config $CONFIG db migrate"
echo ""
echo "🌐 ПРОВЕРКА ДОСТУПНОСТИ ИЗВНЕ:"
echo "   Веб-интерфейс должен быть доступен по:"
echo "   http://89.127.203.22:8080"
echo ""
echo "📱 ДЛЯ ПОДКЛЮЧЕНИЯ УСТРОЙСТВ:"
echo "   Если всё работает, получи auth key:"
echo "   sudo -u headscale headscale --config $CONFIG preauthkeys list"