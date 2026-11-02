#!/usr/bin/env bash
# Consigna 3: pruebas de estrés con Apache Benchmark.
#   Escenario 1 - concurrencia moderada: 100 usuarios concurrentes
#   Escenario 2 - concurrencia extrema: 1000 usuarios concurrentes (satura la CPU)
# Guarda la salida completa de ab y el uso de CPU en pruebas/resultados/
#   ./pruebas/carga.sh
set -euo pipefail
source "$(dirname "$0")/comun.sh"

escenario() {   # nombre, peticiones, concurrencia, muestras de CPU
  local nombre=$1 n=$2 c=$3 muestras=$4
  echo ">> Escenario '$nombre': $n peticiones con $c usuarios concurrentes"
  muestrear_cpu "$RESULTADOS/cpu_$nombre.csv" "$muestras" &
  local pid_cpu=$!
  ab_docker -n "$n" -c "$c" -e "/res/percentiles_$nombre.csv" "$URL_INTERNA" > "$RESULTADOS/ab_$nombre.txt" 2>&1
  wait "$pid_cpu" || true
  echo "   req/s;media_ms;p50;p95;p99;max;fallidas;no_2xx"
  echo "   $(metricas_ab "$RESULTADOS/ab_$nombre.txt")"
  echo
}

echo "Calentando las réplicas..."
ab_docker -n 500 -c 10 "$URL_INTERNA" > /dev/null 2>&1
sleep 3

escenario moderado 20000 100 6
sleep 10   # dejamos que se enfríe un poco entre escenarios
escenario extremo 50000 1000 12

echo "Listo. Resultados en $RESULTADOS"
