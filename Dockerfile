# Broccers — Dockerfile multi-stage
# Stage 1 : build (Dart compile-exe avec toutes les sources)
# Stage 2 : runtime (Alpine minimal avec juste le binaire + tools)

# ============================================================================
# STAGE 1 — BUILD
# ============================================================================
FROM dart:stable AS build

WORKDIR /app

# Copy workspace + packages
COPY pubspec.yaml ./
COPY packages/ ./packages/
COPY scripts/ ./scripts/

# Resolve dependencies
RUN dart pub get

# Compile br_server to a native executable
RUN dart compile exe packages/br_server/bin/server.dart -o /app/br_server

# ============================================================================
# STAGE 2 — RUNTIME
# ============================================================================
FROM debian:bookworm-slim

# Runtime dependencies : SQLite (used by sqlite3 Dart binding via ffi),
# ca-certificates pour HTTPS calls éventuels, curl pour healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libsqlite3-0 \
      ca-certificates \
      curl \
      tzdata && \
    rm -rf /var/lib/apt/lists/*

# Time zone (defaults to Europe/Paris for Broc)
ENV TZ=Europe/Paris

# Application directories
RUN mkdir -p /app/data /app/docs && \
    groupadd -r broccers && useradd -r -g broccers -d /app -s /sbin/nologin broccers

WORKDIR /app

# Copy artifacts from build stage
COPY --from=build --chown=broccers:broccers /app/br_server /app/br_server

# Copy docs (served by br_server via /docs/* routes)
COPY --chown=broccers:broccers docs/ /app/docs/

# Default environment (override via docker run -e)
ENV BR_HOST=0.0.0.0
ENV BR_PORT=8444
ENV BR_DATA_DIR=/app/data
ENV BR_DB_PATH=/app/data/broc.db
ENV DOCKER_CONTAINER=1

# Healthcheck : the server's /api/health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -fs http://localhost:${BR_PORT}/api/health || exit 1

USER broccers

EXPOSE 8444

ENTRYPOINT ["/app/br_server"]
