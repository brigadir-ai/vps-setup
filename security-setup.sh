#!/bin/bash
# security-setup.sh - Базовая настройка безопасности для Ubuntu 22.04 VPS
# Выполняй этот скрипт первым после подключения к серверу

set -e  # Остановиться при любой ошибке
set -u  # Ошибка при использовании неопределённых переменных

echo "========================================"
echo "НАСТРОЙКА БЕЗОПАСНОСТИ ДЛЯ VPS"
echo "IP: $(hostname -I | awk '{print $1}')"
echo "========================================"

# 1. Обновление системы
echo "🔧 Шаг 1: Обновление системы..."
apt update
apt upgrade -y
apt autoremove -y

# 2. Установка базовых утилит
echo "🔧 Шаг 2: Установка базовых утилит..."
apt install -y \
    curl \
    wget \
    git \
    nano \
    htop \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges

# 3. Настройка firewall (UFW)
echo "🔧 Шаг 3: Настройка firewall..."
# Запретить всё входящее по умолчанию
ufw default deny incoming
# Разрешить исходящее
ufw default allow outgoing
# Открыть необходимые порты
ufw allow 22/tcp comment 'SSH'
ufw allow 443/udp comment 'WireGuard (обфусцированный как HTTPS)'
ufw allow 53/tcp comment 'DNS (AdGuard)'
ufw allow 53/udp comment 'DNS (AdGuard)'
ufw allow 3000/tcp comment 'AdGuard Web UI'
# Включить UFW
ufw --force enable
echo "🔥 Firewall настроен. Открытые порты:"
ufw status numbered

# 4. Настройка fail2ban
echo "🔧 Шаг 4: Настройка fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban
# Создаём локальную конфигурацию для SSH
cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF
systemctl restart fail2ban
echo "🛡️  Fail2ban запущен. Блокирует после 5 неудачных попыток."

# 5. Настройка автоматических обновлений безопасности
echo "🔧 Шаг 5: Настройка автоматических обновлений безопасности..."
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

systemctl restart unattended-upgrades
echo "🤖 Автоматические обновления безопасности настроены."

# 6. Создание непривилегированного пользователя (опционально, но рекомендуется)
echo "🔧 Шаг 6: Создание пользователя 'admin'..."
if ! id "admin" &>/dev/null; then
    adduser --disabled-password --gecos "" admin
    usermod -aG sudo admin
    echo "✅ Пользователь 'admin' создан и добавлен в группу sudo."
    echo "⚠️  Не забудь настроить SSH ключи для пользователя admin:"
    echo "   mkdir -p /home/admin/.ssh"
    echo "   cp /root/.ssh/authorized_keys /home/admin/.ssh/"
    echo "   chown -R admin:admin /home/admin/.ssh"
else
    echo "ℹ️  Пользователь 'admin' уже существует."
fi

# 7. Настройка SSH безопасности (РЕКОМЕНДУЕТСЯ НАСТРОИТЬ ПОСЛЕ СОЗДАНИЯ ПОЛЬЗОВАТЕЛЯ)
echo "🔧 Шаг 7: Рекомендации по безопасности SSH..."
echo "========================================"
echo "РЕКОМЕНДАЦИИ ДЛЯ ДАЛЬНЕЙШЕЙ НАСТРОЙКИ SSH:"
echo ""
echo "1. Отключить вход под root:"
echo "   nano /etc/ssh/sshd_config"
echo "   Измени: PermitRootLogin no"
echo ""
echo "2. Отключить аутентификацию по паролю:"
echo "   В том же файле:"
echo "   PasswordAuthentication no"
echo "   ChallengeResponseAuthentication no"
echo ""
echo "3. Использовать только ключи SSH:"
echo "   PubkeyAuthentication yes"
echo ""
echo "4. После изменений перезагрузи SSH:"
echo "   systemctl restart ssh"
echo ""
echo "⚠️  ВАЖНО: Настрой SSH ключи ДО отключения парольной аутентификации!"
echo "========================================"

# 8. Установка мониторинга ресурсов
echo "🔧 Шаг 8: Установка мониторинга..."
apt install -y sysstat
# Включаем сбор статистики
sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
systemctl enable sysstat
systemctl start sysstat

# 9. Настройка времени и часового пояса
echo "🔧 Шаг 9: Настройка времени..."
timedatectl set-timezone Europe/Moscow
apt install -y chrony
systemctl enable chrony
systemctl start chrony

echo "========================================"
echo "✅ НАСТРОЙКА БЕЗОПАСНОСТИ ЗАВЕРШЕНА!"
echo "========================================"
echo ""
echo "Следующие шаги:"
echo "1. Настрой SSH безопасность (см. рекомендации выше)"
echo "2. Запусти wireguard-setup.sh для установки VPN"
echo "3. Запусти adguard-setup.sh для блокировки рекламы"
echo "4. Запусти headscale-setup.sh для mesh-сети"
echo ""
echo "Для проверки безопасности:"
echo "  • ufw status        - статус firewall"
echo "  • fail2ban-client status - статус fail2ban"
echo "  • ss -tulpn         - открытые порты"
echo "  • who -a            - кто подключен"
echo ""
echo "⚠️  Сохрани этот вывод для будущих справок."