# Stage 1: Dependencies
FROM node:18-alpine AS deps
WORKDIR /app

RUN apk add --no-cache python3 make g++ git

# Install pnpm
RUN npm install -g pnpm@8.15.6

# Copy package files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/web/package.json ./apps/web/
COPY packages/ ./packages/

# Install all dependencies
RUN cd apps/web && pnpm install --frozen-lockfile

# Stage 2: Build
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git
RUN npm install -g pnpm@8.15.6

# Copy source files
COPY apps/web/ ./apps/web/
COPY packages/ ./packages/
COPY . .

# Build using pnpm's next build script
RUN cd apps/web && pnpm run build

# Stage 3: Production
FROM node:18-alpine AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy only runtime dependencies and build output
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