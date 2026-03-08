#!/usr/bin/env bash
set -e
COMPOSE="docker compose"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}▶  $1${NC}\n"; }
ok()     { echo -e "${GREEN}✔  $1${NC}"; }
warn()   { echo -e "${YELLOW}⚠  $1${NC}"; }
info()   { echo -e "${BLUE}ℹ  $1${NC}"; }

cmd_up() {
    header "Starting obs-lab stack"
    cd "$PROJECT_DIR"
    $COMPOSE up -d --build
    sleep 3
    cmd_status
    echo ""
    info "Grafana      → http://localhost:3000  (admin / admin123)"
    info "Prometheus   → http://localhost:9090"
    info "Alertmanager → http://localhost:9093"
    info "Demo App     → http://localhost:5000"
    info "cAdvisor     → http://localhost:8080"
    info "Node Exporter→ http://localhost:9100/metrics"
}
cmd_down()    { header "Stopping"; cd "$PROJECT_DIR"; $COMPOSE down; ok "Stopped"; }
cmd_status()  { header "Container status"; cd "$PROJECT_DIR"; $COMPOSE ps; }
cmd_logs()    { header "Logs: ${1:-all}"; cd "$PROJECT_DIR"; $COMPOSE logs -f --tail=50 ${1:-}; }
cmd_reload()  { header "Reloading Prometheus"; curl -s -X POST http://localhost:9090/-/reload && ok "Reloaded" || warn "Failed"; }
cmd_mem()     { header "Memory usage"; docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}"; }
cmd_targets() {
    header "Prometheus targets"
    curl -s http://localhost:9090/api/v1/targets | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d['data']['activeTargets']:
    s='✔' if t['health']=='up' else '✘'
    print(f\"{s}  {t['labels'].get('job','?'):25s} {t['health']}\")
" 2>/dev/null || warn "Prometheus not reachable"
}
cmd_promql() {
    local q="${1:-up}"
    header "PromQL: $q"
    curl -s "http://localhost:9090/api/v1/query?query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$q'))")" \
        | python3 -m json.tool 2>/dev/null || warn "Prometheus not reachable"
}

case "${1:-help}" in
    up)      cmd_up ;;
    down)    cmd_down ;;
    status)  cmd_status ;;
    logs)    cmd_logs "$2" ;;
    reload)  cmd_reload ;;
    mem)     cmd_mem ;;
    targets) cmd_targets ;;
    promql)  cmd_promql "$2" ;;
    *)
        echo -e "${BOLD}obs-lab.sh — Phase 1 Management${NC}"
        echo ""
        echo -e "  ${CYAN}./obs-lab.sh up/down/status/logs/reload/mem/targets${NC}"
        echo -e "  ${CYAN}./obs-lab.sh promql 'rate(http_requests_total[5m])'${NC}"
        ;;
esac
