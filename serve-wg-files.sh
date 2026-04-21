#!/bin/bash
# serve-wg-files.sh - Запускает HTTP сервер для скачивания WireGuard конфига и QR-кода
# Не требует копирования текста из терминала!

set -e

echo "🚀 ЗАПУСК HTTP СЕРВЕРА ДЛЯ СКАЧИВАНИЯ ФАЙЛОВ"
echo "=========================================="

# Проверяем наличие конфига
CONF="/etc/wireguard/clients/phone.conf"
PNG="/etc/wireguard/clients/phone.png"

if [ ! -f "$CONF" ]; then
    echo "❌ Конфиг не найден: $CONF"
    echo "Запусти сначала: ./wireguard-setup.sh"
    exit 1
fi

echo "✅ Конфиг найден: $CONF"

# Создаём PNG если нет
if [ ! -f "$PNG" ]; then
    echo "📸 Создаю PNG QR-код..."
    if command -v qrencode &>/dev/null; then
        qrencode -o "$PNG" < "$CONF"
        echo "✅ PNG создан: $PNG"
    else
        echo "⚠️  qrencode не установлен. PNG не создан."
    fi
fi

# Открываем порт 8080 в firewall
echo "🔓 Открываю порт 8080 для скачивания..."
ufw allow 8080/tcp comment 'WireGuard file download' 2>/dev/null || true
ufw reload 2>/dev/null || true

# Получаем IP сервера
SERVER_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "🌐 СЕРВЕР ЗАПУЩЕН!"
echo "=========================================="
echo "📱 НА ТЕЛЕФОНЕ ОТКРОЙ ЭТУ ССЫЛКУ:"
echo ""
echo "    http://${SERVER_IP}:8080/"
echo ""
echo "📁 БУДУТ ДОСТУПНЫ ФАЙЛЫ:"
echo "• phone.conf   - текстовый конфиг"
if [ -f "$PNG" ]; then
    echo "• phone.png    - QR-код (скачай и отсканируй)"
fi
echo "=========================================="
echo ""
echo "⚡ ИНСТРУКЦИЯ ДЛЯ ТЕЛЕФОНА:"
echo "1. Открой ссылку выше в браузере телефона"
echo "2. Нажми на 'phone.png' чтобы скачать QR-код"
echo "3. В приложении WireGuard: '+' → 'Сканировать QR-код из галереи'"
echo "4. Выбери скачанный файл"
echo "5. Или нажми на 'phone.conf' чтобы увидеть текст конфига"
echo ""
echo "⏰ Сервер будет работать 10 минут"
echo "   Для остановки нажми Ctrl+C"
echo "=========================================="

# Копируем файлы в /tmp для безопасности
mkdir -p /tmp/wg-files
cp "$CONF" /tmp/wg-files/
if [ -f "$PNG" ]; then
    cp "$PNG" /tmp/wg-files/
fi

# Запускаем HTTP сервер с таймаутом
cd /tmp/wg-files
echo ""
echo "📡 HTTP сервер запущен на порту 8080"
echo "   Лог запросов:"
echo "------------------------------------------"

# Запускаем Python HTTP сервер с таймаутом
timeout 600 python3 -m http.server 8080 2>&1 | while IFS= read -r line; do
    echo "   $line"
done

echo ""
echo "=========================================="
echo "⏹️  СЕРВЕР ОСТАНОВЛЕН"
echo "Закрываю порт 8080..."
ufw delete allow 8080/tcp 2>/dev/null || true
ufw reload 2>/dev/null || true
echo "✅ Готово!"