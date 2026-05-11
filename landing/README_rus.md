# landing — erbsultan.uz

Парадный вход homelab. Статичная landing-страница на захардненной
Ubuntu 24.04 VPS, отдаётся по HTTPS на **[erbsultan.uz](https://erbsultan.uz)**.

> English version: [README.md](./README.md)

## Стек

- **Vultr** Cloud Compute (Frankfurt) — `homelab-fra-01`, 2 vCPU / 2 GB / 60 GB
- **Ubuntu 24.04 LTS** — захардено: `ufw`, `fail2ban`, `unattended-upgrades`, SSH только по ключу
- **Nginx 1.24** — статика, редирект HTTP → HTTPS (его добавил certbot)
- **Let's Encrypt** — сертификат через `certbot --nginx`, авто-продление через systemd timer
- **Duck DNS** — `erbsultan.duckdns.org` оставлен как резервная A-запись

## Структура

```
landing/
├── bootstrap/
│   ├── bootstrap.sh   # одноразовый провижн свежей Ubuntu 24.04 VPS
│   └── lockdown.sh    # вырубает root-SSH и пароли (запускать ПОСЛЕ проверки юзера)
├── nginx/
│   └── erbsultan.uz.conf  # server-блок (HTTPS-половину certbot дописывает сам)
└── site/
    └── index.html     # сама страница
```

## Что живёт на сервере

- юзер `erbol` без пароля, с passwordless sudo, в группе `docker`
- root по SSH и парольный логин выключены
- `ufw`: входящее запрещено, исходящее разрешено; открыты только `22`, `80`, `443`
- `fail2ban` смотрит дефолтный sshd-jail
- Docker Engine + плагин Compose (из официального docker-репо)
- Nginx отдаёт `/var/www/erbsultan.uz/html`
- сертификат Let's Encrypt в `/etc/letsencrypt/live/erbsultan.uz/`

## Первичный деплой (вручную, один раз)

```bash
# 1. хардим коробку
scp bootstrap/bootstrap.sh bootstrap/lockdown.sh root@<ip>:/root/
ssh root@<ip> 'chmod +x bootstrap.sh lockdown.sh && ./bootstrap.sh'
# из второго терминала проверяем, что новый юзер работает:
#   ssh erbol@<ip> 'sudo whoami && docker --version'
# только потом закрываем root:
ssh root@<ip> './lockdown.sh'

# 2. nginx-конфиг + контент
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

Дальше обновления страницы будут приезжать через GitHub Actions — воркфлоу
лежит в `.github/workflows/deploy.yml` (запланировано следующим шагом).
