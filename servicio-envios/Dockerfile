# Imagen del microservicio de Envíos
FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production

# primero las dependencias (así Docker cachea esta capa si no cambian)
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src

# no corremos como root
USER node
EXPOSE 3000

# health check por defecto (en el docker-compose.yml se vuelve a definir)
HEALTHCHECK --interval=5s --timeout=2s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health > /dev/null || exit 1

CMD ["node", "src/server.js"]
