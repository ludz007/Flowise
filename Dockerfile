# ─────────── STAGE 1: Build ────────────────────────────────────────────────
FROM node:18-bullseye AS builder

# Install build tools so bcrypt can compile
RUN apt-get update && apt-get install -y build-essential python3 make gcc g++

WORKDIR /usr/src

# Copy monorepo manifest files
COPY package.json pnpm-lock.yaml ./

# Copy entire repo
COPY . .

# Install pnpm, all dependencies, and build everything
RUN npm install -g pnpm@9
RUN pnpm install --recursive
RUN pnpm build

# ─────────── STAGE 2: Runtime ─────────────────────────────────────────────
FROM node:18-bullseye

WORKDIR /usr/src

# Copy built UI and server code from builder
COPY --from=builder /usr/src/packages/ui/build ./packages/ui/build
COPY --from=builder /usr/src/packages/server/dist ./packages/server/dist

# Copy node_modules so Express and other deps are available
COPY --from=builder /usr/src/node_modules ./node_modules

# Expose port 3000 for Render
EXPOSE 3000

# Start the compiled Express server by invoking its exported start() function
CMD ["node", "-e", "require('./packages/server/dist/index').start()"]
