# Observability-lab
🔭 obs-lab
A full-stack DevOps observability lab — built from scratch on Ubuntu 24.04, running entirely in Docker.

## Overview

This lab covers the **three pillars of modern observability** — Metrics, Logs, and Traces — by running production-grade tools locally against a live instrumented application.

Each phase is self-contained, builds on the previous one, and produces real dashboards, real alerts, and real pipelines — not toy examples.

---

## 📍 Roadmap

| Phase | Tools |
|-------|-------|
| ⬜ Phase 1 | Prometheus · Grafana · Alertmanager |
| ⬜ Phase 2 | Elasticsearch · Kibana · Filebeat · Logstash |
| ⬜ Phase 3 | Jaeger · OpenTelemetry |
| ⬜ Phase 4 | Kubernetes · Prometheus Operator |
| ⬜ Phase 5 | Nagios Core |

---

## 🏗️ Architecture

<img width="695" height="842" alt="image" src="https://github.com/user-attachments/assets/1431d7a1-2fed-46c3-b681-3e6f6848245b" />

---

## 🚀 Quick Start

### Prerequisites

- Ubuntu 24.04 LTS (8GB RAM · 6 CPU cores recommended)
- Docker + Docker Compose
- Git

### Phase 1 — Prometheus + Grafana

```bash
git clone https://github.com/4-sai/obs-lab.git
cd obs-lab
chmod +x obs-lab.sh scripts/*.sh
./obs-lab.sh up
```

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | `admin / admin123` |
| Prometheus | http://localhost:9090 | — |
| Alertmanager | http://localhost:9093 | — |
| Demo App | http://localhost:5000 | — |
| Node Exporter | http://localhost:9100/metrics | — |

### Phase 2 — ELK Stack

> Phase 1 must be running first — ELK shares the same Docker network.

```bash
# One-time host requirement for Elasticsearch
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf

chmod +x elk.sh
./elk.sh up
./elk.sh health        # wait for green
./elk.sh setup-kibana  # create index patterns
```

| Service | URL | Credentials |
|---------|-----|-------------|
| Kibana | http://localhost:5601 | `elastic / elastic123` |
| Elasticsearch | http://localhost:9200 | `elastic / elastic123` |
| Logstash API | http://localhost:9600 | — |

---

## 📁 Project Structure

```
obs-lab/
├── docker-compose.yml              # Phase 1 — Prometheus + Grafana
├── docker-compose.elk.yml          # Phase 2 — ELK Stack
├── obs-lab.sh                      # Phase 1 management script
├── elk.sh                          # Phase 2 management script
│
├── demo-app/
│   ├── app.py                      # Flask app — metrics, JSON logs, trace IDs
│   └── Dockerfile
│
├── prometheus/
│   ├── prometheus.yml              # Scrape configs
│   └── rules/
│       ├── alerts.yml              # Alert rules: host, app, blackbox
│       └── recording.yml          # Pre-computed recording rules
│
├── grafana/
│   └── provisioning/
│       ├── datasources/            # Auto-provisioned Prometheus datasource
│       └── dashboards/             # Dashboard provisioning config
│
├── alertmanager/
│   └── alertmanager.yml            # Routing tree + Slack receivers
│
├── elk/
│   ├── filebeat/
│   │   └── filebeat.yml            # Collects Docker + system logs
│   └── logstash/
│       ├── pipeline/main.conf      # Parse, enrich, and route pipeline
│       └── config/logstash.yml
│
├── scripts/
│   ├── generate-traffic.sh         # Sends realistic traffic to demo-app
│   └── stress-test.sh              # Triggers alert conditions for practice
│
├── jaeger/                         # Phase 3 — coming soon
├── k8s/                            # Phase 4 — coming soon
└── nagios/                         # Phase 5 — coming soon
```

---

## 🛠️ Management Scripts

### `obs-lab.sh` — Phase 1

