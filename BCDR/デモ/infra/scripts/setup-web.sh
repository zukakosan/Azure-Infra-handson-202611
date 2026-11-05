#!/usr/bin/env bash
set -euo pipefail

state_dir=/var/lib/backup-demo

# Do not replace demo updates if the extension runs again after initialization.
if [ ! -f "$state_dir/initialized" ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y apache2 curl
  apache2ctl configtest
  systemctl enable --now apache2

  printf '%s\n' '<!doctype html>' '<html lang="en">' \
    '<head><meta charset="utf-8"><title>Azure Backup Demo</title></head>' \
    '<body><h1>Azure Backup Demo</h1>' \
    '<p>Recovery marker: backup-demo-good-v1</p></body></html>' \
    > /tmp/backup-demo-good.html
  install -m 644 /tmp/backup-demo-good.html /var/www/html/index.html
  sync
fi

systemctl is-enabled apache2
systemctl is-active apache2
sha256sum /var/www/html/index.html
curl --fail --silent --show-error --connect-timeout 5 --max-time 15 http://127.0.0.1/

install -d -m 755 "$state_dir"
date -u +%Y-%m-%dT%H:%M:%SZ > "$state_dir/initialized"
