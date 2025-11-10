#!/usr/bin/env bash
# Backup Node-RED, InfluxDB y Grafana volúmenes locales
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$ROOT_DIR/backups"
TIMESTAMP="$(date +%F-%H%M%S)"

mkdir -p "$BACKUP_DIR"

echo "[+] Backup InfluxDB..."
tar --warning=no-file-changed -C "$ROOT_DIR" -czf "$BACKUP_DIR/influxdb2-$TIMESTAMP.tgz" nx-core-ops/influxdb

echo "[+] Backup Node-RED..."
tar --warning=no-file-changed -C "$ROOT_DIR" -czf "$BACKUP_DIR/nodered-$TIMESTAMP.tgz" nx-core-ops/nodered

echo "[+] Backup Grafana..."
docker run --rm -v "$ROOT_DIR/nx-core-ops/grafana":/data -v "$BACKUP_DIR":/backups alpine \
  sh -c "cd /data && tar -czf /backups/grafana-$TIMESTAMP.tgz ."

echo "[+] Backups creados en $BACKUP_DIR:"
ls -lh "$BACKUP_DIR" | tail -n +2
