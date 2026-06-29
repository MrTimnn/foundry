FROM node:18-alpine AS builder
WORKDIR /app

RUN apk add --no-cache python3 make g++ git && \
    npm install -g pnpm@8.15.6

COPY . .

RUN pnpm install --frozen-lockfile

# Build everything without filter
RUN pnpm build
