# observability

Monitoring and log collection for the homelab.

This project will start small:

- Grafana as the only public UI, available at `grafana.erbsultan.uz`
- Prometheus for metrics
- Loki for logs
- node_exporter for VPS system metrics
- Alloy or Promtail for collecting nginx logs

DNS lives in eskiz.uz. The server runs on Vultr Cloud in Germany,
Frankfurt.

## Goal

The first milestone is to see the health of the existing VPS and the
`landing/` nginx service from Grafana.

## Boundary

This project belongs next to `landing/`, not inside it, because it is a
shared platform layer for the whole homelab.

`landing/` is one service. `observability/` watches the infrastructure
that can later host many services.

## First steps

1. Create the DNS record `grafana.erbsultan.uz` in eskiz.uz. Done:
   `A grafana.erbsultan.uz -> 108.61.211.82`, TTL 3600.
   Verified locally with `dig +short grafana.erbsultan.uz A`.
2. Check the current VPS baseline. Done:
   `hostname` is `homelab-fra-01`, no Docker containers are running, and
   `nginx -t` passes.
3. Create the remote working directory. Done:
   `/opt/erbols-homelab/observability` exists and is owned by
   `erbol:erbol`.
4. Check Docker on the VPS. Done:
   Docker `29.4.3`, Docker Compose `v5.1.3`.
5. Create the remote `.env` file for Grafana credentials. Done:
   `/opt/erbols-homelab/observability/.env` exists with `0600`
   permissions and is not committed to Git.
   Grafana expects `GF_SECURITY_ADMIN_USER` and
   `GF_SECURITY_ADMIN_PASSWORD`; the first run initially used the default
   `admin/admin`, then forced a password change in the UI.
6. Add the first Docker Compose service for Grafana. Done:
   `docker compose config` validates successfully. Grafana is bound to
   `127.0.0.1:3000`, so it is not exposed directly to the internet.
   Use the official OSS image repository `grafana/grafana`; Docker will
   pull it automatically on first start.
7. Start Grafana. Done:
   container `observability-grafana` is running from
   `grafana/grafana:12.2.1` on `127.0.0.1:3000`.
8. Check Grafana locally from the VPS. Done:
   `curl -I http://127.0.0.1:3000` returns `302 Found` to `/login`.
9. Add the nginx HTTP reverse proxy for `grafana.erbsultan.uz`. Done:
   `nginx -t` passes before reload.
10. Reload nginx and check the HTTP reverse proxy. Done:
   `curl -I http://grafana.erbsultan.uz` returns `302 Found` to `/login`.
11. Add HTTPS with certbot. Done:
    Let's Encrypt certificate is deployed for `grafana.erbsultan.uz`.
    `curl -I https://grafana.erbsultan.uz` returns `302 Found` to
    `/login`.
12. Log in to Grafana over HTTPS. Done:
    `https://grafana.erbsultan.uz` opens the Grafana home screen after
    the initial admin password change.
13. Add Prometheus, Loki, and exporters.
14. Keep Prometheus and Loki private.
