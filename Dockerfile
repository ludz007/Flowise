# ─────────── STAGE 1: Build ────────────────────────────────────────────────
FROM node:18-bullseye AS builder

# Install build tools so bcrypt can compile its native bindings
RUN apt-get update && apt-get install -y build-essential python3 make gcc g++

WORKDIR /usr/src

# Copy monorepo manifest files
COPY package.json pnpm-lock.yaml ./

# Copy entire repository
COPY . .

# Install pnpm, dependencies, and build everything (UI + server)
RUN npm install -g pnpm@9
RUN pnpm install --recursive
RUN pnpm build

# ─────────── STAGE 2: Runtime ─────────────────────────────────────────────
FROM node:18-bullseye

WORKDIR /usr/src

# 1) Copy compiled UI assets (for any static pages)
COPY --from=builder /usr/src/packages/ui/build ./packages/ui/build

# 2) Copy compiled server code
COPY --from=builder /usr/src/packages/server/dist ./packages/server/dist

# 3) Copy the entire node_modules folder so runtime has express, cors, bcrypt, etc.
COPY --from=builder /usr/src/node_modules ./node_modules

# Expose port 3000 so Render’s port scanner can detect it
EXPOSE 3000

# 4) Start the Express server by explicitly calling start()
CMD ["node", "-e", "require('./packages/server/dist/index').start()"]
