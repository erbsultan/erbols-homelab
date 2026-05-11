#!/usr/bin/env bash
#
# lockdown.sh — close the front door of a freshly bootstrapped server.
# Disables root SSH login and password authentication entirely.
#
# RUN THIS ONLY AFTER verifying, from a separate terminal:
#     ssh <new-user>@<server>     works with your key
#     sudo whoami                  returns 'root' (sudo works)
#     docker --version             prints a version
#
# If any of those fail, fix it before running this — you will lock
# yourself out otherwise. Recovery requires the cloud provider's
# console (e.g. Vultr web console) and a password on the user account
# (`sudo passwd <user>` from a working session — do this before you
# need it).

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "lockdown.sh: must be run as root (try: sudo $0)" >&2
    exit 1
fi

# cloud-init drops /etc/ssh/sshd_config.d/50-cloud-init.conf with
# `PasswordAuthentication yes`. Alphabetically 50 < 99, so it would
# override our hardening file. Remove it so our settings actually win.
rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf

cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
EOF

# Validate the new config before reloading — if it is broken, sshd
# stays up on the old config and your current session is safe.
sshd -t
systemctl reload ssh

echo "=== root SSH and password auth disabled ==="
echo "Log in only as the non-root user you created in bootstrap.sh."
