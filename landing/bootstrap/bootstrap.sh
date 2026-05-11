#!/usr/bin/env bash
#
# bootstrap.sh — first-touch hardening for a fresh Ubuntu 24.04 server.
# Run once, as root, on a freshly provisioned VPS.
#
# What it does:
#   - apt update + install base packages
#     (ufw, fail2ban, unattended-upgrades, Docker Engine + Compose)
#   - creates a non-root sudo user, copies the SSH key from /root
#   - opens the firewall on 22 / 80 / 443, denies everything else inbound
#   - turns on fail2ban with the default sshd jail
#   - enables daily unattended security upgrades
#
# What it does NOT do:
#   - touch root SSH access
#     That's lockdown.sh — run that AFTER verifying the new user works.
#
# Reusing on your own box? Edit the CONFIG block below.

set -euo pipefail

# ─── CONFIG ────────────────────────────────────────────────────────────
NEW_USER="erbol"            # non-root user this script will create
TIMEZONE="Europe/Berlin"    # IANA tz; see `timedatectl list-timezones`
# ───────────────────────────────────────────────────────────────────────

# Must run as root — we create a user and write under /etc.
if [[ $EUID -ne 0 ]]; then
    echo "bootstrap.sh: must be run as root (try: sudo $0)" >&2
    exit 1
fi

# We copy /root/.ssh/authorized_keys to the new user. If it is missing
# or empty, the new user has no way to log in — and after lockdown.sh
# you would lock yourself out of the box entirely.
if [[ ! -s /root/.ssh/authorized_keys ]]; then
    echo "bootstrap.sh: /root/.ssh/authorized_keys is missing or empty." >&2
    echo "Add your SSH public key to /root/.ssh/authorized_keys first." >&2
    exit 1
fi

echo "==> [1/7] apt update + base packages"
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    ca-certificates curl gnupg lsb-release \
    ufw fail2ban unattended-upgrades \
    htop vim

echo "==> [2/7] timezone -> $TIMEZONE"
timedatectl set-timezone "$TIMEZONE"

echo "==> [3/7] user '$NEW_USER' + sudo + SSH key"
if ! id "$NEW_USER" &>/dev/null; then
    adduser --disabled-password --gecos "" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
fi
mkdir -p "/home/$NEW_USER/.ssh"
cp /root/.ssh/authorized_keys "/home/$NEW_USER/.ssh/authorized_keys"
chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
chmod 700 "/home/$NEW_USER/.ssh"
chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
# Passwordless sudo — convenient for automation. Comment out the next
# two lines if you'd rather be prompted for a password on every sudo.
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$NEW_USER"
chmod 0440 "/etc/sudoers.d/90-$NEW_USER"

echo "==> [4/7] ufw — deny inbound, allow 22/80/443"
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp  comment 'SSH'
ufw allow 80/tcp  comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

echo "==> [5/7] fail2ban (default sshd jail)"
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
echo "NEXT: from a SECOND terminal, verify the new user works:"
echo "    ssh -i ~/.ssh/<your-key> $NEW_USER@<this-ip>"
echo "    sudo whoami       # must print 'root'"
echo "    docker --version  # must print a version"
echo
echo "If all three pass, run ./lockdown.sh from this session."
echo "If anything fails, DO NOT run lockdown.sh — debug first."
