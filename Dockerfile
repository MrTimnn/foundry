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
RUN pnpm exec next build

# Stage 2: Production
FROM node:18-alpine AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

RUN apk add --no-cache python3 make g++

# Install pnpm and production dependencies in the runtime image so the
# workspace links resolve the same way they do during the build.
RUN npm install -g pnpm@8.6.10

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/docs/package.json ./apps/docs/package.json
COPY apps/web/package.json ./apps/web/package.json
COPY packages/eslint-config-custom/package.json ./packages/eslint-config-custom/package.json
COPY packages/oracle-engine/package.json ./packages/oracle-engine/package.json
COPY packages/tsconfig/package.json ./packages/tsconfig/package.json
COPY packages/ui/package.json ./packages/ui/package.json

RUN pnpm install --frozen-lockfile --prod

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000

# Copy the built app artifacts and runtime source needed by the server.
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next ./apps/web/.next
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/public ./apps/web/public
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/package.json ./apps/web/package.json
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/src ./apps/web/src
COPY --from=builder --chown=nextjs:nodejs /app/packages ./packages

USER nextjs

WORKDIR /app/apps/web

EXPOSE 3000

CMD ["pnpm", "start", "-p", "3000"]