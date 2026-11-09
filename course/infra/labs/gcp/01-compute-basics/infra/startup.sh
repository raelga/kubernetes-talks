#!/bin/bash
set -eu

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3
install -d -m 755 /opt/compute-basics
cat > /opt/compute-basics/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Compute Engine basics</title></head>
<body><h1>Compute Engine basics</h1><p>This page is served from the lab VM.</p></body>
</html>
HTML
cat > /etc/systemd/system/compute-basics.service <<'UNIT'
[Unit]
Description=Compute basics demonstration web page
After=network.target

[Service]
User=nobody
WorkingDirectory=/opt/compute-basics
ExecStart=/usr/bin/python3 -m http.server 8080 --bind 0.0.0.0
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now compute-basics.service
