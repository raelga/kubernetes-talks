#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3
install -d -m 755 /opt/vm-basics
cat > /opt/vm-basics/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Azure VM basics</title></head>
<body><h1>Azure VM basics</h1><p>This page is served from the lab VM.</p></body>
</html>
HTML
cat > /etc/systemd/system/vm-basics.service <<'UNIT'
[Unit]
Description=VM basics demonstration web page
After=network.target

[Service]
User=nobody
WorkingDirectory=/opt/vm-basics
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 0.0.0.0
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now vm-basics.service
