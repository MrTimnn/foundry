# Stage 1: Install and build dependencies
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git build-base

# Copy only essential files
COPY apps/web/package.json ./apps/web/
COPY pnpm-lock.yaml ./
COPY packages/ ./packages/
COPY . .

# Install dependencies with optimized settings to avoid native compilation issues
RUN echo "Installing dependencies..." && \
    # Explicitly install search package first
    if [ ! -d "apps/web/node_modules/@foundry/search" ]; then \
        git clone --depth 1 https://github.com/d2foundry/search.git apps/web/node_modules/@foundry/search; \
    fi && \
    # Install remaining dependencies with optimized settings for Alpine
    cd apps/web && \
    NODE_OPTIONS="--max-old-space-size=4096" \
    pnpm install --frozen-lockfile --prefer-offline --ignore-scripts && \
    # Clear npm cache to reduce build size
    rm -rf ~/.npm && rm -rf /root/.cache/pnpm

# Generate contentlayer
RUN cd apps/web && npx contentlayer --config contentlayer.config.ts

# Build the Next.js app (using pnpm run build as specified in root package.json)
RUN cd apps/web && pnpm run build

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