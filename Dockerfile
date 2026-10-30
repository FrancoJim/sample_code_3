FROM node:25-bookworm-slim
LABEL org.opencontainers.image.source="https://github.com/FrancoJim/sample_code_3"

ENV NODE_ENV=production \
    PORT=8080

WORKDIR /usr/src/app

COPY chainsaw_jugglers/package*.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force

# Only what the server needs; tests stay out of the image
COPY chainsaw_jugglers/app.js ./
COPY chainsaw_jugglers/public/ ./public/

EXPOSE 8080

USER 1000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["node", "-e", "require('http').get('http://127.0.0.1:'+(process.env.PORT||8080)+'/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"]

CMD ["node", "app.js"]
