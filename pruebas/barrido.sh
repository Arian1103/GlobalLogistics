#!/usr/bin/env bash
# Barrido de concurrencia: corre ab con 1, 5, 10 ... 1000 usuarios para ver en
# qué punto se degradan los tiempos de respuesta. Deja un CSV con los resultados.
#   ./pruebas/barrido.sh
set -euo pipefail
source "$(dirname "$0")/comun.sh"

SALIDA="$RESULTADOS/barrido.csv"
echo "concurrencia;peticiones;rps;media_ms;p50;p95;p99;max;fallidas;no2xx" > "$SALIDA"

for c in 1 5 10 25 50 100 200 300 400 600 800 1000; do
  n=$(( c * 20 )); [ "$n" -lt 3000 ] && n=3000
  printf ">> %4d usuarios (%d peticiones)... " "$c" "$n"
  ab_docker -n "$n" -c "$c" "$URL_INTERNA" > "$RESULTADOS/barrido_c$c.txt" 2>&1
  linea="$c;$n;$(metricas_ab "$RESULTADOS/barrido_c$c.txt")"
  echo "$linea" >> "$SALIDA"
  echo "$linea"
  sleep 3
done
echo "Listo: $SALIDA"
