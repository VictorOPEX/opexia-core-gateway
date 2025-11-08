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

## TLS y certificados
- Certificados del broker en `nx-core-ops/mosquitto/certs` (CA `ca-mosquitto.crt`, par `server.crt|key`).
- Configuración TLS en `nx-core-ops/mosquitto/config/mosquitto.conf` (listeners 1883 loopback, 8883 TLS 1.2, ACL y contraseñas).
- Copia de una nueva CA al contenedor (desde la raíz del repo):
  ```bash
  docker cp ca-mosquitto.crt mosquitto:/mosquitto/certs/ca-mosquitto.crt
  docker exec mosquitto chown mosquitto:mosquitto /mosquitto/certs/ca-mosquitto.crt
  docker exec mosquitto chmod 644 /mosquitto/certs/ca-mosquitto.crt
  ```
- Tras sustituir certificados o contraseñas, reinicia sólo el broker:
  ```bash
  docker compose restart mosquitto
  docker logs --tail 50 mosquitto   # verifica que no hay errores TLS / "not authorised"
  ```

## Checklist seguridad MQTT
1. `listener 1883 127.0.0.1` sigue limitado a loopback (no exponer EDGE).
2. Listener `8883` usa `cafile /mosquitto/certs/ca-mosquitto.crt` y `tls_version tlsv1.2`.
3. `passwords` y `acl.conf` con permisos `600` y propietario `mosquitto:mosquitto`.
4. ACL vigentes (nodered-core, ed-gate-zn1-01, nodos físicos) documentadas en `nx-core-ops/mosquitto/config/acl.conf`.
5. Logs limpios tras reinicio (`docker logs mosquitto` sin “not authorised”).
6. Clientes externos confían en la CA actual y validan hostname del certificado.

## Flujos Node-RED
- Exporta/importa los flujos principales desde `edge-templates/nodered/flow-opexia-coreedge.json` (JSON listo para el editor).
- Para versionar cambios desde el contenedor: `docker exec nodered cat /data/flows.json > edge-templates/nodered/flow-opexia-coreedge.json`.
- Antes de importar en otro gateway, ajusta el nodo `fn_store_token` para leer `INFLUX_TOKEN` desde `.env`/secrets en lugar de incrustarlo en el flow.
- Documenta certificaciones TLS en el nodo `TLS_CA` y asegúrate de que `ca-mosquitto.crt` esté disponible en el host que ejecuta Node-RED.

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

### Checklist de backup
1. Ejecuta los tres comandos anteriores (InfluxDB, Node-RED, Grafana) y confirma que los archivos `.tgz` aparecen en `backups/`.
2. Verifica cada archivo con `tar -tzf backups/<archivo>.tgz | head` para detectar corrupción antes de borrar la copia anterior.
3. Calcula un hash opcional (`sha256sum backups/<archivo>.tgz`) y guarda el resultado junto al backup.
4. Copia los `.tgz` fuera del host (NAS/S3) para evitar pérdida por fallo del equipo local.

### Restauración (ensayada)
1. **Preparación:** detén la stack `docker compose down` y respalda el estado actual (`mv nx-core-ops nx-core-ops.$(date +%F)`).
2. **InfluxDB:** descomprime el backup deseado `tar -xzf backups/influxdb2-YYYY-MM-DD-HHMM.tgz -C .` y verifica que `nx-core-ops/influxdb` recupere `config.json` y `engine/`.
3. **Node-RED:** extrae `backups/nodered-*.tgz` sobre `nx-core-ops/nodered` y confirma que `flows.json` y `flows_cred.json` corresponden a la fecha restaurada.
4. **Grafana:** usa un contenedor Alpine para restaurar (mismo comando de backup pero reemplazando `tar -czf` por `tar -xzf` y apuntando al archivo elegido).
5. **Relanzar:** `docker compose up -d` y revisa salud de los servicios (`docker ps`, `docker logs <servicio>`). Comprueba que Influx tiene el bucket, Node-RED carga los flows y Grafana muestra los dashboards esperados.
6. **Documentar:** registra fecha del backup y resultado del ensayo en `backups/README.md` o bitácora para saber qué snapshot es válido.
