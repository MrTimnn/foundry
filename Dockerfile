# Stage 1: Install dependencies
FROM node:18-alpine AS deps
WORKDIR /app

RUN apk add --no-cache python3 make g++ git build-base

# Install pnpm globally
RUN npm install -g pnpm@8.15.6

# Copy web app package.json and install dependencies
COPY apps/web/package.json ./
RUN pnpm init --yes

# Clone @foundry/search (git dependency)
RUN git clone --depth 1 https://github.com/d2foundry/search.git ./node_modules/@foundry/search

# Install @foundry/ui (workspace dependency) and other packages
RUN pnpm add @foundry/ui github:d2foundry/search.git

# Stage 2: Build the app
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git build-base
RUN npm install -g pnpm@8.15.6

# Copy source files
COPY apps/web/ ./apps/web/
COPY packages/ ./packages/
COPY . .

# Build Next.js app
RUN cd apps/web && next build

# Stage 3: Production runner
FROM node:18-alpine AS runner
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder /app/apps/web/.next ./apps/web/.next
COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder /app/apps/web/package.json ./apps/web/package.json
COPY --from=builder /app/apps/web/content ./apps/web/content
COPY --from=builder /app/apps/web/next.config.js ./apps/web/next.config.js

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

USER nextjs

EXPOSE 3000

ENV PORT=3000

CMD ["cd", "apps/web", "&&", "node_modules/.bin/next", "start"]