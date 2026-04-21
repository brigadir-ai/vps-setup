#!/bin/bash
# show-qr-code.sh - Выводит ТОЛЬКО QR-код WireGuard конфига

set -e

CONF="/etc/wireguard/clients/phone.conf"

# Проверяем наличие конфига
if [ ! -f "$CONF" ]; then
    echo "Конфиг не найден: $CONF"
    echo "Запусти: ./wireguard-setup.sh"
    exit 1
fi

# Проверяем/устанавливаем qrencode
if ! command -v qrencode &> /dev/null; then
    echo "Устанавливаю qrencode..."
    apt update && apt install -y qrencode
fi

# Выводим QR-код
echo "QR-код WireGuard (отсканируй в приложении):"
echo "=========================================="
qrencode -t ansiutf8 < "$CONF"
echo "=========================================="
echo ""
echo "Сервер: 89.127.203.22:443"
echo "Твой IP в VPN: 10.0.0.2"