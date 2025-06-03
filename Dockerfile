# ─────────── STAGE 1: Build ────────────────────────────────────────────────
FROM node:18.18.1-alpine AS builder

WORKDIR /app

# 1) Install pnpm and build tools (needed for bcrypt, etc.)
RUN npm install -g pnpm@9 \
    && apk add --no-cache python3 make g++ libc6-compat

# 2) Copy repo manifest and source code
COPY package.json pnpm-lock.yaml ./
COPY . .

# 3) Install all dependencies and build UI + server
RUN pnpm install --shamefully-hoist
RUN pnpm build

# ─────────── STAGE 2: Runtime ─────────────────────────────────────────────
FROM node:18.18.1-alpine

WORKDIR /app

# 1) Copy compiled server code
COPY --from=builder /app/packages/server/dist ./packages/server/dist

# 2) Copy the built UI (if you serve static assets)
COPY --from=builder /app/packages/ui/build ./packages/ui/build

# 3) Copy node_modules (so express, cors, bcrypt, etc. are available)
COPY --from=builder /app/node_modules ./node_modules

# 4) Ensure the server binds to 0.0.0.0 and uses PORT=3000 by default
ENV HOST=0.0.0.0
ENV PORT=3000

# 5) Expose port 3000 so Render’s port scanner can find it
EXPOSE 3000

# 6) Finally, explicitly call start() so Express actually listens:
CMD ["node", "-e", "require('./packages/server/dist/index').start()"]