```bash
./obs-lab.sh up                   # Start the full stack
./obs-lab.sh down                 # Stop the stack
./obs-lab.sh status               # Container status
./obs-lab.sh logs [service]       # Tail logs
./obs-lab.sh reload               # Hot-reload Prometheus config
./obs-lab.sh targets              # Show all Prometheus scrape targets
./obs-lab.sh mem                  # Memory usage per container
./obs-lab.sh promql 'up'          # Run a PromQL query from terminal
```

### `elk.sh` — Phase 2

```bash
./elk.sh up                       # Start ELK stack
./elk.sh down                     # Stop ELK stack
./elk.sh health                   # Cluster health + index list
./elk.sh logs [service]           # Tail logs
./elk.sh search 'error'           # Search logs from terminal
./elk.sh setup-kibana             # Create Kibana data views
./elk.sh test-log                 # Send a test log event
```

### `scripts/`

```bash
./scripts/generate-traffic.sh 10  # Send 10 req/s to demo-app
./scripts/stress-test.sh          # Interactive menu to trigger alerts
```

---

## 🔔 Alert Rules

Defined in `prometheus/rules/alerts.yml`:

| Alert | Condition | Severity |
|-------|-----------|----------|
| `AppHighErrorRate` | HTTP 5xx rate > 5% for 5m | 🔴 critical |
| `AppHighLatencyP99` | P99 latency > 2s for 10m | 🟡 warning |
| `AppDown` | App unreachable for 1m | 🔴 critical |
| `HostHighCpuLoad` | CPU > 80% for 5m | 🟡 warning |
| `HostOutOfMemory` | Free memory < 15% for 5m | 🔴 critical |
| `HostDiskSpaceLow` | Disk < 20% for 5m | 🟡 warning |
| `EndpointDown` | HTTP probe failed for 2m | 🔴 critical |
| `EndpointSlowResponse` | Response time > 3s for 5m | 🟡 warning |

---

## 🧩 Demo App

A Flask service that generates realistic observability data across all three pillars.

| Endpoint | Behaviour |
|----------|-----------|
| `GET /api/fast` | ~10ms — simulates a cache hit |
| `GET /api/slow` | 200–800ms — simulates a slow DB query |
| `GET /api/error` | Returns HTTP 500 ~20% of the time |
| `POST /api/orders` | Orders across 5 products × 5 Indian regions |
| `GET /metrics` | Prometheus scrape endpoint |
| `GET /health` | Health check |

Every request emits a structured JSON log containing `trace_id`, `method`, `path`, `status`, and `duration_ms` — enabling correlation across Grafana, Kibana, and Jaeger from day one.

---

## 🧪 Exercises

### Phase 1 — Prometheus + Grafana
- [x] RED method dashboard built from scratch (Rate · Errors · Duration)
- [x] Node Exporter Full dashboard imported and working
- [x] `AppHighErrorRate` alert fired end-to-end — Inactive → Pending → Firing
- [x] Prometheus alert lifecycle understood (`for:` duration, pending → firing → resolved)

### Phase 2 — ELK Stack
- [x] Elasticsearch running, logs flowing from all containers via Filebeat
- [x] Demo app emitting structured JSON with `trace_id` on every request
- [x] Kibana Discover — search and filter by `trace_id` · `level` · `service`
- [x] Build Kibana dashboard for error rate from log data
- [ ] Correlate a Grafana metric spike with its Kibana log events

### Phase 3 — Jaeger + OpenTelemetry *(planned)*
- [x] Instrument demo-app with OpenTelemetry SDK
- [x] View distributed traces in Jaeger UI
- [x] Link trace IDs across Grafana + Kibana + Jaeger

### Phase 4 — Kubernetes *(planned)*
- [x] Deploy demo-app as a Kubernetes Deployment
- [x] kube-prometheus-stack via Helm
- [x] Kubernetes dashboards in Grafana

### Phase 5 — Nagios *(planned)*
- [x] Host and service checks via NRPE
- [x] Custom check plugin for demo-app
- [x] Compare check-based vs scrape-based monitoring

---
