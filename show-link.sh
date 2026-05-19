#!/bin/bash
CONFIG="/etc/xray/g2ray.json"

# Source runtime UUIDs
if [ -f /tmp/g2ray-uuids.env ]; then
  source /tmp/g2ray-uuids.env
else
  UUID1=$(grep -o '"id": *"[^"]*"' "$CONFIG" | sed -n '1p' | grep -o '"[^"]*"$' | tr -d '"')
  UUID2=$(grep -o '"id": *"[^"]*"' "$CONFIG" | sed -n '2p' | grep -o '"[^"]*"$' | tr -d '"')
  UUID3=$(grep -o '"id": *"[^"]*"' "$CONFIG" | sed -n '3p' | grep -o '"[^"]*"$' | tr -d '"')
fi

if [ -z "$UUID1" ] || [ -z "$UUID2" ] || [ -z "$UUID3" ]; then
  echo "[g2ray] UUIDs not found. Is start.sh done running?"
  exit 1
fi

SNI="${CODESPACE_NAME}-443.app.github.dev"

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║               VLESS LINKS — 3 Plans                             ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

echo "📊 LINK 1: 20 MB Quota (no expiry)"
echo "──────────────────────────────────────────────────────────────────"
echo "vless://${UUID1}@${SNI}:443?encryption=none&security=tls&sni=${SNI}&host=${SNI}&fp=chrome&allowInsecure=1&type=xhttp&mode=packet-up&path=%2F#20MB-Limit"
echo ""

echo "⏰ LINK 2: 5-Minute Trial (unlimited volume)"
echo "──────────────────────────────────────────────────────────────────"
echo "vless://${UUID2}@${SNI}:443?encryption=none&security=tls&sni=${SNI}&host=${SNI}&fp=chrome&allowInsecure=1&type=xhttp&mode=packet-up&path=%2F#5Min-Trial"
echo ""

echo "✅ LINK 3: Unlimited (no limits)"
echo "──────────────────────────────────────────────────────────────────"
echo "vless://${UUID3}@${SNI}:443?encryption=none&security=tls&sni=${SNI}&host=${SNI}&fp=chrome&allowInsecure=1&type=xhttp&mode=packet-up&path=%2F#Unlimited"
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║ Generated: $(date '+%Y-%m-%d %H:%M:%S')                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
