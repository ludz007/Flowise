# ─────────── STAGE 1: Build ────────────────────────────────────────────────
FROM node:18-bullseye AS builder

# Install build tools so bcrypt can compile
RUN apt-get update && apt-get install -y build-essential python3 make gcc g++

WORKDIR /usr/src

# Copy monorepo manifest files
COPY package.json pnpm-lock.yaml ./

# Copy everything else
COPY . .

# Install pnpm, dependencies, and build all packages
RUN npm install -g pnpm@9
RUN pnpm install --recursive
RUN pnpm build

# ─────────── STAGE 2: Runtime ─────────────────────────────────────────────
FROM node:18-bullseye

WORKDIR /usr/src

# Copy built UI and server code from builder stage
COPY --from=builder /usr/src/packages/ui/build ./packages/ui/build
COPY --from=builder /usr/src/packages/server/dist ./packages/server/dist

# Copy package.json + pnpm-lock to install production dependencies
COPY --from=builder /usr/src/package.json /usr/src/pnpm-lock.yaml ./

# Install production-only dependencies, skipping postinstall scripts (e.g. husky)
RUN npm install -g pnpm@9
RUN pnpm install --prod --ignore-scripts

# Tell Docker/Render we listen on port 3000
EXPOSE 3000

# Start the Express server directly
CMD ["node", "packages/server/dist/index.js"]
