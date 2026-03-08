
#!/usr/bin/env bash
# Usage: ./scripts/generate-traffic.sh [req_per_second]
BASE="http://localhost:5000"
RATE="${1:-1}"
echo "Traffic generator: ${RATE} req/s → $BASE  (Ctrl+C to stop)"
PRODUCTS=("shirt" "shoes" "hat" "bag" "watch")
REGIONS=("mumbai" "delhi" "bangalore" "pune" "hyderabad")
i=0
while true; do
    i=$((i + 1))
    R=$((RANDOM % 10))
    if   [ $R -lt 5 ]; then
        curl -s "$BASE/api/fast" > /dev/null
        echo -ne "\r  req #$i → /api/fast    "
    elif [ $R -lt 7 ]; then
        curl -s "$BASE/api/slow" > /dev/null
        echo -ne "\r  req #$i → /api/slow    "
    elif [ $R -lt 9 ]; then
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api/error")
        echo -ne "\r  req #$i → /api/error  [$STATUS]"
    else
        P=${PRODUCTS[$RANDOM % ${#PRODUCTS[@]}]}
        REG=${REGIONS[$RANDOM % ${#REGIONS[@]}]}
        curl -s -X POST "$BASE/api/orders" \
            -H "Content-Type: application/json" \
            -d "{\"product\":\"$P\",\"region\":\"$REG\"}" > /dev/null
        echo -ne "\r  req #$i → /api/orders ($P/$REG)"
    fi
    sleep "$(echo "scale=3; 1/$RATE" | bc)"
done
