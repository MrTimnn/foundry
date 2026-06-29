# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git

# Install pnpm globally
RUN npm install -g pnpm@8.15.6

# Copy app package.json only
COPY apps/web/package.json ./apps/web/

# Install search package directly and other dependencies
RUN pnpm add github:d2foundry/search.git

# Copy all source code
COPY apps/web/ ./apps/web/
COPY packages/ ./packages/

# Generate Contentlayer sources first
RUN cd apps/web && npx contentlayer --config apps/web/contentlayer.config.ts

# Build Next.js app
RUN cd apps/web && pnpm run build

# Stage 2: Production
FROM node:18-alpine AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy production-ready files
COPY --from=builder /app/apps/web/.next ./apps/web/.next
COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder /app/apps/web/node_modules ./apps/web/node_modules
COPY --from=builder /app/apps/web/package.json ./apps/web/package.json

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD ["cd", "apps/web", "&&", "node_modules/.bin/next", "start"]