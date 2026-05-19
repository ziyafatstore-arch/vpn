#!/bin/bash
# Prevents GitHub Codespaces idle shutdown by generating port activity every 4 minutes.
# GitHub Codespaces idles out after 30 min (default) or up to 4 hours (max, set in account settings).
# Self-pinging the forwarded public port keeps the Codespace active.

INTERVAL=240  # 4 minutes — well under the 30-min default idle window

echo "[keepalive] Started. Pinging every ${INTERVAL}s."

while true; do
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

  # Self-ping via public Codespace URL (generates forwarded-port activity)
  if [ -n "$CODESPACE_NAME" ]; then
    STATUS=$(curl -sk --max-time 10 \
      "https://${CODESPACE_NAME}-443.app.github.dev/" \
      -o /dev/null -w "%{http_code}" 2>/dev/null || echo "err")
    echo "[$TIMESTAMP] self-ping → $STATUS" >> /tmp/keepalive.log
  fi

  # Fallback external ping
  curl -s --max-time 5 https://github.com/ -o /dev/null 2>/dev/null || true

  sleep $INTERVAL
done
