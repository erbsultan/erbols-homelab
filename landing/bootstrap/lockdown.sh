#!/usr/bin/env bash
# Запускай ТОЛЬКО после того, как новый юзер реально заходит по SSH и sudo работает.
# Вырубает root по SSH и парольный логин совсем.

set -euo pipefail

# cloud-init дропает свой 50-cloud-init.conf с PasswordAuthentication yes.
# Алфавитно 50 < 99, поэтому он бы переопределил наш hardening. Сносим.
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf

cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
EOF

# валидация конфига перед reload — если сломан, ssh не перезагружается
sshd -t
systemctl reload ssh

echo "=== root-SSH и пароли отключены ==="
echo "Заходи теперь только как 'erbol'."
