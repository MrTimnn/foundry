# Stage 1: Install and build dependencies
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git

# Copy only essential files
COPY apps/web/package.json ./apps/web/
COPY pnpm-lock.yaml ./
COPY packages/ ./packages/
COPY . .

# Install search package as it's a direct dependency
RUN if [ ! -d "apps/web/node_modules/@foundry/search" ]; then \
    cd apps/web && git clone --depth 1 https://github.com/d2foundry/search.git ./node_modules/@foundry/search; \
    fi

# Install all remaining dependencies
RUN cd apps/web && pnpm install --frozen-lockfile

# Generate contentlayer
RUN cd apps/web && npx contentlayer --config contentlayer.config.ts

# Build the Next.js app
RUN cd apps/web && next build

# Stage 2: Production runner
FROM node:18-alpine AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy runtime dependencies and built application
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