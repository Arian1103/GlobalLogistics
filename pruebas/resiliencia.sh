#!/usr/bin/env bash
# Resiliencia: mientras corre una carga constante, tiramos una réplica y
# marcamos otra como enferma. Gracias a los health checks y al reintento de NGINX
# el cliente no debería ver errores.
#   ./pruebas/resiliencia.sh
set -euo pipefail
source "$(dirname "$0")/comun.sh"
cd "$(dirname "$0")/.."

admin() {   # $1 = índice de réplica, $2 = ruta admin
  docker compose exec -T --index "$1" envios wget -qO- --post-data='' "http://127.0.0.1:3000$2" || true
}

echo ">> Carga constante de fondo: 50 usuarios, 40000 peticiones"
ab_docker -n 40000 -c 50 "$URL_INTERNA" > "$RESULTADOS/ab_resiliencia.txt" 2>&1 &
pid_ab=$!

sleep 5
echo ">> [t=5s]  Se cae el proceso de la réplica 1";            admin 1 /admin/caer; echo
sleep 4
echo ">> [t=9s]  La réplica 2 pasa a estar enferma (responde 503)"; admin 2 /admin/salud/DOWN; echo
sleep 18
echo ">> [t=27s] Estado de las réplicas (Docker ya marcó a la 2 como unhealthy):"
docker ps --filter "name=globallogistics-envios" --format "   {{.Names}}  {{.Status}}"
echo ">> [t=27s] La réplica 2 se recupera";                      admin 2 /admin/salud/UP; echo

wait "$pid_ab"
echo
echo ">> Resultado de la carga mientras pasaba todo esto:"
grep -E "Complete requests|Failed requests|Non-2xx|Requests per second|  95%|  99%" "$RESULTADOS/ab_resiliencia.txt" | sed 's/^/   /'
echo
echo ">> Estado final de las réplicas (la 1 fue reiniciada por Docker sola):"
docker ps --filter "name=globallogistics-envios" --format "   {{.Names}}  {{.Status}}"
docker inspect -f '   {{.Name}} reinicios={{.RestartCount}}' $(docker ps -q --filter "name=globallogistics-envios") 
