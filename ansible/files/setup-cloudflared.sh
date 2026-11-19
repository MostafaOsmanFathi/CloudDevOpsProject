#!/usr/bin/env bash
# Install cloudflared and run a quick tunnel to the Argo CD server.
# Idempotent: safe to run again.
set -euo pipefail

ARCH=amd64
BIN=/usr/local/bin/cloudflared

if [ ! -x "$BIN" ]; then
  echo "downloading cloudflared..."
  curl -fsSL --max-time 300 -o "$BIN" \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}"
  chmod +x "$BIN"
fi
"$BIN" --version

cat > /etc/systemd/system/cloudflared.service <<'EOF'
[Unit]
Description=Cloudflare Tunnel to Argo CD
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --no-autoupdate --url http://10.0.10.4:30080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cloudflared.service
sleep 12
systemctl is-active cloudflared.service
echo "--- tunnel url ---"
journalctl -u cloudflared.service --no-pager -o cat | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1 || true
