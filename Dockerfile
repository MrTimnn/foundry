# Stage 1: Install dependencies
FROM node:18-alpine AS deps
WORKDIR /app

RUN apk add --no-cache python3 make g++ git build-base

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/web/package.json ./apps/web/
COPY packages/ ./packages/

RUN npm install -g pnpm@8.15.6 && \
    pnpm install --frozen-lockfile && \
    npm rebuild better-sqlite3

# Stage 2: Build the app
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git build-base && \
    npm install -g pnpm@8.15.6

# Copy from deps (ALREADY INSTALLED & BUILT) - NO REDUNDANT pnpm install!
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/packages ./packages
COPY . .

# Verify environment
RUN pnpm --version && node --version
# Check installed packages
RUN ls apps/web/node_modules/@foundry/ 2>/dev/null || echo "No @foundry packages"
# Check content files
RUN ls apps/web/content/ 2>/dev/null | head -5 || echo "No content files"

# Clone @foundry/search if not already cloned (pre-built git dependency)
RUN if [ ! -d "apps/web/node_modules/@foundry/search" ]; then \
    git clone https://github.com/d2foundry/search.git apps/web/node_modules/@foundry/search; \
    fi

# Generate contentlayer source
RUN npx contentlayer --config apps/web/contentlayer.config.ts

# Build the project
RUN pnpm build  # Now runs efficiently with pre-installed deps!
