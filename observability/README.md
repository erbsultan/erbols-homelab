# observability

✨ Monitoring and log collection for the homelab.

This project watches the Vultr VPS that serves
[`erbsultan.uz`](https://erbsultan.uz) and exposes one public UI:
[`grafana.erbsultan.uz`](https://grafana.erbsultan.uz).

> Russian version: [README_rus.md](./README_rus.md)

## Status

| Layer | Tool | State |
|-------|------|-------|
| 📊 Metrics UI | Grafana | ✅ Live on `https://grafana.erbsultan.uz` |
| 📈 Metrics store | Prometheus | ✅ Private on `127.0.0.1:9090` |
| 🖥️ VPS metrics | node_exporter | ✅ Scraped by Prometheus |
| 🪵 Logs store | Loki | ✅ Private on `127.0.0.1:3100` |
| 🚚 Logs shipper | Alloy | ✅ Tails nginx logs |
| 🔐 Public access | nginx + Let's Encrypt | ✅ HTTPS enabled |

## Architecture

```mermaid
flowchart TD
    browser["Browser"] -->|HTTPS| nginx["nginx<br/>grafana.erbsultan.uz"]
    nginx --> grafana["Grafana<br/>public UI"]

    node["VPS system<br/>CPU, RAM, disk, network"] --> exporter["node_exporter"]
    exporter --> prometheus["Prometheus<br/>private"]
    prometheus --> grafana

    logs["nginx logs<br/>/var/log/nginx/*.log"] --> alloy["Alloy"]
    alloy --> loki["Loki<br/>private"]
    loki --> grafana
```

## What Works

- ✅ Grafana opens over HTTPS at `grafana.erbsultan.uz`
- ✅ Prometheus scrapes itself and `node_exporter`
- ✅ `Node Exporter Full` dashboard is imported from dashboard ID `1860`
- ✅ Loki is connected as a Grafana data source
- ✅ Grafana Explore returns nginx logs with `{job="nginx"}`
- ✅ Prometheus, Loki, and Alloy UI stay private on localhost

## Screenshots

<p>
  <img src="docs/img/01-grafana-node-exporter-dashboard.png" alt="Grafana Node Exporter dashboard" width="49%">
  <img src="docs/img/02-grafana-loki-nginx-logs.png" alt="Grafana Explore with nginx logs from Loki" width="49%">
</p>

<p>
  <sub>Left: live VPS metrics from node_exporter. Right: nginx logs flowing through Alloy into Loki.</sub>
</p>

## Components

| Component | Purpose | Address |
|-----------|---------|---------|
| Grafana | Dashboards and Explore UI | `https://grafana.erbsultan.uz` |
| Prometheus | Metrics storage and queries | `http://127.0.0.1:9090` |
| node_exporter | VPS system metrics | Docker network only |
| Loki | Log storage and LogQL queries | `http://127.0.0.1:3100` |
| Alloy | Reads nginx logs and sends them to Loki | `http://127.0.0.1:12345` |

## Useful Checks

```bash
docker ps
curl http://127.0.0.1:9090/-/ready
curl http://127.0.0.1:3100/ready
curl -I http://127.0.0.1:12345
```

Prometheus targets:

```bash
curl -s http://127.0.0.1:9090/api/v1/targets \
  | jq '.data.activeTargets[] | {job: .labels.job, health: .health, scrapeUrl: .scrapeUrl}'
```

Loki query in Grafana Explore:

```logql
{job="nginx"}
```

## Files

```text
observability/
├── compose.yml                       # Grafana, Prometheus, node_exporter, Loki, Alloy
├── .env.example                      # example Grafana admin variables
├── prometheus/
│   └── prometheus.yml                # scrape config
├── loki/
│   └── loki-config.yaml              # single-node Loki config
├── alloy/
│   └── config.alloy                  # nginx log collection
└── nginx/
    └── grafana.erbsultan.uz.conf     # reverse proxy before certbot edits
```

The real `.env` lives only on the VPS:

```text
/opt/erbols-homelab/observability/.env
```

It is intentionally not committed.

## Security Posture

Grafana is the only public observability entrypoint. Everything else is
bound to localhost or kept inside the Docker network.

| Service | Public? | Why |
|---------|---------|-----|
| Grafana | ✅ Yes | Human-facing dashboard UI |
| Prometheus | ❌ No | Internal metrics API |
| Loki | ❌ No | Internal logs API |
| Alloy UI | ❌ No | Local debugging only |
| node_exporter | ❌ No | Internal scrape target |

## Build Log

| Step | Result |
|------|--------|
| DNS | ✅ `grafana.erbsultan.uz -> 108.61.211.82` |
| VPS baseline | ✅ `homelab-fra-01`, nginx OK, Docker ready |
| Grafana | ✅ container running behind nginx + HTTPS |
| Prometheus | ✅ targets `prometheus` and `node` are `up` |
| Dashboard | ✅ `Node Exporter Full` imported |
| Loki | ✅ returns `ready` |
| Alloy | ✅ tails `/var/log/nginx/*.log` |
| Logs | ✅ `{job="nginx"}` returns nginx entries |

## Next

- 🚨 Add basic Grafana alerts for disk usage, high load, and service down
- 📬 Send alerts to Telegram or email
- 🧭 Add an nginx access-log dashboard
- 🔐 Later: move Grafana behind OpenVPN when the VPN project exists
