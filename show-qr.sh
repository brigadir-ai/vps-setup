#!/bin/bash
# show-qr.sh - Показать QR-код и конфиг WireGuard для подключения телефона

set -e

echo "🔍 ПРОВЕРКА WIREGUARD НА VPS"
echo "============================="

# Проверяем установлен ли WireGuard
if ! command -v wg &> /dev/null; then
    echo "❌ WireGuard не установлен."
    echo ""
    echo "📋 Действие: Запусти ./wireguard-setup.sh"
    echo ""
    exit 1
fi

# Проверяем наличие конфига
CONF_PATH="/etc/wireguard/clients/phone.conf"
if [ ! -f "$CONF_PATH" ]; then
    echo "❌ Конфиг для телефона не найден."
    echo ""
    echo "📋 Действие: Запусти ./wireguard-setup.sh"
    echo ""
    exit 1
fi

echo "✅ WireGuard установлен"
echo "✅ Конфиг найден: $CONF_PATH"
echo ""

# Проверяем статус службы
if systemctl is-active --quiet wg-quick@wg0; then
    echo "✅ WireGuard сервис запущен"
else
    echo "⚠️  WireGuard сервис не запущен. Запускаю..."
    systemctl start wg-quick@wg0 2>/dev/null || true
fi

echo ""
echo "📄 КОНФИГ ДЛЯ ТЕЛЕФОНА (скопируй весь блок ниже):"
echo "================================================"
cat "$CONF_PATH"
echo "================================================"
echo ""

# Проверяем наличие qrencode
if command -v qrencode &> /dev/null; then
    echo "📱 QR-КОД (отсканируй в приложении WireGuard):"
    echo "================================================"
    qrencode -t ansiutf8 < "$CONF_PATH"
    echo "================================================"
    echo ""
    
    # Проверяем PNG файл
    PNG_PATH="/etc/wireguard/clients/phone.png"
    if [ -f "$PNG_PATH" ]; then
        echo "💾 QR-код также сохранён в файл: $PNG_PATH"
        echo "Скачать: curl -O http://89.127.203.22:8080/phone.png 2>/dev/null || echo 'HTTP сервер не запущен'"
    fi
else
    echo "ℹ️  Установи qrencode для генерации QR-кода:"
    echo "apt install qrencode"
fi

echo ""
echo "🌐 ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ:"
echo "• Сервер: 89.127.203.22:443"
echo "• Твой IP в VPN: 10.0.0.2"
echo "• DNS: 10.0.0.1 (AdGuard, после настройки)"
echo ""
echo "📱 КАК ПОДКЛЮЧИТЬ:"
echo "1. Установи WireGuard (Android/iOS)"
echo "2. Нажми '+', выбери 'Импорт из файла или архива'"
echo "3. Скопируй КОНФИГ выше и вставь в приложение"
echo "4. Или отсканируй QR-код"
echo "5. Нажми 'Подключиться'"
echo ""
echo "🛠️  ПРОВЕРКА:"
echo "• wg show                    - статус подключений"
echo "• ping 10.0.0.2              - проверь связь"
echo ""

# Дополнительная проверка
if ip addr show wg0 &>/dev/null; then
    echo "✅ Интерфейс wg0 активен"
else
    echo "⚠️  Интерфейс wg0 не активен"
fi