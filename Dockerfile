FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash curl wget unzip ca-certificates openssl uuid-runtime tmux python3 \
    && rm -rf /var/lib/apt/lists/*

# Download Xray binary at image build time (update version as needed)
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

EXPOSE 443
