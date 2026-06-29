# Stage 1: Install and build dependencies
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git build-base && \
    npm install -g pnpm@8.15.6

# Copy only essential files
COPY apps/web/package.json ./apps/web/
COPY pnpm-lock.yaml ./
COPY packages/ ./packages/
COPY . .

# Install dependencies and install them globally to make available
RUN cd apps/web && \
    pnpm install --frozen-lockfile && \
    npm install -g pnpm@8.15.6

# Clone search package if needed
RUN if [ ! -d "apps/web/node_modules/@foundry/search" ]; then \
    git clone https://github.com/d2foundry/search.git apps/web/node_modules/@foundry/search; \
    fi

# Generate contentlayer
RUN cd apps/web && npx contentlayer --config contentlayer.config.ts

# Build with next directly (simplified approach)
RUN cd apps/web && pnpm build

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
COPY --from=builder /app/apps/web/content ./content
COPY --from=builder /app/apps/web/next.config.js ./next.config.js

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD ["node_modules/.bin/next", "start"]