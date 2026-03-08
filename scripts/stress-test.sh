
#!/usr/bin/env bash
echo "🔥 Obs-Lab Stress Tester"
echo "  1) Hammer /api/error  → AppHighErrorRate alert"
echo "  2) Hammer /api/slow   → AppHighLatencyP99 alert"
echo "  3) CPU stress         → HostHighCpuLoad alert"
echo ""
read -p "Enter choice [1-3]: " CHOICE
BASE="http://localhost:5000"
case "$CHOICE" in
  1)
    echo "Sending sustained error traffic for 10 minutes..."
    for i in $(seq 1 1200); do
      curl -s "$BASE/api/error" > /dev/null
      echo -ne "\r  $i/1200..."
      sleep 0.5
    done ;;
  2)
    echo "Sending parallel slow requests..."
    for i in $(seq 1 100); do
      curl -s "$BASE/api/slow" > /dev/null &
      echo -ne "\r  $i/100..."
    done; wait ;;
  3)
    sudo apt-get install -y -qq stress-ng 2>/dev/null
    stress-ng --cpu 4 --timeout 180s ;;
  *) echo "Invalid choice" ;;
esac
