# Multi-stage: install deps, build Next.js, run with npm start (Prisma migrate + next start)
# Use Debian (glibc) for reliable Prisma engines; Alpine+musl can fail on some architectures.
# See .github/workflows/ci-cd.yml for required GitHub secrets and Coolify runtime env.

# -----------------------------------------------------------------------------
# Dependencies
# -----------------------------------------------------------------------------
FROM node:20-bookworm-slim AS deps
WORKDIR /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json ./
RUN npm ci

# -----------------------------------------------------------------------------
# Build (prisma generate + next build)
# -----------------------------------------------------------------------------
FROM node:20-bookworm-slim AS builder
WORKDIR /app
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
ENV NEXT_TELEMETRY_DISABLED=1
ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}
# Satisfies build-time if tools expect DATABASE_URL; production uses Coolify env
ARG DATABASE_URL=postgresql://placeholder:placeholder@127.0.0.1:5432/placeholder?schema=public
ENV DATABASE_URL=${DATABASE_URL}
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# -----------------------------------------------------------------------------
# Production runner (curl for Coolify/health checks)
# -----------------------------------------------------------------------------
FROM node:20-bookworm-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN apt-get update \
  && apt-get install -y --no-install-recommends curl openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --system --gid 1001 nodejs \
  && useradd --system --uid 1001 --gid nodejs nextjs
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/prisma ./prisma
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0
# Coolify: e.g. curl -f http://127.0.0.1:3000/api/healthz
CMD ["npm", "run", "start"]
