#!/bin/bash
# show-wg-config.sh - Выводит ТОЛЬКО конфиг WireGuard (текст)

set -e

CONF="/etc/wireguard/clients/phone.conf"

if [ ! -f "$CONF" ]; then
    echo "Конфиг не найден: $CONF"
    echo "Запусти: ./wireguard-setup.sh"
    exit 1
fi

echo "Конфиг WireGuard (скопируй весь блок):"
echo "========================================"
cat "$CONF"
echo "========================================"
echo ""
echo "Вставь в приложение WireGuard через 'Импорт из файла или архива'"