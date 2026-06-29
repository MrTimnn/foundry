# Stage 1: Dependencies
FROM node:18-alpine AS deps
WORKDIR /app

RUN apk add --no-cache python3 make g++ git

RUN npm install -g pnpm@8.15.6

COPY apps/web/package.json ./apps/web/
COPY pnpm-lock.yaml ./
RUN cd apps/web && pnpm install --frozen-lockfile

# Stage 2: Build
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git
RUN npm install -g pnpm@8.15.6

COPY apps/web/ ./apps/web/
COPY packages/ ./packages/
COPY . .

RUN cd apps/web && next build

# Stage 3: Production
FROM node:18-alpine AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/apps/web/.next ./apps/web/.next
COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder /app/apps/web/package.json ./apps/web/package.json
COPY --from=builder /app/apps/web/content ./apps/web/content
COPY --from=builder /app/apps/web/next.config.js ./apps/web/next.config.js

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD ["cd", "apps/web", "&&", "node_modules/.bin/next", "start"]

CMD ["cd", "apps/web", "&&", "node_modules/.bin/next", "start"]