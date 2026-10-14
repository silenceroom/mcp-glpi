# syntax=docker/dockerfile:1

# Build stage: compile TypeScript, then drop the devDependencies from the same
# tree (`npm prune` beats a second `npm ci --omit=dev` — no second install).
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

# Runtime stage: dist/ plus production dependencies, nothing else.
FROM node:24-alpine AS runtime
ARG VERSION=0.0.0
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/package.json ./package.json
LABEL org.opencontainers.image.title="mcp-glpi" \
      org.opencontainers.image.description="MCP server for GLPI (IT Service Management)" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="MIT"
USER node

# ENTRYPOINT (not CMD) so the CLI flags pass straight through:
#   docker run --rm mcp-glpi --http --host 0.0.0.0 --port 3000
# With CMD, `docker run <image> --http` would replace the whole command instead.
#
# No HEALTHCHECK here on purpose: /health only exists in HTTP mode, so a
# Dockerfile-level probe would report every stdio container as unhealthy.
# docker-compose.yml defines it, where the transport is known to be HTTP.
ENTRYPOINT ["node", "dist/index.js"]
