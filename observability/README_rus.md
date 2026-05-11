# observability

Мониторинг и сбор логов для homelab.

Начинаем маленько:

- Grafana как единственный публичный интерфейс на `grafana.erbsultan.uz`
- Prometheus для метрик
- Loki для логов
- node_exporter для системных метрик VPS
- Alloy или Promtail для сбора nginx-логов

DNS находится в eskiz.uz. Сервер работает в Vultr Cloud, регион Germany,
Frankfurt.

## Цель

Первый milestone — увидеть состояние текущего VPS и nginx-сервиса из
`landing/` в Grafana.

## Граница проекта

Этот проект лежит рядом с `landing/`, а не внутри него, потому что это
общий инфраструктурный слой для всего homelab.

`landing/` — один сервис. `observability/` наблюдает за инфраструктурой,
на которой позже может жить много сервисов.

## Первые шаги

1. Создать DNS-запись `grafana.erbsultan.uz` в eskiz.uz. Готово:
   `A grafana.erbsultan.uz -> 108.61.211.82`, TTL 3600.
   Проверено локально через `dig +short grafana.erbsultan.uz A`.
2. Проверить текущий baseline VPS. Готово:
   `hostname` — `homelab-fra-01`, Docker-контейнеров нет, `nginx -t`
   проходит успешно.
3. Создать рабочую папку на сервере. Готово:
   `/opt/erbols-homelab/observability` существует и принадлежит
   `erbol:erbol`.
4. Проверить Docker на VPS. Готово:
   Docker `29.4.3`, Docker Compose `v5.1.3`.
5. Создать remote `.env` для логина и пароля Grafana. Готово:
   `/opt/erbols-homelab/observability/.env` существует с правами
   `0600` и не коммитится в Git.
   Grafana ожидает `GF_SECURITY_ADMIN_USER` и
   `GF_SECURITY_ADMIN_PASSWORD`; первый запуск сначала использовал
   дефолтные `admin/admin`, после чего UI заставил сменить пароль.
6. Добавить первый Docker Compose service для Grafana. Готово:
   `docker compose config` проходит успешно. Grafana привязана к
   `127.0.0.1:3000`, поэтому напрямую в интернет не торчит.
   Используем официальный OSS image repository `grafana/grafana`; Docker
   сам скачает его при первом запуске.
7. Запустить Grafana. Готово:
   контейнер `observability-grafana` работает из
   `grafana/grafana:12.2.1` на `127.0.0.1:3000`.
8. Проверить Grafana локально с VPS. Готово:
   `curl -I http://127.0.0.1:3000` возвращает `302 Found` на `/login`.
9. Добавить nginx HTTP reverse proxy для `grafana.erbsultan.uz`. Готово:
   `nginx -t` проходит успешно перед reload.
10. Перезагрузить nginx и проверить HTTP reverse proxy. Готово:
   `curl -I http://grafana.erbsultan.uz` возвращает `302 Found` на
   `/login`.
11. Добавить HTTPS через certbot. Готово:
    Let's Encrypt certificate выпущен для `grafana.erbsultan.uz`.
    `curl -I https://grafana.erbsultan.uz` возвращает `302 Found` на
    `/login`.
12. Зайти в Grafana по HTTPS. Готово:
    `https://grafana.erbsultan.uz` открывает Grafana home screen после
    первичной смены admin-пароля.
13. Добавить Prometheus config file. Готово:
    `/opt/erbols-homelab/observability/prometheus/prometheus.yml`
    существует на VPS.
14. Добавить services Prometheus и node_exporter. Готово:
    `docker compose config` проходит успешно. Prometheus привязан к
    `127.0.0.1:9090`, поэтому напрямую в интернет не торчит.
15. Запустить Prometheus и node_exporter. Готово:
    контейнеры `observability-prometheus` и
    `observability-node-exporter` работают. Prometheus опубликован на
    `127.0.0.1:9090`; node_exporter доступен только внутри Docker
    network.
16. Проверить здоровье Prometheus и node_exporter. Готово:
    Prometheus readiness возвращает `Prometheus Server is Ready.`;
    node_exporter отдаёт метрики внутри Docker network.
17. Проверить Prometheus scrape targets. Готово:
    Prometheus видит оба job здоровыми: `prometheus` — `up`, и `node`
    — `up` на `http://node_exporter:9100/metrics`.
18. Добавить Prometheus как Grafana data source. Готово:
    Grafana успешно опрашивает Prometheus на `http://prometheus:9090`.
19. Импортировать node_exporter dashboard. Готово:
    Grafana dashboard `Node Exporter Full` импортирован по dashboard ID
    `1860` и показывает CPU, memory, disk, network и uptime метрики VPS.
20. Добавить Loki config file. Готово:
    `/opt/erbols-homelab/observability/loki/loki-config.yaml`
    существует на VPS.
21. Добавить Alloy config file для nginx-логов. Готово:
    `/opt/erbols-homelab/observability/alloy/config.alloy` существует на
    VPS. Он читает `/var/log/nginx/*.log` и отправляет entries в Loki.
22. Добавить services Loki и Alloy. Готово:
    `docker compose config` проходит успешно. Loki привязан к
    `127.0.0.1:3100`; Alloy UI привязан к `127.0.0.1:12345`.
23. Запустить Loki и Alloy. Готово:
    контейнеры `observability-loki` и `observability-alloy` работают.
    Loki опубликован на `127.0.0.1:3100`; Alloy UI опубликован на
    `127.0.0.1:12345`.
24. Проверить здоровье Loki и Alloy. Готово:
    Loki возвращает `ready`; Alloy UI возвращает `200 OK`; Alloy читает
    nginx access и error logs из `/var/log/nginx/*.log`.
25. Добавить Loki как Grafana data source. Готово:
    Grafana успешно подключается к Loki на `http://loki:3100`.
26. Запросить nginx-логи в Grafana Explore. Готово:
    `{job="nginx"}` возвращает nginx access logs с labels
    `instance=homelab-fra-01`, `job=nginx` и `service=nginx`.
27. Оставить Prometheus и Loki приватными. Готово:
    Prometheus, Loki и Alloy UI привязаны только к `127.0.0.1`; Grafana
    — единственный публичный observability UI.
