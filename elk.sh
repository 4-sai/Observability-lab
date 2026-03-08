
#!/usr/bin/env bash
# ============================================================
#  elk.sh  —  ELK Stack management
#  Usage: ./elk.sh [up|down|status|logs|health|search|setup-kibana|test-log]
# ============================================================

set -e
COMPOSE="docker compose -f docker-compose.elk.yml"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}▶  $1${NC}\n"; }
ok()     { echo -e "${GREEN}✔  $1${NC}"; }
warn()   { echo -e "${YELLOW}⚠  $1${NC}"; }

cmd_up() {
    header "Starting ELK stack"
    CURRENT=$(sysctl -n vm.max_map_count)
    if [ "$CURRENT" -lt 262144 ]; then
        warn "Setting vm.max_map_count=262144 (required by Elasticsearch)"
        sudo sysctl -w vm.max_map_count=262144
    fi
    $COMPOSE up -d
    echo ""
    warn "Elasticsearch takes 60-90 seconds to start. Run './elk.sh health' to check."
    echo ""
    echo "  Kibana        → http://localhost:5601  (elastic / elastic123)"
    echo "  Elasticsearch → http://localhost:9200"
    echo "  Logstash API  → http://localhost:9600"
}

cmd_down() {
    header "Stopping ELK stack"
    $COMPOSE down
    ok "ELK stopped (data preserved in volumes)"
}

cmd_status() {
    header "ELK container status"
    $COMPOSE ps
}

cmd_logs() {
    header "Logs: ${1:-all}"
    $COMPOSE logs -f --tail=40 ${1:-}
}

cmd_health() {
    header "Elasticsearch cluster health"
    curl -s -u elastic:elastic123 http://localhost:9200/_cluster/health \
        | python3 -m json.tool 2>/dev/null || warn "Elasticsearch not ready yet"
    echo ""
    header "Indices"
    curl -s -u elastic:elastic123 \
        "http://localhost:9200/_cat/indices?v&h=index,docs.count,store.size,health" \
        2>/dev/null || warn "No indices yet"
}

cmd_search() {
    local QUERY="${1:-*}"
    local INDEX="${2:-obs-lab-logs-*}"
    header "Searching '$QUERY' in $INDEX"
    curl -s -u elastic:elastic123 \
        -H "Content-Type: application/json" \
        "http://localhost:9200/$INDEX/_search" \
        -d "{
          \"query\": { \"query_string\": { \"query\": \"$QUERY\" } },
          \"size\": 5,
          \"sort\": [{\"@timestamp\": \"desc\"}]
        }" | python3 -c "
import json,sys
d = json.load(sys.stdin)
hits = d.get('hits',{}).get('hits',[])
print(f'Total hits: {d[\"hits\"][\"total\"][\"value\"]}')
print()
for h in hits:
    src = h['_source']
    ts  = src.get('@timestamp','?')[:19]
    msg = src.get('message', src.get('log_message','?'))[:100]
    svc = src.get('container',{}).get('name', src.get('service','?'))
    print(f'[{ts}] {svc:20s} {msg}')
" 2>/dev/null || warn "Search failed — is Elasticsearch running?"
}

cmd_setup_kibana() {
    header "Setting up Kibana data views"
    echo "Waiting for Kibana..."
    until curl -s -u elastic:elastic123 http://localhost:5601/api/status \
          | grep -q "available"; do
        sleep 5; echo -n "."
    done
    echo ""
    for PATTERN in "obs-lab-logs-*" "demo-app-logs-*" "system-logs-*"; do
        curl -s -u elastic:elastic123 \
            -H "Content-Type: application/json" \
            -H "kbn-xsrf: true" \
            -X POST "http://localhost:5601/api/data_views/data_view" \
            -d "{\"data_view\":{\"title\":\"$PATTERN\",\"timeFieldName\":\"@timestamp\"}}" \
            > /dev/null
        ok "Created data view: $PATTERN"
    done
}

cmd_send_test_log() {
    header "Sending test log to Logstash"
    echo '{"level":"ERROR","msg":"Test error from elk.sh","service":"test","trace_id":"abc123"}' \
        | nc -q1 localhost 5001
    ok "Sent. Check Kibana in ~30 seconds"
}

case "${1:-help}" in
    up)           cmd_up ;;
    down)         cmd_down ;;
    status)       cmd_status ;;
    logs)         cmd_logs "$2" ;;
    health)       cmd_health ;;
    search)       cmd_search "$2" "$3" ;;
    setup-kibana) cmd_setup_kibana ;;
    test-log)     cmd_send_test_log ;;
    *)
        echo -e "${BOLD}elk.sh — ELK Stack Management${NC}"
        echo ""
        echo -e "  ${CYAN}./elk.sh up${NC}                Start ELK stack"
        echo -e "  ${CYAN}./elk.sh down${NC}              Stop ELK stack"
        echo -e "  ${CYAN}./elk.sh status${NC}            Container status"
        echo -e "  ${CYAN}./elk.sh health${NC}            Elasticsearch health + indices"
        echo -e "  ${CYAN}./elk.sh logs [service]${NC}    Tail logs"
        echo -e "  ${CYAN}./elk.sh search 'error'${NC}    Search logs from terminal"
        echo -e "  ${CYAN}./elk.sh setup-kibana${NC}      Create Kibana data views"
        echo -e "  ${CYAN}./elk.sh test-log${NC}          Send a test log event"
        ;;
esac
