# ─────────── STAGE 1: BUILD EVERYTHING ───────────────────────────────────
FROM node:18-bullseye AS builder

# 1) Install all build‐time prerequisites (bcrypt, Cairo/Pango for UI, etc.)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      python3 \
      make \
      g++ \
      libcairo2-dev \
      libpango1.0-dev \
      libjpeg62-turbo-dev \
      libgif-dev \
      librsvg2-dev \
 && rm -rf /var/lib/apt/lists/*

# 2) Install PNPM globally, set working dir
WORKDIR /app
RUN npm install -g pnpm@9

# 3) Copy only the workspace’s pnpm‐lockfiles so that pnpm can resolve everything
COPY package.json        pnpm-lock.yaml         ./

# 4) Do a recursive install of all workspaces (ui, server, components, etc.)
#    This pulls in every dependency, including native ones (bcrypt, etc.)
RUN pnpm install --recursive

# 5) Copy the entire monorepo into /app and run the build scripts
COPY . .
RUN pnpm build

# ─────────── STAGE 2: RUNTIME ─────────────────────────────────────────────
FROM node:18-bullseye-slim

# 6) At runtime we only need the shared node_modules, the compiled server, and minimal OS libs
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libcairo2 \
      libpango1.0-0 \
      libjpeg62-turbo \
      libgif7 \
      librsvg2-2 \
      chromium \
      curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 7) Copy exactly the node_modules folder from the builder (all production deps)
COPY --from=builder /app/node_modules ./node_modules

# 8) Copy the compiled server code into the same relative path
COPY --from=builder /app/packages/server/dist ./packages/server/dist

# 9) Copy package.json in case the server code looks for it
COPY --from=builder /app/package.json ./package.json

# 10) Tell Puppeteer/Flowise where Chromium lives
ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV NODE_ENV=production

# 11) Make sure port 3000 is exposed
EXPOSE 3000

# 12) Invoke the server’s exported `start()` directly.
#     This bypasses any “pnpm start → oclif start” chain and guarantees
#     that Express actually listens on 0.0.0.0:3000.
CMD ["node", "-e", "require('./packages/server/dist/index').start()"]
