#!/usr/bin/env bash
# Funciones compartidas por los scripts de prueba

RED="gl-red"                                   # red creada por el docker-compose
URL_INTERNA="http://balanceador/cotizar?peso=2&destino=CL"
RESULTADOS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/resultados"
mkdir -p "$RESULTADOS"

# Corre Apache Benchmark desde un contenedor conectado a la misma red que el
# balanceador. Así no hace falta tener ab instalado y no pasamos por el
# port-forwarding de Docker Desktop. -l = no contar como error si cambia el largo
# de la respuesta (el JSON trae el tiempo de cálculo, que varía).
ab_docker() {
  docker run --rm --network "$RED" -v "$RESULTADOS:/res" httpd:2.4-alpine ab -l "$@"
}

# Saca las métricas de una salida de ab y las devuelve en una línea CSV:
# rps;media_ms;p50;p95;p99;max;fallidas;no2xx
metricas_ab() {
  awk '
    /Requests per second/        {rps=$4}
    /Time per request:.*\(mean\)$/ {media=$4}
    /^  50%/ {p50=$2} /^  95%/ {p95=$2} /^  99%/ {p99=$2} /^ 100%/ {max=$2}
    /Failed requests/            {fail=$3}
    /Non-2xx responses/          {no2xx=$3}
    END { if (no2xx=="") no2xx=0; printf "%s;%s;%s;%s;%s;%s;%s;%s\n", rps, media, p50, p95, p99, max, fail, no2xx }
  ' "$1"
}

# Muestra el uso de CPU/memoria de los contenedores cada ~2 s mientras dure la prueba
muestrear_cpu() {   # $1 = archivo destino, $2 = cantidad de muestras
  echo "hora;contenedor;cpu;memoria" > "$1"
  for _ in $(seq 1 "$2"); do
    docker stats --no-stream --format '{{.Name}};{{.CPUPerc}};{{.MemUsage}}' \
      | grep -E 'globallogistics-envios|gl-balanceador' \
      | sed "s/^/$(date +%H:%M:%S);/" >> "$1"
  done
}

esperar_replicas_sanas() {  # $1 = cantidad esperada
  for _ in $(seq 1 30); do
    sanas=$(docker ps --filter "name=globallogistics-envios" --filter "health=healthy" -q | wc -l | tr -d ' ')
    [ "$sanas" -ge "$1" ] && return 0
    sleep 1
  done
  echo "Ojo: no llegaron a estar sanas $1 réplicas" >&2
}
