#!/bin/bash
# fix-vpn-dns.sh - Исправляет DNS в WireGuard конфиге (меняет 10.0.0.1 на 1.1.1.1)
# Запусти на VPS если Telegram не работает из-за DNS

set -e

echo "🔧 ИСПРАВЛЕНИЕ DNS В WIREGUARD"
echo "=============================="

CONF="/etc/wireguard/clients/phone.conf"
BACKUP="${CONF}.backup.$(date +%s)"

if [ ! -f "$CONF" ]; then
    echo "❌ Конфиг не найден: $CONF"
    echo "Запусти сначала: ./wireguard-setup.sh"
    exit 1
fi

# Создаём backup
cp "$CONF" "$BACKUP"
echo "✅ Создан backup: $BACKUP"

# Меняем DNS с 10.0.0.1 на 1.1.1.1
echo ""
echo "📝 МЕНЯЮ DNS В КОНФИГЕ:"
echo "   Было: DNS = 10.0.0.1 (AdGuard, ещё не настроен)"
echo "   Стало: DNS = 1.1.1.1, 8.8.8.8 (публичные DNS)"

sed -i 's/DNS = 10.0.0.1/DNS = 1.1.1.1, 8.8.8.8/' "$CONF"

# Проверяем что заменилось
echo ""
echo "🔍 ПРОВЕРКА ИЗМЕНЕНИЙ:"
grep -n "DNS" "$CONF" || echo "   ❌ DNS строка не найдена"

# Пересоздаём QR-код и PNG если нужно
echo ""
echo "🔄 ОБНОВЛЯЮ QR-КОД:"
if command -v qrencode &>/dev/null; then
    qrencode -t ansiutf8 < "$CONF"
    qrencode -o /etc/wireguard/clients/phone.png < "$CONF"
    echo "✅ QR-код обновлён"
else
    echo "⚠️  qrencode не установлен, QR-код не обновлён"
fi

# Перезапускаем WireGuard (чтобы применить изменения на сервере)
echo ""
echo "🔄 ПЕРЕЗАПУСК WIREGUARD:"
systemctl restart wg-quick@wg0
sleep 2

# Проверяем статус
echo ""
echo "🔍 СТАТУС ПОСЛЕ ПЕРЕЗАПУСКА:"
systemctl is-active wg-quick@wg0 && echo "✅ WireGuard запущен" || echo "❌ WireGuard не запущен"
wg show 2>/dev/null | head -10

echo ""
echo "📱 ЧТО ДЕЛАТЬ НА ТЕЛЕФОНЕ:"
echo "1. В приложении WireGuard: отключи соединение"
echo "2. Нажми на соединение → 'Изменить' → 'Удалить'"
echo "3. Скачай новый конфиг:"
echo "   http://89.127.203.22:8080/phone.conf"
echo "4. Импортируй заново"
echo "5. Подключись"
echo ""
echo "🌐 НОВЫЙ DNS: 1.1.1.1 (Cloudflare) и 8.8.8.8 (Google)"
echo "   Telegram должен заработать!"
echo ""
echo "⚠️  ПРИМЕЧАНИЕ:"
echo "После настройки AdGuard (./adguard-setup.sh) можно вернуть DNS 10.0.0.1"
echo "Для восстановления старого конфига:"
echo "  cp $BACKUP $CONF"
echo "  systemctl restart wg-quick@wg0"