# Provisioning a fresh box

Reference commands for bringing a clean Ubuntu 24.04 VPS to the state
described in the [walkthrough](./README.md). Run top to bottom. Replace
the placeholders (`<ip>`, `<your-key>`, `<your-domain>`) with your own.

Prereqs:
- A fresh Ubuntu 24.04 VPS, public IPv4
- Your SSH public key pre-loaded into `/root/.ssh/authorized_keys`
  (Vultr / DigitalOcean / Hetzner do this automatically when you attach
  a key at deploy time)
- DNS for `<your-domain>` and `www.<your-domain>` already pointing at
  the VPS IP — verify with `dig +short <your-domain>` before step 5

---

## 1. Harden the box

```bash
scp -i ~/.ssh/<your-key> \
    bootstrap/bootstrap.sh bootstrap/lockdown.sh \
    root@<ip>:/root/

ssh -i ~/.ssh/<your-key> root@<ip> \
    'chmod +x bootstrap.sh lockdown.sh && ./bootstrap.sh'
```

`bootstrap.sh` is idempotent and self-checking: it refuses to run if
you're not root, and refuses if `/root/.ssh/authorized_keys` is empty
(otherwise the new user would be unreachable).

Edit the `CONFIG` block at the top of `bootstrap.sh` first if you want
a different username or timezone.

## 2. Verify the new user (from a SEPARATE terminal)

```bash
ssh -i ~/.ssh/<your-key> erbol@<ip> 'sudo whoami && docker --version'
```

Expected: `root` (sudo works) and `Docker version X.Y.Z`.

If both pass — close the root door:

```bash
ssh -i ~/.ssh/<your-key> root@<ip> './lockdown.sh'
```

## 3. (Recommended) Set a password on the user — for cloud-console recovery

```bash
ssh -i ~/.ssh/<your-key> erbol@<ip> 'sudo passwd erbol'
```

SSH still accepts keys only. The password is purely an escape hatch for
the cloud provider's web console, if you ever lock yourself out.

## 4. Drop the nginx config + page

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

Update `server_name` inside the conf file to match your domain before
scp'ing (or `sed` it in-place on the server).

## 5. TLS

```bash
ssh -i ~/.ssh/<your-key> erbol@<ip> \
    "sudo certbot --nginx -d <your-domain> -d www.<your-domain>"
```

certbot prompts:
- **email** — for renewal warnings
- **agree to ToS** — `Y`
- **share with EFF** — `N` (your call)
- **redirect HTTP → HTTPS** — `2` (recommended)

After this, certbot edits the nginx conf in place to add the `:443`
server block and the redirect, then reloads. Cert lives at
`/etc/letsencrypt/live/<your-domain>/`.

## Renewal

Certbot installs a systemd timer that renews automatically:

```bash
sudo systemctl list-timers certbot.timer
sudo certbot renew --dry-run
```
