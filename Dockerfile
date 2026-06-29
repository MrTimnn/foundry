# Stage 1: Install dependencies
FROM node:18-alpine AS deps
WORKDIR /app

RUN apk add --no-cache python3 make g++ git

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/web/package.json ./apps/web/
COPY packages/ ./packages/

RUN npm install -g pnpm@8.15.6 && \
    pnpm install --frozen-lockfile

# Stage 2: Build the app
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git && \
    npm install -g pnpm@8.15.6

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages ./packages
COPY --from=deps /app/ui ./ui
COPY . .

WORKDIR /app/apps/web

# Build with Contentlayer + Next.js
RUN pnpm build

# Stage 3: Production runner
FROM node:18-alpine AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy standalone output or .next build
COPY --from=builder /app/apps/web/public ./public
COPY --from=builder /app/apps/web/.next ./.next
COPY --from=builder /app/apps/web/node_modules ./node_modules
COPY --from=builder /app/apps/web/package.json ./package.json
COPY --from=builder /app/apps/web/contentlayer ./contentlayer
COPY --from=builder /app/apps/web/content ./content
COPY --from=builder /app/apps/web/next.config.js ./next.config.js

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD ["node_modules/.bin/next", "start"]
