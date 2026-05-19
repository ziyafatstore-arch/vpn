FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash curl wget unzip ca-certificates openssl uuid-runtime tmux python3 \
    && rm -rf /var/lib/apt/lists/*

RUN set -e \
    && XRAY_VERSION="v26.3.27" \
    && TMPDIR="$(mktemp -d)" \
    && curl -sL "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-64.zip" \
         -o "$TMPDIR/xray.zip" \
    && unzip -q "$TMPDIR/xray.zip" -d "$TMPDIR" \
    && install -m 755 "$TMPDIR/xray" /usr/local/bin/xray \
    && curl -sL "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" \
         -o /usr/local/bin/geoip.dat \
    && curl -sL "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" \
         -o /usr/local/bin/geosite.dat \
    && rm -rf "$TMPDIR"

COPY start.sh show-link.sh keep-alive.sh /usr/local/bin/
COPY xray-enforcement-v2.py /usr/local/bin/xray-enforcement-v2.py
COPY config.json /usr/local/bin/config.json

RUN chmod +x /usr/local/bin/start.sh \
             /usr/local/bin/show-link.sh \
             /usr/local/bin/keep-alive.sh \
             /usr/local/bin/xray-enforcement-v2.py

EXPOSE 443
