# Провижн свежей коробки

Справочник команд для приведения чистой Ubuntu 24.04 VPS в состояние,
описанное в [walkthrough](./README_rus.md). Гнать сверху вниз. Замени
плейсхолдеры (`<ip>`, `<your-key>`, `<your-domain>`) на свои.

Что нужно заранее:
- Свежая Ubuntu 24.04 VPS, публичный IPv4
- Твой SSH-публичный ключ уже лежит в `/root/.ssh/authorized_keys`
  (Vultr / DigitalOcean / Hetzner кладут его сами, если прицепил ключ
  в момент деплоя)
- DNS для `<your-domain>` и `www.<your-domain>` уже резолвится в IP VPS —
  проверь через `dig +short <your-domain>` перед шагом 5

---

## 1. Захардить коробку

```bash
scp -i ~/.ssh/<your-key> \
    bootstrap/bootstrap.sh bootstrap/lockdown.sh \
    root@<ip>:/root/

ssh -i ~/.ssh/<your-key> root@<ip> \
    'chmod +x bootstrap.sh lockdown.sh && ./bootstrap.sh'
```

`bootstrap.sh` идемпотентен и сам себя проверяет: отказывается работать
не под root и отказывается, если `/root/.ssh/authorized_keys` пуст
(иначе новый юзер останется без доступа).

Если нужен другой username или timezone — поправь `CONFIG`-блок наверху
`bootstrap.sh` перед прогоном.

## 2. Проверить нового юзера (ИЗ ВТОРОГО терминала)

```bash
ssh -i ~/.ssh/<your-key> erbol@<ip> 'sudo whoami && docker --version'
```

Ожидаем: `root` (sudo работает) и `Docker version X.Y.Z`.

Если оба прошли — закрываем root-дверь:

```bash
ssh -i ~/.ssh/<your-key> root@<ip> './lockdown.sh'
```

## 3. (Рекомендовано) Поставить пароль юзеру — для cloud-console recovery

```bash
ssh -i ~/.ssh/<your-key> erbol@<ip> 'sudo passwd erbol'
```

SSH всё равно принимает только ключи. Пароль — чисто escape-hatch для
web-консоли провайдера, если когда-нибудь закроешься снаружи.

## 4. Положить nginx-конфиг и страницу

```bash
scp -i ~/.ssh/<your-key> \
    nginx/erbsultan.uz.conf site/index.html \
    erbol@<ip>:/tmp/

ssh -i ~/.ssh/<your-key> erbol@<ip> "
  sudo mkdir -p /var/www/<your-domain>/html
  sudo mv /tmp/index.html /var/www/<your-domain>/html/
  sudo chown -R www-data:www-data /var/www/<your-domain>
  sudo mv /tmp/erbsultan.uz.conf /etc/nginx/sites-available/<your-domain>.conf
  sudo ln -sf /etc/nginx/sites-available/<your-domain>.conf \
              /etc/nginx/sites-enabled/<your-domain>.conf
  sudo rm -f /etc/nginx/sites-enabled/default
  sudo nginx -t && sudo systemctl reload nginx
"
```

Обнови `server_name` внутри conf-файла под свой домен перед `scp` (или
правь на месте через `sed` на сервере).

## 5. TLS

```bash
ssh -i ~/.ssh/<your-key> erbol@<ip> \
    "sudo certbot --nginx -d <your-domain> -d www.<your-domain>"
```

Certbot задаст:
- **email** — для уведомлений о продлении
- **agree to ToS** — `Y`
- **share with EFF** — `N` (по вкусу)
- **redirect HTTP → HTTPS** — `2` (recommended)

После этого certbot правит nginx-конфиг на месте — добавляет `:443`
server-блок и редирект, делает reload. Сертификат живёт в
`/etc/letsencrypt/live/<your-domain>/`.

## Продление

Certbot прописал systemd timer, который продлевает автоматически:

```bash
sudo systemctl list-timers certbot.timer
sudo certbot renew --dry-run
```
