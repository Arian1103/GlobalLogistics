#!/usr/bin/env bash
# Consigna 2: muestra que peticiones consecutivas al balanceador las atienden
# réplicas distintas (cada respuesta trae el hostname = ID del contenedor).
#   ./pruebas/balanceo.sh [cantidad]
URL="${URL:-http://localhost:8080/}"
N="${1:-12}"

echo "Enviando $N peticiones consecutivas a $URL"
echo
for i in $(seq 1 "$N"); do
  inst=$(curl -s "$URL" | sed -n 's/.*"instancia":"\([^"]*\)".*/\1/p')
  printf "  Petición %2d  ->  atendida por la instancia %s\n" "$i" "$inst"
done
echo
echo "Réplicas corriendo (el ID del contenedor coincide con la instancia):"
docker ps --filter "name=globallogistics-envios" --format "  {{.Names}}   ID={{.ID}}   {{.Status}}"
