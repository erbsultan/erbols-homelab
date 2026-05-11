# landing — erbsultan.uz

The public front door of the homelab. Static landing page on a hardened
Ubuntu 24.04 VPS, served over HTTPS at **[erbsultan.uz](https://erbsultan.uz)**.

> Russian version: [README_rus.md](./README_rus.md)

## Stack

- **Vultr** Cloud Compute (Frankfurt) — `homelab-fra-01`, 2 vCPU / 2 GB / 60 GB
- **Ubuntu 24.04 LTS** — hardened: `ufw`, `fail2ban`, `unattended-upgrades`, key-only SSH
- **Nginx 1.24** — static host, HTTP → HTTPS redirect (added by certbot)
- **Let's Encrypt** — cert via `certbot --nginx`, auto-renew via systemd timer
- **Duck DNS** — `erbsultan.duckdns.org` kept as a fallback A-record

## Layout

```
landing/
├── bootstrap/
│   ├── bootstrap.sh   # one-shot provisioning for a fresh Ubuntu 24.04 VPS
│   └── lockdown.sh    # disables root SSH + password auth (run AFTER user works)
├── nginx/
│   └── erbsultan.uz.conf  # server block (certbot adds the HTTPS half in-place)
└── site/
    └── index.html     # the page itself
```

## What lives on the box

- non-root user `erbol` with passwordless sudo, in the `docker` group
- root SSH and password auth disabled
- `ufw` defaults: incoming deny, outgoing allow; opened only `22`, `80`, `443`
- `fail2ban` watching the sshd jail
- Docker Engine + Compose plugin (from the official Docker repo)
- Nginx serving `/var/www/erbsultan.uz/html`
- Let's Encrypt cert at `/etc/letsencrypt/live/erbsultan.uz/`

## First-time provision (manual, one-off)

```bash
# 1. harden the box
scp bootstrap/bootstrap.sh bootstrap/lockdown.sh root@<ip>:/root/
ssh root@<ip> 'chmod +x bootstrap.sh lockdown.sh && ./bootstrap.sh'
# verify SSH as the new user from a second terminal:
#   ssh erbol@<ip> 'sudo whoami && docker --version'
# only then lock the door:
ssh root@<ip> './lockdown.sh'

# 2. nginx config + content
scp nginx/erbsultan.uz.conf site/index.html erbol@<ip>:/tmp/
ssh erbol@<ip> '
  sudo mkdir -p /var/www/erbsultan.uz/html
  sudo mv /tmp/index.html /var/www/erbsultan.uz/html/
  sudo chown -R www-data:www-data /var/www/erbsultan.uz
  sudo mv /tmp/erbsultan.uz.conf /etc/nginx/sites-available/
  sudo ln -sf /etc/nginx/sites-available/erbsultan.uz.conf /etc/nginx/sites-enabled/
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo nginx -t && sudo systemctl reload nginx
'

# 3. TLS
ssh erbol@<ip> 'sudo certbot --nginx -d erbsultan.uz -d www.erbsultan.uz'
```

Incremental page updates will land via GitHub Actions — workflow lives at
`.github/workflows/deploy.yml` (planned next).
