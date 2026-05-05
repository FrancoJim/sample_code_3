FROM node:20-bookworm-slim AS build

WORKDIR /usr/src/app

COPY chainsaw_jugglers/package*.json ./
RUN npm ci --omit=dev

COPY chainsaw_jugglers/ ./

ENV NODE_ENV=production
ENV PORT=8080
EXPOSE 8080

USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:'+(process.env.PORT||8080)+'/',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "app.js"]
