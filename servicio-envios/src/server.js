// Microservicio de Envíos - GlobalLogistics S.A.
// TP3 Arquitectura de Sistemas (UCh) - Azzolina, Nuñez, Mateu
//
// Es una API REST chica que corre en 3 réplicas detrás de NGINX.
// Lo importante para el TP es que cada respuesta dice qué instancia la atendió.

const express = require("express");
const os = require("os");
const crypto = require("crypto");

const app = express();
app.use(express.json());

const PUERTO = Number(process.env.PUERTO || 3000);
// Dentro de Docker el hostname es el ID corto del contenedor, así sabemos qué réplica respondió
const INSTANCIA = os.hostname();
const INICIO = Date.now();
// Cuántas vueltas hace el cálculo de /cotizar (más vueltas = más CPU por petición)
const ITERACIONES = Number(process.env.ITERACIONES_COTIZACION || 5000);

let sano = true;        // lo usamos para simular una réplica enferma
let atendidas = 0;

// Todas las respuestas llevan el header X-Instancia
app.use((req, res, next) => {
  atendidas++;
  res.set("X-Instancia", INSTANCIA);
  // si la instancia está "enferma" rechaza todo menos el health check y la administración
  if (!sano && req.path !== "/health" && !req.path.startsWith("/admin")) {
    return res.status(503).json({ error: "instancia fuera de servicio", instancia: INSTANCIA });
  }
  next();
});

// Endpoint principal: devuelve el hostname / ID del contenedor
app.get("/", (req, res) => {
  res.json({
    servicio: "envios",
    instancia: INSTANCIA,
    mensaje: "Respuesta de una réplica del microservicio de Envíos",
    uptimeSeg: Math.round((Date.now() - INICIO) / 1000),
    peticionesAtendidas: atendidas,
    fecha: new Date().toISOString(),
  });
});

// Health check: lo consultan Docker (healthcheck) y nosotros en las pruebas
app.get("/health", (req, res) => {
  if (!sano) return res.status(503).json({ estado: "DOWN", instancia: INSTANCIA });
  res.json({ estado: "UP", instancia: INSTANCIA, uptimeSeg: Math.round((Date.now() - INICIO) / 1000) });
});

// Cotización de un envío. El cálculo es pesado a propósito (simula calcular ruta y tarifa)
// para que en las pruebas de estrés la CPU de las réplicas se sature de verdad.
const TARIFAS = { AR: 1.0, CL: 1.4, UY: 1.3, BR: 1.6, MX: 2.2, US: 2.8 };

app.get("/cotizar", (req, res) => {
  const peso = Number(req.query.peso || 1);
  const destino = String(req.query.destino || "AR").toUpperCase();
  if (!Number.isFinite(peso) || peso <= 0 || peso > 70) {
    return res.status(400).json({ error: "peso inválido (0 a 70 kg)", instancia: INSTANCIA });
  }
  const t0 = process.hrtime.bigint();
  const ruta = crypto
    .pbkdf2Sync(`${peso}-${destino}`, "globallogistics", ITERACIONES, 32, "sha256")
    .toString("hex");
  const calculoMs = Number(process.hrtime.bigint() - t0) / 1e6;
  const factor = TARIFAS[destino] || 3.0;

  res.json({
    instancia: INSTANCIA,
    destino,
    pesoKg: peso,
    precioUSD: Number((12 + peso * 4.5 * factor).toFixed(2)),
    calculoMs: Number(calculoMs.toFixed(2)),
    ruta: ruta.slice(0, 12),
  });
});

// Alta de envío (simulada, no guarda nada). Pide Idempotency-Key como en el contrato del TP2.
app.post("/envios", (req, res) => {
  const clave = req.get("Idempotency-Key");
  if (!clave) {
    return res.status(400).json({ codigo: "IDEMPOTENCY_KEY_REQUERIDA", mensaje: "Falta el header Idempotency-Key", instancia: INSTANCIA });
  }
  const body = req.body || {};
  const pais = body.destinatario && body.destinatario.direccion && body.destinatario.direccion.pais;
  if (!pais || !Array.isArray(body.paquetes) || body.paquetes.length === 0) {
    return res.status(400).json({ codigo: "DATOS_INVALIDOS", mensaje: "Faltan destinatario.direccion.pais o paquetes", instancia: INSTANCIA });
  }
  const idEnvio = crypto.randomUUID();
  res.status(202).location(`/envios/${idEnvio}`).json({
    idEnvio,
    codigoSeguimiento: `GL-${pais}-${Date.now().toString().slice(-7)}`,
    estado: "PENDIENTE_ADUANA",
    instancia: INSTANCIA,
  });
});

// --- Endpoints de administración para las pruebas de resiliencia ---
// El balanceador los bloquea (403), solo se pueden usar desde adentro del contenedor.

// Marca la instancia como sana o enferma: POST /admin/salud/DOWN  o  /admin/salud/UP
app.post("/admin/salud/:estado", (req, res) => {
  sano = req.params.estado.toUpperCase() !== "DOWN";
  console.log(`[${INSTANCIA}] estado cambiado a ${sano ? "UP" : "DOWN"}`);
  res.json({ instancia: INSTANCIA, estado: sano ? "UP" : "DOWN" });
});

// Simula una caída del proceso (Docker lo vuelve a levantar por la política restart)
app.post("/admin/caer", (req, res) => {
  console.log(`[${INSTANCIA}] simulando caída del proceso`);
  res.json({ instancia: INSTANCIA, mensaje: "me caigo en 100 ms" });
  setTimeout(() => process.exit(1), 100);
});

// backlog grande: si llegan muchas conexiones juntas quedan en la cola del kernel
// en vez de descartarse (necesita net.core.somaxconn alto, ver docker-compose.yml)
const server = app.listen(PUERTO, "0.0.0.0", 4096, () => {
  console.log(`[${INSTANCIA}] servicio de envíos escuchando en el puerto ${PUERTO} (iteraciones=${ITERACIONES})`);
});

// Apagado prolijo cuando Docker manda SIGTERM
process.on("SIGTERM", () => {
  console.log(`[${INSTANCIA}] SIGTERM recibido, cerrando`);
  server.close(() => process.exit(0));
});
