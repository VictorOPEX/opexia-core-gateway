#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
TEMPLATE="$ROOT_DIR/grafana/provisioning/datasources/opexia-influx.yml.tmpl"
DASH_PROVISION="$ROOT_DIR/grafana/provisioning/dashboards/opexia-dash.yml"
DASHBOARD_JSON="$ROOT_DIR/grafana/dashboards/opexia-core-health.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No .env found at $ENV_FILE" >&2
  exit 1
fi

read_env() {
  local key="$1"
  python3 - <<'PY' "$ENV_FILE" "$key"
from pathlib import Path
import sys
env_path, key = Path(sys.argv[1]), sys.argv[2]
for line in env_path.read_text().splitlines():
    if not line or line.startswith('#') or '=' not in line:
        continue
    k, v = line.split('=', 1)
    if k.strip() == key:
        print(v.strip().replace('$$', '$'), end='')
        break
PY
}

INFLUX_TOKEN="$(read_env INFLUX_TOKEN)"
if [[ -z "$INFLUX_TOKEN" ]]; then
  echo "INFLUX_TOKEN is empty in .env" >&2
  exit 1
fi

TMP_DS="$(mktemp)"
python3 - <<'PY' "$TEMPLATE" "$TMP_DS" "$INFLUX_TOKEN"
from pathlib import Path
import sys
tpl_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
token = sys.argv[3]
content = tpl_path.read_text().replace("__INFLUX_TOKEN__", token)
out_path.write_text(content)
PY

echo "Copying provisioning files into grafana container..."
docker exec -u 0 grafana sh -c "mkdir -p /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards /var/lib/grafana/dashboards/opexia"
docker cp "$TMP_DS" grafana:/etc/grafana/provisioning/datasources/opexia-influx.yml
docker cp "$DASH_PROVISION" grafana:/etc/grafana/provisioning/dashboards/opexia-dash.yml
docker cp "$DASHBOARD_JSON" grafana:/var/lib/grafana/dashboards/opexia/core-health.json
docker exec -u 0 grafana sh -c "chown 472:0 /etc/grafana/provisioning/datasources/opexia-influx.yml /etc/grafana/provisioning/dashboards/opexia-dash.yml && chown -R 472:0 /var/lib/grafana/dashboards/opexia"

rm -f "$TMP_DS"

echo "Restarting grafana..."
docker restart grafana >/dev/null
echo "Done. Check http://localhost:3000/d/opexiaCoreHealth for the dashboard."
