# Stage 1: Install dependencies
FROM node:18-alpine AS deps
WORKDIR /app

RUN apk add --no-cache python3 make g++ git

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml turbo.json ./
COPY apps/web/package.json ./apps/web/
COPY packages/ ./packages/

RUN npm install -g pnpm@8.15.6 && \
    pnpm install --frozen-lockfile

# Stage 2: Build the app
FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git && \
    npm install -g pnpm@8.15.6

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
RUN npx contentlayer generate
# Run Turborepo build

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
