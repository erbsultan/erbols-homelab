#!/usr/bin/env bash
# Прогон один раз на свежей Ubuntu 24.04 VPS под root.
# Создаёт юзера, ставит фаервол, fail2ban, авто-апдейты, Docker.
# НЕ ломает root-SSH — это в lockdown.sh, после проверки нового юзера.

set -euo pipefail

NEW_USER="erbol"
TIMEZONE="Europe/Berlin"

echo "==> [1/7] apt update + базовые пакеты"
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    ca-certificates curl gnupg lsb-release \
    ufw fail2ban unattended-upgrades \
    htop vim

echo "==> [2/7] таймзона $TIMEZONE"
timedatectl set-timezone "$TIMEZONE"

echo "==> [3/7] юзер $NEW_USER + sudo + SSH-ключ"
if ! id "$NEW_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
fi
mkdir -p "/home/$NEW_USER/.ssh"
cp /root/.ssh/authorized_keys "/home/$NEW_USER/.ssh/authorized_keys"
chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
chmod 700 "/home/$NEW_USER/.ssh"
chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
# passwordless sudo — удобно. Хочешь паранойю — закомментируй и юзай 'sudo' с паролем.
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$NEW_USER"
chmod 0440 "/etc/sudoers.d/90-$NEW_USER"

echo "==> [4/7] ufw — закрываем входящее, открываем 22/80/443"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp  comment 'SSH'
ufw allow 80/tcp  comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

echo "==> [5/7] fail2ban (дефолтный sshd jail)"
systemctl enable --now fail2ban

echo "==> [6/7] unattended-upgrades"
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

echo "==> [7/7] Docker Engine + Compose plugin"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
apt-get update -qq
apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
usermod -aG docker "$NEW_USER"

echo
echo "=== bootstrap done ==="
echo "СЛЕДУЮЩИЙ ШАГ: открой ВТОРОЙ терминал на Маке и проверь:"
echo "    ssh -i ~/.ssh/homelab_ed25519 $NEW_USER@<этот-IP>"
echo "    sudo whoami   # должен ответить 'root'"
echo "Если оба ОК — запусти lockdown.sh."
echo "Если нет — НЕ запускай lockdown, разбираемся."
