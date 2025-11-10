#!/usr/bin/env bash
# Restaurar backups de Node-RED / InfluxDB / Grafana
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$ROOT_DIR/backups"

usage() {
  echo "Uso: $0 --influx influxdb2-YYYY-MM-DD-HHMMSS.tgz --nodered nodered-YYYY...tgz --grafana grafana-YYYY...tgz"
  exit 1
}

INFLUX_BKP=""
NODERED_BKP=""
GRAFANA_BKP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --influx) INFLUX_BKP="$2"; shift 2;;
    --nodered) NODERED_BKP="$2"; shift 2;;
    --grafana) GRAFANA_BKP="$2"; shift 2;;
    *) usage;;
  esac
done

[[ -z "$INFLUX_BKP" || -z "$NODERED_BKP" || -z "$GRAFANA_BKP" ]] && usage

echo "[+] Asegúrate de haber corrido 'docker compose down' antes de restaurar."
read -p "¿Continuar y restaurar? [y/N] " confirm
[[ "$confirm" != "y" ]] && exit 0

echo "[+] Restaurando InfluxDB..."
rm -rf "$ROOT_DIR/nx-core-ops/influxdb"
tar -C "$ROOT_DIR" -xzf "$BACKUP_DIR/$INFLUX_BKP"

echo "[+] Restaurando Node-RED..."
rm -rf "$ROOT_DIR/nx-core-ops/nodered"
tar -C "$ROOT_DIR" -xzf "$BACKUP_DIR/$NODERED_BKP"

echo "[+] Restaurando Grafana..."
docker run --rm -v "$ROOT_DIR/nx-core-ops/grafana":/data -v "$BACKUP_DIR":/backups alpine \
  sh -c "rm -rf /data/* && tar -xzf /backups/$GRAFANA_BKP -C /data"

echo "[+] Restauración completa. Ejecuta 'docker compose up -d' para relanzar la stack."
