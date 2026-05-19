# g2ray — VLESS Proxy on GitHub Codespaces

Run a VLESS proxy server for free using GitHub Codespaces. Each GitHub account gives you **120 free core-hours/month** (= 60 hours on a 2-core machine).

> **Use a secondary GitHub account** — not your main one.

---

## Quick Start

1. Fork this repo to your (secondary) GitHub account
2. Click **Code → Codespaces → Create codespace on main**
3. Wait 2–5 minutes for the container to build and Xray to start
4. Your 3 VLESS links will be printed automatically in the terminal
5. Import a link into **V2RayNG** (Android), **Clash Meta**, or any VLESS client

---

## How to Make It Run Longer Than 4 Hours

GitHub Codespaces stops after the **idle timeout** (default: 30 minutes, max: **4 hours**).

### Step 1 — Set maximum idle timeout
Go to **github.com → Settings → Codespaces → Default idle timeout** and set it to **4 hours**.

### Step 2 — The keepalive script handles the rest
`keep-alive.sh` self-pings the forwarded port every 4 minutes, which counts as activity and resets the idle timer. This keeps the Codespace alive for the full 4 hours with no browser open.

### Step 3 — For 24/7 operation
Use **multiple GitHub accounts** (each gets 60 free hours/month). When one account's hours run out or the Codespace stops, create a new Codespace on the next account.

---

## Architecture

```
Dockerfile
  └── Installs Xray binary + system packages during image build

start.sh  (runs automatically on every Codespace start)
  ├── Generates 3 fresh random UUIDs
  ├── Writes /etc/xray/g2ray.json with those UUIDs
  ├── Starts Xray in tmux window "xray"
  ├── Starts enforcement in tmux window "enforce"
  └── Starts keepalive in tmux window "keepalive"

xray-enforcement-v2.py
  └── Reads UUIDs from runtime config; enforces volume/time limits via Xray gRPC API

keep-alive.sh
  └── Self-pings port 443 every 4 minutes to prevent idle shutdown

show-link.sh
  └── Prints the 3 VLESS links (also runs on every terminal attach)
```

---

## VLESS Plans

| Link | Limit | Notes |
|------|-------|-------|
| Link 1 | 20 MB quota | No time expiry |
| Link 2 | 5-minute trial | Unlimited volume |
| Link 3 | Unlimited | No limits |

---

## Useful Commands (inside the Codespace terminal)

```bash
tmux attach -t g2ray            # View all services
tmux attach -t g2ray:xray       # View Xray logs only
tail -f /tmp/enforce.log        # Monitor quota enforcement
tail -f /tmp/keepalive.log      # Monitor keepalive pings
bash show-link.sh               # Re-print VLESS links
```

---

## Troubleshooting

- **Links not showing** — wait 30 seconds then run `bash show-link.sh`
- **Can't connect** — run `tmux attach -t g2ray:xray` and check for errors
- **Codespace stopped** — create a new one; a fresh set of links is generated automatically
- **"Port not found"** — the port 443 visibility is set to `public` in devcontainer.json; if it didn't apply, run:
  ```bash
  gh codespace ports visibility 443:public -c $CODESPACE_NAME
  ```

---

## Compatible ISPs / Networks

Tested with Shecan free plan. If these IPs route correctly for you, the proxy works:
- `63.141.252.203`
- `50.7.5.83`
- `94.130.50.12`
