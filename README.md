# OPEXIA – Gateway (NX-CORE-OPS + EDGE templates)
Stack Docker del gateway maestro (NX-CORE-OPS) y plantillas para gateways EDGE.

## Arranque rápido
```bash
cp env/sample.env .env
docker compose up -d
```

## Puertos expuestos
- Mosquitto: `1883` (loopback laboratorio), `8883` (TLS)
- Node-RED: `1880`
- InfluxDB: `8086`
- Grafana: `3000`

## Volúmenes
- `nx-core-ops/mosquitto/config|certs|data|log`
- `nx-core-ops/nodered`
- `nx-core-ops/influxdb`
- `nx-core-ops/grafana`

## Política ACL MQTT
- `allow_anonymous false`
- Usuarios en `nx-core-ops/mosquitto/config/passwords`
- ACL en `nx-core-ops/mosquitto/config/acl.conf`
- Listener `1883` sólo loopback; producción usa `8883` con TLS

## Variables `.env` (nombres)
- `INFLUX_USER`, `INFLUX_PASS`, `INFLUX_TOKEN`
- `GRAFANA_USER`, `GRAFANA_PASS`
- `NR_CREDENTIAL_SECRET`
- `TZ`

## Backups
```bash
mkdir -p backups
tar -czf backups/influxdb2-$(date +%F-%H%M).tgz nx-core-ops/influxdb
tar -czf backups/nodered-$(date +%F-%H%M).tgz   nx-core-ops/nodered
docker run --rm -v "$PWD/nx-core-ops/grafana":/data -v "$PWD/backups":/backups alpine \
  sh -c 'cd /data && tar -czf /backups/grafana-$(date +%F-%H%M).tgz .'
```
