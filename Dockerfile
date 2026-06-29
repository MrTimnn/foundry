# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

# Install pnpm and build dependencies
RUN npm install -g pnpm && \
    apk add --no-cache python3 make g++

# Copy package files for all workspaces
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/ ./apps/
COPY packages/ ./packages/
COPY turbo.json ./

# Install dependencies for all workspaces
RUN pnpm install --frozen-lockfile --filter=web

# Build only the web app
RUN pnpm build --filter=web

# Stage 2: Production
FROM node:18-alpine AS runner
WORKDIR /app

# Copy built web app and its dependencies
COPY --from=builder /app/apps/web/.next ./apps/web/.next
COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder /app/apps/web/package.json ./apps/web/package.json
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages ./packages

# Copy the workspace package.json
COPY --from=builder /app/package.json ./package.json

WORKDIR /app/apps/web

EXPOSE 3000

CMD ["pnpm", "start"]
