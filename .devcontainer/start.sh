#!/bin/bash
set -e

WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_CONFIG="/etc/xray/g2ray.json"

echo "[g2ray] Generating fresh UUIDs..."
UUID1=$(uuidgen | tr '[:upper:]' '[:lower:]')
UUID2=$(uuidgen | tr '[:upper:]' '[:lower:]')
UUID3=$(uuidgen | tr '[:upper:]' '[:lower:]')

# Persist UUIDs so other scripts can source them
cat > /tmp/g2ray-uuids.env << EOF
UUID1=$UUID1
UUID2=$UUID2
UUID3=$UUID3
EOF

echo "[g2ray] Writing Xray config..."
mkdir -p /etc/xray
sed \
  -e "s/UUID_PLACEHOLDER_1/$UUID1/g" \
  -e "s/UUID_PLACEHOLDER_2/$UUID2/g" \
  -e "s/UUID_PLACEHOLDER_3/$UUID3/g" \
  "$WORKDIR/config.json" > "$RUNTIME_CONFIG"

echo "[g2ray] Cleaning up old processes..."
pkill xray 2>/dev/null || true
tmux kill-session -t g2ray 2>/dev/null || true
sleep 1

echo "[g2ray] Starting Xray..."
tmux new-session -d -s g2ray -n xray
tmux send-keys -t g2ray:xray "xray run -c $RUNTIME_CONFIG 2>&1 | tee /tmp/xray.log" Enter
sleep 2

echo "[g2ray] Starting enforcement..."
tmux new-window -t g2ray -n enforce
tmux send-keys -t g2ray:enforce "python3 $WORKDIR/xray-enforcement-v2.py 2>&1 | tee /tmp/enforce.log" Enter

echo "[g2ray] Starting keepalive..."
tmux new-window -t g2ray -n keepalive
tmux send-keys -t g2ray:keepalive "bash $WORKDIR/keep-alive.sh" Enter

sleep 1
bash "$WORKDIR/show-link.sh"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                 g2ray started successfully                    ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  tmux attach -t g2ray          → view all services           ║"
echo "║  tmux attach -t g2ray:xray     → view Xray logs             ║"
echo "║  tail -f /tmp/enforce.log      → monitor quota enforcement   ║"
echo "║  tail -f /tmp/keepalive.log    → monitor keepalive          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
