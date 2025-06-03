# Use a Node version compatible with Flowise (18.18.1 as recommended)
FROM node:18.18.1-alpine AS builder
WORKDIR /app

# Install pnpm and build tools
RUN npm install -g pnpm \
    && apk add --no-cache git python3 make g++ cairo-dev pango-dev chromium

# Copy code and install deps
COPY . .
RUN pnpm install

# Build Flowise (compiles TypeScript to JS)
RUN pnpm build

# Final image
FROM node:18.18.1-alpine
WORKDIR /app

# Copy built code and node_modules from builder
COPY --from=builder /app/packages/server /app/packages/server
COPY --from=builder /app/node_modules /app/node_modules

# Expose the port Flowise will listen on
ENV HOST=0.0.0.0
ENV PORT=3000
EXPOSE 3000

# Start Flowise server
CMD ["node", "packages/server/dist/index.js"]
