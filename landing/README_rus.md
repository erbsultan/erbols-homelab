# landing — erbsultan.uz

![](docs/img/00-hero.png)

Парадный вход homelab. Статичная страница на захардненной Ubuntu 24.04
VPS, отдаётся по HTTPS на **[erbsultan.uz](https://erbsultan.uz)**.

Сама страница нарочно минималистичная — самое интересное в том, что её
держит.

> English version: [README.md](./README.md) · Воспроизвести деплой: [PROVISION_rus.md](./PROVISION_rus.md)

## Архитектура

```
       eskiz DNS
           │
           │  A erbsultan.uz  →  108.61.211.82
           ▼
   ┌─────────────────────────────────────────┐
   │  Vultr · Frankfurt · homelab-fra-01     │
   │  Ubuntu 24.04 LTS                       │
   │                                         │
   │    ufw      →  только 22 / 80 / 443     │
   │    fail2ban →  следит за sshd-jail      │
   │                                         │
   │    nginx :443  ──▶  /var/www/.../html   │
   │                          └ index.html   │
   │                                         │
   │    TLS:  Let's Encrypt (90 д auto-renew)│
   └─────────────────────────────────────────┘
           ▲
           │  HTTPS
           │
       браузер
```

## Стек

- **Vultr** Cloud Compute, Frankfurt — `homelab-fra-01`, 2 vCPU / 2 GB / 60 GB
- **Ubuntu 24.04 LTS** — захардено: `ufw`, `fail2ban`, `unattended-upgrades`, SSH только по ключу
- **Nginx 1.24** — статика, редирект HTTP → HTTPS
- **Let's Encrypt** — `certbot --nginx`, auto-renew через systemd timer
- **eskiz.uz** — DNS для `erbsultan.uz` (пока только A-запись, без CDN)
- **Duck DNS** — `erbsultan.duckdns.org` оставлен как резервная A-запись

## Walkthrough

### 1. Коробка

Маленькая Vultr-ка во Франкфурте. AMD shared CPU, 2 vCPU / 2 GB,
IPv4 + IPv6, SSH-ключ прикручен в момент деплоя — поэтому у коробки
никогда не было root-пароля, который Vultr мог бы прислать на почту
и засветить.

![Vultr-инстанс в Running](docs/img/01-vultr-instance.png)

Самый дешёвый тариф с IPv4 хватает с головой — остальной стек масштабом
не парится, а апгрейд на Vultr — одно нажатие.

### 2. SSH-ключ

Отдельная `ed25519`-пара специально под homelab, отдельная от той, что
пушит в GitHub. Меньше blast-radius, если что-то когда-нибудь утечёт.

```bash
ssh-keygen -t ed25519 -C "homelab@erbsultan" -f ~/.ssh/homelab_ed25519
```

Публичную половину кладём в Vultr → Account → SSH Keys **до** деплоя
инстанса, чтобы она автоматически попала в `/root/.ssh/authorized_keys`.

### 3. Bootstrap

[`bootstrap/bootstrap.sh`](bootstrap/bootstrap.sh) — один прогон, под
root, на свежем сервере. Создаёт не-root юзера (`erbol`) с sudo,
копирует ему ключ, ставит `ufw` / `fail2ban` / `unattended-upgrades` /
Docker, открывает наружу только 22 / 80 / 443.

![Хвост bootstrap.sh](docs/img/02-bootstrap-done.png)

Он намеренно **не трогает root-SSH** — это задача `lockdown.sh`. Сплит
сделан не от хорошей жизни: если с новым юзером что-то пошло не так,
нужно чтобы root оставался как канал восстановления.

### 4. Lockdown

Только после того, как **во втором терминале** проверили, что новый
юзер заходит и sudo работает:

```
ssh erbol@<ip>     # коннектится
sudo whoami        # → root
docker --version   # → Docker version X.Y.Z
```

…запустил [`bootstrap/lockdown.sh`](bootstrap/lockdown.sh) — он отрубает
root-SSH и парольный логин совсем.

Гоча, которую поймал по дороге: Ubuntu-овский cloud-init дропает
`/etc/ssh/sshd_config.d/50-cloud-init.conf` с `PasswordAuthentication yes`.
По алфавиту `50` < `99`, поэтому он переопределяет наш hardening-файл
(sshd берёт **первое** объявление каждой директивы). `lockdown.sh`
сносит этот cloud-init-файл перед тем, как писать свой.

В итоге:

![ufw + fail2ban active](docs/img/03-ufw-fail2ban.png)

Перед lockdown я ещё поставил пароль на `erbol` через `sudo passwd erbol`.
SSH всё равно принимает только ключи — пароль чисто для Vultr web-консоли,
на случай если я случайно закроюсь снаружи и придётся восстанавливаться
через out-of-band-канал провайдера.

### 5. DNS

`erbsultan.uz` зарегистрирован через [eskiz.uz](https://eskiz.uz), там же
живёт DNS — простая A-запись на IP VPS плюс CNAME для `www`. Cloudflare
сейчас не подключён; это итерация на будущее, если понадобится wildcard
или edge-защита.

![DNS-панель eskiz](docs/img/04-eskiz-dns.png)

`erbsultan.duckdns.org` тоже указывает на этот же IP через Duck DNS —
бесплатный fallback, второе резолвящееся имя на случай DNS-проблем
у eskiz.

### 6. Nginx + Let's Encrypt

Сначала чистый HTTP server-блок ([`nginx/erbsultan.uz.conf`](nginx/erbsultan.uz.conf)),
слушает `:80`, `server_name erbsultan.uz www.erbsultan.uz`, root —
`/var/www/erbsultan.uz/html`. Как только `curl -I http://erbsultan.uz`
вернул `200 OK`, отдаём управление certbot:

```bash
sudo certbot --nginx -d erbsultan.uz -d www.erbsultan.uz
```

HTTP-01 challenge идёт через живой nginx (Let's Encrypt стучится на
`/.well-known/acme-challenge/...`), certbot патчит тот же конфиг прямо
на месте — дописывает `:443` server-блок, пути к сертификатам и
редирект `301 → https` с порта 80.

![Удача certbot](docs/img/05-certbot-success.png)

Сертификат от Let's Encrypt, живёт 90 дней. Certbot прописал systemd
timer, который запускает `certbot renew` дважды в сутки; обновление
проходит тихо, когда сертификат переваливает середину срока.

![Детали сертификата](docs/img/06-cert-details.png)

### 7. CI/CD

Маленький GitHub Actions воркфлоу ([`.github/workflows/deploy-landing.yml`](../.github/workflows/deploy-landing.yml))
срабатывает на каждый push в `main`, который меняет `landing/site/**`,
и rsync-ит содержимое на сервер под отдельным deploy-юзером.

Правка `index.html` → `git push` → ~15 секунд → изменения уже на
`https://erbsultan.uz`. Никаких ручных `scp`.

Аутентификация — отдельная ed25519-пара (не личный SSH-ключ),
приватная часть в repo Secrets, публичная в `authorized_keys`
у `erbol`. Host fingerprint тоже хранится в Secret, чтобы runner
не доверял случайному хосту при каждом ране.

## Структура

```
landing/
├── bootstrap/
│   ├── bootstrap.sh   # провижн свежей Ubuntu 24.04 VPS
│   └── lockdown.sh    # выключает root-SSH и пароли
├── nginx/
│   └── erbsultan.uz.conf  # server-блок (HTTPS-половину certbot дописывает)
├── site/
│   └── index.html     # сама страница
└── docs/img/          # скриншоты walkthrough
```

В обоих скриптах сверху есть `CONFIG`-блок с единственными значениями,
которые имеет смысл крутить (`NEW_USER`, `TIMEZONE`) — кидаешь на любую
свежую Ubuntu, правишь две строки, запускаешь.

## Что дальше

- **Мониторинг** — Prometheus + Grafana + node_exporter на `grafana.erbsultan.uz`
- **WireGuard VPN** на отдельной коробке, чтобы внутренние сервисы вообще не торчали наружу
- **Cloudflare DNS** (может быть) — делегировать NS на CF ради wildcard-сертификатов и edge

Точные команды для воспроизведения на свежей коробке — в [PROVISION_rus.md](./PROVISION_rus.md).
