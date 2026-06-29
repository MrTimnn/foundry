# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git

# Install pnpm globally
RUN npm install -g pnpm@8.6.10

# Copy workspace manifests first so pnpm can resolve the monorepo correctly.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/docs/package.json ./apps/docs/package.json
COPY apps/web/package.json ./apps/web/package.json
COPY packages/eslint-config-custom/package.json ./packages/eslint-config-custom/package.json
COPY packages/oracle-engine/package.json ./packages/oracle-engine/package.json
COPY packages/tsconfig/package.json ./packages/tsconfig/package.json
COPY packages/ui/package.json ./packages/ui/package.json

RUN pnpm install --frozen-lockfile

# Copy the full source tree after dependencies are installed.
COPY . .

WORKDIR /app/apps/web

# Generate Contentlayer sources before the Next.js build.
RUN pnpm exec contentlayer --config contentlayer.config.ts

# Build Next.js app
RUN pnpm run build

# Stage 2: Production
FROM node:18-alpine AS runner
WORKDIR /app/apps/web

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000

# The app opens a relative SQLite path at src/lib/database/sqlite.db.
# Create the directory and copy it so the runtime user can create the file.
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/src/lib/database ./src/lib/database

USER nextjs

EXPOSE 3000

CMD ["./node_modules/.bin/next", "start", "-p", "3000"]