# Stage 1: Build the application
FROM node:18-alpine AS builder
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile

# Copy the rest of the source code and build the app
COPY . .
RUN pnpm build

# Stage 2: Run the application
FROM node:18-alpine AS runner
WORKDIR /app

# Copy necessary files from the builder stage
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules

# Expose the port your app runs on (Next.js default is 3000)
EXPOSE 3000

# Start the application
CMD ["pnpm", "start"]
