FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git && \
    npm install -g pnpm@8.15.6

COPY . .

RUN pnpm install --frozen-lockfile

# Navigate to web app and build directly
WORKDIR /app/apps/web
RUN pnpm build

# Back to root
WORKDIR /app
