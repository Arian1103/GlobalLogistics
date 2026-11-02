# Resultados de las pruebas

Salidas reales de nuestras corridas (MacBook Apple M1, Docker Desktop, 3 réplicas con 0,5 CPU).

| Archivo | Qué es |
|---|---|
| `compose_ps.txt`, `balanceo.txt` | Estado de los contenedores y 12 peticiones consecutivas repartidas entre las 3 réplicas |
| `ab_moderado.txt`, `ab_extremo.txt` | Salida completa de Apache Benchmark (100 y 1000 usuarios) con la configuración final |
| `percentiles_*.csv` | Percentiles 0–100 de cada escenario (`ab -e`) |
| `cpu_moderado.csv`, `cpu_extremo.csv` | Muestras de `docker stats` tomadas durante cada escenario |
| `barrido.csv`, `barrido_c*.txt` | Barrido de 1 a 1000 usuarios concurrentes |
| `escalado.csv`, `escalado_r*.txt` | Misma carga con 1, 2 y 3 réplicas |
| `ab_resiliencia.txt`, `salida_resiliencia.txt`, `resiliencia_*.txt` | Prueba con una réplica caída y otra enferma durante la carga |
| `v1_config_inicial/` | Primera corrida, con la configuración inicial de NGINX (keepalive + timeouts contados como fallas): 79,6 % de respuestas 502 en el escenario extremo |
| `diagnostico/` | Experimentos que hicimos para encontrar la causa: sin `max_fails`, con `keepalive 256` y contra una sola réplica con y sin keep-alive |
