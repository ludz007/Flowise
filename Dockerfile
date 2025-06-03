# ─────────── STAGE 1: BUILD ─────────────────────────────────────────────
FROM node:20-bullseye AS builder

# Install OS packages required to build native dependencies (like bcrypt)
RUN apt-get update && apt-get install -y \
    build-essential python3 make gcc g++ \
    libx11-dev libxkbfile-dev libsecret-1-dev curl

WORKDIR /app

# Copy only dependency files first (cache layer)
COPY package.json pnpm-lock.yaml ./

# Install pnpm globally
RUN npm install -g pnpm@9

# Install dependencies for all sub-packages
COPY . .
RUN pnpm install --recursive

# Build each package in dependency-safe order
RUN pnpm --filter "./packages/components" run build
RUN pnpm --filter "./packages/ui" run build
RUN pnpm --filter "./packages/server" run build

# ─────────── STAGE 2: RUNTIME ────────────────────────────────────────────
FROM node:20-bullseye

WORKDIR /app

# Chromium for Puppeteer support (if used)
RUN apt-get update && apt-get install -y chromium curl

# Set Puppeteer env vars
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV NODE_OPTIONS=--max-old-space-size=8192

# Install pnpm globally
RUN npm install -g pnpm@9

# Copy built assets from builder
COPY --from=builder /app/packages/ui/build ./packages/ui/build
COPY --from=builder /app/packages/server/dist ./packages/server/dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Expose the web port for Render.com to detect
EXPOSE 3000

# Start the Flowise app
CMD ["node", "packages/server/dist/index.js"]
