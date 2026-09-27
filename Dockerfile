ARG NODE_IMAGE=node:22-bookworm-slim

FROM ${NODE_IMAGE} AS deps
WORKDIR /app
# Toolchain for compiling better-sqlite3's native addon if no prebuilt binary matches this image.
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN npm ci

FROM deps AS build
WORKDIR /app
COPY . .
RUN npm run build

FROM ${NODE_IMAGE} AS prod-deps
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production
WORKDIR /app

COPY --from=prod-deps /app/node_modules ./node_modules
COPY package.json ./
COPY server ./server
COPY --from=build /app/dist ./dist

RUN mkdir -p /data/uploads /data/backups \
  && useradd --system --uid 10001 --home-dir /app --shell /usr/sbin/nologin manifesto \
  && chown -R manifesto:manifesto /app /data
USER manifesto

ENV PORT=3000 \
    DB_PATH=/data/manifesto.db \
    UPLOAD_DIR=/data/uploads \
    BACKUP_DIR=/data/backups

EXPOSE 3000
CMD ["node", "server/index.js"]
