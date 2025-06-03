# ─────────── STAGE 1: Build ────────────────────────────────────────────────
FROM node:20-bullseye AS builder

WORKDIR /usr/src

# 1) Install build tools (for bcrypt, pdfjs, etc.)
RUN apt-get update \
 && apt-get install -y python3 make g++ libcairo2-dev libpango1.0-dev curl \
 && rm -rf /var/lib/apt/lists/*

# 2) Install pnpm globally
RUN npm install -g pnpm@9

# 3) Copy source files
COPY package.json pnpm-lock.yaml ./
COPY . .

# 4) Install dependencies & build
RUN pnpm install --recursive
RUN pnpm build

# ─────────── STAGE 2: Runtime ─────────────────────────────────────────────
FROM node:20-bullseye AS runner

WORKDIR /usr/src

# 1) Copy built server code
COPY --from=builder /usr/src/packages/server/dist ./packages/server/dist

# 2) Copy built UI (if you serve it)
COPY --from=builder /usr/src/packages/ui/build ./packages/ui/build

# 3) Copy node_modules (so express, cors, bcrypt, chromium, etc. are available)
COPY --from=builder /usr/src/node_modules ./node_modules

# 4) Install Chromium runtime dependencies
RUN apt-get update \
 && apt-get install -y chromium \
 && rm -rf /var/lib/apt/lists/*

# 5) Set environment so Puppeteer uses the system Chromium
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# 6) Ensure the server binds to 0.0.0.0:3000
ENV HOST=0.0.0.0
ENV PORT=3000

EXPOSE 3000

# 7) Explicitly call start() so Express actually listens on PORT
CMD ["node", "-e", "require('./packages/server/dist/index').start()"]
