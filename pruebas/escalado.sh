#!/usr/bin/env bash
# Escalabilidad horizontal: misma carga (100 usuarios) con 1, 2 y 3 réplicas.
# NGINX descubre las réplicas nuevas solo (resolver de Docker + "resolve"),
# no hay que tocar la configuración del balanceador.
#   ./pruebas/escalado.sh
set -euo pipefail
source "$(dirname "$0")/comun.sh"
cd "$(dirname "$0")/.."

SALIDA="$RESULTADOS/escalado.csv"
echo "replicas;rps;media_ms;p50;p95;p99;max;fallidas;no2xx" > "$SALIDA"

for r in 1 2 3; do
  echo ">> Escalando a $r réplica(s)"
  docker compose up -d --no-recreate --scale envios="$r" > /dev/null 2>&1
  esperar_replicas_sanas "$r"
  sleep 8   # le damos tiempo a NGINX para volver a resolver el DNS
  ab_docker -n 10000 -c 100 "$URL_INTERNA" > "$RESULTADOS/escalado_r$r.txt" 2>&1
  linea="$r;$(metricas_ab "$RESULTADOS/escalado_r$r.txt")"
  echo "$linea" >> "$SALIDA"
  echo "   $linea"
done
echo "Listo: $SALIDA (quedan 3 réplicas corriendo)"
