#!/usr/bin/env python3
"""
Xray gRPC API Enforcement v2
Monitors traffic quotas and time limits per VLESS user.
UUIDs are loaded dynamically from the runtime Xray config at startup.
"""

import json
import time
import logging
import subprocess
from datetime import datetime
from pathlib import Path

RUNTIME_CONFIG = "/etc/xray/g2ray.json"
XRAY_GRPC_HOST = "127.0.0.1"
XRAY_GRPC_PORT = 10085
LOG_FILE = "/tmp/enforce.log"
TRACKER_DB = "/tmp/g2ray-tracker.json"
CHECK_INTERVAL = 10  # seconds


logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)


def load_user_limits():
    """Read UUIDs and assign limits based on position in config."""
    try:
        with open(RUNTIME_CONFIG) as f:
            config = json.load(f)

        clients = []
        for inbound in config.get("inbounds", []):
            if inbound.get("tag") == "vless-in":
                clients = inbound["settings"]["clients"]
                break

        limits = {}
        plan_definitions = [
            # (name, limit_bytes, has_time_limit_seconds)
            ("20MB-Limit", 20 * 1024 * 1024, None),
            ("5Min-Trial", None, 300),
            ("Unlimited",  None, None),
        ]

        for i, client in enumerate(clients):
            uuid = client["id"]
            name, limit_bytes, time_limit = plan_definitions[i] if i < len(plan_definitions) else ("Extra", None, None)
            limits[uuid] = {
                "name": name,
                "limit_bytes": limit_bytes,
                "time_limit_seconds": time_limit,
                "email": client.get("email", f"user-{i}"),
            }

        logger.info(f"Loaded {len(limits)} users from config")
        return limits

    except Exception as e:
        logger.error(f"Failed to load user limits from config: {e}")
        return {}


def init_tracker(user_limits):
    now = int(time.time())
    tracker = {}
    for uuid, cfg in user_limits.items():
        expires_at = (now + cfg["time_limit_seconds"]) if cfg["time_limit_seconds"] else None
        tracker[uuid] = {
            "name": cfg["name"],
            "email": cfg["email"],
            "limit_bytes": cfg["limit_bytes"],
            "expires_at": expires_at,
            "traffic_bytes": 0,
            "blocked": False,
            "block_reason": None,
        }
    with open(TRACKER_DB, "w") as f:
        json.dump(tracker, f, indent=2)
    return tracker


def load_tracker():
    try:
        with open(TRACKER_DB) as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def save_tracker(tracker):
    with open(TRACKER_DB, "w") as f:
        json.dump(tracker, f, indent=2)


def get_xray_stats():
    """Query Xray stats API for per-user byte counts."""
    stats = {}
    try:
        result = subprocess.run(
            ["xray", "api", "statquery",
             "-s", f"{XRAY_GRPC_HOST}:{XRAY_GRPC_PORT}", "-reset"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                if "user>>>" in line and ": " in line:
                    key, _, value = line.partition(": ")
                    try:
                        uuid = key.split("user>>>")[1].split(">>>")[0]
                        stats[uuid] = stats.get(uuid, 0) + int(value.strip())
                    except (ValueError, IndexError):
                        pass
    except Exception as e:
        logger.debug(f"Stats API unavailable: {e}")
    return stats


def block_user(uuid, email):
    """Remove user from Xray via gRPC."""
    try:
        result = subprocess.run(
            ["xray", "api", "uin",
             "-s", f"{XRAY_GRPC_HOST}:{XRAY_GRPC_PORT}",
             "-op", "remove", "-email", email],
            capture_output=True, text=True, timeout=5
        )
        return result.returncode == 0
    except Exception as e:
        logger.error(f"gRPC block failed for {email}: {e}")
        return False


def check_quotas(tracker):
    now = int(time.time())
    stats = get_xray_stats()

    for uuid, user in tracker.items():
        if user["blocked"]:
            continue

        # Accumulate traffic
        new_bytes = stats.get(uuid, 0)
        user["traffic_bytes"] += new_bytes

        # Volume limit
        if user["limit_bytes"] and user["traffic_bytes"] > user["limit_bytes"]:
            used_mb = user["traffic_bytes"] / 1024 / 1024
            limit_mb = user["limit_bytes"] / 1024 / 1024
            logger.warning(f"QUOTA EXCEEDED: {user['name']} — {used_mb:.1f}MB / {limit_mb:.0f}MB")
            if block_user(uuid, user["email"]):
                user["blocked"] = True
                user["block_reason"] = f"Quota: {used_mb:.1f}MB used"
                logger.info(f"BLOCKED: {user['name']}")

        # Time limit
        if user["expires_at"] and now > user["expires_at"] and not user["blocked"]:
            logger.warning(f"EXPIRED: {user['name']}")
            if block_user(uuid, user["email"]):
                user["blocked"] = True
                user["block_reason"] = "Time limit expired"
                logger.info(f"BLOCKED: {user['name']}")


def display_status(tracker):
    now = int(time.time())
    logger.info("=" * 65)
    for uuid, user in tracker.items():
        state = "BLOCKED" if user["blocked"] else "ACTIVE"
        traffic_mb = user["traffic_bytes"] / 1024 / 1024

        if user["limit_bytes"]:
            limit_mb = user["limit_bytes"] / 1024 / 1024
            traffic_info = f"{traffic_mb:.1f}/{limit_mb:.0f}MB"
        else:
            traffic_info = f"{traffic_mb:.1f}MB used"

        if user["expires_at"]:
            remaining = max(0, user["expires_at"] - now)
            time_info = f" | {remaining}s left"
        else:
            time_info = ""

        reason = f" [{user['block_reason']}]" if user["blocked"] else ""
        logger.info(f"[{state}] {user['name']:20s} | {traffic_info}{time_info}{reason}")
    logger.info("=" * 65)


def main():
    logger.info("Xray Enforcement v2 starting...")

    user_limits = load_user_limits()
    if not user_limits:
        logger.error("No users loaded. Exiting.")
        return

    tracker = init_tracker(user_limits)

    logger.info("User plans:")
    for uuid, user in tracker.items():
        limit = f"{user['limit_bytes']//1024//1024}MB" if user["limit_bytes"] else "unlimited"
        expiry = f"expires in {user['expires_at'] - int(time.time())}s" if user["expires_at"] else "no expiry"
        logger.info(f"  {user['name']:20s} | quota={limit} | {expiry}")

    status_counter = 0
    try:
        while True:
            tracker = load_tracker() or tracker
            check_quotas(tracker)
            save_tracker(tracker)

            status_counter += 1
            if status_counter >= 6:
                display_status(tracker)
                status_counter = 0

            time.sleep(CHECK_INTERVAL)

    except KeyboardInterrupt:
        logger.info("Enforcement stopped.")
    except Exception as e:
        logger.error(f"Fatal: {e}", exc_info=True)


if __name__ == "__main__":
    main()
