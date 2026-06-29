# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

# Install build dependencies
RUN apk add --no-cache python3 make g++ git && \
    npm install -g pnpm@8.15.6

# Copy all package files first (better layer caching)
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY turbo.json ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy the entire project
COPY . .

# Build all apps (not just web)
RUN pnpm run build

# Stage 2: Production
FROM node:18-alpine AS runner
WORKDIR /app

# Install pnpm
RUN npm install -g pnpm@8.15.6

# Copy the built web app and its dependencies
COPY --from=builder /app/apps/web/.next ./apps/web/.next
COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder /app/apps/web/package.json ./apps/web/package.json
COPY --from=builder /app/apps/web/next.config.js ./apps/web/next.config.js 2>/dev/null || echo "No next.config.js found"

# Copy shared packages
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Copy any other necessary files
COPY --from=builder /app/apps/web/.env* ./apps/web/ 2>/dev/null || echo "No .env files found"

WORKDIR /app/apps/web

EXPOSE 3000

# Start with proper production command
CMD ["pnpm", "start"]# Stage 1: Build
FROM node:18-alpine AS builder
WORKDIR /app

# Install pnpm and build tools
RUN npm install -g pnpm@8.15.6 && \
    apk add --no-cache python3 make g++ git

# Copy root package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY turbo.json ./

# Copy all workspaces
COPY apps/web ./apps/web
COPY packages/ ./packages/

# Install all dependencies
RUN pnpm install --frozen-lockfile

# Build the web app with verbose output
RUN pnpm build --filter=web --verbose

# Stage 2: Production
FROM node:18-alpine AS runner
WORKDIR /app

# Install pnpm in runner
RUN npm install -g pnpm@8.15.6

# Copy necessary files
COPY --from=builder /app/apps/web/.next ./apps/web/.next
COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder /app/apps/web/package.json ./apps/web/package.json
COPY --from=builder /app/apps/web/next.config.js ./apps/web/next.config.js 2>/dev/null || true
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/package.json ./package.json

# Set working directory to web app
WORKDIR /app/apps/web

EXPOSE 3000

# Start the application
CMD ["pnpm", "start"]
